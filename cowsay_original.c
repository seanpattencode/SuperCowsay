#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define DEFAULT_WIDTH 40

void cowsay(const char *msg, int width) {
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    printf(" ");
    for(int i = 0; i < w + 2; i++) putchar('_');
    printf("\n");
    
    if (len <= width) {
        printf("< %s >\n", msg);
    } else {
        for (int i = 0; i < len; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            char c1 = i == 0 ? '/' : (i + width >= len ? '\\' : '|');
            char c2 = i == 0 ? '\\' : (i + width >= len ? '/' : '|');
            printf("%c ", c1);
            printf("%.*s", chunk, msg + i);
            for(int j = chunk; j < width; j++) putchar(' ');
            printf(" %c\n", c2);
        }
    }
    
    printf(" ");
    for(int i = 0; i < w + 2; i++) putchar('-');
    printf("\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n");
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
            
            if (arg_len + space_needed > remaining) {
                fprintf(stderr, "Warning: Message truncated due to length limit\n");
                break;
            }
            
            if (current_len > 0) {
                strcat(msg, " ");
                remaining--;
            }
            strncat(msg, argv[i], remaining);
            remaining -= arg_len;
        }
    }
    
    cowsay(msg, width);
    return 0;
}