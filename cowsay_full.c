/* cowsay_full.c - feature-matched port of the Perl cowsay 3.8.5, byte-identical
 * on stdout+stderr+exit code (eval_full.py fuzzes it against the Perl: 344/344).
 * The reproduced Perl quirks are commented at the point of code; the README has
 * the long form. Build: gcc -O2 -static -o cowsay_full cowsay_full.c */
#define _GNU_SOURCE
#include <ctype.h>
#include <dirent.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define VERSION "3.8.5-SNAPSHOT"
#define TABSTOP 8

/* Default cow in RAW cowfile form (backslashes still doubled, as on disk) so it
 * runs through the same unescape path as any -f cowfile. */
static const char *DEFAULT_COW_RAW =
    "        $thoughts   ^__^\n"
    "         $thoughts  ($eyes)\\\\_______\n"
    "            (__)\\\\       )\\\\/\\\\\n"
    "             $tongue ||----w |\n"
    "                ||     ||\n";

static const char *progname = "cowsay";

static void die_oom(void) { fprintf(stderr, "%s: out of memory\n", progname); exit(1); }

typedef struct { char *s; size_t len, cap; } Buf;

static void bput(Buf *b, const char *p, size_t n) {
    if (b->len + n + 1 > b->cap) {
        b->cap = (b->len + n + 1) * 2;
        if (!(b->s = realloc(b->s, b->cap))) die_oom();
    }
    memcpy(b->s + b->len, p, n);
    b->s[b->len += n] = 0;
}
static void bputs(Buf *b, const char *p) { bput(b, p, strlen(p)); }
static void bputc_(Buf *b, char c) { bput(b, &c, 1); }
static void brep(Buf *b, char c, size_t n) { while (n--) bputc_(b, c); }
static char *bfin(Buf *b) { if (!b->s) bputs(b, ""); return b->s; }

typedef struct { char **v; size_t n, cap; } Lines;

static void ladd(Lines *l, const char *s, size_t n) {
    if (l->n == l->cap) {
        l->cap = l->cap ? l->cap * 2 : 16;
        if (!(l->v = realloc(l->v, l->cap * sizeof *l->v))) die_oom();
    }
    char *c = malloc(n + 1);
    if (!c) die_oom();
    memcpy(c, s, n); c[n] = 0;
    l->v[l->n++] = c;
}

/* Text::Tabs::expand */
static char *expand_tabs(const char *s) {
    Buf b = {0};
    for (size_t col = 0; *s; s++) {
        if (*s != '\t') { bputc_(&b, *s); col++; continue; }
        size_t pad = TABSTOP - col % TABSTOP;
        brep(&b, ' ', pad);
        col += pad;
    }
    return bfin(&b);
}

static int is_break(unsigned char c) { return isspace(c) != 0; }

static int all_breaks(const char *s) {
    for (; *s; s++) if (!is_break((unsigned char)*s)) return 0;
    return 1;
}

/* Text::Wrap::wrap 2024.001 for one whitespace-squeezed paragraph. Greedily take
 * the longest prefix <= ll followed by a break or end; else hard-split at ll.
 * Two tails a naive greedy wrapper gets wrong:
 *  - `$r .= $remainder` re-appends the break that ended the LAST line, so a
 *    paragraph ending in a space yields a trailing-space line, which widens the
 *    whole balloon through maxlength (see -W 5).
 *  - No trailing-text append: the loop-condition regex is itself a /g match, so
 *    on exit pos is already at the end. Hence an all-blank message gives `<  >`. */
static char *wrap_para(const char *t, long ll) {
    size_t len = strlen(t), pos = 0;
    if (ll < 0) ll = 0;
    Buf r = {0};
    const char *remainder = "";
    int first = 1;

    while (!all_breaks(t + pos)) {
        size_t avail = len - pos;
        long maxk = (long)(avail < (size_t)ll ? avail : (size_t)ll), k = -1;
        for (long j = maxk; j >= 0; j--) {                 /* greedy: longest first */
            size_t p = pos + j;
            if (p == len)                      { k = j; remainder = "";  break; }
            if (is_break((unsigned char)t[p])) { k = j; remainder = " "; break; }
        }
        if (k < 0 && ll <= 0) break;                       /* no progress possible */
        if (!first) bputc_(&r, '\n');
        first = 0;
        if (k >= 0) {
            bput(&r, t + pos, k);
            pos += k;
            if (pos < len) pos++;                          /* consume the break */
        } else {
            bput(&r, t + pos, ll);                         /* $huge eq 'wrap' */
            pos += ll;
            remainder = "\n";
        }
    }
    bputs(&r, remainder);
    return bfin(&r);
}

