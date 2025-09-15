#!/bin/bash

# Rigorous benchmarking script with hyperfine and perf
# Implements recommendations for bulletproof benchmarks

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== SuperCowsay Rigorous Benchmark Suite ===${NC}"
echo "Implementing performance measurement best practices"
echo ""

# Check dependencies
check_dependencies() {
    local missing=()

    if ! command -v hyperfine >/dev/null 2>&1; then
        missing+=("hyperfine")
    fi

    if ! command -v perf >/dev/null 2>&1; then
        missing+=("perf")
    fi

    if ! command -v taskset >/dev/null 2>&1; then
        missing+=("taskset")
    fi

    if ! command -v chrt >/dev/null 2>&1; then
        missing+=("chrt")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}Missing dependencies: ${missing[*]}${NC}"
        echo "Install with:"
        echo "  sudo apt install linux-tools-common linux-tools-generic util-linux"
        echo "  cargo install hyperfine  # or: sudo apt install hyperfine"
        exit 1
    fi
}

# System optimization for benchmarking
optimize_system() {
    echo -e "${YELLOW}Optimizing system for benchmarking...${NC}"

    # Check if we can optimize without sudo
    local optimizations_applied=0

    # Set CPU governor to performance (try without sudo first)
    if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] 2>/dev/null; then
        echo performance | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 && {
            echo "✓ CPU governor set to performance"
            ((optimizations_applied++))
        }
    elif command -v cpupower >/dev/null 2>&1; then
        echo "⚠ CPU governor optimization requires sudo: sudo cpupower frequency-set -g performance"
    else
        echo "⚠ Cannot set CPU governor (cpupower not available or no permissions)"
    fi

    # Disable turbo boost for consistent results
    if [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] 2>/dev/null; then
        echo 1 | tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1 && {
            echo "✓ Turbo boost disabled"
            ((optimizations_applied++))
        }
    else
        echo "⚠ Cannot disable turbo boost (no permissions or not supported)"
    fi

    # Drop caches
    if [ -w /proc/sys/vm/drop_caches ] 2>/dev/null; then
        echo 3 | tee /proc/sys/vm/drop_caches >/dev/null 2>&1 && {
            echo "✓ Caches dropped"
            ((optimizations_applied++))
        }
    else
        echo "⚠ Cannot drop caches (no permissions). For better results: sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'"
    fi

    if [ $optimizations_applied -eq 0 ]; then
        echo "⚠ No system optimizations applied. Results may vary."
        echo "For more consistent results, consider running with appropriate permissions."
    fi

    echo ""
}

# Restore system settings
restore_system() {
    echo -e "${YELLOW}Restoring system settings...${NC}"

    if [ -w /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ] 2>/dev/null; then
        echo powersave | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>&1 && {
            echo "✓ CPU governor restored to powersave"
        }
    fi

    if [ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] 2>/dev/null; then
        echo 0 | tee /sys/devices/system/cpu/intel_pstate/no_turbo >/dev/null 2>&1 && {
            echo "✓ Turbo boost re-enabled"
        }
    fi

    echo "✓ Cleanup completed (restored available settings)"
}

# Build all implementations
build_implementations() {
    echo -e "${YELLOW}Building all implementations...${NC}"

    # Main dynamic assembly
    if [ -f cowsay_dynamic.s ]; then
        as -o cowsay_dynamic.o cowsay_dynamic.s
        ld -o cowsay_dynamic cowsay_dynamic.o -z noexecstack
        echo "✓ cowsay_dynamic.s -> cowsay_dynamic"
    fi

    # Alternative methods
    cd "Alternative Methods" || exit 1

    # C implementations
    if [ -f cowsay_original.c ]; then
        gcc -O3 -o cowsay_original cowsay_original.c
        echo "✓ cowsay_original.c (dynamic)"
    fi

    # Static C implementation
    if [ -f cowsay_original.c ]; then
        gcc -O3 -static -s -o cowsay_original_static cowsay_original.c
        echo "✓ cowsay_original.c (static)"
    fi

    # Nostartfiles C implementation
    if [ -f cowsay_minimal.c ]; then
        gcc -O3 -nostartfiles -o cowsay_minimal_nostartfiles cowsay_minimal.c
        echo "✓ cowsay_minimal.c (nostartfiles)"
    fi

    # Extreme syscall implementation
    if [ -f cowsay_extreme3_syscall.c ]; then
        gcc -O3 -o cowsay_extreme3_syscall cowsay_extreme3_syscall.c
        echo "✓ cowsay_extreme3_syscall.c"
    fi

    cd ..
}

