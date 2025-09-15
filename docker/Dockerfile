# Reproducible build environment for SuperCowsay
FROM ubuntu:22.04

LABEL maintainer="SuperCowsay Project"
LABEL description="Reproducible build environment for performance-optimized cowsay"

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install build dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    binutils \
    make \
    linux-tools-common \
    linux-tools-generic \
    util-linux \
    curl \
    python3 \
    && rm -rf /var/lib/apt/lists/*

# Install Rust and hyperfine for benchmarking
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"
RUN cargo install hyperfine

# Set working directory
WORKDIR /supercowsay

# Copy source code
COPY . .

# Build all implementations
RUN make all

# Run tests to verify build
RUN make test

# Create non-root user for security
RUN useradd -m -s /bin/bash cowuser
USER cowuser

# Set entrypoint
ENTRYPOINT ["./cowsay_dynamic"]
CMD ["Hello from SuperCowsay Docker!"]