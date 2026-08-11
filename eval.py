#!/usr/bin/env python3
"""eval.py - adversarial evaluation of the SuperCowsay claim.

bench_ultra.sh proves our two implementations agree with each other; a shared bug
would pass it. This evaluates them against an INDEPENDENT oracle (the spec
re-derived in Python), fuzzes them with inputs designed to break hand-written
assembly, and measures where the "superior" claim actually holds and where it
does not.

  python3 eval.py            # full evaluation
  python3 eval.py --quick    # skip the slow compat + speed dimensions
"""
import ctypes, os, random, subprocess, sys, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ULTRA = os.path.join(HERE, "cowsay_ultra")
DYN = os.path.join(HERE, "cowsay_dynamic")
PERL = os.path.join(HERE, "cowsay_original_perl.pl")

COW = (b"        \\   ^__^\n"
       b"         \\  (oo)\\_______\n"
       b"            (__)\\       )\\/\\\n"
       b"                ||----w |\n"
       b"                ||     ||\n")
DEFAULT = b"Hello, World!"
MAX_ARG, MAX_MSG = 256, 1024
ERR = b"Error: Input too long (max 1024 characters)\n"


def oracle(args):
    """Independent reimplementation of the spec. Returns (stdout, stderr, rc)."""
    if not args:
        msg = DEFAULT
    else:
        total = 0
        for a in args:                      # limits checked incrementally, as the asm does
            if len(a) >= MAX_ARG:
                return b"", ERR, 1
            if total != 0:
                total += 1
            total += len(a)
            if total >= MAX_MSG:
                return b"", ERR, 1
        msg = b""
        for a in args:                      # separator only once something is emitted
            msg += (b" " if msg else b"") + a
    bar = b"_" * (len(msg) + 2)
    dash = b"-" * (len(msg) + 2)
    return (b" " + bar + b"\n< " + msg + b" >\n " + dash + b"\n" + COW, b"", 0)


def run(binary, args):
    p = subprocess.run([binary] + list(args), capture_output=True)
    return p.stdout, p.stderr, p.returncode


def structural(out, args):
    """Format invariants, checked without reference to any implementation.

    Newline-safe: a message may itself contain \\n (the box then renders broken,
    which is the documented single-line limitation, but the geometry of the
    border/body/cow decomposition must still hold).
    """
    if not out:
        return "empty output"
    if not out.endswith(COW):
        return "cow art missing or corrupted"
    rest = out[:-len(COW)]
    lines = rest.split(b"\n")
    if lines[-1] != b"" or len(lines) < 4:
        return "output not newline-terminated"
    lines = lines[:-1]
    top, bot, body = lines[0], lines[-1], b"\n".join(lines[1:-1])
    if not (body.startswith(b"< ") and body.endswith(b" >")):
        return "message line not wrapped in < >"
    inner = body[2:-2]
    if top != b" " + b"_" * (len(inner) + 2):
        return f"top border is {len(top)-1} chars, message is {len(inner)} (+2 expected)"
    if bot != b" " + b"-" * (len(inner) + 2):
        return f"bottom border is {len(bot)-1} chars, message is {len(inner)} (+2 expected)"
    return None


def corpus():
    """Adversarial cases first, then randomized fuzz."""
    c = [
        [], [b""], [b"", b""], [b"", b"x"], [b"x", b""], [b"x", b"", b"y"],
        [b"Hello"], [b"Hello", b"World"], [b"a"] * 100,
        [b"Test!@#$%^&*()"], [b"'quoted'"], [b'"dquoted"'], [b"back\\slash"],
        [b"\t"], [b"tab\there"], [b"new\nline"], [b"car\rriage"],
        [b"\x01\x02\x03"], [b"\x7f"], [b"\xff\xfe"], [b"\xc3"],          # invalid UTF-8
        [b"\xe2\x98\x83"], ["🐄".encode()], ["日本語".encode()],
        [b"-h"], [b"--help"], [b"-f"], [b"--version"],                    # flags are just text
        [b"A" * 255], [b"A" * 256], [b"A" * 257], [b"A" * 1023], [b"A" * 5000],
        [b"A" * 255] * 4,              # 1023 total: legal
        [b"A" * 255] * 4 + [b""],      # 1024 total: error
        [b"A" * 255] * 5,
        [b"a"] * 512, [b"a"] * 511, [b"a"] * 513,
        [b"a"] * 5000,                 # huge argc
        [b""] * 2000,                  # many empties: total stays 0
        [b"x" * 200, b"y" * 200, b"z" * 200],
    ]
    rnd = random.Random(1337)
    pool = bytes(range(1, 256))
    for _ in range(600):
        n = rnd.choice([1, 1, 1, 2, 3, 5, 10])
        args = []
        for _ in range(n):
            ln = rnd.choice([0, 1, 5, 40, 100, 250, 255, 256, 300])
            args.append(bytes(rnd.choice(pool) for _ in range(ln)))
        c.append(args)
    return c


def dim_oracle(binaries, cases):
    print("\n[1] ORACLE CONFORMANCE - vs an independent Python reimplementation")
    fails = 0
    for name, b in binaries:
        bad = 0
        for args in cases:
            got, exp = run(b, args), oracle(args)
            if got != exp:
                bad += 1
                if bad <= 2:
                    print(f"  MISMATCH {name} argc={len(args)} "
                          f"lens={[len(a) for a in args][:6]}\n"
                          f"    expected rc={exp[2]} out={exp[0][:60]!r}\n"
                          f"    got      rc={got[2]} out={got[0][:60]!r}")
        print(f"  {'PASS' if not bad else 'FAIL'}  {name}: {len(cases)-bad}/{len(cases)} match the oracle")
        fails += bad
    return fails


