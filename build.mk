# Build rules for C implementations in Alternative Methods directory
# Called from main Makefile

CC = gcc
CFLAGS = -O3 -Wall -Wextra

.PHONY: all clean

all: build_existing

# Build only the C files that exist
build_existing:
	@if [ -f cowsay_original.c ]; then \
		echo "Building cowsay_original..."; \
		$(CC) $(CFLAGS) -o cowsay_original cowsay_original.c; \
	fi
	@if [ -f cowsay_static.c ]; then \
		echo "Building cowsay_static..."; \
		$(CC) $(CFLAGS) -static -s -o cowsay_static cowsay_static.c; \
	fi
	@if [ -f cowsay_nostartfiles.c ]; then \
		echo "Building cowsay_nostartfiles..."; \
		$(CC) $(CFLAGS) -nostartfiles -o cowsay_nostartfiles cowsay_nostartfiles.c; \
	fi
	@if [ -f cowsay_minimal_crt.c ]; then \
		echo "Building cowsay_minimal_crt..."; \
		$(CC) $(CFLAGS) -nostdlib -fno-builtin -o cowsay_minimal_crt cowsay_minimal_crt.c 2>/dev/null || echo "Skipping cowsay_minimal_crt (requires advanced setup)"; \
	fi

clean:
	rm -f cowsay_original cowsay_static cowsay_nostartfiles cowsay_minimal_crt *.o