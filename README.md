# SuperCowsay: Maximum Performance Cowsay

**Performance-first optimization of the classic `cowsay` program. No compromises on speed.**

```
 __________________________________________________________________
< 1.3 microseconds above the kernel exec floor. There is no lower. >
 ------------------------------------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

## The Champion: `cowsay_ultra`

**`cowsay_ultra` is a 629-byte hand-written ELF executable that runs 1.3µs above the kernel's own process-spawn floor.** Not 1.3µs above another program — 1.3µs above an executable whose entire body is `exit(0)`. Everything cowsay actually does (read argv, build the box, draw the cow, write it) costs 1.3µs; the other 58.5µs is the kernel creating a process, which no userspace program can avoid.

The assembler emits the finished executable directly (`nasm -f bin`) — there is no linker, and no toolchain-generated ELF. The file *is* the ELF: 120 bytes of hand-written headers, then code, then the cow.

### Same-run benchmark (all rows, one machine, one hyperfine session)

| implementation | mean | min | binary | syscalls | max RSS | vs floor |
|---|---|---|---|---|---|---|
| exec floor (`floor_exit`, `exit(0)` only) | 58.5µs | 50.9µs | 129 B | 1 | 392 KB | 1.00x |
| **`cowsay_ultra` (champion)** | **59.8µs** | **51.3µs** | **629 B** | **2** | **392 KB** | **1.02x** |
| `cowsay_dynamic` (previous champion) | 62.9µs | 54.6µs | 9,896 B | 2 | 392 KB | 1.08x |
| `cowsay_original` (C, full cowsay) | 219.0µs | 199.7µs | 16,744 B | 35 | 1,656 KB | 3.74x |
| `cowsay_original_perl.pl` (Perl, full cowsay) | 8,649µs | 8,334µs | 9,704 B | 639 | 8,820 KB | 147.9x |

*Conditions: hyperfine 1.19 `-N`, pinned with `taskset`, 100 warmup runs; 37k–43k timed runs for the microsecond rows, 12,921 for C, 354 for the 8.6ms Perl row. Every number above comes from a single session so the rows are directly comparable; earlier revisions of this README quoted a different session, which is why absolute values differ from git history. Ratios, not absolutes, are the portable part.*

**`cowsay_ultra` vs the field:**
- **145x faster than the original Perl** (8,649µs → 59.8µs)
- **3.7x faster than the C implementation** (219.0µs → 59.8µs)
- **1.05–1.08x faster than `cowsay_dynamic`**, the previous assembly champion — consistent across repeat runs and CPU cores
- **93.6% smaller than the previous champion** (9,896 B → 629 B), **96.2% smaller than C**
- **99.7% fewer syscalls than Perl** (639 → 2), **94.3% fewer than C** (35 → 2)
- **95.6% less memory than Perl** (8,820 KB → 392 KB), **76.3% less than C**
- **Faults exactly as many pages as a program that does nothing** (16 minor faults, same as `floor_exit`)

**Fair-comparison note:** the C and Perl rows are *full* cowsay — they word-wrap at 40 columns and parse cowfiles from disk, so they do strictly more work and produce different output for long messages. They are the honest "what you'd actually run" baseline, not an identical-output twin. For strict byte-identity comparisons across 30+ languages, see the [Polyglot Benchmark](#polyglot-benchmark--full-pypl-index) below, where every implementation is verified byte-identical before timing.

### Why it wins: the ELF itself was the last remaining cost

`cowsay_dynamic` was already at the theoretical minimum of **2 syscalls** (one `write`, one `exit`). No instruction-level tuning could touch it, because at that point the program is not what costs anything — `execve` is. The remaining overhead lives entirely in what the kernel must map and fault in before the first instruction runs:

| | `cowsay_dynamic` | `cowsay_ultra` |
|---|---|---|
| PT_LOAD segments (vmas the kernel maps) | 4 | **1** |
| `.bss` requiring zero-fill page faults | 5 KB | **none** (output built on the stack) |
| Total file size | 9,896 B | **629 B** |
| Minor page faults | 19 | **16** (identical to `exit(0)`) |

So `cowsay_ultra` hand-writes the ELF headers: one R+X `PT_LOAD` covering the whole file, plus a `PT_GNU_STACK` for `noexecstack`. One file-backed page holds headers, code, and cow. There is no `.bss` at all — the output buffer is 4 KB of stack, touched once.

**Result: the hand-rolled ELF reclaimed ~70% of all remaining beatable time** (70% in the session tabled above, 76% in a separate pinned session — the gap itself is small enough that run-to-run noise moves the ratio). `cowsay_dynamic` sat 4.4µs above the exec floor; `cowsay_ultra` sits 1.3µs above it. What is left is one `write` syscall and ~200 instructions. **Below the exec floor, no spawned program can go** — this is the end of the road for per-process cowsay.

### Verify it yourself

`bench_ultra.sh` is the complete proof in one command: it builds everything, proves byte-identity against the previous champion across an edge-case matrix, then benchmarks against the exec floor.

```bash
./bench_ultra.sh
```

The identity matrix covers 15 cases — no arguments (default message), empty arguments, multiple arguments, empty-then-nonempty and nonempty-then-empty, shell special characters, digits, multi-byte UTF-8, a 255-char argument (pass) vs 256 (error), a 1,023-char total (pass) vs 1,024 (error), and both error paths. Each case compares **stdout, stderr, and exit code**:

```
OK  rc=0 argc=0
OK  rc=0 argc=3
OK  rc=1 argc=1
...
=== byte-identical: stdout+stderr+exit codes ===
```

`cowsay_ultra` is a drop-in replacement: identical output, identical `stderr` message, identical exit codes, identical limits (256 chars/arg, 1,024 chars total).

```bash
make cowsay_ultra              # nasm -f bin — assembler emits the executable, no linker
./cowsay_ultra "Hello, performance!"
make install                   # installs cowsay_ultra as 'supercowsay'
```

Requires `nasm`: `sudo apt install nasm`

## The Previous Champion: Dynamic Assembly

**File**: `cowsay_dynamic.s` — still built by `make all`, still the reference implementation whose output `cowsay_ultra` must match byte-for-byte.

This was the fastest implementation in the project until the hand-rolled ELF, and it is where the syscall count reached its floor. It is written in GNU AS with Intel syntax, links with `ld`, and uses no libc.

```asm
.intel_syntax noprefix
.global _start

