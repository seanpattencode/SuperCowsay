#!/bin/bash

# SuperCowsay Development Environment Setup
# Installs all dependencies and prepares the system for building and benchmarking

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== SuperCowsay Development Environment Setup ===${NC}"
echo ""

# Check if running on supported system
check_system() {
    echo -e "${YELLOW}Checking system compatibility...${NC}"

    if [ "$(uname)" != "Linux" ]; then
        echo -e "${RED}Error: This setup script is for Linux systems only${NC}"
        exit 1
    fi

    if [ "$(uname -m)" != "x86_64" ]; then
        echo -e "${YELLOW}Warning: Not x86_64 architecture. Assembly implementation may not work.${NC}"
        echo "Only C implementations will be available."
    fi

    echo -e "${GREEN}✓ System compatibility check passed${NC}"
    echo ""
}

# Install system packages
install_packages() {
    echo -e "${YELLOW}Installing system packages...${NC}"

    # Detect package manager
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y \
            gcc \
            binutils \
            make \
            linux-tools-common \
            linux-tools-generic \
            util-linux \
            curl \
            python3 \
            git
        echo -e "${GREEN}✓ Installed packages via apt${NC}"
    elif command -v yum >/dev/null 2>&1; then
        sudo yum install -y \
            gcc \
            binutils \
            make \
            perf \
            util-linux \
            curl \
            python3 \
            git
        echo -e "${GREEN}✓ Installed packages via yum${NC}"
    elif command -v dnf >/dev/null 2>&1; then
        sudo dnf install -y \
            gcc \
            binutils \
            make \
            perf \
            util-linux \
            curl \
            python3 \
            git
        echo -e "${GREEN}✓ Installed packages via dnf${NC}"
    else
        echo -e "${RED}Error: No supported package manager found (apt, yum, dnf)${NC}"
        echo "Please install the following packages manually:"
        echo "  gcc, binutils, make, perf, util-linux, curl, python3, git"
        exit 1
    fi

    echo ""
}

# Install Rust and hyperfine
install_rust_tools() {
    echo -e "${YELLOW}Installing Rust and hyperfine...${NC}"

    if ! command -v cargo >/dev/null 2>&1; then
        echo "Installing Rust..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source ~/.cargo/env
        echo -e "${GREEN}✓ Installed Rust${NC}"
    else
        echo -e "${GREEN}✓ Rust already installed${NC}"
    fi

    if ! command -v hyperfine >/dev/null 2>&1; then
        echo "Installing hyperfine..."
        source ~/.cargo/env
        cargo install hyperfine
        echo -e "${GREEN}✓ Installed hyperfine${NC}"
    else
        echo -e "${GREEN}✓ hyperfine already installed${NC}"
    fi

    echo ""
}

# Set up development environment
setup_dev_env() {
    echo -e "${YELLOW}Setting up development environment...${NC}"

    # Make scripts executable
    chmod +x rigorous_benchmark.sh
    chmod +x correctness_tests.sh

    # Create directories
    mkdir -p test_results
    mkdir -p build

    echo -e "${GREEN}✓ Development environment setup complete${NC}"
    echo ""
}

# Verify installation
verify_installation() {
    echo -e "${YELLOW}Verifying installation...${NC}"

    local errors=0

    # Check required tools
    for tool in gcc as ld make; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $tool${NC}"
        else
            echo -e "${RED}✗ $tool not found${NC}"
            ((errors++))
        fi
    done

    # Check optional tools
    for tool in hyperfine perf; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo -e "${GREEN}✓ $tool (optional)${NC}"
        else
            echo -e "${YELLOW}⚠ $tool not found (optional)${NC}"
        fi
    done

    if [ $errors -eq 0 ]; then
        echo -e "${GREEN}✓ All required tools installed${NC}"
    else
        echo -e "${RED}✗ Missing $errors required tools${NC}"
        return 1
    fi

    echo ""
}

# Build and test
build_and_test() {
    echo -e "${YELLOW}Building and testing SuperCowsay...${NC}"

    # Build
    echo "Building all implementations..."
    make all

    # Quick test
    echo "Testing basic functionality..."
    ./cowsay_dynamic "Setup test successful!"

    echo -e "${GREEN}✓ Build and test successful${NC}"
    echo ""
}

# Show usage information
show_usage() {
    echo -e "${BLUE}=== SuperCowsay is ready! ===${NC}"
    echo ""
    echo "Next steps:"
    echo "  make help          - Show all available make targets"
    echo "  make test          - Run comprehensive correctness tests"
    echo "  make bench         - Run rigorous performance benchmarks"
    echo "  make bench-quick   - Run quick benchmarks"
    echo ""
    echo "Example usage:"
    echo "  ./cowsay_dynamic \"Hello World!\""
    echo "  make install       - Install system-wide as 'supercowsay'"
    echo ""
    echo "For CI/development:"
    echo "  docker build -f docker/Dockerfile -t supercowsay ."
    echo "  docker run supercowsay \"Docker test\""
    echo ""
}

# Main execution
main() {
    check_system
    install_packages
    install_rust_tools
    setup_dev_env
    verify_installation
    build_and_test
    show_usage

    echo -e "${GREEN}Setup complete! SuperCowsay development environment is ready.${NC}"
}

# Show help
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    echo "SuperCowsay Development Environment Setup"
    echo ""
    echo "This script installs all dependencies and sets up the development"
    echo "environment for building and benchmarking SuperCowsay."
    echo ""
    echo "Supported systems: Linux x86_64"
    echo "Required: sudo privileges for package installation"
    echo ""
    echo "Usage: $0"
    exit 0
fi

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi