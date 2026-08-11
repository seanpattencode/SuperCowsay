; floor_exit - the exec floor instrument: smallest correct process, exit(0) only, 1 syscall.
; Anything a spawned cowsay could ever do sits above this line.
; Build: nasm -f bin -o floor_exit floor_exit.asm && chmod +x floor_exit
BITS 64
org 0x400000
db 0x7F,"ELF",2,1,1,0
times 8 db 0
dw 2,0x3E
dd 1
dq _start, phdr-$$, 0
dd 0
dw 64,56,1,0,0,0
phdr: dd 1,5
dq 0,$$,$$,fsz,fsz,0x1000
_start:
mov eax,60
xor edi,edi
syscall
fsz equ $-$$
