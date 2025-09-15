#!/bin/bash

TEST_MESSAGE="The quick brown fox jumps over the lazy dog"
RUNS=50

echo "Single-call performance measurement ($RUNS runs each)"
echo "=================================================="
echo

measure_single() {
    local name=$1
    local binary=$2
    local times=()

    echo "Testing $name:"

    # Warm up
    ./$binary "$TEST_MESSAGE" >/dev/null 2>&1

    # Measure
    for i in $(seq 1 $RUNS); do
        start=$(date +%s%N)
        ./$binary "$TEST_MESSAGE" >/dev/null 2>&1
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
    printf "  Total for 10k: %6.0f ms\n" $(echo "scale=0; $avg*10000/1000000" | bc -l)
    echo
}

measure_single "Original" "cowsay_original"
measure_single "Dynamic Assembly" "cowsay_dynamic"
measure_single "Minimal C" "minimal"
measure_single "Zero-copy I/O" "cowsay_v10_zerocopy"