.equ MAX_MESSAGE_LEN, 1024
.equ MAX_BUFFER_LEN, 4096
.equ MAX_ARG_LEN, 256

_start:
    mov rbx, [rsp]              # argc
    lea rsi, [rsp + 8]          # argv

    # Bounds checks: arg < 256 chars, total < 1024, output < 4096

    mov rax, 1                  # sys_write — the only output syscall
    mov rdi, 1
    syscall

    mov rax, 60                 # sys_exit
    xor rdi, rdi
    syscall
```

**What it eliminated (and `cowsay_ultra` inherits):**

1. **Zero C library overhead** — no libc init, no `atexit` handlers, no global constructors. Direct kernel interface.
2. **Minimal syscalls** — 2 total (write + exit) vs 35 in C and 639 in Perl. Each syscall costs ~1-2µs in kernel transitions.
3. **Single-buffer algorithm** — the entire output is constructed in one buffer and written once. No intermediate strings, no allocations.
4. **Hand-chosen instructions** — no function call overhead, no stack frame management, register-to-register where possible.
5. **Cache-friendly access** — linear memory patterns, stack-based buffer, zero heap.

**What it could not eliminate, and `cowsay_ultra` did:** the linker's ELF. Four `PT_LOAD` segments, a 5 KB `.bss`, and 9.6 KB of section and symbol overhead — all of it paid on every `execve`, before `_start`.

**Note**: The project includes the Official Cowsay implementation (`cowsay_original_perl.pl`) from the actively maintained fork at https://github.com/cowsay-org/cowsay for authentic performance comparison.

## Build and Run

### Quick Start

```bash
# One-command setup (installs dependencies and builds)
chmod +x scripts/setup.sh && ./scripts/setup.sh

# Or manual build (builds cowsay_ultra + cowsay_dynamic + C variants)
make all

# Run the champion
./cowsay_ultra "Hello, performance!"
./cowsay_ultra "Any arbitrary message works"
./cowsay_ultra                              # defaults to "Hello, World!"

# Prove it: byte-identity matrix + benchmark vs the kernel exec floor
./bench_ultra.sh

# Compare implementations
make bench-quick

# Install system-wide (installs cowsay_ultra)
make install
supercowsay "Now available system-wide!"
```

### Reproducible Build Environment

```bash
# Docker (fully reproducible)
docker build -f docker/Dockerfile -t supercowsay .
docker run supercowsay "Docker test"

# Docker Compose (with benchmarks)
docker-compose -f docker/docker-compose.yml up benchmark

