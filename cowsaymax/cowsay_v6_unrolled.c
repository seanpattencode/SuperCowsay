#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>

#define DEFAULT_WIDTH 40
#define BUFFER_SIZE 8192

#define UNROLL_8(action) \
    action; action; action; action; \
    action; action; action; action;

#define UNROLL_4(action) \
    action; action; action; action;

void cowsay_unrolled(const char *msg, int width) {
    static char buffer[BUFFER_SIZE];
    char *ptr = buffer;
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    *ptr++ = ' ';
    
    int border_len = w + 2;
    int unroll8 = border_len / 8;
    int remainder = border_len % 8;
    
    for (int i = 0; i < unroll8; i++) {
        UNROLL_8(*ptr++ = '_');
    }
    
    switch(remainder) {
        case 7: *ptr++ = '_';
        case 6: *ptr++ = '_';
        case 5: *ptr++ = '_';
        case 4: *ptr++ = '_';
        case 3: *ptr++ = '_';
        case 2: *ptr++ = '_';
        case 1: *ptr++ = '_';
        case 0: break;
    }
    *ptr++ = '\n';
    
    if (len <= width) {
        *ptr++ = '<';
        *ptr++ = ' ';
        
        int msg_unroll8 = len / 8;
        int msg_remainder = len % 8;
        const char *msg_ptr = msg;
        
        for (int i = 0; i < msg_unroll8; i++) {
            UNROLL_8(*ptr++ = *msg_ptr++);
        }
        
        switch(msg_remainder) {
            case 7: *ptr++ = *msg_ptr++;
            case 6: *ptr++ = *msg_ptr++;
            case 5: *ptr++ = *msg_ptr++;
            case 4: *ptr++ = *msg_ptr++;
            case 3: *ptr++ = *msg_ptr++;
            case 2: *ptr++ = *msg_ptr++;
            case 1: *ptr++ = *msg_ptr++;
            case 0: break;
        }
        
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
            
            const char *chunk_ptr = msg + i;
            int chunk_unroll4 = chunk / 4;
            int chunk_remainder = chunk % 4;
            
            for (int j = 0; j < chunk_unroll4; j++) {
                UNROLL_4(*ptr++ = *chunk_ptr++);
            }
            
            switch(chunk_remainder) {
                case 3: *ptr++ = *chunk_ptr++;
                case 2: *ptr++ = *chunk_ptr++;
                case 1: *ptr++ = *chunk_ptr++;
                case 0: break;
            }
            
            int padding = width - chunk;
            int pad_unroll8 = padding / 8;
            int pad_remainder = padding % 8;
            
            for (int j = 0; j < pad_unroll8; j++) {
                UNROLL_8(*ptr++ = ' ');
            }
            
            switch(pad_remainder) {
                case 7: *ptr++ = ' ';
                case 6: *ptr++ = ' ';
                case 5: *ptr++ = ' ';
                case 4: *ptr++ = ' ';
                case 3: *ptr++ = ' ';
                case 2: *ptr++ = ' ';
                case 1: *ptr++ = ' ';
                case 0: break;
            }
            
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    
    for (int i = 0; i < unroll8; i++) {
        UNROLL_8(*ptr++ = '-');
    }
    
    switch(remainder) {
        case 7: *ptr++ = '-';
        case 6: *ptr++ = '-';
        case 5: *ptr++ = '-';
        case 4: *ptr++ = '-';
        case 3: *ptr++ = '-';
        case 2: *ptr++ = '-';
        case 1: *ptr++ = '-';
        case 0: break;
    }
    
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
    
    cowsay_unrolled(msg, width);
    return 0;
}