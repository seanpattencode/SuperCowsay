#!/bin/bash

echo "Cowsay Performance Benchmark (Simple)"
echo "======================================"
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=1000

echo "Compiling all versions..."
gcc -O3 -o cowsay_original cowsay_original.c 2>/dev/null && echo "Original compiled"
gcc -O3 -o cowsay_v1_buffer cowsay_v1_buffer.c 2>/dev/null && echo "V1 Buffer compiled"
gcc -O3 -mavx2 -o cowsay_v2_simd cowsay_v2_simd.c 2>/dev/null && echo "V2 SIMD compiled"
gcc -O3 -o cowsay_v4_asm cowsay_v4_asm.c 2>/dev/null && echo "V4 Assembly compiled"
gcc -O3 -o cowsay_v5_lut cowsay_v5_lut.c 2>/dev/null && echo "V5 LUT compiled"
gcc -O3 -o cowsay_v6_unrolled cowsay_v6_unrolled.c 2>/dev/null && echo "V6 Unrolled compiled"
gcc -O3 -o cowsay_v7_mmap cowsay_v7_mmap.c 2>/dev/null && echo "V7 Mmap compiled"
gcc -O3 -o cowsay_v8_vector cowsay_v8_vector.c 2>/dev/null && echo "V8 Vector compiled"
gcc -O3 -pthread -o cowsay_v9_threaded cowsay_v9_threaded.c 2>/dev/null && echo "V9 Threaded compiled"
gcc -O3 -o cowsay_v10_zerocopy cowsay_v10_zerocopy.c 2>/dev/null && echo "V10 Zero-copy compiled"

echo
echo "Testing each version first..."
./cowsay_original "$TEST_MESSAGE" > /dev/null 2>&1 && echo "Original works"
./cowsay_v1_buffer "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V1 Buffer works"
./cowsay_v2_simd "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V2 SIMD works"
./cowsay_v4_asm "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V4 Assembly works"
./cowsay_v5_lut "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V5 LUT works"
./cowsay_v6_unrolled "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V6 Unrolled works"
./cowsay_v7_mmap "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V7 Mmap works"
./cowsay_v8_vector "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V8 Vector works"
./cowsay_v9_threaded "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V9 Threaded works"
./cowsay_v10_zerocopy "$TEST_MESSAGE" > /dev/null 2>&1 && echo "V10 Zero-copy works"

echo
echo "Running benchmarks ($ITERATIONS iterations each)..."
echo

run_benchmark() {
    local name=$1
    local binary=$2
    
    if [ -f "$binary" ]; then
        echo -n "$name: "
        time (for i in $(seq 1 $ITERATIONS); do
            ./$binary "$TEST_MESSAGE" > /dev/null 2>&1
        done) 2>&1 | grep real | awk '{print $2}'
    fi
}

run_benchmark "Original" "cowsay_original"
run_benchmark "V1 Buffer" "cowsay_v1_buffer"
run_benchmark "V2 SIMD" "cowsay_v2_simd"
run_benchmark "V4 Assembly" "cowsay_v4_asm"
run_benchmark "V5 LUT" "cowsay_v5_lut"
run_benchmark "V6 Unrolled" "cowsay_v6_unrolled"
run_benchmark "V7 Mmap" "cowsay_v7_mmap"
run_benchmark "V8 Vector" "cowsay_v8_vector"
run_benchmark "V9 Threaded" "cowsay_v9_threaded"
run_benchmark "V10 Zero-copy" "cowsay_v10_zerocopy"

echo
echo "Benchmark complete!"