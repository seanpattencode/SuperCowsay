#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define DEFAULT_WIDTH 40
#define BUFFER_SIZE 8192
#define VECTOR_SIZE 16

typedef char char16 __attribute__((vector_size(16)));

void cowsay_vector(const char *msg, int width) {
    static char buffer[BUFFER_SIZE] __attribute__((aligned(16)));
    char *ptr = buffer;
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    *ptr++ = ' ';
    
    char16 underscore_vec = {
        '_', '_', '_', '_', '_', '_', '_', '_',
        '_', '_', '_', '_', '_', '_', '_', '_'
    };
    
    int border_len = w + 2;
    int vec_iters = border_len / VECTOR_SIZE;
    int remainder = border_len % VECTOR_SIZE;
    
    for (int i = 0; i < vec_iters; i++) {
        *((char16*)ptr) = underscore_vec;
        ptr += VECTOR_SIZE;
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
        char16 space_vec = {
            ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ',
            ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' '
        };
        
        for (int i = 0; i < len; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            char c1 = i == 0 ? '/' : (i + width >= len ? '\\' : '|');
            char c2 = i == 0 ? '\\' : (i + width >= len ? '/' : '|');
            *ptr++ = c1;
            *ptr++ = ' ';
            memcpy(ptr, msg + i, chunk);
            ptr += chunk;
            
            int padding = width - chunk;
            int pad_vec_iters = padding / VECTOR_SIZE;
            int pad_remainder = padding % VECTOR_SIZE;
            
            for (int j = 0; j < pad_vec_iters; j++) {
                *((char16*)ptr) = space_vec;
                ptr += VECTOR_SIZE;
            }
            
            memset(ptr, ' ', pad_remainder);
            ptr += pad_remainder;
            
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    
    char16 dash_vec = {
        '-', '-', '-', '-', '-', '-', '-', '-',
        '-', '-', '-', '-', '-', '-', '-', '-'
    };
    
    for (int i = 0; i < vec_iters; i++) {
        *((char16*)ptr) = dash_vec;
        ptr += VECTOR_SIZE;
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
    
    cowsay_vector(msg, width);
    return 0;
}