#!/usr/bin/env node
"use strict";
/* cowsay_full.js - the compatibility build in JavaScript: one file, no dependencies,
 * the same source on Node and Bun. A feature-matched port of the Perl cowsay 3.8.5,
 * byte-identical to it on stdout+stderr+exit code under differential fuzzing:
 *   python3 eval_full.py --extra --impl "node cowsay_full.js"   # 375/375; same under bun
 *   bun build --compile --bytecode cowsay_full.js --outfile cowsay_full_bun   # standalone, 375/375
 * Everything is handled as BYTES (latin1 strings): Perl measures and wraps in bytes,
 * so a 4-byte emoji is four columns wide. The Perl quirks that had to be reproduced
 * are commented where they bite; the README carries the long form. */
const fs = require("fs"), path = require("path"), tty = require("tty");

const VERSION = "3.8.5-SNAPSHOT", TABSTOP = 8;
const B = s => Buffer.from(s, "latin1");          // byte string -> bytes
const L = b => b.toString("latin1");              // bytes -> byte string
const bytes = s => L(Buffer.from(s, "utf8"));     // JS string (argv, env) -> byte string

/* Perl truthiness: "" and "0" are false. Numeric context: the leading numeric prefix. */
const perlTrue = s => s !== undefined && s !== "" && s !== "0";
function perlNum(v) {
    if (typeof v === "number") return v;
    const m = /^[\t\n\v\f\r ]*([+-]?(?:\d+\.?\d*(?:e[+-]?\d+)?|\.\d+(?:e[+-]?\d+)?|inf(?:inity)?|nan))/i.exec(v || "");
    if (!m) return 0;
    const s = m[1].toLowerCase();
    return s.includes("inf") ? (s[0] === "-" ? -Infinity : Infinity) : s.includes("nan") ? NaN : Number(m[1]);
}
function perlSplit(s, re) {                       // split: nothing from "", trailing empty fields dropped
    const f = s === "" ? [] : s.split(re);
    while (f.length && f[f.length - 1] === "") f.pop();
    return f;
}
function lines(s) {                               // chomp(@lines = <FH>)
    const out = [];
    for (let i = 0; i < s.length;) {
        const j = s.indexOf("\n", i);
        if (j < 0) { out.push(s.slice(i)); break; }
        out.push(s.slice(i, j)); i = j + 1;
    }
    return out;
}

/* $0. Node keeps the invoked (symlink) name in argv[1]; a Bun-compiled binary reports a
 * virtual /$bunfs/ entry, so there the binary itself is the program. */
const compiled = typeof Bun !== "undefined" && (process.argv[1] || "").startsWith("/$bunfs/");
const invoked = compiled ? process.execPath : (process.argv[1] || "cowsay");
const progname = bytes(path.basename(invoked));
const think = /think/i.test(progname);

/* --- I/O: one write for stdout, raw bytes in, raw bytes out ---------------------- */
const pause = () => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 1);
function writeAll(fd, buf) {
    for (let off = 0; off < buf.length;) {
        try { off += fs.writeSync(fd, buf, off, buf.length - off); }
        catch (e) {
            if (e.code === "EAGAIN") { pause(); continue; }
            if (e.code === "EPIPE") return;
            throw e;
        }
    }
}
const out = s => writeAll(1, B(s)), err = s => writeAll(2, B(s));
const exit = code => process.exit(code);
const die = (msg, code) => { err(msg); exit(code); };
function readStdin() {
    const chunks = [], buf = Buffer.alloc(1 << 16);
    for (;;) {
        let n;
        try { n = fs.readSync(0, buf, 0, buf.length, null); }
        catch (e) {
            if (e.code === "EAGAIN") { pause(); continue; }
            if (e.code === "EOF" || e.code === "EBADF") break;
            throw e;
        }
        if (!n) break;
        chunks.push(Buffer.from(buf.subarray(0, n)));
    }
    return L(Buffer.concat(chunks));
}
const stat = p => { try { return fs.statSync(B(p)); } catch (e) { return null; } };
const lstat = p => { try { return fs.lstatSync(B(p)); } catch (e) { return null; } };
const isFile = p => { const s = stat(p); return !!s && s.isFile(); };
const isDir = p => { const s = stat(p); return !!s && s.isDirectory(); };
const readFile = p => { try { return L(fs.readFileSync(B(p))); } catch (e) { return null; } };
const readDir = p => { try { return fs.readdirSync(B(p), { encoding: "buffer" }).map(L); } catch (e) { return []; } };

