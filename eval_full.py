#!/usr/bin/env python3
"""eval_full.py - differential fuzzing of cowsay_full against the original Perl.

Every case runs through BOTH `perl cowsay_original_perl.pl` and `./cowsay_full`
and the stdout, stderr, and exit code are compared byte-for-byte. Perl is the
oracle; any difference is our bug.

  python3 eval_full.py            # full run
  python3 eval_full.py -v         # show a diff for each failure
"""
import os, random, shutil, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
PERL = os.path.join(HERE, "cowsay_original_perl.pl")
FULL = os.path.join(HERE, "cowsay_full")
ENV = dict(os.environ, COWPATH=os.path.join(HERE, "cows"))
VERBOSE = "-v" in sys.argv


def norm(data, name):
    """Both programs print their own name in help and error text; that difference
    is expected, so normalize it rather than counting it as a divergence."""
    return data.replace(name.encode(), b"PROG")


def run_perl(args, stdin=b"", script=PERL):
    p = subprocess.run(["perl", script] + list(args), input=stdin,
                       capture_output=True, env=ENV)
    n = os.path.basename(script)
    return norm(p.stdout, n), norm(p.stderr, n), p.returncode


def run_full(args, stdin=b"", exe=FULL):
    p = subprocess.run([exe] + list(args), input=stdin,
                       capture_output=True, env=ENV)
    n = os.path.basename(exe)
    return norm(p.stdout, n), norm(p.stderr, n), p.returncode


