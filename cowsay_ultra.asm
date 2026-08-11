; cowsay_ultra - hand-rolled minimal ELF cowsay. Byte-identical to cowsay_dynamic (incl. limits:
; arg<256, total<1024, same error+exit codes), 2 syscalls, ONE R+X LOAD segment, no .bss - output
; built on the stack. Build: nasm -f bin -o cowsay_ultra cowsay_ultra.asm && chmod +x cowsay_ultra
BITS 64
org 0x400000
db 0x7F,"ELF",2,1,1,0
times 8 db 0
dw 2,0x3E
dd 1
dq _start, phdr-$$, 0
dd 0
dw 64,56,2,0,0,0
phdr: dd 1,5
dq 0,$$,$$,fsz,fsz,0x1000
dd 0x6474E551,6                 ; PT_GNU_STACK RW = noexecstack
dq 0,0,0,0,0,16

_start:
mov r8, [rsp]
lea r9, [rsp+16]
dec r8
jg .m
push dmsg                       ; no args: fake 1-entry argv -> "Hello, World!"
mov r9, rsp
mov r8, 1
mov r12, 13
jmp .e
.m:                             ; pass 1: r12 = joined length, champion's exact limits
xor r12, r12
mov r10, r9
mov rbx, r8
.a: mov rsi, [r10]
add r10, 8
xor rcx, rcx
.l: cmp byte [rsi+rcx], 0
je .d
inc rcx
cmp rcx, 256
jae .err
jmp .l
.d:
test r12, r12                   ; separator only if message nonempty so far
jz .n
inc r12
.n:
add r12, rcx
cmp r12, 1024
jae .err
dec rbx
jnz .a
.e:                             ; pass 2: build output on stack (max 11+3*1023+123=3203), one write
sub rsp, 4096
mov rdi, rsp
mov al, ' '
stosb
lea rcx, [r12+2]
mov al, '_'
rep stosb
mov ax, 0x3C0A                  ; "\n<"
stosw
mov al, ' '
stosb
mov r11, rdi
mov rbx, r8
.c: mov rsi, [r9]
add r9, 8
cmp rdi, r11
je .p
mov al, ' '
stosb
.p: lodsb
test al, al
jz .x
stosb
jmp .p
.x:
dec rbx
jnz .c
mov eax, 0x200A3E20             ; " >\n "
stosd
lea rcx, [r12+2]
mov al, '-'
rep stosb
mov al, 10
stosb
mov rsi, cow
mov rcx, clen
rep movsb
mov rdx, rdi
mov rsi, rsp
sub rdx, rsi
mov edi, 1
mov eax, 1
syscall
xor edi, edi
.die:
mov eax, 60
syscall
.err:
mov edi, 2
mov rsi, emsg
mov edx, 44
mov eax, 1
syscall
mov edi, 1
jmp .die

dmsg: db "Hello, World!",0
cow: db "        \   ^__^",10,"         \  (oo)\_______",10
db "            (__)\       )\/\",10,"                ||----w |",10,"                ||     ||",10
clen equ $-cow
emsg: db "Error: Input too long (max 1024 characters)",10
fsz equ $-$$
