; https://superuser.com/questions/1094409/how-do-i-auto-turn-off-a-dos-only-machine-using-software-the-pc-has-no-power-sw
; nasm-0.98.39 -O0 -o atxoff.com atxoff.nasm
org 100h
mov ax, 5301h
xor bx, bx
int 15h
mov ax, 530eh
xor bx, bx
mov cx, 0102h
int 15h
mov ax, 5307h
xor bx, bx
inc bx
mov cx, 0003h
int 15h
ret
