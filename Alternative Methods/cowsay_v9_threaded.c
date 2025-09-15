#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <pthread.h>
#include <unistd.h>

#define DEFAULT_WIDTH 40
#define BUFFER_SIZE 8192
#define NUM_THREADS 4

typedef struct {
    char *buffer;
    int start;
    int end;
    char pattern;
} fill_task_t;

typedef struct {
    char *dest;
    const char *src;
    int len;
} copy_task_t;

void* fill_worker(void* arg) {
    fill_task_t *task = (fill_task_t*)arg;
    memset(task->buffer + task->start, task->pattern, task->end - task->start);
    return NULL;
}

void* copy_worker(void* arg) {
    copy_task_t *task = (copy_task_t*)arg;
    memcpy(task->dest, task->src, task->len);
    return NULL;
}

void parallel_fill(char *buffer, char pattern, int len) {
    if (len < NUM_THREADS * 16) {
        memset(buffer, pattern, len);
        return;
    }
    
    pthread_t threads[NUM_THREADS];
    fill_task_t tasks[NUM_THREADS];
    int chunk_size = len / NUM_THREADS;
    
    for (int i = 0; i < NUM_THREADS; i++) {
        tasks[i].buffer = buffer;
        tasks[i].start = i * chunk_size;
        tasks[i].end = (i == NUM_THREADS - 1) ? len : (i + 1) * chunk_size;
        tasks[i].pattern = pattern;
        pthread_create(&threads[i], NULL, fill_worker, &tasks[i]);
    }
    
    for (int i = 0; i < NUM_THREADS; i++) {
        pthread_join(threads[i], NULL);
    }
}

void cowsay_threaded(const char *msg, int width) {
    static char buffer[BUFFER_SIZE];
    char *ptr = buffer;
    int len = strlen(msg);
    int w = len <= width ? len : width;
    
    *ptr++ = ' ';
    
    pthread_t border_threads[2];
    fill_task_t border_tasks[2];
    
    border_tasks[0].buffer = ptr;
    border_tasks[0].start = 0;
    border_tasks[0].end = w + 2;
    border_tasks[0].pattern = '_';
    pthread_create(&border_threads[0], NULL, fill_worker, &border_tasks[0]);
    
    char *dash_ptr = buffer + 1024;
    border_tasks[1].buffer = dash_ptr;
    border_tasks[1].start = 0;
    border_tasks[1].end = w + 2;
    border_tasks[1].pattern = '-';
    pthread_create(&border_threads[1], NULL, fill_worker, &border_tasks[1]);
    
    pthread_join(border_threads[0], NULL);
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
            
            int padding = width - chunk;
            if (padding > 0) {
                parallel_fill(ptr, ' ', padding);
                ptr += padding;
            }
            
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
        }
    }
    
    *ptr++ = ' ';
    
    pthread_join(border_threads[1], NULL);
    memcpy(ptr, dash_ptr, w + 2);
    ptr += w + 2;
    
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
    
    cowsay_threaded(msg, width);
    return 0;
}