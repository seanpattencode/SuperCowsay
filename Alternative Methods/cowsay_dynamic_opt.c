// Optimized C version that mimics the assembly approach
// No libc except the absolute minimum
__attribute__((naked))
void _start() {
    __asm__ volatile(
        ".intel_syntax noprefix\n"
        
        // Get argc/argv
        "mov rbx, [rsp]\n"
        "lea r15, [rsp + 8]\n"
        
        // Skip program name
        "add r15, 8\n"
        "dec rbx\n"
        
        // Allocate stack space for buffers
        "sub rsp, 5120\n"
        "lea r14, [rsp]\n"        // buffer start
        "mov r13, r14\n"           // current position
        
        // Build message first (at rsp + 4096)
        "lea r12, [rsp + 4096]\n"  // message buffer
        "mov r11, r12\n"           // message write pointer
        "xor r10, r10\n"           // message length
        
        "test rbx, rbx\n"
        "jz 2f\n"                  // no_args
        
        // Build message loop
        "1:\n"
        "test r10, r10\n"
        "jz 3f\n"                  // skip_space
        "mov byte ptr [r11], ' '\n"
        "inc r11\n"
        "inc r10\n"
        
        "3:\n"                     // skip_space
        "mov r9, [r15]\n"          // current arg
        
        "4:\n"                     // copy_char
        "mov al, [r9]\n"
        "test al, al\n"
        "jz 5f\n"                  // next_arg
        "mov [r11], al\n"
        "inc r11\n"
        "inc r10\n"
        "inc r9\n"
        "jmp 4b\n"
        
        "5:\n"                     // next_arg
        "add r15, 8\n"
        "dec rbx\n"
        "jnz 1b\n"
        "jmp 6f\n"
        
        "2:\n"                     // no_args - use default
        "mov rax, 0x57202c6f6c6c6548\n"  // 'Hello, W'
        "mov [r11], rax\n"
        "mov dword ptr [r11 + 8], 0x646c726f\n"  // 'orld'
        "mov byte ptr [r11 + 12], '!'\n"
        "mov r10, 13\n"
        
        "6:\n"                     // message_done
        // Build output
        // Top border
        "mov byte ptr [r13], ' '\n"
        "inc r13\n"
        
        // Underscores
        "mov rcx, r10\n"
        "add rcx, 2\n"
        "mov al, '_'\n"
        "7:\n"
        "mov [r13], al\n"
        "inc r13\n"
        "dec rcx\n"
        "jnz 7b\n"
        
        "mov byte ptr [r13], '\\n'\n"
        "inc r13\n"
        
        // Message line
        "mov word ptr [r13], 0x203c\n"  // '< '\n"
        "add r13, 2\n"
        
        // Copy message
        "mov rsi, r12\n"
        "mov rcx, r10\n"
        "8:\n"
        "mov al, [rsi]\n"
        "mov [r13], al\n"
        "inc rsi\n"
        "inc r13\n"
        "dec rcx\n"
        "jnz 8b\n"
        
        "mov word ptr [r13], 0x0a3e20\n"  // ' >\\n' (little-endian)\n"
        "add r13, 3\n"
        
        // Bottom border
        "mov byte ptr [r13], ' '\n"
        "inc r13\n"
        
        // Dashes
        "mov rcx, r10\n"
        "add rcx, 2\n"
        "mov al, '-'\n"
        "9:\n"
        "mov [r13], al\n"
        "inc r13\n"
        "dec rcx\n"
        "jnz 9b\n"
        
        "mov byte ptr [r13], '\\n'\n"
        "inc r13\n"
        
        // Cow art (optimized as immediate values)
        "mov rax, 0x5e5c2020202020200a\n"
        "mov [r13], rax\n"
        "add r13, 8\n"
        "mov rax, 0x205c202020200a5e5f\n"
        "mov [r13], rax\n"
        "add r13, 8\n"
        "mov rax, 0x5f5f5f29\n"
        "mov qword ptr [r13], 0x5f5f5f5f5c29\n"
        "add r13, 6\n"
        "mov rax, 0x202020200a0a5f5f5f\n"
        "mov [r13], rax\n"
        "add r13, 8\n"
        
        // Add rest of cow manually
        "lea rsi, [rip + cow]\n"
        "mov rcx, 91\n"
        "10:\n"
        "mov al, [rsi]\n"
        "mov [r13], al\n"
        "inc rsi\n"
        "inc r13\n"
        "dec rcx\n"
        "jnz 10b\n"
        
        // Calculate total length
        "mov rdx, r13\n"
        "sub rdx, r14\n"
        
        // Write syscall
        "mov rax, 1\n"
        "mov rdi, 1\n"
        "mov rsi, r14\n"
        "syscall\n"
        
        // Exit
        "mov rax, 60\n"
        "xor rdi, rdi\n"
        "syscall\n"
        
        "cow:\n"
        ".ascii \"        \\\\\\\\   ^__^\\n\"\n"
        ".ascii \"         \\\\\\\\  (oo)\\\\\\\\_______\\n\"\n"
        ".ascii \"            (__)\\\\\\\\       )\\\\\\\\/\\\\\\\\\\n\"\n"
        ".ascii \"                ||----w |\\n\"\n"
        ".ascii \"                ||     ||\\n\"\n"
        
        ".att_syntax prefix\n"
    );
}