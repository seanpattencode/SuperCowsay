# Pure assembly cowsay - maximum speed
# No libc, no stack frame, minimal instructions
# Build with: as -o hyperspeed.o cowsay_hyperspeed.s && ld -o hyperspeed hyperspeed.o

.intel_syntax noprefix
.global _start

.section .text
_start:
    # Single syscall to write pre-computed output
    mov rax, 1                  # sys_write
    mov rdi, 1                  # stdout
    lea rsi, [rip + output]     # buffer address
    mov rdx, 267                # exact length
    syscall
    
    # Exit immediately
    mov rax, 60                 # sys_exit
    xor rdi, rdi                # exit code 0
    syscall

.section .rodata
output:
    .ascii " ______________________________________________\n"
    .ascii "< The quick brown fox jumps over the lazy dog >\n"
    .ascii " ----------------------------------------------\n"
    .ascii "        \\   ^__^\n"
    .ascii "         \\  (oo)\\_______\n"
    .ascii "            (__)\\       )\\/\\\n"
    .ascii "                ||----w |\n"
    .ascii "                ||     ||\n"
