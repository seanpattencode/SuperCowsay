#define _GNU_SOURCE
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/uio.h>

#define DEFAULT_WIDTH 40
#define MAX_IOVECS 128

static char underscore_buf[1024];
static char dash_buf[1024];
static char space_buf[1024];
static int buf_init = 0;

static inline void init_buffers() {
    if (!buf_init) {
        memset(underscore_buf, '_', sizeof(underscore_buf));
        memset(dash_buf, '-', sizeof(dash_buf));
        memset(space_buf, ' ', sizeof(space_buf));
        buf_init = 1;
    }
}

void cowsay_ultimate(const char *msg, int width) {
    init_buffers();
    
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    struct iovec iov[MAX_IOVECS];
    int iov_count = 0;
    
    static const char space = ' ';
    static const char newline = '\n';
    static const char lt = '<';
    static const char gt = '>';
    static const char slash = '/';
    static const char backslash = '\\';
    static const char pipe = '|';
    static const char cow[] = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    
    iov[iov_count++] = (struct iovec){(void*)&space, 1};
    iov[iov_count++] = (struct iovec){underscore_buf, w + 2};
    iov[iov_count++] = (struct iovec){(void*)&newline, 1};
    
    if (len <= width) {
        iov[iov_count++] = (struct iovec){(void*)&lt, 1};
        iov[iov_count++] = (struct iovec){(void*)&space, 1};
        iov[iov_count++] = (struct iovec){(void*)msg, len};
        iov[iov_count++] = (struct iovec){(void*)&space, 1};
        iov[iov_count++] = (struct iovec){(void*)&gt, 1};
        iov[iov_count++] = (struct iovec){(void*)&newline, 1};
    } else {
        for (int i = 0; i < len && iov_count < MAX_IOVECS - 10; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            const char *c1 = i == 0 ? &slash : (i + width >= len ? &backslash : &pipe);
            const char *c2 = i == 0 ? &backslash : (i + width >= len ? &slash : &pipe);
            
            iov[iov_count++] = (struct iovec){(void*)c1, 1};
            iov[iov_count++] = (struct iovec){(void*)&space, 1};
            iov[iov_count++] = (struct iovec){(void*)(msg + i), chunk};
            
            int padding = width - chunk;
            if (padding > 0) {
                iov[iov_count++] = (struct iovec){space_buf, padding};
            }
            
            iov[iov_count++] = (struct iovec){(void*)&space, 1};
            iov[iov_count++] = (struct iovec){(void*)c2, 1};
            iov[iov_count++] = (struct iovec){(void*)&newline, 1};
        }
    }
    
    iov[iov_count++] = (struct iovec){(void*)&space, 1};
    iov[iov_count++] = (struct iovec){dash_buf, w + 2};
    iov[iov_count++] = (struct iovec){(void*)cow, sizeof(cow) - 1};
    
    writev(STDOUT_FILENO, iov, iov_count);
}

int main(int argc, char *argv[]) {
    char msg[1024] = "Hello, World!";
    int width = DEFAULT_WIDTH;
    
    if (argc > 1) {
        msg[0] = '\0';
        for (int i = 1; i < argc; i++) {
            if (strcmp(argv[i], "-w") == 0 && i + 1 < argc) {
                width = atoi(argv[++i]);
            } else {
                if (msg[0] != '\0') strcat(msg, " ");
                strcat(msg, argv[i]);
            }
        }
    }
    
    cowsay_ultimate(msg, width);
    return 0;
}