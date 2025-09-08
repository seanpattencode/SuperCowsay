#!/bin/bash

echo "EXTREME Cowsay Quick Benchmark"
echo "=============================="
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=10000

# Compile
gcc -O3 -march=native -o original cowsay_original.c 2>/dev/null
gcc -O3 -march=native -fno-stack-protector -o extreme1 cowsay_extreme1_static.c 2>/dev/null
gcc -O3 -march=native -fno-stack-protector -o extreme2 cowsay_extreme2_cached.c 2>/dev/null
gcc -O3 -march=native -nostdlib -fno-stack-protector -o extreme3 cowsay_extreme3_syscall.c 2>/dev/null
gcc -O3 -march=native -nostdlib -fno-stack-protector -o extreme5 cowsay_extreme5_ultimate.c 2>/dev/null

echo "Results ($ITERATIONS iterations):"
echo

run() {
    printf "%-25s: " "$1"
    shift
    { time -p for i in $(seq 1 $ITERATIONS); do "$@" > /dev/null 2>&1; done; } 2>&1 | grep real | awk '{print $2}'
}

run "Original" ./original $TEST_MESSAGE
run "Static (no string ops)" ./extreme1 $TEST_MESSAGE  
run "Cached (after warmup)" ./extreme2 $TEST_MESSAGE
run "Direct Syscall" ./extreme3
run "Pure Assembly" ./extreme5

echo
echo "Single call test (to see startup overhead):"
time ./original "$TEST_MESSAGE" > /dev/null 2>&1
time ./extreme3 > /dev/null 2>&1
time ./extreme5 > /dev/null 2>&1