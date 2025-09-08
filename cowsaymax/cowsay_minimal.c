#include <unistd.h>
#include <string.h>

// Ultra-minimal cowsay - no stdio, minimal operations
int main(int argc, char *argv[]) {
    static char buf[2048];
    char *p = buf;
    
    // Combine args into message
    char msg[1024];
    int len = 0;
    for (int i = 1; i < argc; i++) {
        if (i > 1) msg[len++] = ' ';
        char *s = argv[i];
        while (*s) msg[len++] = *s++;
    }
    
    // Top border
    *p++ = ' ';
    memset(p, '_', len + 2); p += len + 2;
    *p++ = '\n';
    
    // Message
    *p++ = '<'; *p++ = ' ';
    memcpy(p, msg, len); p += len;
    *p++ = ' '; *p++ = '>'; *p++ = '\n';
    
    // Bottom border  
    *p++ = ' ';
    memset(p, '-', len + 2); p += len + 2;
    *p++ = '\n';
    
    // Cow
    memcpy(p, "        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n", 135);
    p += 135;
    
    write(1, buf, p - buf);
    return 0;
}