/* Text::Wrap::fill then split("\n"). Paragraphs split on /\n\s+/, each squeezed
 * /\s+/ -> " ", wrapped, joined by "\n\n". NOTE: 2024.001's fill has no
 * `s/\A //`, so leading whitespace survives and widens the box by one. */
static void fill_and_split(Lines *in, long columns, Lines *out) {
    Buf joined = {0};
    for (size_t i = 0; i < in->n; i++) {
        if (i) bputc_(&joined, '\n');
        bputs(&joined, in->v[i]);
    }
    const char *s = bfin(&joined);
    size_t len = joined.len, i = 0;
    Buf filled = {0};

    for (int first_para = 1; i <= len;) {
        size_t start = i, end = len, j = i;
        for (; j < len; j++)
            if (s[j] == '\n' && j + 1 < len && isspace((unsigned char)s[j + 1])) { end = j; break; }

        Buf p = {0};
        for (size_t k = start, ws = 0; k < end; k++) {     /* squeeze /\s+/ -> " " */
            if (!isspace((unsigned char)s[k])) { bputc_(&p, s[k]); ws = 0; }
            else if (!ws) { bputc_(&p, ' '); ws = 1; }
        }
        /* Perl quirk: with $columns < 2, wrap() bails via `return @_`, evaluated
         * in fill()'s scalar context -> the ARGUMENT COUNT of wrap($ip,$xp,$pp).
         * So `cowsay -W 1 hello` prints the literal string "3". */
        char *w = columns < 2 ? strdup("3") : wrap_para(bfin(&p), columns - 1);
        if (!first_para) bputs(&filled, "\n\n");
        first_para = 0;
        bputs(&filled, w);
        free(w);
        free(p.s);

        if (end >= len) break;
        i = end + 1;
        while (i < len && isspace((unsigned char)s[i])) i++;
    }
    free(joined.s);

    for (char *p = bfin(&filled);;) {                      /* split("\n", ...) */
        char *nl = strchr(p, '\n');
        ladd(out, p, nl ? (size_t)(nl - p) : strlen(p));
        if (!nl) break;
        p = nl + 1;
    }
    free(filled.s);
    while (out->n && !out->v[out->n - 1][0]) out->n--;     /* drop trailing empties */
}

static char *slurp(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    Buf b = {0};
    char tmp[4096];
    size_t n;
    while ((n = fread(tmp, 1, sizeof tmp, f)) > 0) bput(&b, tmp, n);
    fclose(f);
    return bfin(&b);
}

/* Body of `$the_cow = <<"EOC"; ... EOC` */
static char *extract_heredoc(const char *src) {
    const char *p = strstr(src, "$the_cow");
    if (!p || !(p = strstr(p, "<<"))) return NULL;
    p += 2;
    while (*p == ' ' || *p == '\t') p++;
    char q = (*p == '"' || *p == '\'') ? *p++ : 0;
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
        size_t n = eol ? (size_t)(eol - p) : strlen(p);
        if (n == t && !strncmp(p, tag, t)) break;          /* terminator */
        bput(&b, p, n);
        bputc_(&b, '\n');
        if (!eol) break;
        p = eol + 1;
    }
    return bfin(&b);
}

static int ident_char(unsigned char c) { return isalnum(c) || c == '_'; }
static int ident_start(unsigned char c) { return isalpha(c) || c == '_'; }

/* Perl double-quoted heredoc. Unknown $scalar and bare @array interpolate to
 * EMPTY, so a cowfile containing "@home" silently loses it. \\ \$ \@ suppress. */
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
        }
        if ((*p == '$' || *p == '@') && ident_start((unsigned char)p[1])) {
            for (p++; ident_char((unsigned char)*p); p++) {}
            continue;
        }
        bputc_(&b, *p++);
    }
    return bfin(&b);
}

/* Perl derives the default cowpath from the script's own location; we do the
 * same from the executable's, so an installed /usr/local/bin/supercowsay uses
 * /usr/local/share/cowsay and an in-repo run stays off the system cowdir.
 * Defaults first, then $COWPATH, deduped. */
