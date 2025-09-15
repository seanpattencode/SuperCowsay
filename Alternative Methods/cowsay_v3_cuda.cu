#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <cuda_runtime.h>

#define DEFAULT_WIDTH 40
#define THREADS_PER_BLOCK 256

__global__ void fill_pattern_kernel(char *buffer, char pattern, int count, int offset) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < count) {
        buffer[offset + idx] = pattern;
    }
}

__global__ void copy_message_kernel(char *buffer, const char *msg, int len, int offset) {
    int idx = blockIdx.x * blockDim.x + threadIdx.x;
    if (idx < len) {
        buffer[offset + idx] = msg[idx];
    }
}

void cowsay_cuda(const char *msg, int width) {
    int len = strlen(msg);
    int w = len <= width ? len : width;
    int buffer_size = 8192;
    
    char *h_buffer = (char*)malloc(buffer_size);
    char *d_buffer;
    char *d_msg;
    
    cudaMalloc(&d_buffer, buffer_size);
    cudaMalloc(&d_msg, len + 1);
    cudaMemcpy(d_msg, msg, len + 1, cudaMemcpyHostToDevice);
    
    char *ptr = h_buffer;
    int offset = 0;
    
    *ptr++ = ' ';
    offset++;
    
    int blocks = (w + 2 + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    fill_pattern_kernel<<<blocks, THREADS_PER_BLOCK>>>(d_buffer, '_', w + 2, offset);
    cudaDeviceSynchronize();
    offset += w + 2;
    ptr += w + 2;
    
    cudaMemcpy(h_buffer + 1, d_buffer + 1, w + 2, cudaMemcpyDeviceToHost);
    *ptr++ = '\n';
    offset++;
    
    if (len <= width) {
        strcpy(ptr, "< ");
        ptr += 2;
        offset += 2;
        
        blocks = (len + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
        copy_message_kernel<<<blocks, THREADS_PER_BLOCK>>>(d_buffer, d_msg, len, offset);
        cudaDeviceSynchronize();
        cudaMemcpy(ptr, d_buffer + offset, len, cudaMemcpyDeviceToHost);
        
        ptr += len;
        offset += len;
        strcpy(ptr, " >\n");
        ptr += 3;
        offset += 3;
    } else {
        for (int i = 0; i < len; i += width) {
            int chunk = (len - i < width) ? len - i : width;
            char c1 = i == 0 ? '/' : (i + width >= len ? '\\' : '|');
            char c2 = i == 0 ? '\\' : (i + width >= len ? '/' : '|');
            
            *ptr++ = c1;
            *ptr++ = ' ';
            offset += 2;
            
            blocks = (chunk + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
            copy_message_kernel<<<blocks, THREADS_PER_BLOCK>>>(d_buffer, d_msg + i, chunk, offset);
            cudaDeviceSynchronize();
            cudaMemcpy(ptr, d_buffer + offset, chunk, cudaMemcpyDeviceToHost);
            
            ptr += chunk;
            offset += chunk;
            
            int padding = width - chunk;
            if (padding > 0) {
                blocks = (padding + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
                fill_pattern_kernel<<<blocks, THREADS_PER_BLOCK>>>(d_buffer, ' ', padding, offset);
                cudaDeviceSynchronize();
                cudaMemcpy(ptr, d_buffer + offset, padding, cudaMemcpyDeviceToHost);
                ptr += padding;
                offset += padding;
            }
            
            *ptr++ = ' ';
            *ptr++ = c2;
            *ptr++ = '\n';
            offset += 3;
        }
    }
    
    *ptr++ = ' ';
    offset++;
    
    blocks = (w + 2 + THREADS_PER_BLOCK - 1) / THREADS_PER_BLOCK;
    fill_pattern_kernel<<<blocks, THREADS_PER_BLOCK>>>(d_buffer, '-', w + 2, offset);
    cudaDeviceSynchronize();
    cudaMemcpy(ptr, d_buffer + offset, w + 2, cudaMemcpyDeviceToHost);
    ptr += w + 2;
    
    const char *cow = "\n        \\   ^__^\n         \\  (oo)\\_______\n            (__)\\       )\\/\\\n                ||----w |\n                ||     ||\n";
    strcpy(ptr, cow);
    ptr += strlen(cow);
    
    fwrite(h_buffer, 1, ptr - h_buffer, stdout);
    
    cudaFree(d_buffer);
    cudaFree(d_msg);
    free(h_buffer);
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
    
    cowsay_cuda(msg, width);
    return 0;
}