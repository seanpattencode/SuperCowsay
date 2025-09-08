#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <unistd.h>
#include <fcntl.h>

#define DEFAULT_WIDTH 40
#define MMAP_SIZE 8192

void cowsay_mmap(const char *msg, int width) {
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    char *buffer = mmap(NULL, MMAP_SIZE, 
                       PROT_READ | PROT_WRITE, 
                       MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    
    if (buffer == MAP_FAILED) {
        perror("mmap");
        return;
    }
    
    char *ptr = buffer;
    
    *ptr++ = ' ';
    memset(ptr, '_', w + 2);
    ptr += w + 2;
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
            memset(ptr, ' ', width - chunk);
            ptr += width - chunk;
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    memset(ptr, '-', w + 2);
    ptr += w + 2;
    
    const char *cow = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    size_t cow_len = strlen(cow);
    memcpy(ptr, cow, cow_len);
    ptr += cow_len;
    
    size_t total_size = ptr - buffer;
    
    write(STDOUT_FILENO, buffer, total_size);
    
    munmap(buffer, MMAP_SIZE);
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
    
    cowsay_mmap(msg, width);
    return 0;
}