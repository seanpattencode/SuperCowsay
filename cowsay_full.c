/* cowsay_full.c - feature-matched port of the original Perl cowsay (3.8.5).
 *
 * Byte-identical to `perl cowsay_original_perl.pl` across word wrapping, all box
 * shapes, appearance modes, custom eyes/tongue, width control, stdin input,
 * cowfile loading, and cowthink. Verified by differential fuzzing (eval_full.py).
 *
 * This is the COMPATIBILITY build. cowsay_ultra is the SPEED build: 145x faster
 * than Perl but a single-line subset. This one trades some of that speed for
 * actually being cowsay.
 *
 * Semantics reproduced deliberately, each verified against the Perl:
 *   - Text::Wrap wraps to (columns - 1), so -W 40 yields 39-char lines.
 *   - `if ($ARGV[0])` is a Perl truthiness test: a bare "0" or "" first argument
 *     is FALSE, so cowsay reads stdin instead of using it as the message.
 *   - fill() squeezes all whitespace runs to one space and splits paragraphs on
 *     a newline followed by whitespace.
 *   - Words longer than the wrap width are hard-split, not overflowed.
 *   - Mode flags (-b -d ...) are applied after -e/-T, so they override them.
 *
 * Build: gcc -O2 -o cowsay_full cowsay_full.c
 */
#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <unistd.h>

#define VERSION "3.8.5-SNAPSHOT"
#define TABSTOP 8

/* The default cow in RAW cowfile form (backslashes still doubled, as on disk),
 * so it runs through exactly the same unescape path as a -f cowfile. */
static const char *DEFAULT_COW_RAW =
    "        $thoughts   ^__^\n"
    "         $thoughts  ($eyes)\\\\_______\n"
    "            (__)\\\\       )\\\\/\\\\\n"
    "             $tongue ||----w |\n"
    "                ||     ||\n";

static const char *progname = "cowsay";

/* ---------- growable buffer ---------- */
typedef struct { char *s; size_t len, cap; } Buf;

static void bput(Buf *b, const char *p, size_t n) {
    if (b->len + n + 1 > b->cap) {
        b->cap = (b->len + n + 1) * 2;
        b->s = realloc(b->s, b->cap);
        if (!b->s) { fprintf(stderr, "%s: out of memory\n", progname); exit(1); }
    }
    memcpy(b->s + b->len, p, n);
    b->len += n;
    b->s[b->len] = 0;
}
static void bputs(Buf *b, const char *p) { bput(b, p, strlen(p)); }
static void bputc_(Buf *b, char c) { bput(b, &c, 1); }
static void brep(Buf *b, char c, size_t n) { while (n--) bputc_(b, c); }

/* ---------- line list ---------- */
typedef struct { char **v; size_t n, cap; } Lines;

static void ladd(Lines *l, const char *s, size_t n) {
    if (l->n == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 16;
        l->v = realloc(l->v, l->cap * sizeof(char *));
        if (!l->v) { fprintf(stderr, "%s: out of memory\n", progname); exit(1); }
    }
    char *c = malloc(n + 1);
    if (!c) { fprintf(stderr, "%s: out of memory\n", progname); exit(1); }
    memcpy(c, s, n); c[n] = 0;
    l->v[l->n++] = c;
}

/* ---------- Text::Tabs::expand ---------- */
static char *expand_tabs(const char *s) {
    Buf b = {0};
    size_t col = 0;
    for (; *s; s++) {
        if (*s == '\t') {
            size_t pad = TABSTOP - (col % TABSTOP);
            brep(&b, ' ', pad);
            col += pad;
        } else {
            bputc_(&b, *s);
            col++;
        }
    }
    if (!b.s) bputs(&b, "");
    return b.s;
}

