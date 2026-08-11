#!/bin/bash
# bench_ultra.sh - build both, prove cowsay_ultra byte-identical to cowsay_dynamic, then bench vs the exec floor.
cd "$(dirname "$0")"
as -o cowsay_dynamic.o cowsay_dynamic.s && ld -o cowsay_dynamic cowsay_dynamic.o -z noexecstack || exit 1
nasm -f bin -o cowsay_ultra cowsay_ultra.asm && chmod +x cowsay_ultra || exit 1
nasm -f bin -o floor_exit "Alternative Methods/floor_exit.asm" && chmod +x floor_exit || exit 1

A=$(printf 'A%.0s' {1..255}); fail=0
check(){
  ./cowsay_dynamic "$@" >/tmp/scd.out 2>/tmp/scd.err; de=$?
  ./cowsay_ultra   "$@" >/tmp/scu.out 2>/tmp/scu.err; ue=$?
  cmp -s /tmp/scd.out /tmp/scu.out && cmp -s /tmp/scd.err /tmp/scu.err && [ "$de" = "$ue" ] \
    && echo "OK  rc=$de argc=$#" || { echo "FAIL [$*]"; fail=1; }
}
check; check Hello; check Hello World Test; check ""; check "" ""; check "" x; check x ""
check 'Test!@#$%^&*()'; check 123 456; check "Hello 🐄 World"
check "$A"; check "${A}B"; check "$A" "$A" "$A" "$A"; check "$A" "$A" "$A" "$A" ""
check "The quick brown fox jumps over the lazy dog"
[ $fail = 0 ] && echo "=== byte-identical: stdout+stderr+exit codes ===" || exit 1

echo; ls -l cowsay_dynamic cowsay_ultra floor_exit | awk '{printf "%8d B  %s\n",$5,$9}'
for b in cowsay_dynamic cowsay_ultra; do
  echo "$b: $(readelf -lW $b | grep -c ' LOAD') LOAD segments"
done
echo
M="The quick brown fox jumps over the lazy dog"
PIN=""; command -v taskset >/dev/null && PIN="taskset -c 3"
$PIN hyperfine -N --warmup 200 --min-runs 1000 \
  "./cowsay_dynamic '$M'" "./cowsay_ultra '$M'" "./floor_exit"