# Perf stat analysis
run_perf_analysis() {
    local binary="$1"
    local name="$2"
    local message="The quick brown fox jumps over the lazy dog"

    echo -e "${BLUE}=== Performance Analysis: $name ===${NC}"

    # Try CPU pinning and real-time priority if available
    local perf_cmd="perf stat"
    if command -v taskset >/dev/null 2>&1; then
        perf_cmd="taskset -c 3 $perf_cmd"
    fi
    # Skip chrt -f 99 as it requires special permissions
    local events="cycles,instructions,branches,branch-misses,task-clock,context-switches,faults,cache-references,cache-misses"

    echo "Running perf stat with events: $events"

    if [ -x "$binary" ]; then
        $perf_cmd -e $events --repeat 10 "$binary" "$message" >/dev/null
    else
        echo "⚠ Binary $binary not found or not executable"
    fi

    echo ""
}

# Syscall analysis
run_syscall_analysis() {
    local binary="$1"
    local name="$2"
    local message="The quick brown fox jumps over the lazy dog"

    echo -e "${BLUE}=== Syscall Analysis: $name ===${NC}"

    if [ -x "$binary" ]; then
        echo "Syscall counts and timing:"
        strace -f -c "$binary" "$message" 2>&1 | grep -E "(calls|total|sys_)"
    else
        echo "⚠ Binary $binary not found or not executable"
    fi

    echo ""
}

