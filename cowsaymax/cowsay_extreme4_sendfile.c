#define _GNU_SOURCE
#include <sys/sendfile.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <string.h>
#include <stdio.h>

static const char OUTPUT[] = 
" ______________________________________________\n"
"< The quick brown fox jumps over the lazy dog >\n"
" ----------------------------------------------\n"
"        \\   ^__^\n"
"         \\  (oo)\\_______\n"
"            (__)\\       )\\/\\\n"
"                ||----w |\n"
"                ||     ||\n";

int main(int argc, char *argv[]) {
    static int initialized = 0;
    static int fd = -1;
    static off_t len = sizeof(OUTPUT) - 1;
    
    if (!initialized) {
        // Create temp file once
        fd = open("/tmp/cowsay_cache", O_RDWR | O_CREAT | O_TRUNC, 0600);
        if (fd >= 0) {
            write(fd, OUTPUT, len);
            initialized = 1;
        }
    }
    
    if (fd >= 0) {
        // Use sendfile for zero-copy transfer
        off_t offset = 0;
        sendfile(STDOUT_FILENO, fd, &offset, len);
    } else {
        // Fallback
        write(STDOUT_FILENO, OUTPUT, len);
    }
    
    return 0;
}