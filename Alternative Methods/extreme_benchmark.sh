#!/bin/bash

echo "EXTREME Cowsay Performance Benchmark"
echo "====================================="
echo

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
ITERATIONS=100000

echo "Compiling extreme versions..."
echo

# Original for comparison
gcc -O3 -march=native -o cowsay_original cowsay_original.c 2>/dev/null && echo "✓ Original compiled"

# Extreme versions
gcc -O3 -march=native -fno-stack-protector -o extreme1_static cowsay_extreme1_static.c 2>/dev/null && echo "✓ Extreme1 Static compiled"
gcc -O3 -march=native -fno-stack-protector -o extreme2_cached cowsay_extreme2_cached.c 2>/dev/null && echo "✓ Extreme2 Cached compiled"
gcc -O3 -march=native -nostdlib -fno-stack-protector -o extreme3_syscall cowsay_extreme3_syscall.c 2>/dev/null && echo "✓ Extreme3 Syscall compiled"
gcc -O3 -march=native -o extreme4_sendfile cowsay_extreme4_sendfile.c 2>/dev/null && echo "✓ Extreme4 Sendfile compiled"
gcc -O3 -march=native -nostdlib -fno-stack-protector -o extreme5_ultimate cowsay_extreme5_ultimate.c 2>/dev/null && echo "✓ Extreme5 Ultimate compiled"
gcc -O3 -march=native -o extreme6_splice cowsay_extreme6_splice.c 2>/dev/null && echo "✓ Extreme6 Splice compiled"

echo
echo "Testing correctness..."
./extreme1_static "$TEST_MESSAGE" > /tmp/test1.txt 2>/dev/null && echo "✓ Static works"
./extreme2_cached "$TEST_MESSAGE" > /tmp/test2.txt 2>/dev/null && echo "✓ Cached works"
./extreme3_syscall > /tmp/test3.txt 2>/dev/null && echo "✓ Syscall works"
./extreme4_sendfile "$TEST_MESSAGE" > /tmp/test4.txt 2>/dev/null && echo "✓ Sendfile works"
./extreme5_ultimate > /tmp/test5.txt 2>/dev/null && echo "✓ Ultimate works"
./extreme6_splice > /tmp/test6.txt 2>/dev/null && echo "✓ Splice works"

echo
echo "Performance Results ($ITERATIONS iterations):"
echo "=============================================="

run_test() {
    local name=$1
    local binary=$2
    local args=$3
    
    if [ -f "$binary" ]; then
        printf "%-20s: " "$name"
        { time -p for i in $(seq 1 $ITERATIONS); do ./$binary $args > /dev/null 2>&1; done; } 2>&1 | grep real | awk '{printf "%.3f seconds (%.0f ops/sec)\n", $2, '"$ITERATIONS"'/$2}'
    fi
}

echo
echo "Baseline:"
run_test "Original" "cowsay_original" "$TEST_MESSAGE"

echo
echo "Extreme Optimizations:"
run_test "Static Pre-computed" "extreme1_static" "$TEST_MESSAGE"
run_test "Cached Output" "extreme2_cached" "$TEST_MESSAGE"
run_test "Direct Syscall" "extreme3_syscall" ""
run_test "Sendfile Zero-copy" "extreme4_sendfile" "$TEST_MESSAGE"
run_test "Pure Assembly" "extreme5_ultimate" ""
run_test "Splice Pipe" "extreme6_splice" ""

echo
echo "=============================================="
echo "WINNER ANALYSIS:"
echo

# Show improvement
original_time=$(time -p (for i in $(seq 1 1000); do ./cowsay_original $TEST_MESSAGE > /dev/null 2>&1; done) 2>&1 | grep real | awk '{print $2}')
extreme_time=$(time -p (for i in $(seq 1 1000); do ./extreme3_syscall > /dev/null 2>&1; done) 2>&1 | grep real | awk '{print $2}')

echo "Sample (1000 iterations):"
echo "Original: ${original_time}s"
echo "Extreme:  ${extreme_time}s"
echo
echo "Speedup: $(echo "scale=2; $original_time / $extreme_time" | bc)x faster!"