/* --- Text::Tabs::expand: the offset restarts after every tab, which is column-equivalent */
function expandLine(line) {
    let s = "", offs;
    for (const seg of line.split("\t")) {
        if (offs !== undefined) s += " ".repeat(TABSTOP - offs % TABSTOP);
        s += seg; offs = seg.length;
    }
    return s;
}
const expand = text => text.split(/(?<=\n)/).map(expandLine).join("");

/* --- Text::Wrap 2024.001 ----------------------------------------------------------
 * wrap("", "", $text) with $Text::Wrap::columns = W.columns; W is an object because
 * wrap() writes $columns back (see the "3" below).
 * $break is '(?>\n|\r\n|[^\x{a0}\x{202f}\S]\pM*)'. That pattern holds a code point above
 * 0xFF, so Perl applies Unicode rules to the BYTE string: NEL (0x85) is whitespace and a
 * break, NBSP (0xA0) is excluded by name. fill()'s own s/\s+/ /g has no such code point
 * and stays ASCII. Net effect: a UTF-8 'Å' (C3 85) can wrap in the middle. */
const isBreak = c => c === " " || c === "\x85" || (c >= "\t" && c <= "\r");
const allBreaks = (t, i) => { for (; i < t.length; i++) if (!isBreak(t[i])) return false; return true; };
function wrap(text, W) {
    const t = expand(text), len = t.length;
    const nll = W.columns - 1;                   // later lines: NOT clamped, so -W 0 makes {0,-1} literal braces
    let ll = nll < 0 ? 0 : nll;                  // first line
    let r = "", remainder = "", nl = "", pos = 0, zeroAt = -1;
    while (!allBreaks(t, pos)) {
        const avail = len - pos;
        let k = -1;
        if (ll >= 0) {                           // /\G(X{0,$ll})($break|\n+|\z)/: greedy, longest first
            let maxk = Math.min(avail, ll);
            const nlAt = t.indexOf("\n", pos);
            if (nlAt >= 0 && nlAt - pos < maxk) maxk = nlAt - pos;
            for (let j = maxk; j >= 0; j--) {
                const p = pos + j;
                if (p === len) { k = j; remainder = ""; break; }
                if (isBreak(t[p])) { k = j; remainder = t[p] === "\r" && t[p + 1] === "\n" ? "\r\n" : t[p]; break; }
            }
        }
        if (k >= 0) {
            r += nl + t.slice(pos, pos + k);
            pos += k + remainder.length;         // the break is consumed, and re-appended after the LAST line:
        } else if (ll > 0 && avail >= ll) {      //   a paragraph ending in a space gets a trailing-space line
            r += nl + t.slice(pos, pos + ll);    // $huge eq 'wrap': hard split at exactly $ll
            pos += ll; remainder = "\n";
        } else if (ll === 0 && zeroAt !== pos) { // X{0} matches empty once; Perl refuses a second
            r += nl; remainder = "\n"; zeroAt = pos;   //   zero-length match at the same position
        } else if (W.columns < 2) {
            W.columns = 2;                       // "Increasing $Text::Wrap::columns from N to 2": the NEXT
            return "3";                          //   paragraph wraps at 2; this one is `return @_` evaluated
        } else {                                 //   in fill()'s scalar context, i.e. the argument count
            throw new Error("This shouldn't happen");   // Perl's own text; unreachable for integer widths
        }
        ll = nll; nl = "\n";
    }
    return r + remainder;
}
/* fill("", "", @lines): paragraphs split on /\n\s+/, whitespace squeezed, "\n\n"-joined.
 * No s/\A // in this version, so a leading space survives and widens the box. */
const fill = (ls, W) => perlSplit(ls.join("\n"), /\n[\t\n\v\f\r ]+/)
    .map(pp => wrap(pp.replace(/[\t\n\v\f\r ]+/g, " "), W)).join("\n\n");

/* --- Getopt::Std::getopts, warts included: warns and continues on unknown options, so
 * `-notaflag` sets -n and -t, then hands "lag" to -f. Only the first `--` ends parsing;
 * each extra leading dash is one more "Unknown option: -". */
const OPTSTR = "bCde:f:ghlLnNprstT:wW:y";
function getopts(argv) {
    const opts = { e: "oo", f: "default.cow", n: 0, T: "  ", W: 40 };
    let m;
    while (argv.length && (m = /^-([\s\S])([\s\S]*)$/.exec(argv[0]))) {
        let [, first, rest] = m;
        if (argv[0] === "--") { argv.shift(); break; }
        const pos = OPTSTR.indexOf(first);
        if (pos >= 0) {
            if (OPTSTR[pos + 1] === ":") {
                argv.shift();
                if (rest === "") rest = argv.shift();      // undefined when the value is missing
                opts[first] = rest;
            } else {
                opts[first] = 1;
                if (rest === "") argv.shift(); else argv[0] = "-" + rest;
            }
        } else if (first === "-" && (rest === "help" || rest === "version")) {
            out(`${progname} version ${VERSION}\n`);       // Perl adds two lines naming its own
            if (rest === "help") out(help());              //   Getopt::Std and perl versions
            exit(0);
        } else {
            err(`Unknown option: ${first}\n`);
            if (rest !== "") argv[0] = "-" + rest; else argv.shift();
        }
    }
    return opts;
}

/* Byte-for-byte the Perl HELP_MESSAGE heredoc. */
const help = () => `${progname} version ${VERSION}

Usage:

    ${progname} [-bdgpstwy] [-f <cowfile>] [-r [-C]] [-e <eyes>] [-T <tongue>]
        [-W <wrapcolumn>] [-n]
        <message>

    ${progname} -l              # List defined cows
    ${progname} [-h | --help]   # Display this help screen

Options:

    -b, -d, -g, -s, -t, -w, and -y activate Borg, dead, greedy, sleepy, tired, wired, and
        young appearance modes, respectively.

    -f <cowfile> selects an alternate cow picture. <cowfile> may be either the name of a
        cow defined in a cowdir on the cowpath (without the '.cow' file extension), or the
        path to a cowfile (with the '.cow' file extension). \`${progname} -l\` will list the
        names of available cows.

    -r selects a random cowfile from those present on the cowpath. If -C is also given,
        then full-color cows will be included.

    -e <eyes> defines a custom eye appearance. <eyes> should be a two-character string.
        It is up to you whether they actually look like eyes.

    -T <tongue> defines a custom tongue appearance.

    -n activates word wrapping, to support messages with arbitrary whitespace. Must be the
        last option given before <message> starts.

    -W <wrapcolumn> controls where line wrapping occurs. Default is 40 columns.

`;

/* --- cowpath: derived from the program's own location like the Perl (abs_path(__FILE__)),
 * so an installed /usr/local/bin/supercowsay uses /usr/local/share/cowsay. Defaults, then
 * $prefix/etc/cowsay/cowpath.d/*.path, then $COWPATH (alone if COWSAY_ONLY_COWPATH == 1). */
let cowpathCache;
function cowpath() {
    if (cowpathCache) return cowpathCache;
    let script = invoked;
    try { script = fs.realpathSync(script); } catch (e) { script = path.resolve(script); }
    const prefix = path.dirname(path.dirname(script));
    let real = prefix;
    try { real = fs.realpathSync(prefix); } catch (e) { /* keep */ }
    const share = bytes(prefix) + "/share/cowsay";
    const dirs = [share + "/site-cows", share + "/cows"];
    const cpd = bytes(real === "/usr" ? "/etc" : real + "/etc") + "/cowsay/cowpath.d";
    if (isDir(cpd))
        for (const f of readDir(cpd))
            if (isFile(cpd + "/" + f) && f.endsWith(".path"))
                for (const entry of lines(readFile(cpd + "/" + f) || "")) dirs.push(entry);
    let cp = dirs;
    if (perlTrue(process.env.COWPATH)) {
        const user = perlSplit(bytes(process.env.COWPATH), /:/);
        cp = perlNum(process.env.COWSAY_ONLY_COWPATH) === 1 ? user : dirs.concat(user);
    }
    return (cowpathCache = [...new Set(cp)]);   // uniquify_list: first occurrence wins
}
function findCow(name) {                        // resolve_cow, minus the die
    for (const d of cowpath()) {
        if (isFile(d + "/" + name)) return d + "/" + name;
        if (isFile(d + "/" + name + ".cow")) return d + "/" + name + ".cow";
    }
    return null;
}
/* File::Find walk: symlinked directories are not descended, symlinked files count.
 * Names are relative to the cowdir with ".cow" stripped. File::Find drops one trailing
 * slash from the start directory but cowsay slices by the unstripped length, so
 * COWPATH=dir/ lists "efault" for default.cow. Reproduced. */
