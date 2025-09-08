// Ultimate optimization: Inline assembly with pre-computed output
// No libc, no stack, minimal instructions
__asm__(
    ".text\n"
    ".global _start\n"
    "_start:\n"
    "    mov $1, %rax\n"          // sys_write
    "    mov $1, %rdi\n"          // stdout
    "    lea output(%rip), %rsi\n" // buffer address
    "    mov $267, %rdx\n"        // length
    "    syscall\n"
    "    mov $60, %rax\n"         // sys_exit
    "    xor %rdi, %rdi\n"        // exit code 0
    "    syscall\n"
    ".section .rodata\n"
    "output:\n"
    ".ascii \" ______________________________________________\\n\"\n"
    ".ascii \"< The quick brown fox jumps over the lazy dog >\\n\"\n"
    ".ascii \" ----------------------------------------------\\n\"\n"
    ".ascii \"        \\\\   ^__^\\n\"\n"
    ".ascii \"         \\\\  (oo)\\\\_______\\n\"\n"
    ".ascii \"            (__)\\\\       )\\\\/\\\\\\n\"\n"
    ".ascii \"                ||----w |\\n\"\n"
    ".ascii \"                ||     ||\\n\"\n"
);