# Manual dependencies (Ubuntu/Debian)
sudo apt install gcc binutils nasm make linux-tools-generic
cargo install hyperfine  # For benchmarks
```

### Rigorous Performance Benchmark

```bash
# Champion benchmark: identity proof + exec-floor comparison
./bench_ultra.sh

# Comprehensive benchmark with hyperfine and perf
chmod +x rigorous_benchmark.sh
./rigorous_benchmark.sh

# Legacy benchmark (Alternative Methods)
cd "Alternative Methods"
chmod +x dynamic_benchmark.sh
./dynamic_benchmark.sh
```

The rigorous benchmark implements performance measurement best practices:
- **hyperfine**: Statistical timing with warmup and multiple runs
- **perf stat**: Hardware performance counters (cycles, instructions, cache misses)
- **strace**: Syscall counting and timing
- **System optimization**: CPU governor, cache clearing, CPU pinning
- **Fair comparison**: Static C, nostartfiles C, and assembly baselines

**Example commands used**:
```bash
# Timing with statistical analysis (-N bypasses the shell, required at µs scale)
hyperfine -N --warmup 200 --min-runs 1000 './cowsay_ultra "test"'

# Race the champion against the kernel's process-spawn floor
taskset -c 3 hyperfine -N --warmup 200 './cowsay_ultra "test"' './floor_exit'

# Hardware performance analysis (if perf available)
perf stat -e cycles,instructions,branches,task-clock --repeat 10 ./cowsay_ultra "test"

# Syscall analysis
strace -c ./cowsay_ultra "test"