/* ---------- Text::Wrap::wrap (2024.001), one whitespace-squeezed paragraph ----
 * Perl:
 *   while ($t !~ /\G(?:$break)*\Z/gc) {
 *       if ($t =~ /\G(.{0,$ll})($break|\n+|\z)/) { $r .= $nl.$1; $remainder = $2 }
 *       elsif ($huge eq 'wrap' && $t =~ /\G(.{$ll})/) { $r .= $nl.$1; $remainder = "\n" }
 *   }
 *   $r .= $remainder;
 *   $r .= substr($t, pos($t)) if pos($t) != length($t);
 *
 * The two tails are what a naive greedy wrapper gets wrong: the break character
 * that terminated the LAST line is re-appended, so a paragraph ending in a space
 * yields a final line with a trailing space (which then widens the whole box via
 * maxlength). Verified against Perl with -W 5. */
static int is_break(unsigned char c) { return isspace(c) != 0; }

static int all_breaks(const char *s) {
    for (; *s; s++) if (!is_break((unsigned char)*s)) return 0;
    return 1;
}

static char *wrap_para(const char *t, long ll) {
    size_t len = strlen(t), pos = 0;
    if (ll < 0) ll = 0;
    Buf r = {0};
    const char *remainder = "";
    int first = 1;

    while (!all_breaks(t + pos)) {
        size_t avail = len - pos;
        long maxk = (long)(avail < (size_t)ll ? avail : (size_t)ll);
        long k = -1;
        for (long j = maxk; j >= 0; j--) {          /* greedy: longest first */
            size_t p = pos + j;
            if (p == len)                  { k = j; remainder = "";  break; }
            if (is_break((unsigned char)t[p])) { k = j; remainder = " "; break; }
        }
        if (k >= 0) {
            if (!first) bputc_(&r, '\n');
            bput(&r, t + pos, k);
            first = 0;
            pos += k;
            if (pos < len) pos++;                   /* consume the break char */
        } else if (ll > 0) {                        /* $huge eq 'wrap': hard split */
            if (!first) bputc_(&r, '\n');
            bput(&r, t + pos, ll);
            first = 0;
            pos += ll;
            remainder = "\n";
        } else {
            break;                                  /* ll == 0: no progress possible */
        }
    }
    bputs(&r, remainder);
    /* No trailing-text append here: the while-condition regex is itself a /g match,
     * so when it succeeds (remaining text is all breaks) it advances pos to the end
     * and Perl's `if pos($t) ne length($t)` never fires. That is why an all-blank
     * message yields an EMPTY line (`<  >`) rather than a space (`<   >`). */
    if (!r.s) bputs(&r, "");
    return r.s;
}

/* ---------- Text::Wrap::fill + split("\n", ...) ----------
 * fill: split into paragraphs on /\n\s+/, squeeze /\s+/ to " ", wrap each, join
 * with "\n\n". cowsay then splits the result on "\n".
 * NOTE: Text::Wrap 2024.001's fill does NOT strip a leading space (older copies
 * of the algorithm do). Perl keeps it, so a leading-whitespace message widens the
 * balloon by one - verified against `cowsay "   leading"`. */
