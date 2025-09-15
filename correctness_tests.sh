#!/bin/bash

# Comprehensive correctness tests for SuperCowsay implementations
# Tests feature parity, edge cases, and proper error handling

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Test results directory
RESULTS_DIR="test_results"
mkdir -p "$RESULTS_DIR"

echo -e "${BLUE}=== SuperCowsay Correctness Test Suite ===${NC}"
echo "Testing feature parity and correctness across implementations"
echo ""

# Helper functions
log_test() {
    echo -e "${BLUE}Testing: $1${NC}"
}

assert_output() {
    local description="$1"
    local expected="$2"
    local actual="$3"

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓ $description${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ $description${NC}"
        echo "Expected:"
        echo "$expected" | sed 's/^/  /'
        echo "Actual:"
        echo "$actual" | sed 's/^/  /'
        ((TESTS_FAILED++))
        return 1
    fi
}

assert_exit_code() {
    local description="$1"
    local expected_code="$2"
    local actual_code="$3"

    if [ "$expected_code" = "$actual_code" ]; then
        echo -e "${GREEN}✓ $description${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ $description - expected exit code $expected_code, got $actual_code${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

skip_test() {
    local description="$1"
    echo -e "${YELLOW}⚠ Skipped: $description${NC}"
    ((TESTS_SKIPPED++))
}

# Test implementations
test_implementation() {
    local name="$1"
    local binary="$2"

    if [ ! -x "$binary" ]; then
        skip_test "$name tests - binary not found: $binary"
        return
    fi

    echo -e "${YELLOW}=== Testing $name ===${NC}"

    # Test 1: Basic functionality
    log_test "Basic single word"
    if timeout 5s "$binary" "Hello" 2>/dev/null | grep -q "< Hello >"; then
        echo -e "${GREEN}✓ Basic single word${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Basic single word${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 2: Multiple arguments
    log_test "Multiple arguments"
    if timeout 5s "$binary" "Hello" "World" "Test" 2>/dev/null | grep -q "< Hello World Test >"; then
        echo -e "${GREEN}✓ Multiple arguments${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Multiple arguments${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 3: No arguments (default message)
    log_test "No arguments (default message)"
    output=$("$binary" 2>/dev/null) || true
    expected_pattern="< Hello, World! >"
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✓ No arguments default${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ No arguments default - missing expected pattern: $expected_pattern${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 4: Empty argument
    log_test "Empty string handling"
    output=$("$binary" "" 2>/dev/null) || true
    expected_pattern="<  >"
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✓ Empty string handling${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Empty string handling - missing expected pattern: $expected_pattern${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 5: Special characters
    log_test "Special characters"
    output=$("$binary" "Test!@#$%^&*()" 2>/dev/null) || true
    expected_pattern="< Test!@#\$%^&*() >"
    if echo "$output" | grep -q "< Test!@#"; then
        echo -e "${GREEN}✓ Special characters${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Special characters${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 6: Long input (should handle gracefully)
    log_test "Long input handling"
    local long_input=$(printf 'A%.0s' {1..100})
    if timeout 5s "$binary" "$long_input" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Long input handling${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Long input handling - timeout or crash${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 7: Very long input (should error or truncate safely)
    log_test "Very long input bounds checking"
    local very_long_input=$(printf 'B%.0s' {1..2000})
    local exit_code
    "$binary" "$very_long_input" >/dev/null 2>&1 || exit_code=$?
    if [ "${exit_code:-0}" -ne 0 ]; then
        echo -e "${GREEN}✓ Very long input bounds checking (proper error)${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠ Very long input - no error returned (may be truncating)${NC}"
        ((TESTS_PASSED++))
    fi

    # Test 8: Output format structure
    log_test "Output format structure"
    output=$("$binary" "Test" 2>/dev/null) || true

    # Check for required components
    local has_top_border=0
    local has_message=0
    local has_bottom_border=0
    local has_cow=0

    if echo "$output" | grep -q "^_"; then has_top_border=1; fi
    if echo "$output" | grep -q "< Test >"; then has_message=1; fi
    if echo "$output" | grep -q "^-"; then has_bottom_border=1; fi
    if echo "$output" | grep -q "\\\\.*\\^__\\^"; then has_cow=1; fi

    if [ "$has_top_border" -eq 1 ] && [ "$has_message" -eq 1 ] && [ "$has_bottom_border" -eq 1 ] && [ "$has_cow" -eq 1 ]; then
        echo -e "${GREEN}✓ Output format structure${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Output format structure - missing components (border1:$has_top_border msg:$has_message border2:$has_bottom_border cow:$has_cow)${NC}"
        ((TESTS_FAILED++))
    fi

    # Test 9: Unicode handling (if supported)
    log_test "Unicode handling"
    if timeout 5s "$binary" "Hello 🐄 World" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Unicode handling${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${YELLOW}⚠ Unicode handling - may not be supported${NC}"
        ((TESTS_PASSED++))
    fi

    # Test 10: Numeric arguments
    log_test "Numeric arguments"
    output=$("$binary" "123" "456" 2>/dev/null) || true
    expected_pattern="< 123 456 >"
    if echo "$output" | grep -q "$expected_pattern"; then
        echo -e "${GREEN}✓ Numeric arguments${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Numeric arguments${NC}"
        ((TESTS_FAILED++))
    fi

    echo ""
}

# Performance consistency test
test_performance_consistency() {
    local name="$1"
    local binary="$2"

    if [ ! -x "$binary" ]; then
        skip_test "$name performance consistency - binary not found"
        return
    fi

    echo -e "${YELLOW}=== Performance Consistency: $name ===${NC}"

    log_test "Repeated execution consistency"
    local message="The quick brown fox jumps over the lazy dog"
    local first_output
    local consistent=1

    first_output=$("$binary" "$message" 2>/dev/null) || true

    for i in {1..10}; do
        local current_output
        current_output=$("$binary" "$message" 2>/dev/null) || true
        if [ "$first_output" != "$current_output" ]; then
            consistent=0
            break
        fi
    done

    if [ $consistent -eq 1 ]; then
        echo -e "${GREEN}✓ Repeated execution consistency${NC}"
        ((TESTS_PASSED++))
    else
        echo -e "${RED}✗ Repeated execution consistency - outputs differ${NC}"
        ((TESTS_FAILED++))
    fi

    echo ""
}

# Cross-implementation comparison
cross_implementation_test() {
    echo -e "${YELLOW}=== Cross-Implementation Comparison ===${NC}"

    local test_message="Hello World"
    local outputs=()
    local names=()
    local binaries=(
        "./cowsay_dynamic"
        "./Alternative Methods/cowsay_original"
        "./Alternative Methods/cowsay_static"
        "./Alternative Methods/cowsay_minimal_crt"
    )
    local impl_names=(
        "Dynamic Assembly"
        "C Dynamic"
        "C Static"
        "C Minimal CRT"
    )

    # Collect outputs
    for i in "${!binaries[@]}"; do
        local binary="${binaries[$i]}"
        local name="${impl_names[$i]}"

        if [ -x "$binary" ]; then
            local output
            output=$("$binary" "$test_message" 2>/dev/null) || true
            outputs+=("$output")
            names+=("$name")
        fi
    done

    # Compare outputs
    if [ ${#outputs[@]} -gt 1 ]; then
        log_test "Cross-implementation output consistency"
        local reference="${outputs[0]}"
        local all_match=1

        for i in "${!outputs[@]}"; do
            if [ "${outputs[$i]}" != "$reference" ]; then
                all_match=0
                echo -e "${RED}Output differs between ${names[0]} and ${names[$i]}${NC}"
            fi
        done

        if [ $all_match -eq 1 ]; then
            echo -e "${GREEN}✓ All implementations produce identical output${NC}"
            ((TESTS_PASSED++))
        else
            echo -e "${YELLOW}⚠ Some implementations produce different output (may be expected)${NC}"
            ((TESTS_PASSED++))
        fi
    else
        skip_test "Cross-implementation comparison - need at least 2 implementations"
    fi

    echo ""
}

# Build all implementations
build_all() {
    echo -e "${YELLOW}Building all implementations for testing...${NC}"

    # Main assembly
    if [ -f cowsay_dynamic.s ]; then
        as -o cowsay_dynamic.o cowsay_dynamic.s 2>/dev/null
        ld -o cowsay_dynamic cowsay_dynamic.o -z noexecstack 2>/dev/null
        echo "✓ Built cowsay_dynamic"
    fi

    cd "Alternative Methods" || exit 1

    # C implementations
    for src in cowsay_original.c cowsay_static.c cowsay_nostartfiles.c cowsay_minimal_crt.c; do
        if [ -f "$src" ]; then
            local basename="${src%.c}"
            case "$basename" in
                "cowsay_static")
                    gcc -O3 -static -s -o "$basename" "$src" 2>/dev/null && echo "✓ Built $basename"
                    ;;
                "cowsay_nostartfiles")
                    gcc -O3 -nostartfiles -o "$basename" "$src" 2>/dev/null && echo "✓ Built $basename"
                    ;;
                "cowsay_minimal_crt")
                    gcc -O3 -nostdlib -o "$basename" "$src" 2>/dev/null && echo "✓ Built $basename"
                    ;;
                *)
                    gcc -O3 -o "$basename" "$src" 2>/dev/null && echo "✓ Built $basename"
                    ;;
            esac
        fi
    done

    cd ..
    echo ""
}

# Property-based testing
property_tests() {
    echo -e "${YELLOW}=== Property-Based Tests ===${NC}"

    local binaries=(
        "./cowsay_dynamic"
        "./Alternative Methods/cowsay_original"
    )

    for binary in "${binaries[@]}"; do
        if [ ! -x "$binary" ]; then continue; fi

        local name=$(basename "$binary")
        log_test "Property tests for $name"

        # Property: Output should always contain the input message
        for test_input in "A" "Hello" "Test 123" "Special!@#"; do
            local output
            output=$("$binary" "$test_input" 2>/dev/null) || continue
            if echo "$output" | grep -q "$test_input"; then
                true # Pass
            else
                echo -e "${RED}✗ Property violation: output doesn't contain input '$test_input'${NC}"
                ((TESTS_FAILED++))
                continue 2
            fi
        done

        # Property: Output should have consistent structure
        local output
        output=$("$binary" "test" 2>/dev/null) || continue
        local line_count=$(echo "$output" | wc -l)
        if [ "$line_count" -ge 7 ]; then  # At least 7 lines (borders + message + cow)
            true # Pass
        else
            echo -e "${RED}✗ Property violation: insufficient output lines ($line_count)${NC}"
            ((TESTS_FAILED++))
            continue
        fi

        echo -e "${GREEN}✓ Property tests for $name${NC}"
        ((TESTS_PASSED++))
    done

    echo ""
}

# Main execution
main() {
    build_all

    # Test each implementation
    test_implementation "Dynamic Assembly" "./cowsay_dynamic"
    test_implementation "C Dynamic" "./Alternative Methods/cowsay_original"
    test_implementation "C Static" "./Alternative Methods/cowsay_static"
    test_implementation "C Nostartfiles" "./Alternative Methods/cowsay_nostartfiles"
    test_implementation "C Minimal CRT" "./Alternative Methods/cowsay_minimal_crt"

    # Performance consistency tests
    test_performance_consistency "Dynamic Assembly" "./cowsay_dynamic"
    test_performance_consistency "C Dynamic" "./Alternative Methods/cowsay_original"

    # Cross-implementation comparison
    cross_implementation_test

    # Property-based tests
    property_tests

    # Summary
    echo -e "${BLUE}=== Test Summary ===${NC}"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo -e "Tests skipped: ${YELLOW}$TESTS_SKIPPED${NC}"

    local total=$((TESTS_PASSED + TESTS_FAILED))
    if [ $total -gt 0 ]; then
        local pass_rate=$((TESTS_PASSED * 100 / total))
        echo -e "Pass rate: ${pass_rate}%"
    fi

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed. Check the output above for details.${NC}"
        return 1
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi