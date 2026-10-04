#!/bin/bash
# bench_js.sh - the JavaScript versions: verify both contracts, then time everything in
# ONE hyperfine session next to the native builds, the Perl original, and each runtime's
# own do-nothing floor (`node -e 0`, `bun -e 0`), so the script's cost and the runtime's
# cost can be told apart.
cd "$(dirname "$0")"
command -v node >/dev/null || { echo "node not found"; exit 1; }
command -v bun  >/dev/null || { echo "bun not found:  curl -fsSL https://bun.sh/install | bash"; exit 1; }
command -v hyperfine >/dev/null || { echo "hyperfine not found: sudo apt install hyperfine"; exit 1; }
make -s cowsay_dynamic cowsay_ultra cowsay_full cowsay_full_bun >/dev/null || exit 1
nasm -f bin -o floor_exit "Alternative Methods/floor_exit.asm" && chmod +x floor_exit || exit 1

echo "== compatibility build: 344-case differential fuzz + extras vs the Perl original"
for impl in "node cowsay_full.js" "bun cowsay_full.js" "./cowsay_full_bun"; do
  python3 eval_full.py --extra --impl "$impl" | grep -E 'byte-identical to Perl|cowthink' | sed "s|^ *|  $impl: |" || exit 1
done
echo "== speed-build subset: 16-case identity matrix vs cowsay_dynamic"
for impl in "node langs/cowsay.js" "bun langs/cowsay.js"; do
  QUIET=1 ./verify_identity.sh "$impl" && echo "  OK  $impl  16/16" || exit 1
done

echo
ls -lL cowsay_ultra cowsay_full cowsay_full_bun "$(command -v node)" "$(command -v bun)" | awk '{printf "%11d B  %s\n",$5,$9}'
echo "node $(node --version)   bun $(bun --version)"
echo
M="The quick brown fox jumps over the lazy dog"
PIN=""; command -v taskset >/dev/null && PIN="taskset -c 3"
export COWPATH=./cows
$PIN hyperfine -N --warmup 50 --min-runs 300 \
  "./floor_exit" \
  "./cowsay_ultra '$M'" \
  "./cowsay_full '$M'" \
  "perl cowsay_original_perl.pl '$M'" \
  "bun -e 0" \
  "bun langs/cowsay.js '$M'" \
  "bun cowsay_full.js '$M'" \
  "./cowsay_full_bun '$M'" \
  "node -e 0" \
  "node langs/cowsay.js '$M'" \
  "node cowsay_full.js '$M'"
