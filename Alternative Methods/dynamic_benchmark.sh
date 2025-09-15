#!/bin/bash

echo "=============================================="
echo "   DYNAMIC ASSEMBLY BENCHMARK"
echo "=============================================="
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=10000

echo "Compiling all versions..."
echo "--------------------------"

# Original
gcc -O3 -w -o original cowsay_original.c && echo "✓ Original compiled"

# Static assembly (hardcoded)
as -o hyperspeed.o cowsay_hyperspeed.s 2>/dev/null && \
ld -o hyperspeed hyperspeed.o -z noexecstack && echo "✓ Static assembly compiled"

# Dynamic assembly
as -o cowsay_dynamic.o cowsay_dynamic.s 2>/dev/null && \
ld -o dynamic_asm cowsay_dynamic.o -z noexecstack && echo "✓ Dynamic assembly compiled"

# Dynamic optimized C
gcc -O3 -nostdlib -o dynamic_opt cowsay_dynamic_opt.c 2>/dev/null && echo "✓ Dynamic optimized compiled"

# Minimal C
gcc -O3 -o minimal cowsay_minimal.c && echo "✓ Minimal C compiled"

# Fast fair
gcc -O3 -nostdlib -o fast_fair cowsay_fast_fair.c 2>/dev/null && echo "✓ Fast fair compiled"

echo
echo "Testing correctness (all should show the message):"
echo "---------------------------------------------------"

echo "Original:"
./original "Test message" | head -2

echo
echo "Dynamic Assembly:"
./dynamic_asm "Test message" 2>/dev/null | head -2

echo
echo "Minimal C:"
./minimal "Test message" | head -2

echo
echo "Static Assembly (shows hardcoded):"
./hyperspeed | head -2

echo
echo "=============================================="
echo "PERFORMANCE BENCHMARK ($ITERATIONS iterations)"
echo "=============================================="
echo

run_bench() {
    local name=$1
    local prog=$2
    shift 2
    
    if [ -f "$prog" ]; then
        printf "%-25s: " "$name"
        start=$(date +%s%N)
        for i in $(seq 1 $ITERATIONS); do
            ./$prog "$@" > /dev/null 2>&1
        done
        end=$(date +%s%N)
        elapsed=$((end - start))
        ms=$((elapsed / 1000000))
        ops=$((ITERATIONS * 1000 / ms))
        printf "%5dms (%5d ops/sec)\n" $ms $ops
    else
        printf "%-25s: Not compiled\n" "$name"
    fi
}

echo "Test 1: Standard benchmark message"
echo "-----------------------------------"
run_bench "Original" original $TEST_MESSAGE
run_bench "Minimal C" minimal $TEST_MESSAGE
run_bench "Fast Fair (nostdlib)" fast_fair $TEST_MESSAGE
run_bench "Dynamic Assembly" dynamic_asm $TEST_MESSAGE
run_bench "Dynamic Optimized" dynamic_opt $TEST_MESSAGE
run_bench "Static Assembly (cheat)" hyperspeed

echo
echo "Test 2: Short message"
echo "---------------------"
run_bench "Original" original "Hi"
run_bench "Minimal C" minimal "Hi"
run_bench "Dynamic Assembly" dynamic_asm "Hi"
run_bench "Static Assembly" hyperspeed

echo
echo "Test 3: Multiple arguments"
echo "---------------------------"
run_bench "Original" original A B C D E F
run_bench "Minimal C" minimal A B C D E F
run_bench "Dynamic Assembly" dynamic_asm A B C D E F
run_bench "Static Assembly" hyperspeed

echo
echo "=============================================="
echo "ANALYSIS:"
echo
echo "The dynamic assembly version:"
echo "- Supports arbitrary input (unlike static)"
echo "- Should be much faster than original"
echo "- Uses same technique as static but dynamically"
echo "=============================================="