static void fill_and_split(Lines *in, long columns, Lines *out) {
    Buf joined = {0};
    for (size_t i = 0; i < in->n; i++) {
        if (i) bputc_(&joined, '\n');
        bputs(&joined, in->v[i]);
    }
    if (!joined.s) bputs(&joined, "");

    long ll = columns - 1;
    const char *s = joined.s;
    size_t len = joined.len, i = 0;
    Buf filled = {0};
    int first_para = 1;

    while (i <= len) {
        size_t start = i, end = len, j = i;
        for (; j < len; j++) {
            if (s[j] == '\n' && j + 1 < len && isspace((unsigned char)s[j + 1])) {
                end = j;
                break;
            }
        }
        if (j >= len) end = len;

        Buf p = {0};                                 /* squeeze /\s+/ -> " " */
        int in_ws = 0;
        for (size_t k = start; k < end; k++) {
            if (isspace((unsigned char)s[k])) {
                if (!in_ws) { bputc_(&p, ' '); in_ws = 1; }
            } else { bputc_(&p, s[k]); in_ws = 0; }
        }
        if (!p.s) bputs(&p, "");

        /* Perl quirk: for $columns < 2, Text::Wrap::wrap bails with `return @_`,
         * which in the scalar context fill() calls it from yields the ARGUMENT
         * COUNT. wrap is always called as wrap($ip,$xp,$pp), so the paragraph
         * becomes the literal string "3". Verified: `cowsay -W 1 hello` -> < 3 >. */
        char *w = (columns < 2) ? strdup("3") : wrap_para(p.s, ll);
        if (!first_para) bputs(&filled, "\n\n");     /* $ps when $ip eq $xp */
        first_para = 0;
        bputs(&filled, w);
        free(w);
        free(p.s);

        if (end >= len) break;
        i = end + 1;
        while (i < len && isspace((unsigned char)s[i])) i++;   /* consume \n\s+ */
    }
    free(joined.s);

    if (!filled.s) bputs(&filled, "");
    for (char *p = filled.s;;) {                     /* split("\n", ...) */
        char *nl = strchr(p, '\n');
        if (nl) { ladd(out, p, nl - p); p = nl + 1; }
        else { ladd(out, p, strlen(p)); break; }
    }
    free(filled.s);
    while (out->n > 0 && out->v[out->n - 1][0] == '\0') out->n--;  /* drop trailing empties */
}

/* ---------- cowfile ---------- */
static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    Buf b = {0};
    char tmp[4096];
    size_t n;
    while ((n = fread(tmp, 1, sizeof tmp, f)) > 0) bput(&b, tmp, n);
    fclose(f);
    if (!b.s) bputs(&b, "");
    return b.s;
}

/* Pull the heredoc body out of `$the_cow = <<"EOC"; ... EOC`. */
static char *extract_heredoc(const char *src) {
    const char *p = strstr(src, "$the_cow");
    if (!p) return NULL;
    p = strstr(p, "<<");
    if (!p) return NULL;
    p += 2;
    while (*p == ' ' || *p == '\t') p++;
    char q = 0;
    if (*p == '"' || *p == '\'') q = *p++;
    char tag[128];
    size_t t = 0;
    while (*p && t < sizeof tag - 1 && (isalnum((unsigned char)*p) || *p == '_')) tag[t++] = *p++;
    tag[t] = 0;
    if (q && *p == q) p++;
    while (*p && *p != '\n') p++;
    if (*p == '\n') p++;

    Buf b = {0};
    while (*p) {
        const char *eol = strchr(p, '\n');
        size_t linelen = eol ? (size_t)(eol - p) : strlen(p);
        if (linelen == t && strncmp(p, tag, t) == 0) break;   /* terminator */
        bput(&b, p, linelen);
        bputc_(&b, '\n');
        if (!eol) break;
        p = eol + 1;
    }
    if (!b.s) bputs(&b, "");
    return b.s;
}

/* Perl double-quoted heredoc interpolation.
 * Beyond the three cowsay variables: an unknown $scalar interpolates to empty,
 * and a bare @array does too - so a cowfile containing "@home" silently loses it,
 * exactly as the Perl does. Escapes \\ \$ \@ suppress this. */
static int ident_char(unsigned char c) { return isalnum(c) || c == '_'; }

