# SuperCowsay Makefile - Reproducible builds for all implementations
# Supports x86_64 Linux systems

.PHONY: all clean test bench install install-user uninstall verify eval help

# Default target
all: cowsay_dynamic cowsay_ultra c_implementations

# Champion: hand-rolled minimal ELF (needs nasm)
cowsay_ultra: cowsay_ultra.asm
	nasm -f bin -o cowsay_ultra cowsay_ultra.asm
	chmod +x cowsay_ultra
	@echo "✓ Built cowsay_ultra"

# Configuration
CC = gcc
AS = as
LD = ld
CFLAGS = -O3 -Wall -Wextra
LDFLAGS = -z noexecstack

# Directories
ALT_DIR = Alternative Methods
BUILD_DIR = build
TEST_DIR = test_results

# Primary assembly target
cowsay_dynamic: cowsay_dynamic.s
	@echo "Building dynamic assembly implementation..."
	$(AS) -o cowsay_dynamic.o cowsay_dynamic.s
	$(LD) -o cowsay_dynamic cowsay_dynamic.o $(LDFLAGS)
	@echo "✓ Built cowsay_dynamic"

# C implementations (use existing pre-built binaries)
c_implementations: build_dir
	@echo "Using existing C implementations..."
	@if [ -x "$(ALT_DIR)/original" ]; then echo "✓ Found cowsay_original ($(ALT_DIR)/original)"; fi
	@if [ -x "$(ALT_DIR)/v1_buffer" ]; then echo "✓ Found cowsay_v1_buffer"; fi
	@if [ -x "$(ALT_DIR)/syscall" ]; then echo "✓ Found cowsay_syscall"; fi
	@echo "✓ C implementations ready"

# Create build directory
build_dir:
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(TEST_DIR)

# Clean build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -f cowsay_dynamic cowsay_dynamic.o cowsay_ultra floor_exit
	rm -f "$(ALT_DIR)"/cowsay_*
	rm -f "$(ALT_DIR)"/*.o
	rm -rf $(BUILD_DIR) $(TEST_DIR)
	rm -f benchmark_results.* hyperfine_output.txt output.tmp
	@echo "✓ Cleaned"

# Run correctness tests
test: all
	@echo "Running correctness tests..."
	./correctness_tests.sh

# Run performance benchmarks
bench: all
	@echo "Running rigorous benchmarks..."
	./rigorous_benchmark.sh

# Quick benchmark (no system optimization)
bench-quick: all
	@echo "Running quick benchmark..."
	@if command -v hyperfine >/dev/null 2>&1; then \
		hyperfine --warmup 3 --min-runs 10 \
			'./cowsay_dynamic "The quick brown fox jumps over the lazy dog"' \
			'"$(ALT_DIR)/original" "The quick brown fox jumps over the lazy dog"' \
			2>/dev/null || echo "Install hyperfine for better benchmarks"; \
	else \
		echo "hyperfine not found, install with: cargo install hyperfine"; \
		echo "Manual timing comparison:"; \
		echo "Assembly:"; time ./cowsay_dynamic "The quick brown fox jumps over the lazy dog" >/dev/null; \
		echo "C implementation:"; time "$(ALT_DIR)/original" "The quick brown fox jumps over the lazy dog" >/dev/null; \
	fi

# Install as 'supercowsay': builds, verifies byte-identity, races candidates,
# installs whichever is fastest on THIS machine. See ./install.sh --help.
install:
	./install.sh

install-user:
	./install.sh --user

# Uninstall from every known location
uninstall:
	./install.sh --uninstall

# Prove the champion is byte-identical to the reference implementation
verify: cowsay_ultra cowsay_dynamic
	./verify_identity.sh ./cowsay_ultra

# Adversarial evaluation: independent oracle, fuzzing, compat audit, speed scaling
eval: cowsay_ultra cowsay_dynamic
	python3 eval.py

# Check system requirements
check-deps:
	@echo "Checking system requirements..."
	@echo -n "GCC: "
	@gcc --version | head -1 || echo "MISSING - install with: sudo apt install gcc"
	@echo -n "GNU Assembler: "
	@as --version | head -1 || echo "MISSING - install with: sudo apt install binutils"
	@echo -n "NASM (for the champion): "
	@nasm --version 2>/dev/null || echo "MISSING - install with: sudo apt install nasm"
	@echo -n "Make: "
	@make --version | head -1 || echo "MISSING - install with: sudo apt install make"
	@echo -n "Hyperfine (optional): "
	@hyperfine --version 2>/dev/null || echo "MISSING - install with: cargo install hyperfine"
	@echo -n "Perf (optional): "
	@perf --version 2>/dev/null || echo "MISSING - install with: sudo apt install linux-tools-generic"

# System info for reproducible builds
sysinfo:
	@echo "=== System Information for Reproducible Builds ==="
	@echo "Architecture: $(shell uname -m)"
	@echo "Kernel: $(shell uname -r)"
	@echo "OS: $(shell lsb_release -d 2>/dev/null | cut -f2 || uname -o)"
	@echo "GCC: $(shell gcc --version | head -1)"
	@echo "GNU AS: $(shell as --version | head -1)"
	@echo "GNU LD: $(shell ld --version | head -1)"
	@echo "CPU: $(shell lscpu | grep 'Model name' | cut -d: -f2 | xargs)"
	@echo "Build timestamp: $(shell date -Iseconds)"

# Continuous integration target
ci: check-deps sysinfo all test bench-quick
	@echo "✓ CI pipeline completed successfully"

# Help information
help:
	@echo "SuperCowsay Build System"
	@echo ""
	@echo "Targets:"
	@echo "  all          - Build all implementations"
	@echo "  cowsay_ultra - Build the champion (hand-rolled ELF, needs nasm)"
	@echo "  cowsay_dynamic - Build assembly implementation only"
	@echo "  c_implementations - Build C implementations only"
	@echo "  clean        - Remove all build artifacts"
	@echo "  test         - Run correctness tests"
	@echo "  verify       - Prove the champion is byte-identical to the reference"
	@echo "  eval         - Adversarial eval: oracle, fuzzing, compat, speed scaling"
	@echo "  bench        - Run full rigorous benchmarks"
	@echo "  bench-quick  - Run quick benchmarks"
	@echo "  install      - Install the fastest verified build as 'supercowsay'"
	@echo "  install-user - Same, into ~/.local/bin (no sudo)"
	@echo "  uninstall    - Remove supercowsay from every known location"
	@echo "  check-deps   - Check system dependencies"
	@echo "  sysinfo      - Display system information"
	@echo "  ci           - Full CI pipeline (deps, build, test, bench)"
	@echo "  help         - Show this help"
	@echo ""
	@echo "Examples:"
	@echo "  make all && ./cowsay_ultra \"Hello World\""
	@echo "  make test"
	@echo "  make bench"
	@echo "  make install && supercowsay \"Now installed system-wide\""