function findCows(base, rel, found) {
    for (const e of readDir(rel ? base + "/" + rel : base)) {
        const sub = rel ? rel + "/" + e : e, ls = lstat(base + "/" + sub);
        if (!ls) continue;
        if (ls.isDirectory()) findCows(base, sub, found);
        else if (sub.endsWith(".cow") && isFile(base + "/" + sub)) found.push(sub);
    }
}
function cowsIn(d) {
    const top = d.length > 1 ? d.replace(/\/$/, "") : d, found = [];
    findCows(top, "", found);
    return found.map(sub => (top + "/" + sub).slice(d.length + 1).replace(/\.cow$/, ""));
}
const perlCmp = (a, b) => (a < b ? -1 : a > b ? 1 : 0);   // sort: bytewise
function listCowfiles() {
    const dirs = cowpath();
    if (tty.isatty(1)) {                        // per directory, wrapped at the default 76 columns
        let s = "", first = true;
        for (const d of dirs) {
            if (!isDir(d)) continue;
            const cows = cowsIn(d).sort(perlCmp);
            if (!cows.length) continue;
            if (!first) s += "\n";
            first = false;
            const t = cows.slice(0, -1).map(c => (/[\t\n\v\f\r ]$/.test(c) ? c : c + " ")).join("") + cows[cows.length - 1];
            s += "Cow files in " + d + ":\n" + wrap(t, { columns: 76 }) + "\n";
        }
        out(s);
    } else {                                     // one name per line, deduped across directories
        const all = new Set();
        for (const d of dirs) if (isDir(d)) for (const c of cowsIn(d)) all.add(c);
        out([...all].sort(perlCmp).join("\n") + "\n");
    }
    exit(0);
}

/* --- cowfiles: `$the_cow = <<"EOC"; ... EOC` is a Perl double-quoted heredoc. We take the
 * heredoc body instead of running the file: $thoughts/$eyes/$tongue interpolate, any other
 * $scalar or @array interpolates to NOTHING (so "@home" silently vanishes), backslash
 * escapes apply, and a <<'EOC' body is taken raw. */
const DEFAULT_COW_RAW =
    "        $thoughts   ^__^\n" +
    "         $thoughts  ($eyes)\\\\_______\n" +
    "            (__)\\\\       )\\\\/\\\\\n" +
    "             $tongue ||----w |\n" +
    "                ||     ||\n";
function extractHeredoc(src) {
    let p = src.indexOf("$the_cow");
    if (p < 0 || (p = src.indexOf("<<", p)) < 0) return null;
    p += 2;
    while (src[p] === " " || src[p] === "\t") p++;
    const q = src[p] === '"' || src[p] === "'" ? src[p++] : "";
    let tag = "";
    while (p < src.length && /[A-Za-z0-9_]/.test(src[p])) tag += src[p++];
    if (q && src[p] === q) p++;
    const nl = src.indexOf("\n", p);
    if (nl < 0) return null;
    let body = "";
    for (p = nl + 1; p < src.length;) {
        const eol = src.indexOf("\n", p), end = eol < 0 ? src.length : eol, line = src.slice(p, end);
        if (line === tag) break;
        body += line + "\n";
        if (eol < 0) break;
        p = eol + 1;
    }
    return { body, raw: q === "'" };
}
function interpolate(raw, vars) {
    let s = "", m;
    for (let i = 0; i < raw.length;) {
        const c = raw[i];
        if (c === "\\" && i + 1 < raw.length) {
            const d = raw[i + 1];
            i += 2;
            if (d === "n") s += "\n";
            else if (d === "t") s += "\t";
            else if (d === "r") s += "\r";
            else if (d === "f") s += "\f";
            else if (d === "e") s += "\x1b";
            else if (d === "a") s += "\x07";
            else if (d >= "0" && d <= "7") {
                m = /^[0-7]{1,3}/.exec(raw.slice(i - 1, i + 2));
                s += String.fromCharCode(parseInt(m[0], 8) & 0xff); i += m[0].length - 1;
            } else if (d === "x") {
                m = /^(?:\{([0-9a-f]*)\}|([0-9a-f]{0,2}))/i.exec(raw.slice(i, i + 20));
                s += String.fromCharCode(parseInt((m[1] !== undefined ? m[1] : m[2]) || "0", 16) & 0xff);
                i += m[0].length;
            } else s += d;                               // \\ \$ \@ \" and anything unknown
            continue;
        }
        if ((c === "$" || c === "@") && (m = /^(?:([A-Za-z_]\w*)|\{\s*([A-Za-z_]\w*)\s*\})/.exec(raw.slice(i + 1, i + 80)))) {
            const name = m[1] || m[2];
            if (c === "$" && Object.prototype.hasOwnProperty.call(vars, name)) s += vars[name];
            i += 1 + m[0].length;
            continue;
        }
        s += c; i++;
    }
    return s;
}