def cases():
    """(label, argv, stdin) triples."""
    c = []
    A = lambda n: b"A" * n
    # --- message shapes -------------------------------------------------
    for m in [b"moo", b"", b"hi there", b"a b c", b"a    b     c",
              b"The quick brown fox jumps over the lazy dog",
              A(1), A(38), A(39), A(40), A(41), A(78), A(79), A(80), A(100), A(500),
              b"word " * 20, b"word " * 3, b"one two three four five six seven",
              b"tab\there", b"trailing   ", b"   leading", b"multi  space  here",
              b"-notaflag", b"--", b"a-b-c", b"!@#$%^&*()", b"'quotes'", b'"dq"',
              b"back\\slash", b"100%", b"\xc3\xa9\xc3\xa9", "🐄 moo".encode()]:
        c.append((f"msg({len(m)}b)", [m], b""))
    # --- multiple arguments ---------------------------------------------
    c += [("multi-arg", [b"hello", b"world"], b""),
          ("multi-arg-many", [b"a"] * 30, b""),
          ("multi-empty", [b"", b"x"], b""),
          ("multi-long", [A(30), A(30), A(30)], b"")]
    # --- Perl truthiness quirk ------------------------------------------
    c += [("arg-zero->stdin", [b"0"], b"from stdin\n"),
          ("arg-empty->stdin", [b""], b"from stdin\n")]
    # --- stdin ----------------------------------------------------------
    for s in [b"hello\n", b"", b"line one\nline two\n", b"a\nb\nc\n",
              b"no trailing newline", b"  indented\nsecond\n",
              b"para one\n\npara two\n", b"long " * 30 + b"\n",
              b"tab\tsep\n", b"\n\n\n", b"x\n   y\n"]:
        c.append((f"stdin({len(s)}b)", [], s))
    # --- appearance modes -----------------------------------------------
    for f in [b"-b", b"-d", b"-g", b"-p", b"-s", b"-t", b"-w", b"-y"]:
        c.append((f"mode{f.decode()}", [f, b"moo"], b""))
    c += [("mode-combo", [b"-d", b"-y", b"moo"], b""),
          ("mode-overrides-e", [b"-e", b"@@", b"-d", b"moo"], b"")]
    # --- eyes / tongue --------------------------------------------------
    for e in [b"oo", b"XX", b"X", b"", b"toolong", b"^^"]:
        c.append((f"eyes({e.decode() or 'empty'})", [b"-e", e, b"moo"], b""))
    for t in [b"U ", b"V", b"", b"toolong"]:
        c.append((f"tongue({t.decode() or 'empty'})", [b"-T", t, b"moo"], b""))
    # --- width ----------------------------------------------------------
    for w in [b"10", b"20", b"39", b"40", b"41", b"80", b"5", b"3", b"2", b"1"]:
        c.append((f"-W{w.decode()}", [b"-W", w, b"word " * 15], b""))
    c.append(("-W-long-word", [b"-W", b"10", A(45)], b""))
    # --- no-wrap --------------------------------------------------------
    c += [("-n stdin", [b"-n"], b"a very long line that would otherwise be wrapped by cowsay\n"),
          ("-n tabs", [b"-n"], b"col\tcol\tcol\n"),
          ("-n multiline", [b"-n"], b"one\ntwo\nthree\n"),
          ("-n with args (error)", [b"-n", b"moo"], b"")]
    # --- cowfile / help / list ------------------------------------------
    c += [("-f default", [b"-f", b"default", b"moo"], b""),
          ("-f default.cow", [b"-f", b"default.cow", b"moo"], b""),
          ("-f path", [b"-f", os.path.join(HERE, "cows/default.cow").encode(), b"moo"], b""),
          ("-f missing", [b"-f", b"nosuchcow", b"moo"], b""),
          ("-h", [b"-h"], b"")]
    # --- option bundling and separators ---------------------------------
    c += [("bundled-dy", [b"-dy", b"moo"], b""),
          ("bundled-bt", [b"-bt", b"moo"], b""),
          ("bundled-value", [b"-W20", b"word " * 10], b""),
          ("bundled-eyes", [b"-emm", b"moo"], b""),
          ("bundled-mixed", [b"-dW20", b"word " * 10], b""),
          ("dashdash", [b"--", b"moo"], b""),
          ("dash-alone", [b"-"], b"stdin here\n"),
          ("unknown-opt", [b"-Z", b"moo"], b""),
          ("unknown-bundle", [b"-notaflag"], b""),
          ("opt-after-msg", [b"moo", b"-d"], b"")]
    # --- degenerate widths ----------------------------------------------
    for w in [b"0", b"-5", b"1000", b"abc"]:
        c.append((f"-W{w.decode()}", [b"-W", w, b"word word word"], b""))
    # --- whitespace-only and paragraph shapes ---------------------------
    for s in [b"   \n", b"\t\n", b" \n \n", b"a\n\n\nb\n", b"a\n  b\n  c\n",
              b"first\n second\nthird\n", b"\ttabbed\n\tagain\n",
              b"x\r\ny\r\n", b"trailing space \n"]:
        c.append((f"stdin-ws({len(s)}b)", [], s))
    for m in [b"   ", b" ", b"  x  ", b"x  ", b"\t", b"a\tb\tc"]:
        c.append((f"ws-msg({len(m)}b)", [m], b""))
    # --- cowfile handling -----------------------------------------------
    c += [("-l list", [b"-l"], b""),
          ("-f custom", [b"-f", b"evaltest", b"moo"], b""),
          ("-f custom-path", [b"-f", os.path.join(HERE, "cows/evaltest.cow").encode(), b"moo"], b""),
          ("-f custom -d", [b"-f", b"evaltest", b"-d", b"moo"], b""),
          ("-f custom -e", [b"-f", b"evaltest", b"-e", b"##", b"-T", b"vv", b"moo"], b"")]
    # --- randomized -----------------------------------------------------
    rnd = random.Random(20260811)
    words = [b"cow", b"moo", b"a", b"supercalifragilistic", b"x" * 45, b"hi",
             b"assembly", b"y" * 12, b"z"]
    for i in range(220):
        n = rnd.randint(1, 25)
        msg = b" ".join(rnd.choice(words) for _ in range(n))
        args = []
        if rnd.random() < 0.3:
            args += [rnd.choice([b"-b", b"-d", b"-g", b"-p", b"-s", b"-t", b"-w", b"-y"])]
        if rnd.random() < 0.3:
            args += [b"-W", str(rnd.choice([5, 10, 20, 40, 60, 100])).encode()]
        if rnd.random() < 0.2:
            args += [b"-e", rnd.choice([b"..", b"XX", b"@@"])]
        if rnd.random() < 0.15:
            args += [b"-T", rnd.choice([b"U ", b"vv"])]
        if rnd.random() < 0.25:                       # via stdin instead of argv
            c.append((f"rnd{i}-stdin", args, msg + b"\n"))
        else:
            c.append((f"rnd{i}", args + [msg], b""))
    return c