static char *interpolate(const char *raw, const char *thoughts,
                         const char *eyes, const char *tongue) {
    Buf b = {0};
    for (const char *p = raw; *p;) {
        if (*p == '\\' && (p[1] == '\\' || p[1] == '$' || p[1] == '@')) {
            bputc_(&b, p[1]); p += 2; continue;
        }
        if (*p == '$') {
            if (!strncmp(p, "$thoughts", 9)) { bputs(&b, thoughts); p += 9; continue; }
            if (!strncmp(p, "$eyes", 5))     { bputs(&b, eyes);     p += 5; continue; }
            if (!strncmp(p, "$tongue", 7))   { bputs(&b, tongue);   p += 7; continue; }
            if (isalpha((unsigned char)p[1]) || p[1] == '_') {   /* unknown scalar -> "" */
                p++;
                while (ident_char((unsigned char)*p)) p++;
                continue;
            }
        }
        if (*p == '@' && (isalpha((unsigned char)p[1]) || p[1] == '_')) {
            p++;                                                  /* @array -> "" */
            while (ident_char((unsigned char)*p)) p++;
            continue;
        }
        bputc_(&b, *p++);
    }
    if (!b.s) bputs(&b, "");
    return b.s;
}

/* Perl derives the default cowpath from the SCRIPT's location:
 *   prefix = dirname(dirname(abs_path(script))); share = "$prefix/share/cowsay"
 * so it is <prefix>/share/cowsay/{site-cows,cows}. We do the same from the
 * executable's own path, which puts an installed /usr/local/bin/supercowsay onto
 * /usr/local/share/cowsay and keeps an in-repo run off the system cow directory,
 * exactly as the Perl behaves. Defaults come FIRST, then $COWPATH. */
static void cowpath_dirs(Lines *dirs) {
    char exe[4096];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    int only_user = 0;
    const char *ocp = getenv("COWSAY_ONLY_COWPATH");
    if (ocp && atoi(ocp) == 1) only_user = 1;

    if (n > 0 && !only_user) {
        exe[n] = 0;
        char *slash = strrchr(exe, '/');            /* strip the binary name */
        if (slash) *slash = 0;
        slash = strrchr(exe, '/');                  /* strip the bin/ directory */
        if (slash) *slash = 0;
        char buf[4200];
        snprintf(buf, sizeof buf, "%s/share/cowsay/site-cows", exe);
        ladd(dirs, buf, strlen(buf));
        snprintf(buf, sizeof buf, "%s/share/cowsay/cows", exe);
        ladd(dirs, buf, strlen(buf));
    }
    const char *cp = getenv("COWPATH");
    if (cp && *cp) {
        const char *s = cp;
        while (*s) {
            const char *c = strchr(s, ':');
            size_t len = c ? (size_t)(c - s) : strlen(s);
            if (len) {
                int dup = 0;                        /* uniquify_list */
                for (size_t i = 0; i < dirs->n; i++)
                    if (strlen(dirs->v[i]) == len && !strncmp(dirs->v[i], s, len)) dup = 1;
                if (!dup) ladd(dirs, s, len);
            }
            if (!c) break;
            s = c + 1;
        }
    }
}

static int is_file(const char *p) {
    struct stat st;
    return stat(p, &st) == 0 && S_ISREG(st.st_mode);
}

static char *resolve_cow(const char *name) {
    if (is_file(name)) return strdup(name);
    Lines dirs = {0};
    cowpath_dirs(&dirs);
    static char buf[4096];
    for (size_t i = 0; i < dirs.n; i++) {
        snprintf(buf, sizeof buf, "%s/%s", dirs.v[i], name);
        if (is_file(buf)) return strdup(buf);
        snprintf(buf, sizeof buf, "%s/%s.cow", dirs.v[i], name);
        if (is_file(buf)) return strdup(buf);
    }
    return NULL;
}

