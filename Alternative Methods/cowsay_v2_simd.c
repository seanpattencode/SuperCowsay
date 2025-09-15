#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <immintrin.h>
#include <unistd.h>

#define DEFAULT_WIDTH 40
#define BUFFER_SIZE 8192

void cowsay_simd(const char *msg, int width) {
    static char buffer[BUFFER_SIZE] __attribute__((aligned(32)));
    char *ptr = buffer;
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    *ptr++ = ' ';
    
    __m256i underscore = _mm256_set1_epi8('_');
    int simd_iters = (w + 2) / 32;
    int remainder = (w + 2) % 32;
    
    for (int i = 0; i < simd_iters; i++) {
        _mm256_store_si256((__m256i*)ptr, underscore);
        ptr += 32;
    }
    memset(ptr, '_', remainder);
    ptr += remainder;
    *ptr++ = '\n';
    
    if (len <= width) {
        *ptr++ = '<';
        *ptr++ = ' ';
        memcpy(ptr, msg, len);
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
            memcpy(ptr, msg + i, chunk);
            ptr += chunk;
            
            __m256i space = _mm256_set1_epi8(' ');
            int padding = width - chunk;
            int simd_padding = padding / 32;
            int padding_remainder = padding % 32;
            
            for (int j = 0; j < simd_padding; j++) {
                _mm256_store_si256((__m256i*)ptr, space);
                ptr += 32;
            }
            memset(ptr, ' ', padding_remainder);
            ptr += padding_remainder;
            
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    
    __m256i dash = _mm256_set1_epi8('-');
    for (int i = 0; i < simd_iters; i++) {
        _mm256_store_si256((__m256i*)ptr, dash);
        ptr += 32;
    }
    memset(ptr, '-', remainder);
    ptr += remainder;
    
    const char *cow = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    size_t cow_len = strlen(cow);
    memcpy(ptr, cow, cow_len);
    ptr += cow_len;
    
    write(STDOUT_FILENO, buffer, ptr - buffer);
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
    
    cowsay_simd(msg, width);
    return 0;
}