#!/bin/bash
# verify_identity.sh CANDIDATE [REFERENCE]
# Proves CANDIDATE is byte-identical to REFERENCE (default ./cowsay_dynamic) on
# stdout, stderr, AND exit code across the full edge-case matrix. Single source of
# truth for correctness - bench_ultra.sh and install.sh both call this.
# Exit 0 = identical, 1 = mismatch.
cd "$(dirname "$0")"
CAND="${1:?usage: verify_identity.sh CANDIDATE [REFERENCE]}"
REF="${2:-./cowsay_dynamic}"
QUIET="${QUIET:-0}"
[ -x "$CAND" ] || { echo "verify: $CAND not executable"; exit 1; }
[ -x "$REF" ]  || { echo "verify: reference $REF not executable"; exit 1; }

T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fail=0 n=0
check(){
  "$REF"  "$@" >"$T/r.out" 2>"$T/r.err"; re=$?
  "$CAND" "$@" >"$T/c.out" 2>"$T/c.err"; ce=$?
  n=$((n+1))
  if cmp -s "$T/r.out" "$T/c.out" && cmp -s "$T/r.err" "$T/c.err" && [ "$re" = "$ce" ]; then
    [ "$QUIET" = 1 ] || echo "  OK  rc=$re argc=$#"
  else
    echo "  FAIL argc=$# rc=$re/$ce : $*"; fail=1
  fi
}

A=$(printf 'A%.0s' {1..255})              # 255 chars: the last legal single arg
LONG=$(printf 'C%.0s' {1..1023})          # 1023 chars in ONE arg: over the 256/arg limit

check                                      # no args -> default message
check Hello
check Hello World Test
check ""                                   # single empty arg
check "" ""                                # all-empty
check "" x                                 # empty first (separator logic)
check x ""                                 # empty last
check 'Test!@#$%^&*()'                     # shell specials
check 123 456
check "Hello 🐄 World"                     # multi-byte UTF-8
check "$A"                                 # 255-char arg: legal
check "${A}B"                              # 256-char arg: must error
check "$LONG"                              # 1023 chars in one arg: per-arg limit, must error
check "$A" "$A" "$A" "$A"                  # 255*4 + 3 separators = 1023 total: legal
check "$A" "$A" "$A" "$A" ""               # +1 separator = 1024 total: must error
check "The quick brown fox jumps over the lazy dog"

if [ $fail = 0 ]; then
  [ "$QUIET" = 1 ] || echo "=== $n/$n byte-identical: stdout+stderr+exit codes ==="
  exit 0
fi
echo "=== IDENTITY FAILED ($CAND vs $REF) ==="
exit 1
