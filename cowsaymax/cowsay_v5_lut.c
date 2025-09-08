#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define DEFAULT_WIDTH 40
#define BUFFER_SIZE 8192

static const char COW_TEMPLATE[] = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";

static const char REPEAT_CHARS[256] = {
    ['_'] = '_', ['-'] = '-', [' '] = ' '
};

static char PRECOMPUTED_LINES[128][44];
static int PRECOMPUTED_INIT = 0;

void init_precomputed() {
    if (PRECOMPUTED_INIT) return;
    
    for (int w = 1; w <= 42; w++) {
        memset(PRECOMPUTED_LINES[w * 2], '_', w + 2);
        PRECOMPUTED_LINES[w * 2][w + 2] = '\0';
        
        memset(PRECOMPUTED_LINES[w * 2 + 1], '-', w + 2);
        PRECOMPUTED_LINES[w * 2 + 1][w + 2] = '\0';
    }
    
    PRECOMPUTED_INIT = 1;
}

static inline void fast_repeat(char *dest, char c, int count) {
    if (count <= 0) return;
    
    if (count <= 8) {
        switch(count) {
            case 8: *dest++ = c;
            case 7: *dest++ = c;
            case 6: *dest++ = c;
            case 5: *dest++ = c;
            case 4: *dest++ = c;
            case 3: *dest++ = c;
            case 2: *dest++ = c;
            case 1: *dest++ = c;
        }
    } else {
        memset(dest, c, count);
    }
}

void cowsay_lut(const char *msg, int width) {
    init_precomputed();
    
    static char buffer[BUFFER_SIZE];
    char *ptr = buffer;
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    *ptr++ = ' ';
    if (w <= 42) {
        memcpy(ptr, PRECOMPUTED_LINES[w * 2], w + 2);
        ptr += w + 2;
    } else {
        fast_repeat(ptr, '_', w + 2);
        ptr += w + 2;
    }
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
        static const char brackets[4][2] = {
            {'/', '\\'}, {'|', '|'}, {'\\', '/'}
        };
        
        for (int i = 0; i < len; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            int bracket_idx = (i == 0) ? 0 : ((i + width >= len) ? 2 : 1);
            
            *ptr++ = brackets[bracket_idx][0];
            *ptr++ = ' ';
            memcpy(ptr, msg + i, chunk);
            ptr += chunk;
            fast_repeat(ptr, ' ', width - chunk);
            ptr += width - chunk;
            *ptr++ = ' ';
            *ptr++ = brackets[bracket_idx][1];
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    if (w <= 42) {
        memcpy(ptr, PRECOMPUTED_LINES[w * 2 + 1], w + 2);
        ptr += w + 2;
    } else {
        fast_repeat(ptr, '-', w + 2);
        ptr += w + 2;
    }
    
    memcpy(ptr, COW_TEMPLATE, sizeof(COW_TEMPLATE) - 1);
    ptr += sizeof(COW_TEMPLATE) - 1;
    
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
    
    cowsay_lut(msg, width);
    return 0;
}