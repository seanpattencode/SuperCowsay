#!/bin/bash

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
RUNS=50

echo "Perl Cowsay Benchmark ($RUNS runs)"
echo "================================="
echo

measure_perl() {
    echo "Testing Original Perl Cowsay:"

    # Warm up
    COWPATH="./cows" ./cowsay_original_perl.pl "$TEST_MESSAGE" >/dev/null 2>&1

    # Measure
    times=()
    for i in $(seq 1 $RUNS); do
        start=$(date +%s%N)
        COWPATH="./cows" ./cowsay_original_perl.pl "$TEST_MESSAGE" >/dev/null 2>&1
        end=$(date +%s%N)
        elapsed=$((end - start))
        times+=($elapsed)
    done

    # Calculate stats
    total=0
    min=${times[0]}
    max=${times[0]}

    for time in "${times[@]}"; do
        total=$((total + time))
        if [ $time -lt $min ]; then min=$time; fi
        if [ $time -gt $max ]; then max=$time; fi
    done

    avg=$((total / RUNS))

    printf "  Average: %6.3f ms\n" $(echo "scale=3; $avg/1000000" | bc -l)
    printf "  Min:     %6.3f ms\n" $(echo "scale=3; $min/1000000" | bc -l)
    printf "  Max:     %6.3f ms\n" $(echo "scale=3; $max/1000000" | bc -l)
    printf "  Total for 1k: %6.0f ms\n" $(echo "scale=0; $avg*1000/1000000" | bc -l)
    echo
}

measure_perl

echo "High-volume test (1000 runs):"
start=$(date +%s%N)
for i in $(seq 1 1000); do
    COWPATH="./cows" ./cowsay_original_perl.pl "$TEST_MESSAGE" >/dev/null 2>&1
done
end=$(date +%s%N)
elapsed=$((end - start))
ms=$((elapsed / 1000000))
ops=$((1000 * 1000 / ms))
echo "  Time: ${ms}ms"
echo "  Ops/sec: ${ops}"