function balloon(message) {
    let max = 0;
    for (const l of message) if (l.length > max) max = l.length;
    const bd = think ? "()()()" : message.length < 2 ? "<>" : "/\\\\/||";   // ul ur dl dr l r
    const row = (l, r, s) => l + " " + s + " ".repeat(max - s.length) + " " + r + "\n";   // %s %-${max}s %s
    let s = " " + "_".repeat(max + 2) + "\n" + row(bd[0], bd[1], message.length ? message[0] : "");
    if (message.length >= 2) {
        for (let i = 1; i < message.length - 1; i++) s += row(bd[4], bd[5], message[i]);
        s += row(bd[2], bd[3], message[message.length - 1]);
    }
    return s + " " + "-".repeat(max + 2) + "\n";
}

function main() {
    const argv = process.argv.slice(2).map(bytes);
    const opts = getopts(argv);
    if (opts.h) { out(help()); exit(0); }
    if (opts.l) listCowfiles();

    /* -e/-T apply first, then the modes in Perl's fixed order, so `-y -d` and `-d -y`
     * both end up young. A missing value (-e as the last arg) is undef -> "". */
    let eyes = (opts.e === undefined ? "" : opts.e).slice(0, 2);
    let tongue = (opts.T === undefined ? "" : opts.T).slice(0, 2);
    const cowfile = opts.f === undefined ? "" : opts.f;

    let message;
    if (perlTrue(argv[0])) {                      // `cowsay 0` reads stdin: "0" is false
        if (opts.n) { out(help()); exit(1); }     // -n is stdin-only
        message = [argv.join(" ")];
    } else {
        message = lines(readStdin());
    }
    const W = { columns: perlNum(opts.W) };
    message = opts.n ? message.map(expand) : perlSplit(fill(message, W), /\n/);
    const text = balloon(message);

    if (opts.b) eyes = "==";
    if (opts.d) { eyes = "xx"; tongue = "U "; }
    if (opts.g) eyes = "$$";
    if (opts.p) eyes = "@@";
    if (opts.s) { eyes = "**"; tongue = "U "; }
    if (opts.t) eyes = "--";
    if (opts.w) eyes = "OO";
    if (opts.y) eyes = "..";
    const thoughts = think ? "o" : "\\";

    /* pick_cow. -r in cowsay 3.8.5 reads %defined_cows (a hash that does not exist) instead
     * of the hashref it just built, so its usable list is always empty and it dies looking
     * for the cowfile ''. Reproduced: that is what the oracle does. */
    let cowPath = null, raw = null;
    if (opts.r) cowPath = findCow("") || die(`${progname}: Could not find cowfile for ''!\n`, 2);
    else if (isFile(cowfile)) cowPath = cowfile;
    else if (!(cowPath = findCow(cowfile))) {
        if (cowfile !== "default.cow") die(`${progname}: Could not find cowfile for '${cowfile}'!\n`, 2);
        raw = { body: DEFAULT_COW_RAW, raw: false };    // self-contained: no cowdir needed
    }
    if (cowPath !== null) {
        if (/\.pm$/.test(cowPath))
            die(`${progname}: Cannot load cow from ${cowPath}: .pm (Perl module) format cows are not implemented yet. Sorry.\n`, 2);
        const src = readFile(cowPath);
        raw = src === null ? null : extractHeredoc(src);  // no $the_cow: the Perl prints no cow
    }
    const cow = !raw ? "" : raw.raw ? raw.body : interpolate(raw.body, { thoughts, eyes, tongue });
    out(text + cow);
}
main();
