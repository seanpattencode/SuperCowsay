#!/bin/bash

echo "Cowsay Performance Benchmark"
echo "============================"
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=100000

echo "Compiling all versions..."
gcc -O3 -o cowsay_original cowsay_original.c 2>/dev/null
gcc -O3 -o cowsay_v1_buffer cowsay_v1_buffer.c 2>/dev/null
gcc -O3 -mavx2 -o cowsay_v2_simd cowsay_v2_simd.c 2>/dev/null
nvcc -O3 -o cowsay_v3_cuda cowsay_v3_cuda.cu 2>/dev/null
gcc -O3 -o cowsay_v4_asm cowsay_v4_asm.c 2>/dev/null
gcc -O3 -o cowsay_v5_lut cowsay_v5_lut.c 2>/dev/null
gcc -O3 -o cowsay_v6_unrolled cowsay_v6_unrolled.c 2>/dev/null
gcc -O3 -o cowsay_v7_mmap cowsay_v7_mmap.c 2>/dev/null
gcc -O3 -o cowsay_v8_vector cowsay_v8_vector.c 2>/dev/null
gcc -O3 -pthread -o cowsay_v9_threaded cowsay_v9_threaded.c 2>/dev/null
gcc -O3 -o cowsay_v10_zerocopy cowsay_v10_zerocopy.c 2>/dev/null

echo "Running benchmarks ($ITERATIONS iterations each)..."
echo

run_benchmark() {
    local name=$1
    local binary=$2
    
    if [ -f "$binary" ]; then
        echo -n "$name: "
        start=$(date +%s%N)
        for i in $(seq 1 $ITERATIONS); do
            ./$binary "$TEST_MESSAGE" > /dev/null
        done
        end=$(date +%s%N)
        elapsed=$((end - start))
        elapsed_ms=$((elapsed / 1000000))
        ops_per_sec=$((ITERATIONS * 1000 / elapsed_ms))
        echo "${elapsed_ms}ms (${ops_per_sec} ops/sec)"
    else
        echo "$name: Not compiled (missing dependencies)"
    fi
}

run_benchmark "Original" "cowsay_original"
run_benchmark "V1 Buffer" "cowsay_v1_buffer"
run_benchmark "V2 SIMD" "cowsay_v2_simd"
run_benchmark "V3 CUDA" "cowsay_v3_cuda"
run_benchmark "V4 Assembly" "cowsay_v4_asm"
run_benchmark "V5 LUT" "cowsay_v5_lut"
run_benchmark "V6 Unrolled" "cowsay_v6_unrolled"
run_benchmark "V7 Mmap" "cowsay_v7_mmap"
run_benchmark "V8 Vector" "cowsay_v8_vector"
run_benchmark "V9 Threaded" "cowsay_v9_threaded"
run_benchmark "V10 Zero-copy" "cowsay_v10_zerocopy"

echo
echo "Benchmark complete!"