#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

// Cache for previously generated outputs
typedef struct {
    char key[256];
    char output[1024];
    int len;
} cache_entry_t;

static cache_entry_t cache[16];
static int cache_idx = 0;

int main(int argc, char *argv[]) {
    // Build the key
    char key[256] = "";
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-w") == 0 && i + 1 < argc) {
            i++; // Skip width arg
            continue;
        }
        if (key[0]) strcat(key, " ");
        strcat(key, argv[i]);
    }
    
    // Check cache
    for (int i = 0; i < 16; i++) {
        if (strcmp(cache[i].key, key) == 0) {
            write(STDOUT_FILENO, cache[i].output, cache[i].len);
            return 0;
        }
    }
    
    // Generate output (simplified)
    char output[1024];
    int len = strlen(key);
    int w = len <= 40 ? len : 40;
    
    char *ptr = output;
    *ptr++ = ' ';
    memset(ptr, '_', w + 2);
    ptr += w + 2;
    *ptr++ = '\n';
    
    *ptr++ = '<';
    *ptr++ = ' ';
    memcpy(ptr, key, len);
    ptr += len;
    *ptr++ = ' ';
    *ptr++ = '>';
    *ptr++ = '\n';
    
    *ptr++ = ' ';
    memset(ptr, '-', w + 2);
    ptr += w + 2;
    
    const char *cow = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    size_t cow_len = strlen(cow);
    memcpy(ptr, cow, cow_len);
    ptr += cow_len;
    
    int output_len = ptr - output;
    
    // Cache it
    strcpy(cache[cache_idx].key, key);
    memcpy(cache[cache_idx].output, output, output_len);
    cache[cache_idx].len = output_len;
    cache_idx = (cache_idx + 1) % 16;
    
    write(STDOUT_FILENO, output, output_len);
    return 0;
}