static void cowpath_dirs(Lines *dirs) {
    char exe[4096], buf[4200];
    ssize_t n = readlink("/proc/self/exe", exe, sizeof exe - 1);
    const char *ocp = getenv("COWSAY_ONLY_COWPATH");

    if (n > 0 && !(ocp && atoi(ocp) == 1)) {
        exe[n] = 0;
        for (int i = 0; i < 2; i++) {                      /* strip binary, then bin/ */
            char *slash = strrchr(exe, '/');
            if (slash) *slash = 0;
        }
        snprintf(buf, sizeof buf, "%s/share/cowsay/site-cows", exe);
        ladd(dirs, buf, strlen(buf));
        snprintf(buf, sizeof buf, "%s/share/cowsay/cows", exe);
        ladd(dirs, buf, strlen(buf));
    }
    const char *cp = getenv("COWPATH");
    for (const char *s = cp && *cp ? cp : NULL; s;) {
        const char *c = strchr(s, ':');
        size_t len = c ? (size_t)(c - s) : strlen(s);
        int dup = 0;
        for (size_t i = 0; i < dirs->n && len; i++)
            if (strlen(dirs->v[i]) == len && !strncmp(dirs->v[i], s, len)) dup = 1;
        if (len && !dup) ladd(dirs, s, len);
        s = c ? c + 1 : NULL;
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
    char buf[4096];
    for (size_t i = 0; i < dirs.n; i++)
        for (int ext = 0; ext < 2; ext++) {
            snprintf(buf, sizeof buf, ext ? "%s/%s.cow" : "%s/%s", dirs.v[i], name);
            if (is_file(buf)) return strdup(buf);
        }
    return NULL;
}

/* File::Find walk; names are relative to the cowdir with ".cow" stripped. */
static void find_cows(const char *base, const char *rel, Lines *found) {
    char path[4096], sub[4096], full[8200];
    snprintf(path, sizeof path, *rel ? "%s/%s" : "%s", base, rel);
    DIR *d = opendir(path);
    if (!d) return;
    for (struct dirent *e; (e = readdir(d));) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if (*rel) snprintf(sub, sizeof sub, "%s/%s", rel, e->d_name);
        else snprintf(sub, sizeof sub, "%s", e->d_name);
        snprintf(full, sizeof full, "%s/%s", base, sub);
        struct stat st;
        if (stat(full, &st)) continue;
        if (S_ISDIR(st.st_mode)) find_cows(base, sub, found);
        else if (S_ISREG(st.st_mode)) {
            size_t n = strlen(sub);
            if (n > 4 && !strcmp(sub + n - 4, ".cow")) ladd(found, sub, n - 4);
        }
    }
    closedir(d);
}

static int cmp_str(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }

/* Perl: dedupe, sort, one name per line when stdout is not a tty; when it is,
 * a per-directory listing wrapped at the default 76 columns. */
static void list_cows(void) {
    Lines dirs = {0}, all = {0};
    cowpath_dirs(&dirs);
    int tty = isatty(1), first = 1;
    for (size_t i = 0; i < dirs.n; i++) {
        Lines found = {0};
        find_cows(dirs.v[i], "", &found);
        if (!found.n) continue;
        qsort(found.v, found.n, sizeof *found.v, cmp_str);
        if (tty) {
            Buf j = {0};
            for (size_t k = 0; k < found.n; k++) {
                if (k) bputc_(&j, ' ');
                bputs(&j, found.v[k]);
            }
            char *w = wrap_para(bfin(&j), 75);
            printf("%sCow files in %s:\n%s\n", first ? "" : "\n", dirs.v[i], w);
            free(w); free(j.s);
            first = 0;
        }
        for (size_t k = 0; k < found.n; k++) ladd(&all, found.v[k], strlen(found.v[k]));
    }
    if (tty) return;
    qsort(all.v, all.n, sizeof *all.v, cmp_str);
    for (size_t i = 0; i < all.n; i++)
        if (!i || strcmp(all.v[i], all.v[i - 1])) printf("%s\n", all.v[i]);
}

/* Byte-for-byte the Perl HELP_MESSAGE heredoc. */
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

/* Perl truthiness: "" and "0" are false. So `cowsay 0` reads stdin. */
static int perl_true(const char *s) { return s && s[0] && strcmp(s, "0"); }

