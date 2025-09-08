#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/uio.h>

#define DEFAULT_WIDTH 40
#define MAX_IOVECS 256

void cowsay_zerocopy(const char *msg, int width) {
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    struct iovec iov[MAX_IOVECS];
    int iov_count = 0;
    
    static char space = ' ';
    static char newline = '\n';
    static char lt = '<';
    static char gt = '>';
    static char slash = '/';
    static char backslash = '\\';
    static char pipe = '|';
    
    static char underscore_buf[1024];
    static char dash_buf[1024];
    static char space_buf[1024];
    static int buf_init = 0;
    
    if (!buf_init) {
        memset(underscore_buf, '_', sizeof(underscore_buf));
        memset(dash_buf, '-', sizeof(dash_buf));
        memset(space_buf, ' ', sizeof(space_buf));
        buf_init = 1;
    }
    
    static const char cow[] = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    
    iov[iov_count].iov_base = &space;
    iov[iov_count].iov_len = 1;
    iov_count++;
    
    iov[iov_count].iov_base = underscore_buf;
    iov[iov_count].iov_len = w + 2;
    iov_count++;
    
    iov[iov_count].iov_base = &newline;
    iov[iov_count].iov_len = 1;
    iov_count++;
    
    if (len <= width) {
        iov[iov_count].iov_base = &lt;
        iov[iov_count].iov_len = 1;
        iov_count++;
        
        iov[iov_count].iov_base = &space;
        iov[iov_count].iov_len = 1;
        iov_count++;
        
        iov[iov_count].iov_base = (void*)msg;
        iov[iov_count].iov_len = len;
        iov_count++;
        
        iov[iov_count].iov_base = &space;
        iov[iov_count].iov_len = 1;
        iov_count++;
        
        iov[iov_count].iov_base = &gt;
        iov[iov_count].iov_len = 1;
        iov_count++;
        
        iov[iov_count].iov_base = &newline;
        iov[iov_count].iov_len = 1;
        iov_count++;
    } else {
        for (int i = 0; i < len; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            char *c1 = i == 0 ? &slash : (i + width >= len ? &backslash : &pipe);
            char *c2 = i == 0 ? &backslash : (i + width >= len ? &slash : &pipe);
            
            iov[iov_count].iov_base = c1;
            iov[iov_count].iov_len = 1;
            iov_count++;
            
            iov[iov_count].iov_base = &space;
            iov[iov_count].iov_len = 1;
            iov_count++;
            
            iov[iov_count].iov_base = (void*)(msg + i);
            iov[iov_count].iov_len = chunk;
            iov_count++;
            
            int padding = width - chunk;
            if (padding > 0) {
                iov[iov_count].iov_base = space_buf;
                iov[iov_count].iov_len = padding;
                iov_count++;
            }
            
            iov[iov_count].iov_base = &space;
            iov[iov_count].iov_len = 1;
            iov_count++;
            
            iov[iov_count].iov_base = c2;
            iov[iov_count].iov_len = 1;
            iov_count++;
            
            iov[iov_count].iov_base = &newline;
            iov[iov_count].iov_len = 1;
            iov_count++;
            
            if (iov_count >= MAX_IOVECS - 10) break;
        }
    }
    
    iov[iov_count].iov_base = &space;
    iov[iov_count].iov_len = 1;
    iov_count++;
    
    iov[iov_count].iov_base = dash_buf;
    iov[iov_count].iov_len = w + 2;
    iov_count++;
    
    iov[iov_count].iov_base = (void*)cow;
    iov[iov_count].iov_len = strlen(cow);
    iov_count++;
    
    writev(STDOUT_FILENO, iov, iov_count);
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
    
    cowsay_zerocopy(msg, width);
    return 0;
}