# ELF segment inspection — the thing that actually costs time
readelf -lW ./cowsay_ultra
```

**Note**: The rigorous benchmark may show perf permission errors — this is normal Linux security and doesn't affect the core timing results. The benchmark scripts automatically detect available tools and adjust accordingly.

**Measuring at microsecond scale**: use `hyperfine -N` (no intermediate shell — a shell spawn is 1000x the thing being measured), pin with `taskset`, and use thousands of runs. At 60µs, the difference between champion and floor is 1.3µs; anything less careful measures the harness, not the program.

## Polyglot Benchmark — Full PYPL Index

`langs/` holds the same cowsay in every implementable language of the PYPL index (Jul 2026 ranks 1-30: Python, Java, C, C++, R, JavaScript, Objective-C, PHP, C#, Rust, Swift, Ada, TypeScript, Matlab via Octave, PowerShell, Ruby, Kotlin, Dart, Lua, Go, Julia, Scala, Delphi/Pascal via FPC, Visual Basic via .NET, Zig, Perl original, Haskell, Groovy, Cobol) plus APL and AWK, plus the PYPL DB-index representatives runnable locally (SQLite, MySQL, PostgreSQL, Redis) — all byte-identical output to `cowsay_dynamic`, verified before timing. One Python script installs toolchains (apt + snap + DB user provisioning with `--yes`) and runs the bench.

Not implementable: VBA (needs an Office host), ABAP (SAP-proprietary), Oracle/SQL Server/Db2 (proprietary servers), MongoDB (not in Ubuntu archives), and PYPL's IDE/Online-IDE indices (editors, not runtimes — nothing to execute cowsay in).

```bash
python3 langs/bench.py setup        # check toolchains, print install commands (--yes to run them)
python3 langs/bench.py              # build + verify byte-identical output + hyperfine bench vs assembly
python3 langs/bench.py android      # push Kotlin DEX + Zig arm64 to an adb device, verify + time on ART vs native
```

### On-Device: Kotlin on Android (Pixel 10 Pro)

Kotlin is the first-class language of the world's most-installed OS, so `bench.py android` measures it on the OS's own hardware: the same `cowsay.kt` compiles to a jar, `d8` converts it to DEX, adb pushes it, and it runs directly on ART via `dalvikvm64 -cp` — no APK. A static Zig arm64-musl cross-build of the same cowsay provides the native floor on the same phone. Both verified byte-identical to `cowsay_dynamic` before timing. Pixel 10 Pro, Android 17, timed on-device with its ns clock (adb round-trip excluded):

| on-device | mean | vs native floor |
|---|---|---|
| Zig arm64 static | 6,309µs | 1.0x |
| exec floor (toybox `true`) | 37,045µs | 5.9x |
| Kotlin on ART (`dalvikvm64`) | 319,576µs | 50.7x |

Kotlin cold-start on Android's own silicon is ~320ms per invocation — ~9x its desktop-JVM number (36ms) and ~2,770x the x86 assembly baseline. Installed apps dodge this via zygote pre-forking and AOT compilation — infrastructure that exists precisely because this cost is unbearable at OS scale. Two side findings from the experiment: Android's dynamically-linked `true` takes 37ms to exec, so a static binary beats the OS's smallest utility by 5.9x; and Android's `mksh` does 32-bit shell arithmetic, so nanosecond timestamps wrap — the bench does its timing math host-side.

**It's the VM, not the language:** the same `cowsay.kt` compiled with Kotlin/Native (`kotlinc-native -opt`, a 485KB binary) runs in 1.1ms on desktop — 7x the assembly instead of Kotlin/JVM's 286x, a 40x improvement from deleting the VM. The desktop bench carries it as its own row, and `bench.py android` also cross-compiles it for `android_arm64` (bionic-linked `.kexe`) and times it on-device next to ART.

### On-Device: Windows (HP Omen — different machine, numbers not comparable to the tables above)

`bench.py windows [user@host] [port]` drives a Windows box over ssh into WSL2 with interop: it ships the same sources, compiles them with the compilers every Windows install already contains (`csc.exe` and `vbc.exe` ship in `C:\Windows` with .NET Framework — every Windows machine is secretly a C#/VB compiler), verifies byte-identity, and times natively via `cmd` loops with the WSL-interop + cmd startup measured and subtracted. A Zig `x86_64-windows` cross-build of the same cowsay (kernel32 `WriteFile`, no CRLF translation) is the same-machine floor:

| on the Omen (Windows 11) | mean | vs floor |
|---|---|---|
| Zig win-x64 static (floor) | 23,030µs | 1.0x |
| C# .NET Framework (in-box csc) | 45,471µs | 2.0x |
| VB.NET Framework (in-box vbc) | 48,418µs | 2.1x |
| PowerShell 5.1 | 204,150µs | 8.9x |

The headline is the floor itself: spawning even a 194KB static native exe costs ~23ms on Windows (CreateProcess + Defender scanning) — ~55x the Linux exec floor and ~3.5x the Pixel's — so on Windows the process-creation tax, not the language runtime, dominates any small CLI. VBA remains unmeasured: Office is installed on the Omen, but VBA has no headless runner — driving it means Office COM automation, which is unsupported and hang-prone from a non-interactive ssh session.

## Alternative Implementation Methods

All alternative optimization approaches are available in the `Alternative Methods/` directory, including `floor_exit.asm` — the exit-only ELF that establishes the kernel's process-spawn floor and defines the limit every other row is measured against.

**10 Major Optimization Approaches Tested:**

1. **Single Buffer** (`cowsay_v1_buffer.c`) - 6270ms
2. **SIMD/AVX2** (`cowsay_v2_simd.c`) - Slower due to setup overhead
3. **CUDA GPU** (`cowsay_v3_cuda.cu`) - GPU overhead exceeds benefit
4. **Inline Assembly** (`cowsay_v4_asm.c`) - Mixed C/assembly approach
5. **Lookup Tables** (`cowsay_v5_lut.c`) - Pre-computed character patterns
6. **Loop Unrolling** (`cowsay_v6_unrolled.c`) - Manual loop optimization
7. **Memory Mapping** (`cowsay_v7_mmap.c`) - mmap-based allocation
8. **Vectorization** (`cowsay_v8_vector.c`) - GCC auto-vectorization
9. **Threading** (`cowsay_v9_threaded.c`) - Parallel processing (overkill)
10. **Zero-copy I/O** (`cowsay_v10_zerocopy.c`) - writev scatter-gather - 6100ms

**Extreme Techniques:**
- **Direct Syscalls** (`cowsay_extreme3_syscall.c`) - Bypass libc completely
- **Sendfile** (`cowsay_extreme4_sendfile.c`) - Zero-copy file operations
- **Pure Assembly** (`cowsay_hyperspeed.s`) - Hand-coded for single message
- **Splice** (`cowsay_extreme6_splice.c`) - Kernel pipe operations
- **Exec floor** (`floor_exit.asm`) - 129-byte `exit(0)` ELF; the instrument, not a contender

To explore these alternatives:
```bash
cd "Alternative Methods"
# Build and test any of the implementation variants
gcc -O3 -o cowsay_v1_buffer cowsay_v1_buffer.c
./cowsay_v1_buffer "Test message"
```

## Performance Engineering Insights

**What Works:**
- **Syscall minimization** has the highest impact — until you hit 2, and then it has none
- **C library elimination** saves significant startup time
- **Single-pass algorithms** avoid memory copying overhead
- **Assembly programming** eliminates all function call overhead
- **Shrinking the ELF** — once the code is free, the loader is the program. Fewer `PT_LOAD` segments and no `.bss` beat any further instruction tuning.

**What Doesn't Work:**
- **SIMD/vectorization** - Setup cost exceeds benefit for small data
- **GPU acceleration** - Device transfer overhead is prohibitive
- **Threading** - Synchronization overhead exceeds parallelization benefit
- **Complex algorithms** - Simple approaches are often fastest
- **Optimizing the code once it's below the noise** - at 2 syscalls, `cowsay_dynamic`'s remaining 4.4µs was 100% loader overhead. Instruction tuning would have returned zero.

**Measure against a floor, not against your last version.** A benchmark that only compares implementations tells you which is faster; a benchmark that includes an `exit(0)` binary tells you **how much time is even available to win**. That single 129-byte instrument turned "we got 1.08x faster" into "we captured ~70% of all remaining beatable time, and 1.3µs is what's left."

**Key Lesson**: **The fastest code does the least work at the lowest level possible** — and eventually the lowest level is not your code at all, but the kernel loading it.

## Technical Environment & Limitations

### Environment
- **Platform**: Linux x86_64 only
- **Champion assembler**: NASM (`nasm -f bin` — outputs the executable directly, no linker)
- **Previous champion assembler**: GNU AS (gas) with Intel syntax + `ld`
- **Compiler**: GCC with -O3 optimization
- **Test Data**: "The quick brown fox jumps over the lazy dog" (43 characters)
- **Benchmark tool**: hyperfine 1.19 with `-N`, `taskset` pinning, 12k–43k runs per measurement

## Project Scope & Limitations

### What This Implementation Supports
- **Command-line arguments**: Full support for arbitrary messages via command-line arguments
- **Safety**: Comprehensive bounds checking prevents buffer overflows
- **Performance**: 145x faster than Perl, 3.7x faster than C, 1.3µs above the kernel exec floor
- **Reliability**: Proper error handling with meaningful exit codes

### Current Limitations
This version focuses on the common use-case of processing a single-line message from command-line arguments. It does **not** support:

- **Stdin input**: No `--stdin` or pipe input support
- **Text wrapping**: No word-wrapping for long messages
- **Width control**: No `-w` width parameter support
- **Alternate cow files**: Only supports the classic cow design
- **Multi-line messages**: Designed for single-line output
- **Cross-platform**: x86-64 Linux only (both assembly implementations)

### Technical Limits
Identical in `cowsay_ultra` and `cowsay_dynamic` — the byte-identity matrix in `bench_ultra.sh` tests both sides of every boundary:

- **Maximum message length**: 1024 characters total (1023 passes, 1024 errors)
- **Maximum argument length**: 256 characters per argument (255 passes, 256 errors)
- **Output buffer**: 4096 bytes of stack (max possible output is 3,203 bytes)
- **Error handling**: `Error: Input too long (max 1024 characters)` to stderr, exit code 1

### Design Philosophy
This implementation prioritizes **performance over feature completeness**. The scope is intentionally limited to the most common cowsay usage pattern to achieve maximum optimization.

## Project Philosophy

**Performance is the only metric that matters.** This project explores every possible optimization technique, from high-level algorithmic improvements to bare-metal assembly programming and hand-written ELF headers. Security, portability, and maintainability are secondary concerns — this is pure performance engineering.

The goal is to demonstrate how far you can push a simple program when performance is the absolute priority. The answer, on Linux x86-64, turns out to be **1.3 microseconds from the floor**.

## License and Attribution

**SuperCowsay Implementation**: MIT License (see LICENSE file)

**Cowsay ASCII Art Attribution**: The cow ASCII art is derived from the original cowsay program:
- **Original Author**: Tony Monroe (tony@nog.net)
- **Current Maintainer**: Andrew Janke and cowsay-org contributors
- **Original License**: GNU General Public License version 3
- **Source**: https://github.com/cowsay-org/cowsay

The cow art pattern used in this project:
```
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```

This implementation respects the original cowsay project's GPL-3.0 license and provides full attribution to Tony Monroe and all cowsay contributors. The performance optimizations and implementation code are original work licensed under MIT.

---

And now, a special message from our cow:

```
 ______________________________________________________________________
< I'm udderly optimized - 145x faster than Perl, 1.3us from the floor! >
 ----------------------------------------------------------------------
        \   ^__^
         \  (oo)\_______
            (__)\       )\/\
                ||----w |
                ||     ||
```
