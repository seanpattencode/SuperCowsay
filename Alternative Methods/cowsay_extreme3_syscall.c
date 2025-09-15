#include <string.h>

// Direct syscall without libc
static inline long syscall_write(int fd, const void *buf, unsigned long count) {
    long ret;
    __asm__ volatile(
        "syscall"
        : "=a"(ret)
        : "a"(1), "D"(fd), "S"(buf), "d"(count)
        : "rcx", "r11", "memory"
    );
    return ret;
}

// Pre-computed output
static const char OUTPUT[] = 
" ______________________________________________\n"
"< The quick brown fox jumps over the lazy dog >\n"
" ----------------------------------------------\n"
"        \\   ^__^\n"
"         \\  (oo)\\_______\n"
"            (__)\\       )\\/\\\n"
"                ||----w |\n"
"                ||     ||\n";

void _start() {
    syscall_write(1, OUTPUT, sizeof(OUTPUT) - 1);
    
    // Exit directly
    __asm__ volatile(
        "mov $60, %%rax\n"
        "xor %%rdi, %%rdi\n"
        "syscall"
        ::: "rax", "rdi"
    );
}