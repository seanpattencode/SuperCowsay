# Dynamic assembly cowsay - processes arbitrary input with minimal overhead
# Build: as -o cowsay_dynamic.o cowsay_dynamic.s && ld -o cowsay_dynamic cowsay_dynamic.o

.intel_syntax noprefix
.global _start

.section .bss
    .lcomm buffer, 4096     # Output buffer
    .lcomm message, 1024    # Message buffer

.section .rodata
cow_art:
    .ascii "        \\   ^__^\n"
    .ascii "         \\  (oo)\\_______\n"
    .ascii "            (__)\\       )\\/\\\n"
    .ascii "                ||----w |\n"
    .ascii "                ||     ||\n"
cow_art_end:

.section .text
_start:
    # Get argc and argv from stack
    mov rbx, [rsp]          # argc
    lea rsi, [rsp + 8]      # argv
    
    # Skip program name
    add rsi, 8
    dec rbx
    
    # Build message from arguments
    lea rdi, [rip + message]
    xor r12, r12            # message length
    
    test rbx, rbx
    jz no_args
    
build_message:
    # Add space if not first arg
    test r12, r12
    jz skip_space
    mov byte ptr [rdi + r12], ' '
    inc r12
    
skip_space:
    # Copy current argument
    mov r13, [rsi]          # current arg pointer
    
copy_arg:
    mov al, [r13]
    test al, al
    jz next_arg
    mov [rdi + r12], al
    inc r12
    inc r13
    jmp copy_arg
    
next_arg:
    add rsi, 8              # next argv
    dec rbx
    jnz build_message
    jmp message_done
    
no_args:
    # Default message
    lea rsi, [rip + default_msg]
    mov rcx, 13
    rep movsb
    mov r12, 13
    
message_done:
    # Now r12 contains message length
    # Build output in buffer
    lea rdi, [rip + buffer]
    xor r14, r14            # buffer position
    
    # Top border: " " + "_" * (len + 2) + "\n"
    mov byte ptr [rdi], ' '
    inc rdi
    inc r14
    
    # Fill underscores
    mov rcx, r12
    add rcx, 2
    mov al, '_'
    rep stosb
    add r14, r12
    add r14, 2
    
    mov byte ptr [rdi], '\n'
    inc rdi
    inc r14
    
    # Message line: "< " + message + " >\n"
    mov byte ptr [rdi], '<'
    inc rdi
    inc r14
    mov byte ptr [rdi], ' '
    inc rdi
    inc r14
    
    # Copy message
    lea rsi, [rip + message]
    mov rcx, r12
    rep movsb
    add r14, r12
    
    mov byte ptr [rdi], ' '
    inc rdi
    inc r14
    mov byte ptr [rdi], '>'
    inc rdi
    inc r14
    mov byte ptr [rdi], '\n'
    inc rdi
    inc r14
    
    # Bottom border: " " + "-" * (len + 2) + "\n"
    mov byte ptr [rdi], ' '
    inc rdi
    inc r14
    
    # Fill dashes
    mov rcx, r12
    add rcx, 2
    mov al, '-'
    rep stosb
    add r14, r12
    add r14, 2
    
    mov byte ptr [rdi], '\n'
    inc rdi
    inc r14
    
    # Copy cow art
    lea rsi, [rip + cow_art]
    mov rcx, cow_art_end - cow_art
    rep movsb
    add r14, cow_art_end - cow_art
    
    # Write everything in one syscall
    mov rax, 1              # sys_write
    mov rdi, 1              # stdout
    lea rsi, [rip + buffer]
    mov rdx, r14            # total length
    syscall
    
    # Exit
    mov rax, 60             # sys_exit
    xor rdi, rdi
    syscall

.section .rodata
default_msg:
    .ascii "Hello, World!"