def dim_structural(binaries, cases):
    print("\n[2] STRUCTURAL INVARIANTS - box geometry and cow integrity, no reference impl")
    fails = 0
    for name, b in binaries:
        bad = 0
        for args in cases:
            out, _, rc = run(b, args)
            if rc == 0:
                err = structural(out, args)
                if err:
                    bad += 1
                    if bad <= 2:
                        print(f"  BROKEN {name} argc={len(args)}: {err}")
        print(f"  {'PASS' if not bad else 'FAIL'}  {name}: every success output well-formed")
        fails += bad
    return fails


def dim_robust(binaries, cases):
    print("\n[3] ROBUSTNESS - no crashes, no signals, no unexpected exit codes")
    fails = 0
    for name, b in binaries:
        bad = 0
        for args in cases:
            _, _, rc = run(b, args)
            if rc not in (0, 1):
                bad += 1
                sig = -rc if rc < 0 else 0
                print(f"  CRASH {name} rc={rc}{' SIG'+str(sig) if sig else ''} argc={len(args)}")
        # argc=0: no argv[0] at all. os.execv() refuses an empty list, so go
        # through libc directly - this is the only way to actually produce argc=0.
        pid = os.fork()
        if pid == 0:
            try:
                devnull = os.open(os.devnull, os.O_WRONLY)
                os.dup2(devnull, 1); os.dup2(devnull, 2)
                libc = ctypes.CDLL(None, use_errno=True)
                argv = (ctypes.c_char_p * 1)(None)          # empty, NULL-terminated
                libc.execv(b.encode(), argv)
            except Exception:
                pass
            os._exit(99)                                     # only reached if execv failed
        _, st = os.waitpid(pid, 0)
        argc0 = os.WIFEXITED(st) and os.WEXITSTATUS(st) in (0, 1)
        print(f"  {'PASS' if not bad else 'FAIL'}  {name}: {len(cases)} inputs, no signal deaths"
              f"; argc=0 {'handled' if argc0 else 'CRASHED'}")
        fails += bad + (0 if argc0 else 1)
    return fails


def dim_compat():
    print("\n[4] REAL COWSAY COMPATIBILITY - are we a drop-in replacement?")
    if not shutil.which("perl") or not os.path.exists(PERL):
        print("  SKIP  perl or cowsay_original_perl.pl unavailable")
        return 0
    env = dict(os.environ, COWPATH=os.path.join(HERE, "cows"))
    tests = [b"hi", b"short message", b"A" * 39, b"A" * 40, b"A" * 41,
             b"The quick brown fox jumps over the lazy dog", b"word " * 20]
    match = 0
    for t in tests:
        ours, _, _ = run(ULTRA, [t])
        p = subprocess.run(["perl", PERL, t], capture_output=True, env=env)
        same = ours == p.stdout
        match += same
        note = ""
        if not same:
            theirs = p.stdout.splitlines()
            note = (f"real cowsay: {len(theirs)} lines, "
                    f"first={theirs[1][:34].decode('utf8','replace')!r}...  "
                    f"ours: {len(ours.splitlines())} lines, unwrapped")
        print(f"  {'match ' if same else 'DIFFER'}  len={len(t):4d}  {note}")
    print(f"  {match}/{len(tests)} identical to real cowsay "
          f"(divergence begins at 40 chars, where real cowsay word-wraps)")
    return 0


def dim_speed():
    print("\n[5] SPEED SCALING - does the win hold across message sizes?")
    if not shutil.which("hyperfine"):
        print("  SKIP  hyperfine not installed")
        return 0
    for n in (1, 43, 500, 1023):
        # chunk into <=200-char words: a single 500-char arg legitimately exits 1
        # (per-arg limit is 256) and hyperfine treats non-zero exit as failure
        msg = " ".join("A" * min(200, n - i) for i in range(0, n, 201))
        cmds = [f"{ULTRA} {msg}", f"{DYN} {msg}"]
        csv = "/tmp/_eval_speed.csv"
        # pin like bench_ultra.sh does, or absolute numbers are not comparable to it
        pin = ["taskset", "-c", "3"] if shutil.which("taskset") else []
        r = subprocess.run(pin + ["hyperfine", "-N", "--warmup", "50", "--min-runs", "300",
                                  "--export-csv", csv] + cmds,
                           capture_output=True)
        if r.returncode != 0:
            print(f"  len={n:5d}  benchmark failed")
            continue
        means = []
        with open(csv) as f:
            for line in list(f)[1:]:
                means.append(float(line.split(",")[1]) * 1e6)
        if len(means) == 2:
            print(f"  len={n:5d}  ultra {means[0]:6.1f}us   dynamic {means[1]:6.1f}us   "
                  f"ratio {means[1]/means[0]:.2f}x")
    return 0


def main():
    quick = "--quick" in sys.argv
    for b in (ULTRA, DYN):
        if not os.path.exists(b):
            print(f"missing {b} - run ./bench_ultra.sh first"); return 2
    binaries = [("cowsay_ultra", ULTRA), ("cowsay_dynamic", DYN)]
    cases = corpus()
    print(f"SuperCowsay evaluation - {len(cases)} inputs x {len(binaries)} implementations")
    f = 0
    f += dim_oracle(binaries, cases)
    f += dim_structural(binaries, cases)
    f += dim_robust(binaries, cases)
    if not quick:
        f += dim_compat()
        f += dim_speed()
    print("\n" + ("=" * 62))
    print("VERDICT: all correctness dimensions PASS" if f == 0
          else f"VERDICT: {f} failures - the claim does not hold")
    return 0 if f == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
