;
; fullimg.asm: append 0xe5 bytes to a disk image file
; by pts@fazekas.hu at Sat Dec  7 03:03:23 CET 2024
;
; Compile with: nasm -O0 -o fullimg.com fullimg.nasm
; Run it on DOS >=2.0 or in a DOS emulator (e.g. DOSBox, emu2, kvikdos).
;

DESIRED_SIZE equ 0x3e900
FILL_BYTE equ 0xe5
BUF_SIZE equ 1000h  ; Must be a divisor of 10000h

	org 100h
	mov si, 81h  ; Command-line arguments.
parsearg1:
.skip:	lodsb
	cmp al, 9
	je .skip
	cmp al, ' '
	je .skip
	cmp al, 13
	jne parsearg2
argerror:
	mov dx, argerrmsg
	jmp error
parsearg2:
	mov dx, si
	dec dx  ; DX := start of filename, will be used later, for opening.
.next:	lodsb
	cmp al, 9
	je argerror
	cmp al, ' '
	je argerror
	cmp al, 13
	jne .next
	mov byte [si-1], 0  ; NUL-terminate the filename.
	mov ax, 3d01h
	int 21h  ; Open existing file for writing. AX := filehandle. It stays there from now on.
	jc ioerror
	xchg bx, ax  ; BX := AX (filehandle); BX := junk.
	mov ax, 4202h
	xor cx, cx
	xor dx, dx
	int 21h
	jc ioerror
	; Now: DX:AX is the file size.
	mov di, buf
	mov cx, BUF_SIZE>>1
	push ax  ; Save.
	mov ax, (FILL_BYTE&0xff)*0x101
	rep stosw  ; Fill buffer of 1000h bytes.
	pop ax  ; Restore.
	mov bp, DESIRED_SIZE>>16
	mov di, DESIRED_SIZE&0xffff
	sub di, ax
	sbb bp, dx
	jnc need_grow
longerror:
	mov dx, longerrmsg
	jmp error
need_grow:
	; Now: BP:DI == remaining number of bytes to add.
	mov dx, buf
.again:
	test di, di
	jz next_seg
	mov ah, 40h
	mov cx, di
	cmp cx, BUF_SIZE
	jna .good_size
	mov cx, BUF_SIZE
.good_size:
	int 21h  ; Write DI bytes.
	jc ioerror
	sub di, ax
	jmp .again
next_seg:  ; Write 10000h bytes, in a loop.
	test bp, bp
	jz done
	dec bp
	mov di, 10000h/BUF_SIZE
nextblock:  ; Write BUF_SIZE bytes, in a loop.
	test di, di
	jz next_seg
	dec di
	mov ah, 40h
	mov cx, BUF_SIZE
	int 21h  ; Write BUF_SIZE bytes.
	jc ioerror
	jmp nextblock
done:	ret  ; Exit successfully. No need to close the file, DOS will do it.

ioerror:
	mov dx, ioerrmsg
	; Fall through.
error:  ; Input: DX: points to error message.
	mov ah, 9
	int 21h
	mov ax, 4c02h
	int 21h

argerrmsg: db 'fatal: missing filename', 13, 10, '$'
ioerrmsg: db 'fatal: I/O error', 13, 10, '$'
longerrmsg: db 'fatal: file too long', 13, 10, '$'
absolute $
buf:	resb BUF_SIZE
