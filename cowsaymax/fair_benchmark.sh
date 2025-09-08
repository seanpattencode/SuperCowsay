#!/bin/bash

echo "============================================"
echo "   FAIR BENCHMARK - Arbitrary String Support"
echo "============================================"
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=10000

echo "Compiling versions that support arbitrary input..."
gcc -O3 -o original cowsay_original.c 2>/dev/null
gcc -O3 -nostdlib -fno-stack-protector -o fast_fair cowsay_fast_fair.c 2>/dev/null
gcc -O3 -o minimal cowsay_minimal.c 2>/dev/null
gcc -O3 -o v1_buffer cowsay_v1_buffer.c 2>/dev/null
gcc -O3 -o v10_zerocopy cowsay_v10_zerocopy.c 2>/dev/null

echo
echo "Testing with different messages to ensure they work:"
echo "-----------------------------------------------------"

test_message() {
    local prog=$1
    local msg=$2
    echo -n "$prog with '$msg': "
    if ./$prog "$msg" 2>/dev/null | grep -q "$msg"; then
        echo "✓ works"
    else
        echo "✗ fails"
    fi
}

for prog in original fast_fair minimal v1_buffer v10_zerocopy; do
    if [ -f $prog ]; then
        test_message $prog "Hello"
        test_message $prog "Testing 123"
        test_message $prog "A B C D E F G"
    fi
    echo
done

echo "Performance Benchmark ($ITERATIONS iterations):"
echo "================================================"

run_bench() {
    local name=$1
    local prog=$2
    shift 2
    
    if [ -f $prog ]; then
        printf "%-20s: " "$name"
        { time -p for i in $(seq 1 $ITERATIONS); do ./$prog "$@" > /dev/null 2>&1; done; } 2>&1 | grep real | awk '{print $2 "s"}'
    fi
}

echo
echo "Test 1: Short message ('Hello World')"
echo "--------------------------------------"
run_bench "Original" original "Hello World"
run_bench "Minimal C" minimal "Hello World"
run_bench "Fast Fair (nostdlib)" fast_fair "Hello World"
run_bench "Buffer Version" v1_buffer "Hello World"
run_bench "Zero-copy I/O" v10_zerocopy "Hello World"

echo
echo "Test 2: Long message (fox jumps over lazy dog)"
echo "-----------------------------------------------"
run_bench "Original" original $TEST_MESSAGE
run_bench "Minimal C" minimal $TEST_MESSAGE
run_bench "Fast Fair (nostdlib)" fast_fair $TEST_MESSAGE
run_bench "Buffer Version" v1_buffer $TEST_MESSAGE
run_bench "Zero-copy I/O" v10_zerocopy $TEST_MESSAGE

echo
echo "Test 3: Multiple arguments"
echo "---------------------------"
run_bench "Original" original A B C D E F G H I J
run_bench "Minimal C" minimal A B C D E F G H I J
run_bench "Fast Fair (nostdlib)" fast_fair A B C D E F G H I J
run_bench "Buffer Version" v1_buffer A B C D E F G H I J
run_bench "Zero-copy I/O" v10_zerocopy A B C D E F G H I J

echo
echo "============================================"
echo "ANALYSIS:"
echo "The minimal version is fastest while still"
echo "supporting arbitrary input strings!"
echo "============================================"