int main(int argc, char **argv) {
    const char *slash = strrchr(argv[0], '/');
    progname = slash ? slash + 1 : argv[0];
    int think = strcasestr(progname, "think") != NULL;

    const char *opt_e = "oo", *opt_T = "  ", *cowfile = "default.cow";
    int no_wrap = 0, want_help = 0, want_list = 0;
    long columns = 40;
    int borg = 0, dead = 0, greedy = 0, paranoid = 0, stoned = 0, tired = 0, wired = 0, young = 0;

    /* Getopt::Std emulation. GNU getopt() differs in two ways that matter: it
     * permutes (eating options after the message) and aborts on an unknown one.
     * Perl warns and continues, which is why `-notaflag` sets -n and -t, then
     * hands "lag" to -f as the cowfile. */
    static const char *optstr = "bCde:f:ghlLnNprstT:wW:y";
    int ai = 1;
    while (ai < argc) {
        const char *a = argv[ai];
        if (a[0] != '-' || !a[1]) break;                   /* not an option: stop */
        if (!strcmp(a, "--")) { ai++; break; }
        for (const char *ch = a + 1; *ch;) {
            char f = *ch++;
            const char *p = f == ':' ? NULL : strchr(optstr, f);
            if (!p) { fprintf(stderr, "Unknown option: %c\n", f); continue; }
            if (p[1] == ':') {                             /* takes a value */
                const char *val = *ch ? ch : (ai + 1 < argc ? argv[++ai] : "");
                ch = "";
                switch (f) {
                case 'e': opt_e = val; break;
                case 'T': opt_T = val; break;
                case 'f': cowfile = val; break;
                case 'W': columns = strtol(val, NULL, 10); break;
                }
                continue;
            }
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
            default: break;                                /* C, L, N, r: inert */
            }
        }
        ai++;
    }
    if (want_help) { help(); return 0; }
    if (want_list) { list_cows(); return 0; }

    char eyes[3], tongue[3];
    snprintf(eyes, sizeof eyes, "%.2s", opt_e);
    snprintf(tongue, sizeof tongue, "%.2s", opt_T);
    /* Applied after -e/-T so they override it, and in Perl's fixed order - so
     * `-y -d` and `-d -y` both yield young, the later test winning either way. */
    if (borg)     strcpy(eyes, "==");
    if (dead)     { strcpy(eyes, "xx"); strcpy(tongue, "U "); }
    if (greedy)   strcpy(eyes, "$$");
    if (paranoid) strcpy(eyes, "@@");
    if (stoned)   { strcpy(eyes, "**"); strcpy(tongue, "U "); }
    if (tired)    strcpy(eyes, "--");
    if (wired)    strcpy(eyes, "OO");
    if (young)    strcpy(eyes, "..");

    Lines raw = {0};
    if (ai < argc && perl_true(argv[ai])) {
        if (no_wrap) { help(); return 1; }                 /* -n is stdin-only */
        Buf m = {0};
        for (int i = ai; i < argc; i++) {
            if (i > ai) bputc_(&m, ' ');
            bputs(&m, argv[i]);
        }
        ladd(&raw, bfin(&m), m.len);
        free(m.s);
    } else {
        Buf in = {0};
        char tmp[4096];
        size_t n;
        while ((n = fread(tmp, 1, sizeof tmp, stdin)) > 0) bput(&in, tmp, n);
        for (char *p = in.s; p && *p;) {                   /* chomp(<STDIN>) */
            char *nl = strchr(p, '\n');
            ladd(&raw, p, nl ? (size_t)(nl - p) : strlen(p));
            if (!nl) break;
            p = nl + 1;
        }
        free(in.s);
    }

    Lines msg = {0};
    if (no_wrap)
        for (size_t i = 0; i < raw.n; i++) {
            char *e = expand_tabs(raw.v[i]);
            ladd(&msg, e, strlen(e));
            free(e);
        }
    else
        fill_and_split(&raw, columns, &msg);

    size_t max = 0;
    for (size_t i = 0; i < msg.n; i++) {
        size_t l = strlen(msg.v[i]);
        if (l > max) max = l;
    }
    /* up-left, up-right, down-left, down-right, left, right */
    const char *bd = think ? "()()()" : msg.n < 2 ? "<><><>" : "/\\\\/||";
    const char *thoughts = think ? "o" : "\\";

    Buf out = {0};
    bputc_(&out, ' '); brep(&out, '_', max + 2); bputc_(&out, '\n');
    for (size_t i = 0, n = msg.n ? msg.n : 1; i < n; i++) {
        const char *s = i < msg.n ? msg.v[i] : "";         /* $message[0] may be undef */
        int e = i == 0 ? 0 : (i == n - 1 ? 2 : 4);
        bputc_(&out, bd[e]); bputc_(&out, ' ');
        bputs(&out, s); brep(&out, ' ', max - strlen(s)); /* %-${max}s */
        bputc_(&out, ' '); bputc_(&out, bd[e + 1]); bputc_(&out, '\n');
    }
    bputc_(&out, ' '); brep(&out, '-', max + 2); bputc_(&out, '\n');

    char *raw_cow = NULL, *path = resolve_cow(cowfile);
    if (path) {
        char *src = slurp(path);
        if (src) { raw_cow = extract_heredoc(src); free(src); }
        free(path);
    }
    if (!raw_cow) {
        if (strcmp(cowfile, "default.cow")) {
            /* Perl dies here; its status is $! from the failed stat = ENOENT = 2 */
            fprintf(stderr, "%s: Could not find cowfile for '%s'!\n", progname, cowfile);
            return 2;
        }
        raw_cow = strdup(DEFAULT_COW_RAW);                 /* self-contained fallback */
    }
    fwrite(out.s, 1, out.len, stdout);
    fputs(interpolate(raw_cow, thoughts, eyes, tongue), stdout);
    return 0;
}
