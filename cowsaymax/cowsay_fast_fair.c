#include <unistd.h>
#include <string.h>

void _start() {
    // Get args from stack (Linux x86_64 ABI)
    register long rsp asm("rsp");
    long argc = *((long*)rsp);
    char **argv = (char**)(rsp + 8);
    
    // Build message from args
    char msg[1024];
    char *p = msg;
    for (int i = 1; i < argc; i++) {
        if (i > 1) *p++ = ' ';
        char *arg = argv[i];
        while (*arg) *p++ = *arg++;
    }
    int len = p - msg;
    
    // Build output directly
    char buf[2048];
    char *out = buf;
    
    // Top border
    *out++ = ' ';
    for (int i = 0; i < len + 2; i++) *out++ = '_';
    *out++ = '\n';
    
    // Message line
    *out++ = '<';
    *out++ = ' ';
    for (int i = 0; i < len; i++) *out++ = msg[i];
    *out++ = ' ';
    *out++ = '>';
    *out++ = '\n';
    
    // Bottom border
    *out++ = ' ';
    for (int i = 0; i < len + 2; i++) *out++ = '-';
    *out++ = '\n';
    
    // Cow (static part)
    const char cow[] = "        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    for (int i = 0; i < sizeof(cow)-1; i++) *out++ = cow[i];
    
    // Single syscall to write everything
    asm volatile(
        "syscall"
        : : "a"(1), "D"(1), "S"(buf), "d"(out - buf)
        : "rcx", "r11", "memory"
    );
    
    // Exit
    asm volatile(
        "syscall"
        : : "a"(60), "D"(0)
        : "rcx", "r11"
    );
}