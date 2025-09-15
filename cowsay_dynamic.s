# Dynamic assembly cowsay - processes arbitrary input with minimal overhead and bounds checking
# Build: as -o cowsay_dynamic.o cowsay_dynamic.s && ld -o cowsay_dynamic cowsay_dynamic.o

.intel_syntax noprefix
.global _start

.section .bss
    .lcomm buffer, 4096     # Output buffer (4KB max)
    .lcomm message, 1024    # Message buffer (1KB max)

.section .rodata
cow_art:
    .ascii "        \\   ^__^\n"
    .ascii "         \\  (oo)\\_______\n"
    .ascii "            (__)\\       )\\/\\\n"
    .ascii "                ||----w |\n"
    .ascii "                ||     ||\n"
cow_art_end:

# Constants for bounds checking
.equ MAX_MESSAGE_LEN, 1024
.equ MAX_BUFFER_LEN, 4096
.equ MAX_ARG_LEN, 256

error_msg:
    .ascii "Error: Input too long (max 1024 characters)\n"
error_msg_end:

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

    # Check if adding space would exceed bounds
    cmp r12, MAX_MESSAGE_LEN - 1
    jae input_too_long

    mov byte ptr [rdi + r12], ' '
    inc r12

skip_space:
    # Copy current argument
    mov r13, [rsi]          # current arg pointer
    xor r15, r15            # arg length counter

    # First pass: check argument length
measure_arg:
    mov al, [r13 + r15]
    test al, al
    jz copy_arg_start
    inc r15

    # Check individual arg length limit
    cmp r15, MAX_ARG_LEN
    jae input_too_long
    jmp measure_arg

copy_arg_start:
    # Check if copying this arg would exceed total message bounds
    mov rax, r12
    add rax, r15
    cmp rax, MAX_MESSAGE_LEN
    jae input_too_long

    # Reset for actual copy
    xor r15, r15

copy_arg:
    mov al, [r13 + r15]
    test al, al
    jz next_arg
    mov [rdi + r12], al
    inc r12
    inc r15
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
    # Check if final output will fit in buffer
    # Format: " " + underscores + "\n" + "< " + message + " >\n" + " " + dashes + "\n" + cow_art
    # Total: 1 + (len+2) + 1 + 2 + len + 2 + 1 + 1 + (len+2) + 1 + cow_art_len
    # = 11 + 3*len + cow_art_len
    mov rax, r12
    add rax, r12
    add rax, r12            # 3*len
    add rax, 11             # constant overhead
    add rax, cow_art_end - cow_art  # cow art size
    cmp rax, MAX_BUFFER_LEN
    jae output_too_long

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

    # Exit successfully
    mov rax, 60             # sys_exit
    xor rdi, rdi            # exit code 0
    syscall

# Error handling for input too long
input_too_long:
output_too_long:
    # Write error message
    mov rax, 1              # sys_write
    mov rdi, 2              # stderr
    lea rsi, [rip + error_msg]
    mov rdx, error_msg_end - error_msg
    syscall

    # Exit with error code
    mov rax, 60             # sys_exit
    mov rdi, 1              # exit code 1
    syscall

.section .rodata
default_msg:
    .ascii "Hello, World!"