def show(label, args, stdin, exp, got):
    print(f"\n  FAIL {label}  argv={[a[:25] for a in args]} stdin={stdin[:25]!r}")
    if exp[2] != got[2]:
        print(f"    rc: perl={exp[2]} ours={got[2]}")
    if exp[1] != got[1]:
        print(f"    stderr perl={exp[1][:90]!r}\n           ours={got[1][:90]!r}")
    if exp[0] != got[0]:
        e, g = exp[0].split(b"\n"), got[0].split(b"\n")
        for i in range(max(len(e), len(g))):
            a = e[i] if i < len(e) else b"<missing>"
            b = g[i] if i < len(g) else b"<missing>"
            if a != b:
                print(f"    line {i}: perl={a!r}\n             ours={b!r}")


def main():
    if not os.path.exists(FULL):
        print("build first: gcc -O2 -o cowsay_full cowsay_full.c"); return 2
    cs = cases()
    print(f"Differential fuzz vs the Perl original: {len(cs)} cases")
    # For degenerate -W values Perl leaks internal interpreter warnings naming
    # absolute module paths ("Unescaped left brace in regex ... Text/Wrap.pm").
    # Reproducing that text is meaningless, so these compare stdout+rc only.
    STDOUT_ONLY = {"-W0", "-W-5", "-Wabc"}
    fails, relaxed = [], []
    for label, args, stdin in cs:
        exp, got = run_perl(args, stdin), run_full(args, stdin)
        if label in STDOUT_ONLY:
            if (exp[0], exp[2]) != (got[0], got[2]):
                fails.append((label, args, stdin, exp, got))
            elif exp[1] != got[1]:
                relaxed.append(label)
            continue
        if exp != got:
            fails.append((label, args, stdin, exp, got))
            if VERBOSE and len(fails) <= 12:
                show(label, args, stdin, exp, got)

    # cowthink: both sides renamed so $0 / argv[0] contain "think"
    tmp = tempfile.mkdtemp()
    tperl = os.path.join(tmp, "cowthink.pl")
    tfull = os.path.join(tmp, "cowthink")
    shutil.copy(PERL, tperl); shutil.copy(FULL, tfull)
    think_fail = 0
    for msg in [b"moo", b"word " * 20, b"a"]:
        e = run_perl([msg], b"", script=tperl)
        g = run_full([msg], b"", exe=tfull)
        if (e[0], e[2]) != (g[0], g[2]):
            think_fail += 1
            if VERBOSE:
                show("cowthink", [msg], b"", e, g)
    shutil.rmtree(tmp)

    ok = len(cs) - len(fails)
    print(f"\n  {ok}/{len(cs)} byte-identical to Perl (stdout+stderr+exit code)")
    print(f"  cowthink: {'PASS' if not think_fail else f'{think_fail} FAILED'}")
    if relaxed:
        print(f"  note: {len(relaxed)} case(s) matched on stdout+rc but not stderr, because "
              f"Perl leaks internal regex warnings: {', '.join(relaxed)}")
    if fails:
        print(f"\n  {len(fails)} failing cases:")
        for label, *_ in fails[:25]:
            print(f"    - {label}")
        if not VERBOSE:
            print("  re-run with -v for diffs")
    print("\n" + "=" * 60)
    print("VERDICT: feature-matched, byte-identical to the Perl original"
          if not fails and not think_fail else "VERDICT: divergences remain")
    return 0 if not fails and not think_fail else 1


if __name__ == "__main__":
    sys.exit(main())