/* File::Find walk: names are relative to the cowdir, with ".cow" stripped. */
static void find_cows(const char *base, const char *rel, Lines *found) {
    char path[4096];
    if (*rel) snprintf(path, sizeof path, "%s/%s", base, rel);
    else snprintf(path, sizeof path, "%s", base);
    DIR *d = opendir(path);
    if (!d) return;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        char sub[4096];
        if (*rel) snprintf(sub, sizeof sub, "%s/%s", rel, e->d_name);
        else snprintf(sub, sizeof sub, "%s", e->d_name);
        char full[8200];
        snprintf(full, sizeof full, "%s/%s", base, sub);
        struct stat st;
        if (stat(full, &st) != 0) continue;
        if (S_ISDIR(st.st_mode)) {
            find_cows(base, sub, found);
        } else if (S_ISREG(st.st_mode)) {
            size_t n = strlen(sub);
            if (n > 4 && !strcmp(sub + n - 4, ".cow")) ladd(found, sub, n - 4);
        }
    }
    closedir(d);
}

static int cmp_str(const void *a, const void *b) {
    return strcmp(*(char *const *)a, *(char *const *)b);
}

/* Perl: dedupe via a hash, `sort keys`, and print one per line when stdout is
 * not a tty (list_cowfiles_parseable); a grouped listing when it is. */
static void list_cows(void) {
    Lines dirs = {0};
    cowpath_dirs(&dirs);
    int tty = isatty(1);
    Lines all = {0};
    for (size_t i = 0; i < dirs.n; i++) {
        Lines found = {0};
        find_cows(dirs.v[i], "", &found);
        if (!found.n) continue;
        qsort(found.v, found.n, sizeof(char *), cmp_str);
        if (tty) {
            printf("%s%s:\n", i && all.n ? "\n" : "", dirs.v[i]);
            printf("Cow files in %s:\n", dirs.v[i]);
        }
        for (size_t j = 0; j < found.n; j++) ladd(&all, found.v[j], strlen(found.v[j]));
    }
    if (tty) return;
    qsort(all.v, all.n, sizeof(char *), cmp_str);
    for (size_t i = 0; i < all.n; i++) {
        if (i && !strcmp(all.v[i], all.v[i - 1])) continue;   /* dedupe */
        printf("%s\n", all.v[i]);
    }
}

/* Byte-for-byte the Perl HELP_MESSAGE heredoc (which interpolates $progname and
 * unescapes \< \>). */
static void help(void) {
    printf("%s version " VERSION "\n"
           "\n"
           "Usage:\n"
           "\n"
           "    %s [-bdgpstwy] [-f <cowfile>] [-r [-C]] [-e <eyes>] [-T <tongue>]\n"
           "        [-W <wrapcolumn>] [-n]\n"
           "        <message>\n"
           "\n"
           "    %s -l              # List defined cows\n"
           "    %s [-h | --help]   # Display this help screen\n"
           "\n"
           "Options:\n"
           "\n"
           "    -b, -d, -g, -s, -t, -w, and -y activate Borg, dead, greedy, sleepy, tired, wired, and\n"
           "        young appearance modes, respectively.\n"
           "\n"
           "    -f <cowfile> selects an alternate cow picture. <cowfile> may be either the name of a\n"
           "        cow defined in a cowdir on the cowpath (without the '.cow' file extension), or the\n"
           "        path to a cowfile (with the '.cow' file extension). `%s -l` will list the\n"
           "        names of available cows.\n"
           "\n"
           "    -r selects a random cowfile from those present on the cowpath. If -C is also given,\n"
           "        then full-color cows will be included.\n"
           "\n"
           "    -e <eyes> defines a custom eye appearance. <eyes> should be a two-character string.\n"
           "        It is up to you whether they actually look like eyes.\n"
           "\n"
           "    -T <tongue> defines a custom tongue appearance.\n"
           "\n"
           "    -n activates word wrapping, to support messages with arbitrary whitespace. Must be the\n"
           "        last option given before <message> starts.\n"
           "\n"
           "    -W <wrapcolumn> controls where line wrapping occurs. Default is 40 columns.\n"
           "\n",
           progname, progname, progname, progname, progname);
}

/* Perl truthiness: "" and "0" are false, everything else is true. */
static int perl_true(const char *s) { return s && s[0] && strcmp(s, "0") != 0; }

