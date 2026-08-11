#!/bin/bash
# bench_ultra.sh - build all three, prove cowsay_ultra byte-identical to cowsay_dynamic,
# then bench both against the kernel's process-spawn floor.
cd "$(dirname "$0")"
as -o cowsay_dynamic.o cowsay_dynamic.s && ld -o cowsay_dynamic cowsay_dynamic.o -z noexecstack || exit 1
nasm -f bin -o cowsay_ultra cowsay_ultra.asm && chmod +x cowsay_ultra || exit 1
nasm -f bin -o floor_exit "Alternative Methods/floor_exit.asm" && chmod +x floor_exit || exit 1

./verify_identity.sh ./cowsay_ultra ./cowsay_dynamic || exit 1

echo; ls -l cowsay_dynamic cowsay_ultra floor_exit | awk '{printf "%8d B  %s\n",$5,$9}'
for b in cowsay_dynamic cowsay_ultra; do
  echo "$b: $(readelf -lW $b | grep -c ' LOAD') LOAD segments"
done
echo
M="The quick brown fox jumps over the lazy dog"
PIN=""; command -v taskset >/dev/null && PIN="taskset -c 3"
$PIN hyperfine -N --warmup 200 --min-runs 1000 \
  "./cowsay_dynamic '$M'" "./cowsay_ultra '$M'" "./floor_exit"
