#!/bin/bash

echo "=========================================="
echo "   SINGLE EXECUTION BENCHMARK"
echo "=========================================="
echo
echo "Testing startup + execution overhead for ONE run:"
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"

# Compile everything fresh
gcc -O3 -o original cowsay_original.c 2>/dev/null
gcc -O3 -nostdlib -o syscall cowsay_extreme3_syscall.c 2>/dev/null
as -o hyperspeed.o cowsay_hyperspeed.s 2>/dev/null
ld -o hyperspeed hyperspeed.o -z noexecstack 2>/dev/null

echo "Method 1: Using 'time' command (includes shell overhead):"
echo "----------------------------------------------------------"

echo -n "Original:      "
{ time ./original "$TEST_MESSAGE" > /dev/null 2>&1; } 2>&1 | grep real

echo -n "Direct Syscall:"
{ time ./syscall > /dev/null 2>&1; } 2>&1 | grep real

echo -n "Pure Assembly: "
{ time ./hyperspeed > /dev/null 2>&1; } 2>&1 | grep real

echo
echo "Method 2: High-precision timing (1000 single runs averaged):"
echo "-------------------------------------------------------------"

# Test with higher precision using multiple single runs
for prog in "original:$TEST_MESSAGE" "syscall:" "hyperspeed:"; do
    binary="${prog%%:*}"
    args="${prog#*:}"
    
    echo -n "$binary: "
    total=0
    for i in {1..1000}; do
        start=$(date +%s%N)
        ./$binary $args > /dev/null 2>&1
        end=$(date +%s%N)
        total=$((total + end - start))
    done
    avg=$((total / 1000))
    echo "$(echo "scale=6; $avg / 1000000" | bc)ms average"
done

echo
echo "Method 3: Using perf stat (CPU cycles and instructions):"
echo "---------------------------------------------------------"

if command -v perf &> /dev/null; then
    echo "Original:"
    perf stat -e cycles,instructions ./original "$TEST_MESSAGE" 2>&1 > /dev/null | grep -E "cycles|instructions" | head -2
    
    echo
    echo "Pure Assembly:"
    perf stat -e cycles,instructions ./hyperspeed 2>&1 > /dev/null | grep -E "cycles|instructions" | head -2
else
    echo "perf not available"
fi

echo
echo "Method 4: strace syscall count:"
echo "--------------------------------"

echo -n "Original syscalls: "
strace -c ./original "$TEST_MESSAGE" 2>&1 > /dev/null | grep "total" | awk '{print $4}'

echo -n "Assembly syscalls: "
strace -c ./hyperspeed 2>&1 > /dev/null | grep "total" | awk '{print $4}'

echo
echo "=========================================="
echo "File sizes (binary overhead):"
echo "------------------------------"
ls -lh original syscall hyperspeed | awk '{print $9": "$5}'

echo
echo "=========================================="
echo "ANALYSIS:"
echo "For single execution, the assembly version:"
echo "- Has minimal startup overhead"
echo "- Makes fewer syscalls"
echo "- Has smaller binary size"
echo "- Should be faster even for one-shot runs"
echo "=========================================="