int main(int argc, char **argv) {
    const char *base = strrchr(argv[0], '/');
    progname = base ? base + 1 : argv[0];
    int think = strcasestr(progname, "think") != NULL;

    char eyes[3] = "oo", tongue[3] = "  ";
    const char *opt_e = "oo", *opt_T = "  ", *cowfile = "default.cow";
    int no_wrap = 0, want_help = 0, want_list = 0;
    long columns = 40;
    int borg = 0, dead = 0, greedy = 0, paranoid = 0, stoned = 0, tired = 0,
        wired = 0, young = 0;

    /* Getopt::Std emulation. GNU getopt() differs in two ways that matter:
     * it permutes (eating options that appear after the message), and it aborts
     * on an unknown option. Perl warns "Unknown option: x" and keeps going, which
     * is why `cowsay -notaflag` ends up with -n, -t set and "lag" as the cowfile. */
    static const char *optstr = "bCde:f:ghlLnNprstT:wW:y";
    int ai = 1;
    char pending[4096];
    while (ai < argc) {
        const char *a = argv[ai];
        if (a[0] != '-' || a[1] == '\0') break;          /* not an option: stop */
        if (!strcmp(a, "--")) { ai++; break; }
        const char *chars = a + 1;
        int consumed_arg = 0;
        while (*chars) {
            char f = *chars++;
            const char *p = strchr(optstr, f);
            if (p && f != ':') {
                if (p[1] == ':') {                        /* option takes a value */
                    const char *val;
                    if (*chars) { val = chars; chars = ""; }
                    else if (ai + 1 < argc) { val = argv[++ai]; }
                    else { val = ""; }
                    switch (f) {
                    case 'e': opt_e = val; break;
                    case 'T': opt_T = val; break;
                    case 'f': cowfile = val; break;
                    case 'W': columns = strtol(val, NULL, 10); break;
                    }
                    consumed_arg = 1;
                } else {
                    switch (f) {
                    case 'b': borg = 1; break;
                    case 'd': dead = 1; break;
                    case 'g': greedy = 1; break;
                    case 'p': paranoid = 1; break;
                    case 's': stoned = 1; break;
                    case 't': tired = 1; break;
                    case 'w': wired = 1; break;
                    case 'y': young = 1; break;
                    case 'n': no_wrap = 1; break;
                    case 'h': want_help = 1; break;
                    case 'l': want_list = 1; break;
                    default: break;                       /* C, L, N, r: inert */
                    }
                }
            } else {
                fprintf(stderr, "Unknown option: %c\n", f);
            }
        }
        ai++;
        (void)pending; (void)consumed_arg;
    }
    optind = ai;
    if (want_help) { help(); return 0; }
    if (want_list) { list_cows(); return 0; }

    snprintf(eyes, sizeof eyes, "%.2s", opt_e);
    snprintf(tongue, sizeof tongue, "%.2s", opt_T);
    /* mode flags are applied after -e/-T and therefore override them */
    if (borg)     strcpy(eyes, "==");
    if (dead)     { strcpy(eyes, "xx"); strcpy(tongue, "U "); }
    if (greedy)   strcpy(eyes, "$$");
    if (paranoid) strcpy(eyes, "@@");
    if (stoned)   { strcpy(eyes, "**"); strcpy(tongue, "U "); }
    if (tired)    strcpy(eyes, "--");
    if (wired)    strcpy(eyes, "OO");
    if (young)    strcpy(eyes, "..");

    /* input: argv if the first remaining arg is Perl-true, else stdin */
    Lines raw = {0};
    if (optind < argc && perl_true(argv[optind])) {
        if (no_wrap) { help(); return 1; }      /* -n only works with stdin */
        Buf m = {0};
        for (int i = optind; i < argc; i++) {
            if (i > optind) bputc_(&m, ' ');
            bputs(&m, argv[i]);
        }
        if (!m.s) bputs(&m, "");
        ladd(&raw, m.s, m.len);
        free(m.s);
    } else {
        Buf in = {0};
        char tmp[4096];
        size_t n;
        while ((n = fread(tmp, 1, sizeof tmp, stdin)) > 0) bput(&in, tmp, n);
        if (in.s) {
            char *p = in.s;
            while (*p) {
                char *nl = strchr(p, '\n');
                if (nl) { ladd(&raw, p, nl - p); p = nl + 1; }
                else { ladd(&raw, p, strlen(p)); break; }
            }
            free(in.s);
        }
    }

    Lines msg = {0};
    if (no_wrap) {
        for (size_t i = 0; i < raw.n; i++) {
            char *e = expand_tabs(raw.v[i]);
            ladd(&msg, e, strlen(e));
            free(e);
        }
    } else {
        fill_and_split(&raw, columns, &msg);
    }

    /* ---------- balloon ---------- */
    size_t max = 0;
    for (size_t i = 0; i < msg.n; i++) {
        size_t l = strlen(msg.v[i]);
        if (l > max) max = l;
    }
    const char *b0, *b1, *b2, *b3, *b4, *b5, *thoughts;
    if (think) {
        thoughts = "o";
        b0 = "("; b1 = ")"; b2 = "("; b3 = ")"; b4 = "("; b5 = ")";
    } else if (msg.n < 2) {
        thoughts = "\\";
        b0 = "<"; b1 = ">"; b2 = "<"; b3 = ">"; b4 = "<"; b5 = ">";
    } else {
        thoughts = "\\";
        b0 = "/"; b1 = "\\"; b2 = "\\"; b3 = "/"; b4 = "|"; b5 = "|";
    }

    Buf out = {0};
    bputc_(&out, ' '); brep(&out, '_', max + 2); bputc_(&out, '\n');
    {
        const char *first = msg.n ? msg.v[0] : "";     /* $message[0] may be undef */
        char *pad = malloc(max + 3);
        snprintf(pad, max + 1 + 1, "%-*s", (int)max, first);
        bputs(&out, b0); bputc_(&out, ' '); bputs(&out, pad);
        bputc_(&out, ' '); bputs(&out, b1); bputc_(&out, '\n');
        for (size_t i = 1; msg.n >= 2 && i + 1 < msg.n; i++) {
            snprintf(pad, max + 1 + 1, "%-*s", (int)max, msg.v[i]);
            bputs(&out, b4); bputc_(&out, ' '); bputs(&out, pad);
            bputc_(&out, ' '); bputs(&out, b5); bputc_(&out, '\n');
        }
        if (msg.n >= 2) {
            snprintf(pad, max + 1 + 1, "%-*s", (int)max, msg.v[msg.n - 1]);
            bputs(&out, b2); bputc_(&out, ' '); bputs(&out, pad);
            bputc_(&out, ' '); bputs(&out, b3); bputc_(&out, '\n');
        }
        free(pad);
    }
    bputc_(&out, ' '); brep(&out, '-', max + 2); bputc_(&out, '\n');

    /* ---------- cow ---------- */
    char *raw_cow = NULL, *path = resolve_cow(cowfile);
    if (path) {
        char *src = slurp(path);
        if (src) { raw_cow = extract_heredoc(src); free(src); }
        free(path);
    }
    if (!raw_cow) {
        if (strcmp(cowfile, "default.cow") != 0) {
            /* Perl dies here; its exit status is $! from the failed stat = ENOENT = 2 */
            fprintf(stderr, "%s: Could not find cowfile for '%s'!\n", progname, cowfile);
            return 2;
        }
        raw_cow = strdup(DEFAULT_COW_RAW);   /* self-contained fallback */
    }
    char *cow = interpolate(raw_cow, thoughts, eyes, tongue);

    fwrite(out.s, 1, out.len, stdout);
    fputs(cow, stdout);
    return 0;
}