# Hyperfine benchmarking
run_hyperfine_benchmark() {
    local message="The quick brown fox jumps over the lazy dog"

    echo -e "${BLUE}=== Hyperfine Benchmark Results ===${NC}"

    # Prepare commands array
    local commands=()
    local names=()

    # Check which binaries exist
    if [ -x cowsay_dynamic ]; then
        commands+=("./cowsay_dynamic '$message'")
        names+=("Dynamic Assembly")
    fi

    if [ -x "Alternative Methods/cowsay_original" ]; then
        commands+=("'Alternative Methods/cowsay_original' '$message'")
        names+=("C Dynamic")
    fi

    if [ -x "Alternative Methods/cowsay_original_static" ]; then
        commands+=("'Alternative Methods/cowsay_original_static' '$message'")
        names+=("C Static")
    fi

    if [ -x "Alternative Methods/cowsay_minimal_nostartfiles" ]; then
        commands+=("'Alternative Methods/cowsay_minimal_nostartfiles' '$message'")
        names+=("C Nostartfiles")
    fi

    if [ -x "Alternative Methods/cowsay_extreme3_syscall" ]; then
        commands+=("'Alternative Methods/cowsay_extreme3_syscall' '$message'")
        names+=("C Syscall Only")
    fi

    # Run hyperfine with proper settings
    if [ ${#commands[@]} -gt 0 ]; then
        echo "Running hyperfine with warmup and statistical analysis..."

        # CPU pinning if available (skip real-time priority)
        local hyperfine_cmd="hyperfine"
        if command -v taskset >/dev/null 2>&1; then
            hyperfine_cmd="taskset -c 3 $hyperfine_cmd"
        fi

        # Redirect output to avoid terminal rendering overhead
        $hyperfine_cmd \
            --warmup 10 \
            --min-runs 50 \
            --export-json benchmark_results.json \
            --export-markdown benchmark_results.md \
            "${commands[@]}" | tee hyperfine_output.txt

        echo ""
        echo "Results exported to:"
        echo "  - benchmark_results.json (machine-readable)"
        echo "  - benchmark_results.md (human-readable table)"
        echo "  - hyperfine_output.txt (full output)"
    else
        echo "⚠ No executable binaries found"
    fi
}

# I/O redirection benchmark
run_io_benchmark() {
    local message="The quick brown fox jumps over the lazy dog"

    echo -e "${BLUE}=== I/O Redirection Benchmark ===${NC}"
    echo "Testing with output to pipe/file to avoid terminal rendering overhead"

    if [ -x cowsay_dynamic ]; then
        local bench_cmd="hyperfine"
        if command -v taskset >/dev/null 2>&1; then
            bench_cmd="taskset -c 3 $bench_cmd"
        fi

        echo "Timing with output to /dev/null:"
        $bench_cmd --warmup 5 --min-runs 20 \
            "./cowsay_dynamic '$message' >/dev/null" 2>/dev/null || echo "Hyperfine not available"

        echo ""
        echo "Timing with output to file:"
        $bench_cmd --warmup 5 --min-runs 20 \
            "./cowsay_dynamic '$message' >output.tmp" 2>/dev/null || echo "Hyperfine not available"

        rm -f output.tmp
    fi

    echo ""
}

# Binary size analysis
analyze_binary_sizes() {
    echo -e "${BLUE}=== Binary Size Analysis ===${NC}"

    echo "Binary sizes (bytes):"

    if [ -f cowsay_dynamic ]; then
        size=$(wc -c < cowsay_dynamic)
        echo "  Dynamic Assembly:      $size bytes"
    fi

    if [ -f "Alternative Methods/cowsay_original" ]; then
        size=$(wc -c < "Alternative Methods/cowsay_original")
        echo "  C Dynamic:             $size bytes"
    fi

    if [ -f "Alternative Methods/cowsay_original_static" ]; then
        size=$(wc -c < "Alternative Methods/cowsay_original_static")
        echo "  C Static:              $size bytes"
    fi

    if [ -f "Alternative Methods/cowsay_minimal_nostartfiles" ]; then
        size=$(wc -c < "Alternative Methods/cowsay_minimal_nostartfiles")
        echo "  C Nostartfiles:        $size bytes"
    fi

    echo ""
}

# System information
print_system_info() {
    echo -e "${BLUE}=== System Information ===${NC}"
    echo "Hardware and OS details for reproducibility:"
    echo ""

    echo "CPU:"
    lscpu | grep -E "(Model name|CPU MHz|CPU max MHz|Cache|Architecture)" | sed 's/^/  /'
    echo ""

    echo "Memory:"
    free -h | sed 's/^/  /'
    echo ""

    echo "Kernel:"
    uname -a | sed 's/^/  /'
    echo ""

    echo "CPU governor:"
    cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | sed 's/^/  /' || echo "  (not available)"
    echo ""

    echo "ASLR setting:"
    cat /proc/sys/kernel/randomize_va_space | sed 's/^/  Level: /'
    echo ""

    echo "Timestamp: $(date -Iseconds)"
    echo ""
}

# Cleanup function
cleanup() {
    restore_system
    echo ""
    echo -e "${GREEN}Benchmark completed. Check the generated files for detailed results.${NC}"
}

# Set up cleanup trap
trap cleanup EXIT

# Main execution
main() {
    check_dependencies
    print_system_info
    optimize_system
    build_implementations

    echo -e "${GREEN}=== Starting Rigorous Performance Analysis ===${NC}"
    echo ""

    analyze_binary_sizes

    # Run detailed analysis on key implementations
    if [ -x cowsay_dynamic ]; then
        run_perf_analysis "./cowsay_dynamic" "Dynamic Assembly"
        run_syscall_analysis "./cowsay_dynamic" "Dynamic Assembly"
    fi

    if [ -x "Alternative Methods/cowsay_original" ]; then
        run_perf_analysis "Alternative Methods/cowsay_original" "C Dynamic"
        run_syscall_analysis "Alternative Methods/cowsay_original" "C Dynamic"
    fi

    if [ -x "Alternative Methods/cowsay_original_static" ]; then
        run_perf_analysis "Alternative Methods/cowsay_original_static" "C Static"
        run_syscall_analysis "Alternative Methods/cowsay_original_static" "C Static"
    fi

    # Comprehensive timing comparison
    run_hyperfine_benchmark
    run_io_benchmark

    echo ""
    echo -e "${GREEN}=== Benchmark Analysis Complete ===${NC}"
    echo "Review the generated files for detailed performance metrics."
}

# Check if we're being sourced or executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi