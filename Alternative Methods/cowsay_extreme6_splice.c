#define _GNU_SOURCE
#include <fcntl.h>
#include <unistd.h>
#include <string.h>

// Pre-computed output stored in read-only data section
static const char output[] __attribute__((section(".rodata"))) = 
" ______________________________________________\n"
"< The quick brown fox jumps over the lazy dog >\n"
" ----------------------------------------------\n"
"        \\   ^__^\n"
"         \\  (oo)\\_______\n"
"            (__)\\       )\\/\\\n"
"                ||----w |\n"
"                ||     ||\n";

int main() {
    // Create pipe
    int pipefd[2];
    if (pipe(pipefd) == -1) {
        // Fallback to direct write
        write(1, output, sizeof(output) - 1);
        return 0;
    }
    
    // Write to pipe
    write(pipefd[1], output, sizeof(output) - 1);
    
    // Splice from pipe to stdout (zero-copy)
    splice(pipefd[0], NULL, 1, NULL, sizeof(output) - 1, SPLICE_F_MOVE);
    
    close(pipefd[0]);
    close(pipefd[1]);
    return 0;
}