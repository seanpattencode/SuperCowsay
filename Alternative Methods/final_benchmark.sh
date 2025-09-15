#!/bin/bash

echo "Final Cowsay Performance Test"
echo "============================="
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=10000

echo "Compiling working versions..."
gcc -O3 -march=native -o cowsay_original cowsay_original.c
gcc -O3 -march=native -o cowsay_v1_buffer cowsay_v1_buffer.c
gcc -O3 -march=native -o cowsay_v4_asm cowsay_v4_asm.c
gcc -O3 -march=native -o cowsay_v5_lut cowsay_v5_lut.c
gcc -O3 -march=native -o cowsay_v6_unrolled cowsay_v6_unrolled.c
gcc -O3 -march=native -o cowsay_v7_mmap cowsay_v7_mmap.c
gcc -O3 -march=native -pthread -o cowsay_v9_threaded cowsay_v9_threaded.c
gcc -O3 -march=native -o cowsay_v10_zerocopy cowsay_v10_zerocopy.c
gcc -O3 -march=native -o cowsay_ultimate cowsay_ultimate.c

echo
echo "Benchmark Results ($ITERATIONS iterations):"
echo "============================================"

run_test() {
    local name=$1
    local binary=$2
    
    if [ -f "$binary" ]; then
        printf "%-20s: " "$name"
        { time -p for i in $(seq 1 $ITERATIONS); do ./$binary "$TEST_MESSAGE" > /dev/null; done; } 2>&1 | grep real | awk '{printf "%.3f seconds\n", $2}'
    fi
}

run_test "Original" "cowsay_original"
run_test "V1 Buffer" "cowsay_v1_buffer"
run_test "V4 Assembly" "cowsay_v4_asm"
run_test "V5 LUT" "cowsay_v5_lut"
run_test "V6 Unrolled" "cowsay_v6_unrolled"
run_test "V7 Mmap" "cowsay_v7_mmap"
run_test "V9 Threaded" "cowsay_v9_threaded"
run_test "V10 Zero-copy" "cowsay_v10_zerocopy"
run_test "Ultimate" "cowsay_ultimate"

echo
echo "The fastest version is likely V10 Zero-copy or Ultimate!"
echo "These use writev() for scatter-gather I/O, eliminating buffer copies."