#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define DEFAULT_WIDTH 40

static inline void fast_memset_asm(char *dest, char val, size_t n) {
    __asm__ volatile(
        "cld\n"
        "rep stosb"
        : "+D"(dest), "+c"(n)
        : "a"(val)
        : "memory"
    );
}

static inline void fast_memcpy_asm(char *dest, const char *src, size_t n) {
    __asm__ volatile(
        "cld\n"
        "rep movsb"
        : "+D"(dest), "+S"(src), "+c"(n)
        :
        : "memory"
    );
}

static inline size_t fast_strlen_asm(const char *str) {
    size_t len;
    __asm__ volatile(
        "xor %%rcx, %%rcx\n"
        "not %%rcx\n"
        "xor %%al, %%al\n"
        "cld\n"
        "repne scasb\n"
        "not %%rcx\n"
        "dec %%rcx"
        : "=c"(len), "+D"(str)
        :
        : "al", "memory"
    );
    return len;
}

void cowsay_asm(const char *msg, int width) {
    static char buffer[8192];
    char *ptr = buffer;
    int len = fast_strlen_asm(msg);
    int w = len <= width ? len : width;
    
    *ptr++ = ' ';
    fast_memset_asm(ptr, '_', w + 2);
    ptr += w + 2;
    *ptr++ = '\n';
    
    if (len <= width) {
        *ptr++ = '<';
        *ptr++ = ' ';
        fast_memcpy_asm(ptr, msg, len);
        ptr += len;
        *ptr++ = ' ';
        *ptr++ = '>';
        *ptr++ = '\n';
    } else {
        for (int i = 0; i < len; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            char c1 = i == 0 ? '/' : (i + width >= len ? '\\' : '|');
            char c2 = i == 0 ? '\\' : (i + width >= len ? '/' : '|');
            *ptr++ = c1;
            *ptr++ = ' ';
            fast_memcpy_asm(ptr, msg + i, chunk);
            ptr += chunk;
            fast_memset_asm(ptr, ' ', width - chunk);
            ptr += width - chunk;
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    fast_memset_asm(ptr, '-', w + 2);
    ptr += w + 2;
    
    const char *cow = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    size_t cow_len = strlen(cow);
    fast_memcpy_asm(ptr, cow, cow_len);
    ptr += cow_len;
    
    __asm__ volatile(
        "mov $1, %%rax\n"
        "mov $1, %%rdi\n"
        "mov %0, %%rsi\n"
        "mov %1, %%rdx\n"
        "syscall"
        :
        : "r"(buffer), "r"((size_t)(ptr - buffer))
        : "rax", "rdi", "rsi", "rdx"
    );
}

int main(int argc, char *argv[]) {
    char msg[1024] = "Hello, World!";
    int width = DEFAULT_WIDTH;
    size_t remaining = sizeof(msg) - 1;
    
    int has_message = 0;
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-w") == 0 && i + 1 < argc) {
            width = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--stdin") == 0) {
            fgets(msg, sizeof(msg), stdin);
            msg[strcspn(msg, "\n")] = 0;
            has_message = 1;
        } else {
            if (!has_message) {
                msg[0] = '\0';
                remaining = sizeof(msg) - 1;
                has_message = 1;
            }
            size_t current_len = strlen(msg);
            size_t arg_len = strlen(argv[i]);
            size_t space_needed = (current_len > 0) ? 1 : 0;
            
            if (arg_len + space_needed > remaining) break;
            
            if (current_len > 0) {
                strcat(msg, " ");
                remaining--;
            }
            strncat(msg, argv[i], remaining);
            remaining -= arg_len;
        }
    }
    
    cowsay_asm(msg, width);
    return 0;
}