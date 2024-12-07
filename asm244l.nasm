;
; asm244l.nasm: Seattle Computer Products 8086 Assembler Version 2.44, improved by pts, ported to Linux i386
; SCP assmebler originally written by Tim Paterson between 1979 and 1983-05-09
; NASM and Linux i386 port, improved by pts@fazekas.hu started on 2024-12-02
;
; Compile with: nasm -o asm244i asm244l.nasm && chmod +x asm244i
; Compile with: nasm -w+orphan-labels -f bin -O0 -o asm244i asm244i.nasm && chmod +x asm244i
; It produces identical output with `nasm -O0' and `nasm -O999999999'.
; It compiles with NASM >=0.98.39.
;
; [MIT License](https://github.com/microsoft/MS-DOS/blob/main/LICENSE)
;
; The assembler supports Intel 8086 and 8087 (FPU) instructions. It has a
; syntax similar to Intel's, but with quite many syntax differences.
;
; Seattle Computer Products 8086 Assembler  version 2.44
;   by Tim Paterson
; Runs on the 8086 under MS-DOS
;
;* * * * * * REVISION HISTORY * * * * * *
;
; 12/29/80  2.01  General release with 86-DOS version 0.34
; 02/22/81  2.10  Increased buffer size from 128 bytes to 1024 bytes
; 03/18/81  2.11  General cleanup and more documentation
; 03/24/81  2.20  Modify ESC handling for full 8087 operation
; 04/01/81  2.21  Fix date in .hex and .lst files; modify buffer handling
; 04/03/81  2.22  Fix 2.21 buffer handling
; 04/13/81  2.23  Re-open source file for listing to allow assembling CON:
; 04/28/81  2.24  Allow nested IFs
; 07/30/81  2.25  Add Intel string mnemonics; clean up a little
; 08/02/81  2.30  Re-write pass 2:
;			Always report errors to console
;			Exact byte lengths for .hex and .prn files
; 11/08/81  2.40  Add 8087 mnemonics; print full error messages;
;		  allow expressions with *, /, and ()
; 07/04/82  2.41  Fix Intel's 8087 "reverse-bit" bug; don't copy date
; 08/18/82  2.42  Increase stack from 80 to 256 (Damn! Overflowed again!)
; 01/05/83  2.43  Correct over-zealous optimization in 2.42
; 05/09/83  2.44  Add memory usage report
;
;* * * * * * * * * * * * * * * * * * * * *
;
; The improvements by pts are:
;
; * DONE: more relaxed input: no need for \x1a at EOF; as a side effect, both NUL (\x00) and \x1a stop the input
; * DONE: more relaxed input: whitespace is OK in front of :
; * DONE: more relaxed input: accept any of CR, LF or CRLF as end-of-line
; * DONE: more relaxed input: allow instraction at beginning-of-line even without whitespace or label
; * DONE: more relaxed input: \x1a and \x00 to indicate EOF in the middle of the line
; * DONE: indicate error as non-zero exit status (on DOS 1.x it's still zero, because that's the only one available)
; * DONE: don't add space in front of each line in the .lst file (the space was introduced by more relaxed input)
; * DONE: kvikdos compatibility: autodetect DOS 2.0, and use filehandle-based file ABIs if available; this makes specifying subdirectories possible
; * DONE: autodetect ORG, and write .bin file instead of the .com file if ORG is not 100H
; * DONE: command-line processing is user-friendly, there is usage
; * DONE: assembly source file may have extension other than .asm
; * DONE: store HEXFCB, BINFCB, LSTFCB in .bss to save file size
; * DONE: use a larger BINBUFSIZ; this is relevant only if both .bin and .hex files are disabled, then unify the 3 buffers: LSTBUFSIZ (== 1024) + HEXBUFSIZ (== 70) + BINBUFSIZ (== 26); easier: use LSTBUFSIZ (== 1024) if the .lst file is disabled
; * DONE: the symbol table (-s) is CRLF-terminated
; * DONE: with flag -n, generate `cmp byte' instead of `db 0x82' instruction, for compatibility with NASM ndisasm(1)
; * DONE: reorder bssvars: move 1-byte variables together, to improve word alignment of even-sized variables
; * DONE: remove extra space added by NEXTCHRZ to the beginning of each line
; * DONE: bugfix: fixed source line contents printed to the console when -l (or -c or -p) is not active
; * DONE: bugfix: fixed printing 0 digits of 5-digit integers
; * DONE: parser autodetects whether the first word is an instruction or a label, using data-instruction-second-word and known-unistruction-first-word heuristics
; * DONE: with flag -x, emit X instead of NUL for DS bytes
; * DONE: fail with an error message on write error
; * DONE: fail with an error message on read error (DOS >=2.0 only)
; * DONE: fail with an error message on expression stack too deep
;
; This program uses at most 64 KiB of memory, in a single segment
; (CS=DS=ES=SS). The layout of this segment is:
;
; * 00000H ...00054H   5FE000H...5FE054H: ELF-32 header (Ehdr and Phdr).
; * 00100H ...BSS      5FE054H...600ADCH: Program code and data, the .com program file is loaded to this offset. The USAGE message below is also loaded.
; * BSS    ...BSS0     600ADCH...600BEFH: USAGE message, and start of .bss.
; * BSS0   ...START    600BEFH...600CB0H: .bss: zero-initialized and uninitialized global variables, including buffers.
; * START  ...CODE     600CB0H...60?????: The big 64 KiB starts here. Patch table containing specials, fixups and errors, grows up. Populated in pass1, grows up.
; * CODE   ...HEAP     60?????...60?????: Unused gap between the patch table and the symbol table. The big 64 KiB ends here.
; * HEAP   ...HEAPEND  60?????...60FFFFH: Symbol table, grows down. Populated in pass1.
; * HEAPEND...mem_end  60FFFFH...614046H: I/O buffers.
;
; Some code changes on the Linux i386 port:
;
; * ELF-32 headers have been added.
; * DOS 1.x detection and the -1 command-line flag has been removed.
; * `JMP $+5' has been changed to labels which autocompute the jump delta.
; * Parsing of command-line arguments have been rewritten.
; * Encoded instructions became longer, some jumps had to be changed to NEAR.
; * Changed memory size detection (always full 64 KiB).
; * Jumps based on function pointers have been extended to 4 bytes.
; * Alignment of some .bss variables has been changed to 4.
; * No `PUSH imm' instructions in the code, no direct SP access in the code,
;   good. Thus `CALL` works unchanged even if it pushes 4 bytes.
; * `LOOP to' instructions were analyzed and found that they are never called
;   when ECX == 0 (thus no change of ECX to -1), good.
; * The `XLAT` (same as `XLATB`) instruction has been replaced with a longer
;   sequence of instructions, because it has to use EBX+data_base instead of
;   EBX.
; * `PUSH` and `POP` instructions do registers only. Good.
; * Autogenerated filename extensions have been changed to lowercase.
; * The -p command-line flag (to send the output to the printer) has been
;   removed, because there is no common text printing API on Linux.
; * Effective addresses have been rewritten:
;   * `[LABEL]`, `[LABEL+CONST]`, `[LABEL-CONST]` was kept unchanged.
;   * `[DI]`, `[DI-CONST]`, `[SI]`, `[SI-CONST]` was changed by
;     replacing `SI` with `ESI` and `DI` with `EDI`. That's because ESI and
;     EDI already have `data_base` preadded.
;   * `[SI+BX]` was changed to `[ESI+EBX]`.
;   * `[SI+NDPTAB]` was changed to `[ESI+NDPTAB-data_base]`, because both ESI
;      and DNPTAB have `data_base` preadded.
;   * `[BX]`, `[BX+CONST]`, `[BX-CONST]` were chnged by replacing BX with
;     `EBX+data_base`.
;   * There were no other forms of effective address.
; * The Linux i386 port (asm244i) is about 21.7% larger than the improved
;   DOS port (asm244i.com), because most of the assembly instructions in the
;   Linux i386 port need size prefixes for the word-sized data.
; * Return-address-discarding `POP BX` and `POP CX` have been replaed with
;   `ADD ESP,BYTE 4`. The hidden assumption was that `POP reg` removes a
;   return address from the stack, but actually it was removing only half.
; * DOS I/O calls (INT 21H and INT 20H) have been replaced with Linux i386
;   system calls.
; * Command line parsing has been replaced with the Linux i386 ABI way.
; * Available memory detection has been hardwired to 64 KiB.
; * Added MOVSX+ADD for converting word-sized addresses to dword-sized
;   addresses. This limits the total code+data size to <32 KiB. That's fine,
;   it will remain less than 12 KiB.
; * Moved code and data outside the big 64 KiB, to save memory for assembly
;   computations.
;

; --- NASM compatibility by pts@fazekas.hu at Tue Nov 26 18:56:58 CET 2024
;
; Compile with: nasm-0.98.39 -w+orphan-labels -f bin -O0 -o asm244i asm244l.nasm && chmod +x asm244i
; It produces identical output with `nasm -O0' and `nasm -O999999999'.
;

bits 32
cpu 386
data_base equ 600000h  ; Must be divisible by 10000h, i.e. low word must be 0.
code1_size equ 2<<12  ; Must be divisible by 1000h. To save memory for assembly computations, this must be as large as possible.
org data_base-code1_size

; ELF-32 OSABI constants.
OSABI:
.SYSV: equ 0
.Linux: equ 3
.FreeBSD: equ 9

%ifndef NO_FREEBSD
  %define FREEBSD  ; See try_freebsd.sh for running it in FreeBSD guest in QEMU on Linux.
%endif

%ifdef FREEBSD
  %define Ehdr_OSABI OSABI.FreeBSD  ; The program works natively on both Linux i386 and FreeBSD i386.
%else
  %define Ehdr_OSABI OSABI.Linux  ; The program works natively on Linux i386, but not FreeBSD i386.
%endif

file_header:
Elf32_Ehdr:
	db 7Fh,'ELF',1,1,1,Ehdr_OSABI,0,0,0,0,0,0,0,0,2,0,3,0
	dd 1,_start,Elf32_Phdr-file_header,0,0
	dw Elf32_Phdr-file_header,20h,1,28h,0,0
Elf32_Phdr:
	dd 1,0,$$,0,BSS0-$$,mem_end-$$,7,1000h

; Like DB, but flip the highest bit of the last byte.
; This was really undocumented, the source had to be reverse engineered.
; DM 'hello' is equivalent to: db 'hell', 'o'|80h
; We do it by separating the last byte, e.g.: DM 'he', 'll', 'o'
%macro DM 2
  db %1
  db (%2)|80h
%endm
%macro DM 3
  db %1
  DM %2, %3
%endm
%macro DM 4
  db %1, %2
  DM %3, %4
%endm
%macro DM 5
  db %1, %2, %3
  DM %4, %5
%endm
%macro DM 6
  db %1, %2, %3, %4
  DM %5, %6
%endm
%macro DM 7
  db %1, %2, %3, %4, %5
  DM %6, %7
%endm
%macro DM 8
  db %1, %2, %3, %4, %5, %6
  DM %7, %8
%endm

%macro ALIGN 0
align 2
%endm

%macro DS 1
  times %1 db 0
%endm

%macro JMPS 1
  jmp short %1
%endm

%macro JP 1
  jmp short %1
%endm

%macro UP 0  ; Convert AL to upprecase?
  cld
%endm

%macro RCL 1
  rcl %1, 1
%endm

%macro RCR 1
  rcr %1, 1
%endm

%macro SHL 1
  shl %1, 1
%endm
%macro SHL 2
  shl %1, %2
%endm

%macro SHR 1
  shr %1, 1
%endm
%macro SHR 2
  shr %1, %2
%endm

%macro ROL 1
  rol %1, 1
%endm

%macro DIV 2
  div %2
%endm

%macro MUL 2
  mul %2
%endm

%macro XLAT 0
  ; If we were allowed to change AH to 0, this would be shorter:
  ;   mov ah, 0
  ;   mov al, [data_base+eax+ebx]  ; This assumes that the high 3 bytes of EAX is 0, and the high word of EBX is 0.
  lea ebx, [ebx+data_base]
  db 0d7h  ; Original XLAT instruction.
  lea ebx, [ebx-data_base]
%endm

%define LODB lodsb
%define LODW lodsw
%define MOVB movsb
%define MOVW movsw
%define MOVD movsd
%define SCAB scasb
%define SCAW scasw
%define CMPB cmpsb
%define CMPW cmpsw
%define STOB stosb
%define STOW stosw
%define STOD stosd

%macro check_align_2 0
  times -(($$-$)&1) db 0  ; Check that $ is aligned to 2.
%endm

%macro bss_check_align_2 0
  times -(($$-($+BSS-BSS0))&1) db 0  ; Check that $ within .bss is aligned to 2.
%endm
%macro bss_check_align_4 0
  times -(($$-($+BSS-BSS0))&3) db 0  ; Check that $ within .bss is aligned to 4.
%endm

%macro bssvar 2
  %1:	equ $+BSS-BSS0  ; Start .bss variable earlier, near the start of USAGE.
  resb %2
%endm

%macro bss_align 1
  resb ($$-($+BSS-BSS0)) & ((%1)-1)
%endm

; ---

; Linux open(2) flags constants.
O_RDONLY equ 0
O_WRONLY equ 1
O_RDWR equ 2
O_CREAT equ 100o
O_TRUNC equ 1000o

HEAPENDVAL: EQU	0FFFFH	;Memory address of the end of the heap.
SYMWID:	EQU	5	;5 symbols per line in dump
SRCBUFSIZ: EQU	01000H	;Source code (.asm) file buffer.
LSTBUFSIZ: EQU	SRCBUFSIZ  ;Listing (.lst) file buffer.
CONBUFSIZ: EQU	SRCBUFSIZ  ;Console (stdout) buffer.
BINBUFSIZ: EQU	SRCBUFSIZ  ;.bin file buffer.
HEXBUFSIZ: EQU	70	;.hex file buffer (26*2 + 5*2 + 3 + EXTRA). It is flushed for each line.
EOL:	EQU	13	;ASCII carriage return
OBJECT:	EQU	100H	;DEFAULT "PUT" ADDRESS
MAXEXPRSTACKSIZ: EQU 18000  ;Maximum amount of stack space used by the outermost `CALL EXPRESSION'. This value is arbitrary, Linux typically has megabytes of stack.

;The following equates define some token values returned by GETSYM
UNDEFID:EQU	0	;Undefined identifier (including no nearby RET)
CONST:	EQU	1	;Constant (including $)
REG:	EQU	2	;8-bit register
XREG:	EQU	3	;16-bit register (except segment registers)
SREG:	EQU	4	;Segment register
FREG:	EQU	6	;8087 floating point register

;Bits to build 8087 opcode table entries
ONEREG:	EQU	40H	;Single ST register OK as operand
NEEDOP:	EQU	80H	;Must have an operand
INTEGER:EQU	20H	;For integer operations
REAL:	EQU	28H	;For real operations
EXTENDED EQU	10H	;For Long integers or Temporary real
MEMORY:	EQU	18H	;For general memory operations
STACKOP:EQU	10H	;Two register arithmetic with pop
ARITH:	EQU	8	;Non-pop arithmetic operations

HFLAG:	EQU	1	;-h flag specified: generate Intel HEX file (.hex)
NFLAG:	EQU	2	;-s flag specified: generate symbol listing
SFLAG:	EQU	4	;-n flag specified: generate instructions understood by ndisasm(1)
XFLAG:	EQU	8	;-x flag specified: emit X instead of NUL for DS bytes
PFLAG:	EQU	0x10	;-p flag specified: do not assume initial PUT 100H+DB

;STATE bitmask values.
STHASHEXADD: EQU 1
STHASORG: EQU 2

HEADER:	DB	'Seattle Computer Products 8086 Assembler Version 2.44pts1'
	DB	13,10,'Copyright 1979-1983 by Seattle Computer Products, Inc.'
	DB	13,10,13,10,'$'

%ifdef FREEBSD
DOSYSCALL:
;Do a Linux or FreeBSD i386 syscall.
;Input: EAX: Linux i386 syscall number; EBX: arg1, ECX: arg2; EDX: arg3.
;Output: EAX: negative on failure, nonnegative value on success.
;Ruins: flags.
;
;The syscall number in EAX must be 1 (SYS_exit), 3 (SYS_read), 4
;(SYS_write), 5 (SYS_open) or 6 (SYS_close). This is unchecked.
	CMP	BYTE [ISFREEBSD],0
	JNE	FREEBSDCALL
	INT	80H		;Linux i386 syscall.
	RET
FREEBSDCALL:
	PUSH	ECX		;Save.
	CMP	AL,5		;SYS_open.
	JNE	FREEBSDCALLDONEOPEN
	CMP	CX,O_WRONLY|O_CREAT|O_TRUNC  ; Linux (O_WRONLY | O_CREAT | O_TRUNC) == (1 | 0100o | 01000) == 01101.
	JNE	FREEBSDCALLDONEOPEN
	MOV	CX,601H  ; FreeBSD (O_WRONLY | O_CREAT | O_TRUNC) == (1 | 0x200 | 0x400) == 0x601.
FREEBSDCALLDONEOPEN:
	PUSH	EDX		;arg3.
	PUSH	ECX		;arg2.
	PUSH	EBX		;arg1.
	PUSH	EAX		;Fake return address.
	INT	80H		;FreeBSD i386 syscall.
	LEA	ESP,[ESP+4*4]	;Clean up stack without modifying flags.
	POP	ECX		;Restore.
	JNC	FREEBSDCALLRET
	SBB	EAX,EAX		;EAX := -1. Any negative value indicates error.
FREEBSDCALLRET:
	RET
  %macro SYSCALL 0
	CALL	DOSYSCALL	;Linux and FreeBSD i386 syscall.
  %endm
%else
  %macro SYSCALL 0
	INT	80H		;Linux i386 syscall.
  %endm
%endif

PUTCHAR:
;Print a single byte in AL to the stdout buffer.
	PUSH	EDX
	MOV	DX,[CONPNT]
	CMP	DX,CONBUFSIZ
	JNE	CONFLUSHED
	CALL	FLUSHCON
CONFLUSHED:
	MOV	[EDX+CONBUF],AL
	INC	WORD [CONPNT]
	POP	EDX
	RET

FLUSHCON:
;Flush stdout to file descriptor 1. Also sets DX := 0.
	PUSH	EAX		;Save.
	PUSH	EBX		;Save.
	PUSH	ECX		;Save.
	PUSH	BYTE 4		;SYS_write.
	POP	EAX
	XOR	EBX,EBX
	INC	EBX		;STDOUT_FILENO.
	MOV	ECX,CONBUF
	MOV	DX,[CONPNT]	;It's also OK to write 0 bytes.
	SYSCALL			;Linux or FreeBSD i386 syscall.
	POP	ECX		;Restore.
	POP	EBX		;Restore.
	POP	EAX		;Restore.
	XOR	EDX,EDX
	MOV	[CONPNT],DX
	RET

PRINTMSGD:
;Print dollar-terminated message to stdout.
;It works even if all registers except for DX are uninitialized.
;Input: DX: pointer to message.
;This function ignores the stdout buffer (CONBUF). There is no other way,
;[CONPNT] needs .bss, but we need PRINTMSGD before .bss.
	PUSHA
	PUSH	BYTE 4		;SYS_write.
	POP	EAX
	XOR	EBX,EBX
	INC	EBX		;STDOUT_FILENO.
	MOVSX	ECX,DX
	ADD	ECX,data_base
	OR	EDX,BYTE-1
.NEXT:	INC	EDX
	CMP	BYTE [ECX+EDX],'$'
	JNE	.NEXT
	SYSCALL			;Linux or FreeBSD i386 syscall.
	POPA
	RET

%if 0  ; Disabled, because it is used for debugging only.
PRINTMSGEZ:
;Print dollar-terminated message to stdout.
;It works even if all registers except for EDX are uninitialized.
;Input: EDX: pointer to message.
	PUSHA
	PUSH	BYTE 4		;SYS_write.
	POP	EAX
	XOR	EBX,EBX
	INC	EBX		;STDOUT_FILENO.
	MOV	ECX,EDX
	OR	EDX,BYTE-1
.NEXT:	INC	EDX
	CMP	BYTE [ECX+EDX],0
	JNE	.NEXT
	SYSCALL			;Linux or FreeBSD i386 syscall.
	POPA
	RET
%endif

FFOPENSRC:
;Open the source file.
;Ruins: AX, BX, DX, SI, DI. Actually, it doesn't ruin AX, BX, DX, SI or DI.
	PUSH	EAX		;Save so that the high word can be restored.
	PUSH	EBX		;Save so that the high word can be restored.
	PUSH	ECX		;Save.
	MOV	EAX,[SRCEXTSAVE]
	MOV	EBX,[SRCEXT]
	MOV	[EBX],EAX	;Restore extension (and trailing NUL if needed).
	PUSH	BYTE 5		;SYS_open.
	POP	EAX
	MOV	EBX,[SRCFN]
	PUSH	BYTE O_RDONLY
	POP	ECX
	SYSCALL			;Linux or FreeBSD i386 syscall.
	MOV	[SRCFD],EAX	;Save file descriptor.
	TEST	EAX,EAX
	POP	ECX		;Restore.
	POP	EBX		;Restore for the high word.
	POP	EAX		;Restore for the high word.
	JS	FFOPENERR
RET23:	RET
FFOPENERR:
	MOV	DX,NOFILE
	JP	PRERRD

FFCREATE:
;Inputs: DX: address of destination file descriptor; AX: first 2 characters of .ext; CL: last character of .ext.
;Ruins: AX, BX, DX, SI, DI. Actually, it doesn't ruin AX, BX, DX, SI or DI.
	PUSH	EAX		;Save so that the high word can be restored.
	PUSH	EBX		;Save so that the high word can be restored.
	PUSH	ECX		;Save.
	MOV	EBX,[SRCEXT]
	MOV	CH,0		;Terminating NUL.
	SHL	ECX,16
	OR	EAX,ECX
	MOV	[EBX],EAX	;Change the extension to AX+CL. Also NUL-terminate it.
	PUSH	BYTE 5		;SYS_open.
	POP	EAX
	MOV	EBX,[SRCFN]
	MOV	ECX,O_WRONLY|O_CREAT|O_TRUNC
	PUSH	EDX		;Save.
	MOV	DX,666q
	SYSCALL			;Linux or FreeBSD i386 syscall.
	POP	EDX		;Restore.
	MOV	[EDX+data_base],EAX  ;Save file descriptor.
	TEST	EAX,EAX
	POP	ECX		;Restore.
	POP	EBX		;Restore for the high word.
	POP	EAX		;Restore for the high word.
	JS	FFCREATERR
RET1:	RET
FFCREATERR:
	MOV	DX,NOSPAC
	JP	PRERRD

FFCLOSE:
;Inputs: BX: pointer to file descriptor.
;Ruins: AX, BX and CF. Actually, it doesn't ruin BX.
	PUSH	EBX		;Save so that the high word can be restored.
	PUSH	BYTE 6		;SYS_close.
	POP	EAX
	MOV	EBX,[EBX+data_base]
	SYSCALL			;Linux or FreeBSD i386 syscall.
	POP	EBX		;Restore for the high word.
	RET

EXUSAGE:
	MOV	DX,USAGE
	JP	PRERRD
ABORT:	MOV	DX,NOMEM
PRERRD:	CALL	PRINTMSGD
	JMP	NEAR EXERR

FFREADSRCNUL:
;Reads SRCBUFSIZ bytes from the file [SRCFD] to [SRCBUF+...]. Upon a short
;read, it adds a terminating NUL.
;Inputs: none. Ruins: flags.
	PUSH	EAX		;Save.
	PUSH	EBX		;Save.
	PUSH	ECX		;Save.
	PUSH	EDX		;Save.
	PUSH	BYTE 3		;SYS_read.
	POP	EAX
	MOV	EBX,[SRCFD]	;Get file descriptor.
	MOV	ECX,SRCBUF
	MOV	EDX,SRCBUFSIZ
	SYSCALL			;Linux or FreeBSD i386 syscall.
	TEST	EAX,EAX
	JS	FFREADERR
	CMP	EAX,EDX
	POP	EDX		;Restore.
	POP	ECX		;Restore.
	POP	EBX		;Restore.
	JE	FFREADDONE
	MOV	BYTE [SRCBUF+EAX], 0  ;Write sentinel teminating NUL byte on short read.
FFREADDONE:
	POP	EAX		;Restore.
	RET
FFREADERR:
	MOV	DX,RDERR
	JP	PRERRD

FFWRITED:
;Inputs: BX: pointer to file descriptor; ECX: data to read to; DX: number of bytes to write (must be nonzero).
;Ruins: AX, CF and DX. Keeps BX. Actually, it doesn't ruin DX.
	TEST	DX,DX
	JZ	FFWRITERET	;Just a speed optimization.
	PUSH	EBX
	PUSH	BYTE 4		;SYS_write.
	POP	EAX
	MOV	EBX,[EBX+data_base]  ; Get file descriptor.
	SYSCALL			;Linux or FreeBSD i386 syscall.
	POP	EBX
	TEST	EAX,EAX
	JS	FFWRITEERR
FFWRITERET:
	RET
FFWRITEERR:
	MOV	DX,WRTERR
	JP	PRERRD

FFRELSEEK:
;Inputs: BX: pointer to file descriptor; EDX: relative number of bytes to seek.
;Ruins: AX and CF.
	TEST	EDX,EDX
	JZ	FFWRITERET	;Just a speed optimization.
	PUSH	EBX
	PUSH	ECX
	PUSH	EDX
	MOV	EBX,[EBX+data_base]  ; Get file descriptor.
	MOV	ECX,EDX
	PUSH	BYTE 1		;SEEK_CUR.
	POP	EDX
%ifdef FREEBSD
	CMP	BYTE [ISFREEBSD],0
	JNE	FFRELSEEKFREEBSD
%endif
	PUSH	BYTE 19		;SYS_lseek.
	POP	EAX
	INT	80H		;Linux i386 syscall.
FFRELSEEKDONE:
	POP	EDX
	POP	ECX
	POP	EBX
	TEST	EAX,EAX
	JS	FFWRITEERR
	RET
%ifdef FREEBSD
FFRELSEEKFREEBSD:
	PUSH	EDX		;Argument whence of lseek and sys_freebsd6_lseek.
	XCHG	EAX,ECX
	CDQ			;Sign-extend EAX (32-bit offset) to EDX:EAX (64-bit offset).
	XCHG	EAX,ECX
	PUSH	EDX		;High dword of argument offset of sys_freebsd6_lseek.
	PUSH	ECX		;Low dword of argument offset of lseek and sys_freebsd6_lseek.
	PUSH	EAX		;Dummy argument pad of sys_freebsd6_lseek.
	PUSH	EBX		;Argument fd of lseek and sys_freebsd6_lseek.
	PUSH	EAX		;Dummy return address.
	XOR	EAX,EAX
	MOV	AL,199		;FreeBSD __NR_freebsd6_lseek (also available in FreeBSD 3.0, released on 1998-10-16), with 64-bit offset.
	INT	80H		;FreeBSD i386 syscall.
	JC	FFWRITEERR
	ADD	ESP,BYTE 6*4	;Clean up arguments of sys_freebsd6_lseek(...) above from the stack.
	JP	FFRELSEEKDONE
%endif

_start:
BEGIN:
%ifdef FREEBSD  ; Detect FreeBSD.
	PUSH	BYTE 20		;EAX := SYS_getpid for both Linux and FreeBSD.
	POP	EAX
	STC			;CF := 1.
	INT	80H		;Linux or FreeBSD i386 syscall, for system detection.
	SBB	EAX,EAX		;FreeBSD set s CF := 0 on success, Linux keeps it intact (== 1). EAX := 0 in FreeBSD, -1 on Linux.
	INC	EAX		;EAX := 1 in FreeBSD, 0 on Linux.
	MOV	[ISFREEBSD],AL
%endif
	MOV	DX,HEADER
	CALL	PRINTMSGD
	POP	EBX		;Ignore argc.
	POP	EBX		;EBX := argv[0].
	TEST	EBX,EBX
	JZ	EXUSAGE		;If no argv[0], print usage and fail.
	POP	EBX		;EBX := argv[1].
	TEST	EBX,EBX
	JZ	EXUSAGE		;If no argv[1], print usage and fail.
	POP	ESI		;ESI := argv[2].
	TEST	ESI,ESI
	JZ	NOFLAGARG
	POP	ECX		;ECX := argv[3].
	TEST	ECX,ECX
	JNZ	EXUSAGE		;If argv[2], print usage and fail.
	JP	AFTERFLAGARG
NOFLAGARG:
	MOV	ESI,NUL
AFTERFLAGARG:
	; Now: EBX points to the source file name, ESI points to flags (not NULL).
	XOR	EDX,EDX  ; DH will be BYTE [LSTDEV] (default: no .lst file): DL will be BYTE [FLAGS] (default : no flags).
NEXTFLAG:
	LODB
	CMP	AL,0
	JE	AFTERFLAGS
	CMP	AL,"-"
	JE	NEXTFLAG
	AND	AL,~20H		;Convert to uppercase for DOS >=2.0.
	CMP	AL,"L"
	JNE	ALFLAG
	MOV	DH,80H
	JP	NEXTFLAG
ALFLAG:	CMP	AL,"C"
	JNE	ACFLAG
	MOV	DH,2
	JP	NEXTFLAG
ACFLAG:	CMP	AL,"H"
	JNE	AHFLAG
	OR	DL,HFLAG
	JP	NEXTFLAG
AHFLAG:	CMP	AL,"N"
	JNE	AXFLAG
	OR	DL,NFLAG
	JP	NEXTFLAG
AXFLAG:	CMP	AL,"X"
	JNE	APFLAG
	OR	DL,XFLAG
	JP	NEXTFLAG
APFLAG:	CMP	AL,"P"
	JNE	ANFLAG
	OR	DL,PFLAG
	JP	NEXTFLAG
ANFLAG:	CMP	AL,"S"
	JNE	EXUSAGE
	OR	DL,SFLAG	;Save symbol table request flag.
	JP	NEXTFLAG
AFTERFLAGS:
	XOR	EAX,EAX
	MOV	EDI,BSS
	MOV	ECX,(BSS1-BSS+3)>>2
	REP
	STOD			;Initialize .bss to NUL. We can't do it earlier, because above we still needed USAGE.
	OR	WORD [HEAP],BYTE -1  ;All the way to end of the 64 KiB. For easier rounding, we don't use the last byte. BACK END OF SYMBOL TABLE SPACE. Will grow downward. Also sets CX := 0 (we need it later).
	MOV	[FLAGS],DX	;Modifies BYTE [FLAGS] and BYTE [LSTDEV].
	; Now: EBX points to the source filename; ECX and EAX are 0.
	;
	; We copy the the source filename onto the stack to make room for 4
        ; bytes of filename extension, and we append the .asm extension as a
	; default.
	DEC	ECX
	INC	ECX
SRCFNSCANNEXT:
	INC	ECX
	CMP	BYTE [EBX+ECX],0
	JNE	SRCFNSCANNEXT
	LEA	EDX,[ECX+4+3]
	AND	EDX,BYTE ~3
	SUB	ESP,EDX
	MOV	[STACKEND],ESP	;Also sets DWORD [SRCFN] to ESP.
	MOV	ESI,EBX
	MOV	EDI,ESP
	XOR	EBX,EBX		;EBX will point after the last dot, or (initially) NULL.
NEXTEXTCHR:
	LODB
	STOB
	CMP	AL,0
	JE	NEXTEXTEND
	CMP	AL,'/'
	JE	NEXTEXTBS
	CMP	AL,'.'
	JNE	NEXTEXTCHR
	MOV	EBX,EDI		;Save position after the last dot.
	JP	NEXTEXTCHR
NEXTEXTBS:
	XOR	EBX,EBX		;Forget the previous dot.
	JP	NEXTEXTCHR
NEXTEXTEND:
	TEST	EBX,EBX
	JNZ	HASDOT
	MOV	EBX,EDI
	DEC	EDI		;Skip over the terminating NUL backwards.
	; We may overwrite the 2nd argument and also the first few bytes of
	; code (at 100H), but that's all fine.
	MOV	EAX,'.'|('a'<<8)|('s'<<16)|('m'<<24)
	STOD
	MOV	AL,0
	STOB			;NUL-terminate the filename.
HASDOT:	; Now: CX points to the NUL-terminated source filename, with extension.
	; Now: BX points to the extension in the NUL-terminated source filename, after the dot.
	MOV	[SRCEXT],EBX
	MOV	EAX,[EBX]
	MOV	[SRCEXTSAVE],EAX  ;Save 4 bytes of the original extension, for the reopening with FFOPENSRC.

	; Set final value of high words of all registers except for ESP.
	;
	; EDI and ESI will have their high word same as data_base; EAX,
	; EBX, ECX, EDX and EBP will have their high word set to 0. This
	; arrangement will make all of these work: string instructions (e.g.
	; LODSB), effective addresses changed like this:
        ; * `[LABEL]`, `[LABEL+CONST]`, `[LABEL-CONST]` was kept unchanged.
        ; * `[DI]`, `[DI-CONST]`, `[SI]`, `[SI-CONST]` was changed by
        ;   replacing `SI` with `ESI` and `DI` with `EDI`. That's because ESI and
        ;   EDI already have `data_base` preadded.
        ; * `[SI+BX]` was changed to `[ESI+EBX]`.
        ; * `[SI+NDPTAB]` was changed to `[ESI+NDPTAB-data_base]`, because both ESI
        ;    and DNPTAB have `data_base` preadded.
        ; * `[BX]`, `[BX+CONST]`, `[BX-CONST]` were chnged by replacing BX with
        ;   `EBX+data_base`.
        ; * There were no other forms of effective address.
	MOV	EDI,data_base
	MOV	ESI,EDI
	XOR	EAX,EAX
	XOR	EBX,EBX
	XOR	ECX,ECX
	XOR	EDX,EDX
	XOR	EBP,EBP

%if 0  ; For debugging.
	PUSH	EDX		;Save so that the high word can be restored.;
	MOV	EDX,[SRCFN]
	CALL	PRINTMSGEZ
	POP	EDX		;Restore for the high word.
	MOV	AL,13
	CALL	PUTCHAR
	MOV	AL,10
	CALL	PUTCHAR
	;
	PUSH	EDX		;Save so that the high word can be restored.;
	MOV	EDX,[SRCEXT]
	CALL	PRINTMSGEZ
	POP	EDX		;Restore for the high word.
	MOV	AL,13
	CALL	PUTCHAR
	MOV	AL,10
	CALL	PUTCHAR
	JMP	EXITOK
%endif

	CALL	FFOPENSRC
	;XOR	AX,AX
	;MOV	[FCB+12],AX	;Zero CURRENT BLOCK field. Not used on Linux.
	;MOV	[FCB+32],AL	;Zero Next Record field. Not used on Linux.
	;MOV	WORD [FCB+14],SRCBUFSIZ	;Set record size. Not used on Linux.
	;MOV	WORD [BUFPT],SRCBUFSIZ	;Initialize buffer pointer. Already initialized.
	;MOV	WORD [CODE],START+1	;POINTER TO NEXT BYTE OF INTERMEDIATE CODE. Already initialized.
	;MOV	WORD [IY],START	;POINTER TO CURRENT FIXUP BYTE. Already initialized.
	;MOV	[PC],AX		;DEFAULT PROGRAM COUNTER. Initialized above as part of BSS.
	;MOV	[BASE],AX	;POINTER TO ROOT OF ID TREE=NIL. Initialized above as part of BSS.
	;MOV	[RETPT],AX	;Pointer to last RET record. Initialized above as part of BSS.
	;MOV	[IFFLG],AL	;NOT WITHIN IF/ENDIF. Initialized above as part of BSS.
	;MOV	[CHKLAB],AL	;LOOKUP ALL LABELS. Initialized above as part of BSS.
	;DEC	AX
	;MOV	WORD [LSTRET],-1  ;Location of last RET. Already initialized.
	;MOV	WORD [BCOUNT],4	;CODE BYTES PER FIXUP BYTE. Already initialized.

;Assemble each line of code

$LOOP:
	CALL	NEXTCHR		;Get first character on line
	CMP	AL,1AH
	JZ	ENDJ
	MOV	AL,-1		;Flag that no tokens have been read yet
	MOV	[SYM],AL
	CALL	ASMLIN		;Assemble the line
	MOV	AL,[SYM]
	CMP	AL,-1		;Any tokens found on line?
	JNZ	L0002
	CALL	GETSYM		;If no tokens read yet, read first one
L0002:	
	CMP	AL,';'
	JZ	ENDLN
	CMP	AL,EOL
	JZ	ENDLN
	MOV	AL,14H		;Garbage at end of line error
	JP	ENDLIN
ENDJ:	JMP	END

ENDLN:
	XOR	AL,AL		;Flag no errors on line
ENDLIN:
;AL = error code for line. Stack depth unknown
	MOV	ESP,[STACKEND]	; Clean up stack.
	CALL	NEXLIN
	JP	$LOOP

NEXLIN:
	MOV	CH,0C0H		;Put end of line marker and error code (AL)
	CALL	PUTCD
	CALL	GEN1
	MOV	AL,[CHR]
GETEOL:
	CMP	AL,10
	JZ	RET23
	CMP	AL,1AH
	JZ	ENDJ
	CALL	NEXTCHR		;Scan over comments for linefeed
	JP	GETEOL

ERROR:
	MOV	AL,CL
	JMP	NEAR ENDLIN

NEXTCHR:
;Read a character (byte) from the assebly source file, but use up bytes in
;UNGET first. Return it in AL, and also set BYTE [CHR] to AL.
;
;Ruins: SI.
;Keeps: AH, BX, CX, DX, DI (maybe not needed).
	MOV	SI,[UNGETP]
	CMP	SI,UNGET
	JE	NEXTCHRZ
	DEC	SI
	MOV	[UNGETP],SI
	LODB
	JP	GOTCHR

NEXTCHRZ:
;Read a character (byte) from the assebly source file, but use up bytes in
;UNGET first. Return it in AL, and also set BYTE [CHR] to AL.
;
;Ruins: SI.
;Keeps: AH, BX, CX, DX, DI (maybe not needed).
;
;The extra code between NEXTCHRZ and NEXTCHRLOW implements the `more relaxed
;input' feature. As a side effect, an indication of an empty line is added
;to the .lst file. This is also useful for indicating the address past the
;last byte.
;
;Also since of the improvements take up a few hundred bytes of memory, the
;`Free space' value indicated in the .lst file is a few hundred bytes less.
	XCHG	AH,[NEXTCHRSTATE]
	MOV	AL,AH		;For shorter comparisons in `CMP AL,...' below.
	CMP	AL,0
	JE	NEXTCHR1	;This is the typical case.
	CMP	AL,2
	JNE	TRY3
	MOV	AX,(1AH<<8)|10	;Insert the 10 in front of the 1AH.
	JP	GOTCHP
TRY3:	CMP	AL,1AH
	JE	GOTCHP		;Return the 1AH to indicate EOF, stay in EOF state.
	CMP	AL,4
	JNE	TRY5
	MOV	AX,(5<<8)|10	;Insert the LF after the CR.
	JP	GOTCHP
TRY5:	CMP	AL,5
	JE	AFTLF
	MOV	AX,(0<<8)|10	;Assuming AL == AH == 7, insert the LF.
	JP	GOTCHP
AFTLF:	CALL	NEXTCHRLOW
	CMP	AL,10
	JNE	NEXTAL		;Otherwise, ignore LF after CR on input.
NEXTCHR1:  ; Now: AH == 0.
	CALL	NEXTCHRLOW
NEXTAL:  ; Now: AH == 0.
	CMP	AL,1AH		;EOF with 1AH.
	JE	NEXTE
	CMP	AL,0		;EOF with NUL.
	JNE	NOTXE
NEXTE:	MOV	AX,(2<<8)|13	;Will insert CR and LF in front of the 1AH.
	JP	GOTCHP
NOTXE:	CMP	AL,13
	JNE	NOTCR
	MOV	AH,4		;Will insert LF after the CR.
	JP	GOTCHP
NOTCR:	CMP	AL,10
	MOV	AH,0
	JNE	GOTCHP
	MOV	AX,(7<<8)|13	;Insert a CR first.
GOTCHP:	XCHG	AH,[NEXTCHRSTATE]  ;Also restores previous AH.
GOTCHR:	MOV	[CHR],AL
RET2:	RET
	
NEXTCHRLOW:
	MOV	SI,[BUFPT]
	CMP	SI,SRCBUFSIZ
	JNE	NEXTCHRSHIFT
	; Buffer empty so refill it.
	;MOV	BYTE [SRCBUF], 0  ;Set up sentinel NUL to indicate EOF. No need, FFREADSRCNUL already does it.
	CALL	FFREADSRCNUL	;AH must be retained here.
	; Actually, AL=1 for EOF, AL=3 for a partial read. Then SRCBUF will be NUL-padded, and there is no way to get the actual byte size.
	XOR	SI,SI
NEXTCHRSHIFT:
	MOV	AL,[ESI+SRCBUF-data_base]
	INC	ESI		;`INC SI', but shorter. It won't overflow here.
	MOV	[BUFPT],SI
	JP	GOTCHR		;And return.

MROPS:

; Get two operands and check for certain types, according to flag byte
; in CL. OP code in CH. Returns only if immediate operation.

	PUSH	CX		;Save type flags
	CALL	GETOP
	PUSH	DX		;Save first operand
	CALL	GETOP2
	POP	BX		;First op in BX, second op in DX
	MOV	AL,SREG		;Check for a segment register
	CMP	AL,BH
	JZ	SEGCHK
	CMP	AL,DH
	JZ	SEGCHK
	MOV	AL,CONST	;Check if the first operand is immediate
	MOV	CL,26
	CMP	AL,BH
	JZ	ERROR		;Error if so
	POP	CX		;Restore type flags
	CMP	AL,DH		;If second operand is immediate, then done
	JZ	RET2
	MOV	AL,UNDEFID	;Check for memory reference
	CMP	AL,BH
	JZ	STORE		;Is destination memory?
	CMP	AL,DH
	JZ	LOAD		;Is source memory?
	TEST	CL,1		;Check if register-to-register operation OK
	MOV	CL,27
	JZ	ERROR
	MOV	AL,DH
	CMP	AL,BH		;Registers must be of same length
RR:
	MOV	CL,22
	JNZ	ERROR
RR1:
	AND	AL,1		;Get register length (1=16 bits)
	OR	AL,CH		;Or in to OP code
	CALL	$PUT		;And write it
	ADD	ESP,BYTE 4	;Discard return address.
	MOV	AL,BL
	ADD	AL,AL		;Rotate register number into middle position
	ADD	AL,AL
	ADD	AL,AL
	OR	AL,0C0H		;Set register-to-register mode
	OR	AL,DL		;Combine with other register number
	JMP	$PUT

SEGCHK:
;Come here if at least one operand is a segment register
	POP	CX		;Restore flags
	TEST	CL,8		;Check if segment register OK
	MOV	CL,22
	JZ	NEAR ERR1
	MOV	CX,8E03H	;Segment register move OP code
	MOV	AL,UNDEFID
	CMP	AL,DH		;Check if source is memory
	JZ	LOAD
	CMP	AL,BH		;Check if destination is memory
	JZ	STORE
	MOV	AL,XREG
	SUB	AL,DH		;Check if source is 16-bit register
	JZ	RR		;If so, AL must be zero
	MOV	CH,8CH		;Change direction
	XCHG	BX,DX		;Flip which operand is first and second
	MOV	AL,XREG
	SUB	AL,DH		;Let RR perform finish the test
	JP	RR

STORE:
	TEST	CL,004H		;Check if storing is OK
	JNZ	STERR
	XCHG	BX,DX		;If so, flip operands
	AND	CH,0FDH		;   and zero direction bit
LOAD:
	MOV	DH,25
	CMP	AL,BH		;Check if memory-to-memory
	JZ	MRERR
	MOV	AL,BH
	CMP	AL,REG		;Check if 8-bit operation
	JNZ	XRG
	MOV	DH,22
	TEST	CL,1		;See if 8-bit operation is OK
	JZ	MRERR
XRG:
	MOV	AL,DL
	SUB	AL,6		;Check for R/M mode 6 and register 0
	OR	AL,BL		;   meaning direct load/store of accumulator
	JNZ	NOTAC
	TEST	CL,8		;See if direct load/store of accumulator
	JZ	NOTAC		;   means anything in this case
; Process direct load/store of accumulator
	MOV	AL,CH
	AND	AL,2		;Preserve direction bit only
	XOR	AL,2		;   but flip it
	OR	AL,0A0H		;Combine with OP code
	MOV	CH,AL
	MOV	AL,BH		;Check byte/word operation
	AND	AL,1
	OR	AL,CH
	ADD	ESP,BYTE 4	;Discard return address.
	JMP	PUTADD		;Write the address

NOTAC:
	MOV	AL,BH
	AND	AL,1		;Get byte/word bit
	AND	AL,CL		;But don't use it in word-only operations
	OR	AL,CH		;Combine with OP code
	CALL	$PUT
	MOV	AL,BL
	ADD	AL,AL		;Rotate to middle position
	ADD	AL,AL
	ADD	AL,AL
	OR	AL,DL		;Combine register field
	ADD	ESP,BYTE 4	;Discard return address.
	JMP	PUTADD		;Write the address

STERR:
	MOV	DH,29
MRERR:
	MOV	CL,DH

ERR1:	JMP	ERROR

GETOP2:
;Get the second operand: look for a comma and drop into GETOP
	MOV	AL,[SYM]
	CMP	AL,','
	MOV	CL,21
	JNZ	ERR1


GETOP:

; Get one operand. Operand may be a memory reference in brackets, a register,
; or a constant. If a flag (such as "B" for byte operation) is encountered,
; it is noted and processing continues to find the operand.
;
; On exit, AL (=DH) has the type of operand. Other information depends
; on the actual operand:
;
; AL=DH=0  Memory Reference.  DL has the address mode properly prepared in
; the 8086 R/M format (middle bits zero). The constant part of the address
; is in ADDR. If an undefined label needs to be added to this, a pointer to
; its information fields is in ALABEL, otherwise ALABEL is zero.
;
; AL=DH=1  Value. The constant part is in DATA. If an undefined label needs
; to be added to this, a pointer to its information fields is in DLABEL,
; otherwise DLABEL is zero. "$" and "RET" are in this class.
;
; AL=DH=2  8-bit Register. DL has the register number.
;
; AL=DH=3  16-bit Register. DL has the register number.
;
; AL=DH=4  Segment Register. DL has the register number.

	CALL	GETSYM
GETOP1:
;Enter here if we don't need a GETSYM first
	CMP	AL,'['		;Memory reference?
	JZ	MEM
	CMP	AL,5		;Flag ("B", "W", etc.)?
	JZ	FLG
	CMP	AL,REG		;8-Bit register?
	JZ	NREG
	CMP	AL,XREG		;16-Bit register?
	JZ	NREG
	CMP	AL,SREG		;Segment register?
	JZ	NREG
VAL:				;Must be immediate
	XOR	AL,AL		;No addressing modes allowed
VAL1:
	CALL	GETVAL
	MOV	AX,[CON]	;Defined part
	MOV	[DATA],AX
	MOV	AX,[UNDEF]	;Undefined part
	MOV	[DLABEL],AX
	MOV	DL,CH
	MOV	DH,CONST
	MOV	AL,DH
	RET
NREG:
	PUSH	DX
	CALL	GETSYM
	POP	DX
	MOV	AL,DH
	RET
MEM:
	CALL	GETSYM
	MOV	AL,1
	CALL	GETVAL
	MOV	AL,[SYM]
	CMP	AL,']'
	MOV	CL,24
	JNZ	ERR1
	CALL	GETSYM
	MOV	BX,[CON]
	MOV	[ADDR],BX
	MOV	BX,[UNDEF]
	MOV	[ALABEL],BX
	MOV	DL,CH
	MOV	DH,UNDEFID
	MOV	AL,DH
RET21:	RET
FLG:
	CMP	DL,[MAXFLG]	;Invalid flag for this operation?
	MOV	CL,27H
	JG	ERR1
	CALL	GETSYM
	CMP	AL,','
	JZ	GETOP
	JMP	GETOP1

GETVAL:

; Expression analyzer. On entry, if AL=0 then do not allow base or index
; registers. If AL=1, we are analyzing a memory reference, so allow base
; and index registers, and compute addressing mode when done. The constant
; part of the expression will be found in CON. If an undefined label is to
; be added to this, a pointer to its information fields will be found in
; UNDEF.

	MOV	AH,AL		;Flag is kept in AH
	MOV	WORD [UNDEF],0
	MOV	AL,[SYM]
	MOV	[EXPRSTACKLIMIT],ESP
	SUB	DWORD [EXPRSTACKLIMIT],STRICT DWORD MAXEXPRSTACKSIZ
	CALL	EXPRESSION
	MOV	[CON],DX
	MOV	AL,AH
	MOV	CH,0		;Initial mode
	TEST	AL,10H		;Test INDEX bit
	RCL	AL		;BASE bit (zero flag not affected)
	JZ	NOIND		;Jump if not indexed, with BASE bit in carry
	CMC
	RCL	CH		;Rotate in BASE bit
	RCL	AL		;BP bit
	RCL	CH
	RCL	AL		;DI bit
	RCL	CH		;The low 3 bits now have indexing mode
MODE:
	OR	CH,080H		;If undefined label, force 16-bit displacement
	TEST	WORD [UNDEF],-1
	JNZ	RET21
	MOV	BX,[CON]
	MOV	AL,BL
	CBW			;Extend sign
	CMP	AX,BX		;Is it a signed 8-bit number?
	JNZ	RET21		;If not, use 16-bit displacement
	AND	CH,07FH		;Reset 16-bit displacement
	OR	CH,040H		;Set 8-bit displacement
	OR	BX,BX
	JNZ	RET21		;Use it if not zero displacement
	AND	CH,7		;Specify no displacement
	CMP	CH,6		;Check for BP+0 addressing mode
	JNZ	RET21
	OR	CH,040H		;If BP+0, use 8-bit displacement
RET3:	RET

NOIND:
	MOV	CH,6		;Try direct address mode
	JNC	RET3		;If no base register, that's right
	RCL	AL		;Check BP bit
	JC	MODE
	INC	CH		;If not, must be BX
	JP	MODE

EXPRESSION:
;Analyze arbitrary expression. Flag byte in AH.
;On exit, AL has type byte: 0=register or undefined label
	CMP	[EXPRSTACKLIMIT],ESP
	JNC	ABORT
	MOV	CH,-1		;Initial type
	MOV	DI,DX
	XOR	DX,DX		;Initial value
	CMP	AL,'+'
	JZ	PLSMNS
	CMP	AL,'-'
	JZ	PLSMNS
	MOV	CL,'+'
	PUSH	DX
	PUSH	CX
	MOV	DX,DI
	JP	OPERATE
PLSMNS:
	MOV	CL,AL
	PUSH	DX
	PUSH	CX
	OR	AH,4		;Flag that a sign was found
	CALL	GETSYM
OPERATE:
	CALL	TERM
	POP	CX		;Recover operator
	POP	BX		;Recover current value
	XCHG	BX,DX
	AND	CH,AL
	OR	AL,AL		;Is it register or undefined label?
	JZ	NOCON		;If so, then no constant part
	CMP	CL,"-"		;Subtract it?
	JNZ	$ADD
	NEG	BX
$ADD:
	ADD	DX,BX
NEXTERM:
	MOV	AL,[SYM]
	CMP	AL,'+'
	JZ	PLSMNS
	CMP	AL,'-'
	JZ	PLSMNS
	MOV	AL,CH
	RET
NOCON:
	CMP	CL,"-"
	JNZ	NEXTERM
BADOP:
	MOV	CL,5
	JMP	ERROR

TERM:
	CALL	FACTOR
MULOP:
	PUSH	DX		;Save value
	PUSH	AX		;Save type
	CALL	GETSYM
	POP	CX
	CMP	AL,"*"
	JZ	GETFACT
	CMP	AL,"/"
	JNZ	ENDTERM
GETFACT:
	OR	CL,CL		;Can we operate on this type?
	JZ	BADOP
	PUSH	AX		;Save operator
	CALL	GETSYM		;Get past operator
	CALL	FACTOR
	OR	AL,AL
	JZ	BADOP
	POP	CX		;Recover operator
	POP	BP		;And current value
	XCHG	AX,BP		;Save AH in BP
	CMP	CL,"/"		;Do we divide?
	JNZ	DOMUL
	OR	DX,DX		;Dividing by zero?
	MOV	CL,29H
	JZ	ERR2
	MOV	BX,DX
	XOR	DX,DX		;Make 32-bit dividend
	DIV	AX,BX
	JMPS	NEXFACT
DOMUL:
	MUL	AX,DX
NEXFACT:
	MOV	DX,AX		;Result in DX
	XCHG	AX,BP		;Restore flags to AH
	MOV	AL,-1		;Indicate a number
	JMPS	MULOP
ENDTERM:
	POP	DX
	MOV	AL,CL
RET4:	RET

FACTOR:
	MOV	AL,[SYM]
	CMP	AL,CONST
	JZ	RET4
	CMP	AL,UNDEFID
	JZ	UVAL
	CMP	AL,"("
	JZ	PAREN
	CMP	AL,'"'
	JZ	STRING
	CMP	AL,"'"
	JZ	STRING
	CMP	AL,XREG		;Only 16-bit register may index
	MOV	CL,20
	JNZ	ERR2
	TEST	AH,1		;Check to see if indexing is OK
	MOV	CL,1
	JZ	ERR2
	MOV	AL,DL
	MOV	CL,3
	SUB	AL,3		;Check for BX
	JZ	BXJ
	SUB	AL,2		;Check for BP
	JZ	BPJ
	DEC	AL		;Check for SI
	MOV	CL,4
	JZ	SIJ
	DEC	AL		;Check for DI
	JZ	DIJ
	MOV	CL,2		;Invalid base/index register
ERR2:	JMP	ERROR

DIJ:
	OR	AH,20H		;Flag seeing index register DI
SIJ:
	TEST	AH,10H		;Check if already seen index register
	JNZ	ERR2
	OR	AH,10H		;Flag seeing index register
	RET

BPJ:
	OR	AH,40H		;Flag seeing base register BP
BXJ:
	TEST	AH,80H		;Check if already seen base register
	JNZ	ERR2
	OR	AH,80H		;Flag seeing base register
	RET

PAREN:
;Recursion: EXPRESSION (after PUSH DX CX) calls TERM calls FACTOR jumps to
;PAREN calls EXPRESSION. That's 18 bytes of stack use per paren nesting.
;We limit the paren nesting level by MAXEXPRSTACKSIZ to about 999.
	CALL	GETSYM		;Eat the "("
	CALL	EXPRESSION
	CMP	BYTE [SYM],")"	;Better have closing paren
	MOV	CL,20
	JNZ	ERR30
	RET

UVAL:
	MOV	CL,6
	TEST	AH,8		;Check if undefined label has been seen
	JNZ	ERR30
	OR	AH,8		;Flag seeing undefined label
	MOV	[UNDEF],BX
	RET

ERR30:	JMP	ERROR

STRING:
	MOV	CH,AL
	MOV	AL,[CHR]
	CMP	AL,CH
	MOV	CL,35
	MOV	DL,AL
	MOV	DH,0
	JNZ	L0003
	CALL	ZERLEN
L0003:
	CALL	GETCHR
	MOV	CL,37
	TEST	AH,2
	JZ	ERR30
	TEST	AH,4
	MOV	CL,38
	JNZ	ERR30
STRGDAT:
	MOV	AL,DL
	CMP	AL,EOL
	MOV	CL,39
	JZ	ERR30
	CALL	$PUT
	MOV	AL,[DATSIZ]
	OR	AL,AL
	JNZ	BYTSIZ
	MOV	AL,DH
	CALL	$PUT
BYTSIZ:
	MOV	AL,[CHR]
	MOV	DL,AL
	CALL	GETCHR
	JP	STRGDAT

ZERLEN:
	CALL	NEXTCHR
	CMP	AL,CH
	JNZ	ERR30
RET22:	RET

GETCHR:
	CALL	NEXTCHR
	CMP	AL,CH
	JNZ	RET22
	CALL	NEXTCHR
	CMP	AL,CH
	JZ	RET22
	ADD	ESP,BYTE 4	;Discard return address to STRGDAT loop.
	MOV	AL,-1		;Flag type as constant
	RET


GETSYM:

; The lexical scanner. Used only in the operand field. Returns with the token
; in SYM and AL, sometimes with additional info in BX or DX.
;
; AL=SYM=0  Undefined label. BX has pointer to information fields.
;
; AL=SYM=1  Constant (or defined label). DX has value.
;
; AL=SYM=2,3,4  8-bit register, 16-bit register, or segment register,
; respectively. DL has register number.
;
; AL=SYM=5  A mode flag (such as "B" for byte operation). Type of flag in DL
; and also stored in FLAG: -1=no flags, 0=B, 1=W, 2=S, 3=L, 4=T.
;
; AL=SYM=6  8087 floating point register, ST(n) or ST. DL has register number.
;
; All other values are the ASCII code of the character. Note that this may
; never be a letter or number.

	PUSH	AX		;Save AH
	CALL	GETSY
	POP	AX
	MOV	AL,[SYM]
RET6:	RET

SCANB:
	MOV	AL,[CHR]
SCANT:
	CMP	AL,' '
	JZ	NEXB
	CMP	AL,9
	JNZ	RET6
NEXB:
	CALL	NEXTCHR
	JP	SCANT

DOLLAR:
	MOV	DX,[OLDPC]
	MOV	AL,CONST
	MOV	[SYM],AL
NEXTCHJ:
	JMP	NEXTCHR

GETSY:
	CALL	SCANB
	CMP	AL,'$'
	JZ	DOLLAR
	MOV	[SYM],AL
	OR	AL,20H
	CMP	AL,'z'+1
	JNC	NEXTCHJ
	CMP	AL,'a'
	JNC	NEAR LETTER
	CMP	AL,'9'+1
	JNC	NEXTCHJ
	CMP	AL,'0'
	JC	NEXTCHJ
	MOV	BX,SYM
	MOV	BYTE [EBX+data_base],CONST
	CALL	READID
	DEC	BX
	MOV	AL,[EBX+data_base]
	MOV	CL,7
	MOV	BX,0
	CMP	AL,'h'
	JZ	NEAR HEX
	INC	CL
	MOV	WORD [IX],ID
$DEC:
	MOV	SI,[IX]
	MOV	AL,[ESI]
	INC	WORD [IX]
	CMP	AL,'9'+1
	JNC	NEAR ERROR
	SUB	AL,'0'
	MOV	DX,BX
	SHL	BX
	SHL	BX
	ADD	BX,DX
	SHL	BX
	MOV	DL,AL
	MOV	DH,0
	ADD	BX,DX
	DEC	CH
	JNZ	$DEC
	XCHG	BX,DX
	RET

HEX:
	MOV	DX,ID
	DEC	CH
HEX1:
	MOV	SI,DX
	LODB
	INC	DX
	SUB	AL,'0'
	CMP	AL,10
	JC	GOTIT
	CMP	AL,'g'-'0'
	JNC	ERR4
	SUB	AL,'a'-10-'0'
GOTIT:
	SHL	BX
	SHL	BX
	SHL	BX
	SHL	BX
	ADD	BL,AL
	DEC	CH
	JNZ	HEX1
	XCHG	BX,DX
RET7:	RET

ERR4:	JMP	ERROR

GETLET:  ; Reads to [ID+...].
	CALL	SCANB
	CMP	AL,EOL
	STC
	JZ	RET7
	CMP	AL,';'
	STC
	JZ	RET7
	MOV	CL,10
	OR	AL,20H
	CMP	AL,'a'
	JC	ERR4
	CMP	AL,'z'+1
	JNC	ERR4
READID:  ; Reads to [ID+...].
	MOV	BX,ID
	MOV	CH,0
MOREID:
	MOV	[EBX+data_base],AL
	INC	CH
	INC	BX
	CALL	NEXTCHR
	CMP	AL,'0'
	JC	NOMORE
	OR	AL,20H
	CMP	AL,'z'+1
	JNC	NOMORE
	CMP	AL,'9'+1
	JC	MOREID
	CMP	AL,'a'
	JNC	MOREID
NOMORE:
	MOV	CL,AL
	MOV	AL,CH
	MOV	[LENID],AL
	OR	AL,AL
	MOV	AL,CL
	RET

LETTER:
	CALL	READID
	MOV	AL,CH
	DEC	AL
	JNZ	NOFLG
	MOV	AL,[ID]
	MOV	CX,5
	MOV	DI,FLGTAB
	;UP  ; Always DF=0.
	REPNE
	SCAB			;See if one of B,W,S,L,T
	JZ	SAVFLG		;Go save flag
	XOR	AL,AL
	MOV	CH,[LENID]
NOFLG:
	DEC	AL
	PUSH	BX
	JNZ	L0004
	CALL	REGCHK
L0004:	
	POP	BX
	MOV	AL,DH
	JZ	SYMSAV
	CALL	LOOKRET
SYMSAV:
	MOV	[SYM],AL
	RET

SAVFLG:
	MOV	DL,CL		;Need flag type in DL
	XCHG	[FLAG],CL
	CMP	CL,-1
	MOV	CL,32
	MOV	AL,5
	JZ	SYMSAV
ERRJ3:	JMP	ERROR

FPREG:
;Have detected "ST" for 8087 floating point stack register
	MOV	DL,0		;Default is ST(0)
	CALL	SCANB		;Get next character
	CMP	AL,"("		;Specifying register number?
	JNZ	HAVREG
;Get register number
	CALL	NEXTCHR		;Skip over the "("
	CALL	GETOP		;A little recursion never hurt anybody
	CMP	AL,CONST	;Better have found a constant
	MOV	CL,20		;Operand error if not
	JNZ	ERRJ3
	CMP	WORD [DLABEL],BYTE 0	;Constant must be defined
	MOV	CL,30
	JNZ	ERRJ3
	MOV	DX,[DATA]	;Get constant
	CMP	DX,BYTE 7		;Constant must be in range 0-7
	MOV	CL,31
	JA	ERRJ3
	MOV	AL,[SYM]
	CMP	AL,")"
	MOV	CL,24
	JNZ	ERRJ3
HAVREG:
	MOV	DH,FREG
	XOR	AL,AL		;Zero set means register found
RET8:	RET

REGCHK:
	MOV	BX,ID
	CMP	WORD [EBX+data_base],"s"+7400H	;"st"
	JZ	FPREG
	MOV	CL,[EBX+data_base]
	INC	BX
	MOV	AL,[EBX+data_base]
	MOV	BX,REGTAB
	MOV	DH,XREG
	MOV	DL,0
	CMP	AL,'x'
	JZ	SCANREG
	MOV	DH,REG
	CMP	AL,'l'
	JZ	SCANREG
	MOV	DL,4
	CMP	AL,'h'
	JZ	SCANREG
	MOV	DH,SREG
	MOV	DL,0
	MOV	BX,SEGTAB
	CMP	AL,'s'
	JZ	SCANREG
	MOV	DH,XREG
	CMP	AL,'p'
	JZ	PREG
	CMP	AL,'i'
	JNZ	RET8
	MOV	DL,6
	MOV	AL,CL
	CMP	AL,'s'
	JZ	RET8
	INC	DL
	CMP	AL,'d'
RET5:	RET
PREG:
	MOV	DL,4
	MOV	AL,CL
	CMP	AL,'s'
	JZ	RET5
	INC	DL
	CMP	AL,'b'
RET13:	RET
SCANREG:
	MOV	AL,CL
	MOV	CX,4
	;UP  ; Always DF=0.
	MOV	DI,BX
	REPNZ
	SCAB
	MOV	BX,DI
	JNZ	RET13
	MOV	AL,CL
	ADD	AL,DL
	MOV	DL,AL
	XOR	AL,AL
RET9:	RET

LOOK:
	MOV	CH,[EBX+data_base]
	INC	BX
	MOV	DX,ID
	CALL	CPSLP
	JZ	RET9
	XOR	AL,80H
	ROL	AL		;Make end-of-symbol bit least significant
	MOV	CL,AL
	DEC	BX
	MOV	AL,[EBX+data_base]
	XOR	AL,80H
	ROL	AL
	CMP	AL,CL
	JNC	SMALL
	INC	CH
	INC	CH
SMALL:
	MOV	DL,CH
	MOV	DH,0
	ADD	BX,DX
	MOV	DX,[EBX+data_base]
	INC	BX
	MOV	AL,DL
	OR	AL,DH
	STC
	JZ	RET9
	XCHG	BX,DX
	JP	LOOK

LOOKRET:
	CMP	CH,3		;RET has 3 letters. Now: CH == BYTE [LENID].
	JNE	LOOKUP
	CMP	BYTE [EBX-1+data_base],'t'
	JNE	LOOKUP
	CMP	WORD [EBX-3+data_base],'r'|('e'<<8)
	JNE	LOOKUP
	MOV	DX,[LSTRET]
	MOV	AL,DL
	AND	AL,DH
	INC	AL
	JZ	ALLRET
	MOV	BX,[PC]
	SUB	BX,DX
	MOV	AL,BL
	CBW
	CMP	AX,BX		;Signed 8-bit number?
	MOV	AL,1
	JZ	RET9
ALLRET:
	MOV	BX,[RETPT]
	MOV	AL,BH
	OR	AL,BL
	MOV	AL,0
	JNZ	RET9
	MOV	BX,[HEAP]
	DEC	BX
	DEC	BX
	DEC	BX
	CMP	BX,[CODE]
	JC	JJABORT
	MOV	[HEAP],BX
	XOR	AL,AL
	MOV	[EBX+data_base],AL
	MOV	[RETPT],BX
RET10:	RET

LOOKUP:
	DEC	BX
	OR	BYTE [EBX+data_base],080H
;LOOKIT:
	MOV	BX,[BASE]
	MOV	AL,BH
	OR	AL,BL
	JZ	EMPTY
	CALL	LOOK
	JC	$ENTER
	MOV	DX,4
	ADD	BX,DX
	MOV	AL,[EBX+data_base]
	OR	AL,AL
	JZ	RET10
	INC	BX
	MOV	DX,[EBX+data_base]
	INC	BX
	RET

JJABORT:
	JMP	ABORT

$ENTER:
	PUSH	BX		;Save pointer to link field
	CALL	CREATE		;Add the node
	POP	SI
	MOV	[ESI-1],DX	;Link new node
	RET			;Zero was set by CREATE

EMPTY:
	CALL	CREATE
	MOV	[BASE],DX
	RET

CREATE:

; Add a new node to the identifier tree. The identifier is at ID with
; bit 7 of the last character set to one. The length of the identifier is
; in LENID, which is ID-1.
;
; Node format:
;	1. Length of identifier (1 byte)
;	2. Identifier (1-80 bytes)
;	3. Left link (2-byte pointer to alphabetically smaller identifiers)
;	4. Right link (0 if none larger)
;	5. Data field:
;	   a. Defined flag (0=undefined, 1=defined)
;	   b. Value (2 bytes)
;
; This routine returns with AL=zero and zero flag set (which indicates
; on return from LOOKUP that it has not yet been defined), DX points
; to start of new node, and BX points to data field of new node.

	MOV	AL,[LENID]
	ADD	AL,8		;Storage needed for the node
	MOV	BX,[HEAP]
	MOV	DL,AL
	MOV	DH,0
	SUB	BX,DX		;Heap grows downward
	CMP	BX,[CODE]	;Check to make sure there's enough
	JC	ABORT
	MOV	[HEAP],BX
	XCHG	BX,DX
	PUSH	DX
	MOV	BX,LENID
	MOV	CL,[EBX+data_base]
	INC	CL
	MOV	CH,0
	;UP  ; Always DF=0.
	MOV	SI,BX
	MOV	DI,DX
	REP
	MOVB			;Move identifier and length into node
	MOV	DX,DI
	MOV	BX,SI
	MOV	CH,4
	XCHG	BX,DX
NILIFY:
	MOV	[EBX+data_base],CL		;Zero left and right links
	INC	BX
	DEC	CH
	JNZ	NILIFY
	XOR	AL,AL		;Set zero flag
	MOV	[EBX+data_base],AL		;Zero defined flag
	POP	DX		;Restore pointer to node
RET18:	RET

CPSLP:
	MOV	SI,DX
	LODB
	CMP	AL,[EBX+data_base]
	LAHF
	INC	DX
	INC	BX
	SAHF
	JNZ	RET18
	DEC	CH
	JNZ	CPSLP
RET11:	RET

GETLAB:
;Parse (and consume) the first word, copy the lowercase version of it to
;LENID+ID, and return CF=0 if instruction found in ID, and CF=1 if label
;found in id.
;
;Ruins: AX, BX, CX, DX, SI, DI, flags other than CF.
	MOV	BX,0
	MOV	[LABPT],BX
	MOV	BYTE [FLAG],-1
	CALL	GETLET
	JC	RET11
	CALL	SCANT		;Skip whitespace before ':'.
	CMP	AL,':'
	JNZ	LABCHK
	CALL	NEXTCHR
	JMP	LABEL
LABCHK:
	MOV	DI,UNGET
LABNEXT:
	PUSH	AX
	SUB	AL,'0'
	CMP	AL,9
	JNA	LABA
	ADD	AL,'0'
	OR	AL,32
	SUB	AL,'a'
	CMP	AL,'z'-'a'
LABA:	POP	AX
	JA	LABDONE1
	OR	AL,32		;Convert letter to lowercase.
LABLETTER:
	STOB
	CALL	NEXTCHRZ
	CMP	DI,UNGET+4
	JNE	LABNEXT
LABDONE1:
	STOB
	; Now check for data instruction following ID.
	MOV	AX,[UNGET]
	CMP	DI,UNGET+4
	JNE	LABNOT4
	CMP	AX, 'e'|('q'<<8)
	JNE	LABNOT4
	CMP	BYTE [EDI-2], 'u'
	JNE	LABNOT4
LABST:  ; Data instruction recognized (equ, db, dw, dm or ds). Reject it if at EOL or followed by a comma.
	MOV	AL,' '
	XCHG	AL,[EDI-1]
LABNXS:	CMP	AL,' '
	JE	LABWS
	CMP	AL,9
	JNE	LABNWS
LABWS:	CALL	NEXTCHRZ
	JP	LABNXS
LABNWS:	STOB
	CMP	AL,','		;Don't treat `MOV DS, ...' as label.
	JE	LABDONE		;CF=0 indicates to the caller of GETLAB that ID contains an instruction.
	CMP	AL,';'
	JE	LABDONE		;CF=0 indicates to the caller of GETLAB that ID contains an instruction.
	CMP	AL,13		;Don't treat `PUSH DS' or `POP DS' as label.
	JE	LABDONE		;CF=0 indicates to the caller of GETLAB that ID contains an instruction.
	STC			;CF=1 indicates to the caller of GETLAB that ID contains a label.
	JP	LABDONE
LABNOT4:
	CMP	DI,UNGET+3
	JNE	LABNOT3
	CMP	AX, 'd'|('b'<<8)
	JE	LABST
	CMP	AX, 'd'|('w'<<8)
	JE	LABST
	CMP	AX, 'd'|('m'<<8)
	JE	LABST
	CMP	AX, 'd'|('s'<<8)
	JE	LABST
LABNOT3:
	CMP	DI,UNGET+1	;No word after ID?
	JE	LABDONE		;CF=0 indicates to the caller of GETLAB that ID contains an instruction.
LABNOT:
	; Data instruction not found after ID (e.g. not `mov db 5'). Now ID
	; can be a label (e.g. `foo2' in `foo2 inc ax') or an instruction
	; (e.g. `ret' in `ret nop' after `nop equ 4'). We decide by the following
	; rule: if ID is an instruction we know, then we treat it as an instruction,
	; otherwise we treat it as a label.
	PUSH	DI		;Save DI (for UNGETP).
	CALL	FINDINST	;Returns in BX, ruins AX, CX, DX, SI, DI.
	POP	DI		;Restore DI (for UNGETP).
	CMP	BX,BYTE 1	;CF := (BX is NULL) === (instruction is not known) == (we want to reat ID as a label).
	; CF=0 indicates to the caller of GETLAB that ID contains an instruction; CF=1 indicates a label.
LABDONE:
	PUSHF			;Save CF.
	MOV	[UNGETP],DI
	; Reverse the string delimited by UNGET and DI. Ruins DI and SI.
	DEC	DI
	MOV	SI,UNGET
UNGETREVNEXT:
	CMP	SI,DI
	JNC	UNGETREVDONE
	LODB
	XCHG	AL,[EDI]
	DEC	DI
	MOV	[ESI-1],AL
	JP	UNGETREVNEXT
	;
UNGETREVDONE:
	CALL	NEXTCHR
	POPF			;Restore CF.
	; CF=0 indicates to the caller of GETLAB that ID contains an instruction; CF=1 indicates a label.
	JNC	RET11
LABEL:  ; Process label in [ID+...].
	MOV	AL,[CHKLAB]
	OR	AL,AL
	JNZ	NEAR GETLET
	CALL	LOOKUP
	MOV	CL,11
	JNZ	ERR5
	MOV	DX,[PC]
	MOV	BYTE [EBX+data_base],1
	INC	BX
	MOV	[EBX+data_base],DX
	MOV	[LABPT],BX
	JMP	GETLET

ASMLIN:
	MOV	BYTE [MAXFLG],1	;Allow only B and W flags normally
	MOV	BX,[PC]
	MOV	[OLDPC],BX
	CALL	GETLAB
	JC	NEAR ENDLN
	CALL	FINDINST
	TEST	BX,BX
	JNZ	INSTOK
ERROPC:	MOV	CL,12		;***** ERROR:  Opcode not recognized
ERR5:	JMP	ERROR
INSTOK:	MOV	AL,[EBX+data_base+2]	;Get opcode
	PUSH	EBX
	MOVSX	EBX,WORD [EBX+data_base]
	ADD	EBX,func_base
	XCHG	[ESP],EBX
	RET			;JMP [BX].

$FWAIT:
	CMP	BYTE [NOWAIT],0	;"FNWAIT" not legal
	JNE	ERROPC
	RET			;Nothing to do - "WAIT" already sent

SPECIALOP:
	AND	AL,7		;Mask to special op number
	JZ	$FWAIT		;If zero, go handle FWAIT
;Handle FNOP
	CMP	BYTE [NOWAIT],0	;Was "N" present (If not opcode was "FOP")
	JE	ERROPC
	MOV	AL,9BH		;Need Wait opcode after all
	CALL	$PUT
	MOV	AL,0D9H
	CALL	$PUT
	MOV	AL,0D0H
	JMP	$PUT

FINDINST:
;Find the function handling the instruction at LENID.
;It has some side effects such as setting registers and [NOWAIT].
;Output: BX: pointer to struct or NULL.
;Ruins; AX, CX, DX, SI, DI, flags.
	MOV	BX,LENID
	MOV	AL,[EBX+data_base]
	SUB	AL,2
	MOV	CH,AL
	INC	BX
	CMP	BYTE [EBX+data_base],"f"	;See if an 8087 mnemonic
	JE	FINDNDPOP
	CMP	AL,5
	JNC	OPERR
	MOV	AL,[EBX+data_base]
	SUB	AL,'a'
	MOV	CL,AL
	ADD	AL,AL
	ADD	AL,AL
	ADD	AL,CL
	ADD	AL,CH
	ADD	AL,AL
	MOV	BX,OPTAB
	MOV	DL,AL
	MOV	DH,0
	ADD	BX,DX
	MOV	BX,[EBX+data_base]
	INC	CH
	MOV	CL,CH
	MOV	AH,[EBX+data_base]
	INC	BX
	OR	AH,AH
	JZ	OPERR
FINDOP:	MOV	CH,CL
	MOV	DX,ID+1
	XCHG	AX,BP		;Save count of opcodes in BP
	CALL	CPSLP
	JZ	HAVOP
	XCHG	AX,BP
	MOV	DH,0
	MOV	DL,CH
	INC	DX
	INC	DX
	ADD	BX,DX
	DEC	AH
	JNZ	FINDOP
OPERR:	XOR	BX,BX		;Indicate: ***** ERROR:  Opcode not recognized
HAVOP:	RET
FINDNDPOP:	;First letter is "F" so must be 8087 opcode ("Numeric Data Processor")
	INC	BX
	CMP	BYTE [EBX+data_base],"n"	;"No-wait" form?
	MOV	AH,0
	JNZ	SAVNFLG
	MOV	AH,1
	DEC	AL
	INC	BX		;Skip over the "N"
SAVNFLG:
	MOV	[NOWAIT],AH	;0 for wait, 1 for no wait
	CMP	AL,1
	JB	OPERR		;Not enough char left for valid opcode?
	CMP	AL,5
	JA	OPERR		;Too many?
	CBW
	XCHG	AX,DX		;Save length in DX
	MOV	SI,DX
	OR	BYTE [ESI+EBX],80H	;Set high bit of last character
	MOV	AL,[EBX+data_base]		;Get first char of opcode
	INC	BX
	SUB	AL,"a"
	JB	TRY2XM1		;Go see if opcode starts with "2"
	CMP	AL,"z"-"a"
	JA	OPERR
	CBW
	SHL	AX		;Double to index into address table
	XCHG	AX,SI		;Put in index register
	MOV	DI,[ESI+NDPTAB-data_base]	;Get start of opcode table for this letter
LOOKNDP:
	MOV	AH,[EDI]		;Number of opcodes starting with this letter
	OR	AH,AH
	JZ	OPERR		;Any start with this letter?
FNDNDP:	INC	DI
	MOV	SI,BX		;Pointer to start of opcode
	MOV	CX,DX		;Get length of opcode
	REPE
	CMPB			;Compare opcode to table entry
	JNE	NONDP
	MOV	BX, FPUINSTSTRUC
	JP	HAVOP
NONDP:	DEC	DI		;Back up in case that was last letter
	MOV	AL,80H		;Look for char with high bit set
ENDOP:	SCASB
	JA	ENDOP
	INC	DI		;Skip over info about opcode
	DEC	AH
	JNZ	FNDNDP
	JP	OPERR
TRY2XM1:
	CMP	AL,"2"-"a"
	JNZ	OPERR
	MOV	DI,XM1
	JP	LOOKNDP

FPUINST:
;Generates an FPU (8087) instruction.
	MOV	BYTE [MAXFLG],4	;Allow all type flags
	MOV	SI,DI
	CMP	BYTE [NOWAIT],0
	JNZ	NWAIT
	MOV	AL,9BH		;Wait opcode
	CALL	$PUT
NWAIT:
	LODW			;Get opcode info
	TEST	AL,0F8H		;Any operand bits set?
	JZ	NEAR NOOPS	;If no operands, output code
	TEST	AL,78H		;Special case?
	JZ	SPECIALOP
	PUSH	AX
	CALL	GETSYM		;See if any operands
	POP	CX
	CMP	AL,";"
	JZ	NOOPCHK
	CMP	AL,EOL
	JZ	NOOPCHK
	CMP	AL,FREG		;Is it 8087 register?
	JNZ	NEAR MEMOP
	XCHG	AX,CX
	TEST	AL,ONEREG	;One register OK as operand?
	JNZ	PUTREG		;Yes - save it
	TEST	AL,20H		;Memory-only operation?
	MOV	CL,20
	JNZ	ERRJ4
	TEST	AL,18H		;Two-register operation?
	JPE	ERRJ4		;Must be exactly one bit set
	PUSH	DX		;Save register number
	PUSH	AX		;Save opcode
	CALL	GETSYM
	CMP	AL,","
	MOV	CL,15H
	JNZ	ERRJ4
	CALL	GETSYM
	MOV	CL,20
	CMP	AL,FREG
	JNZ	ERRJ4
	POP	AX
	POP	BX
	XOR	AL,2		;Flip "POP" bit
	AND	AL,0FBH		;Reset direction bit to ST(0)
	OR	BL,BL		;Is first register ST(0)?
	JZ	ST0DEST
	XCHG	BX,DX
	OR	BL,BL		;One of these must be ST(0)
	JNZ	ERRJ4
	XOR	AL,4		;Flip direction
	JMPS	PUTREG
ST0DEST:
	TEST	AL,2		;Is POP bit set?
	JNZ	ERRJ4		;Don't allow destination ST(0) then pop
PUTREG:
	AND	AH,0F8H		;Zero out register field
	OR	AH,DL
	OR	AH,0C0H
	PUSH	AX
	CALL	GETSYM		;Get to next symbol
	POP	AX
	JMPS	NOOPS

NOOPCHK:
	XCHG	AX,CX
	TEST	AL,80H		;Is no operands OK?
	MOV	CL,20
	JNZ	ERRJ4
NOOPS:
;First test for FDIV or FSUB and reverse "R" bit if "D" bit is set
	PUSH	AX
	AND	AX,0E005H
	CMP	AX,0E004H
	POP	AX
	JNZ	NOREV
	XOR	AH,8		;Reverse "R" bit
NOREV:
	AND	AL,7
	OR	AL,0D8H		;ESC hook
	CALL	$PUT
	MOV	AL,AH
	JMP	$PUT

BADFLAG:
	MOV	CL,20H
ERRJ4:	JMP	ERROR

MEMOP:
	PUSH	CX		;Save opcode
	CALL	GETOP1		;Get memory operand
	CMP	AL,UNDEFID	;Is it?
	MOV	CL,20
	JNZ	ERRJ4
	POP	AX
	TEST	AL,20H		;Does it have memory format field?
	JNZ	GETFORMAT
	TEST	AL,8		;Check if any memory operand legal
	JZ	ERRJ4
	TEST	AL,10H		;Check for 2-op arithmetic
	JNZ	PUTMEM		;If not, just use as plain memory op
GETFORMAT:
	AND	AL,0F9H		;Zero memory format bits
	MOV	CL,[FLAG]
	DEC	CL		;Must now be in range 0-3
	JL	BADFLAG
	MOV	CH,AL		;Save opcode byte
	SHR	AL		;Put format bits in bits 2 & 3
	AND	AL,0CH
	OR	AL,CL		;Combine format bits with flag
	MOV	BX,FORMATTAB
	XLAT
	OR	AL,AL		;Valid combination?
	JS	BADFLAG
	OR	AH,AL		;Possibly set new bits in second byte
	OR	AL,CH		;Set memory format bits
PUTMEM:
	AND	AL,7
	OR	AL,0D8H
	CALL	$PUT
	MOV	AL,AH
	AND	AL,38H
	OR	AL,DL		;Combine addressing mode
	JMP	PUTADD

func_base:  ; Base address of function pointers, can be anywhere.

GRP1:
	MOV	CX,8A09H
	CALL	MROPS
	MOV	CX,0C6H
	MOV	AL,BH
	CMP	AL,UNDEFID
	JNZ	L0006
	CALL	STIMM
L0006:	
	AND	AL,1
	JZ	BYTIMM
	MOV	AL,0B8H
	OR	AL,BL
	CALL	$PUT
	JMP	PUTWOR

BYTIMM:
	MOV	AL,0B0H
	OR	AL,BL
	CALL	$PUT
PUTBJ:	JMP	PUTBYT

IMMED:
	MOV	AL,BH
	CMP	AL,UNDEFID
	JZ	STIMM
	MOV	AL,BL
	OR	AL,AL
	JZ	RET12
	MOV	AL,BH
	CALL	IMM
	OR	AL,0C0H
	CALL	$PUT
FINIMM:
	MOV	AL,CL
	ADD	ESP,BYTE 4	;Discard return address.
	TEST	AL,1
	JZ	PUTBJ
	CMP	AL,83H
	JZ	PUTBJ
	JMP	NEAR PUTWOR

STIMM:
	MOV	AL,[FLAG]
	CALL	IMM
	CALL	PUTADD
	JP	FINIMM

IMM:
	AND	AL,1
	OR	AL,CL
	MOV	CL,AL
	CALL	$PUT
	MOV	AL,CH
	AND	AL,38H
	OR	AL,BL
RET12:	RET

$PUT:
;Save byte in AL as pure code, with intermediate code bits 00. AL and
;DI destroyed, no other registers affected.
	PUSH	BX
	PUSH	CX
	MOV	CH,0		;Flag as pure code
	CALL	GEN
	POP	CX
	POP	BX
RET19:	RET

GEN:
;Save byte of code in AL, given intermediate code bits in bits 7&8 of CH.
;Called in pass 1.
;Appeds to the patch table, which contains specials, fixups and errors.
	CALL	PUTINC		;Save it and bump code pointer
GEN1:
	MOV	AL,[RELOC]
	RCL	CH
	RCL	AL
	RCL	CH
	RCL	AL
	MOV	[RELOC],AL
	MOV	BX,BCOUNT
	DEC	BYTE [EBX+data_base]
	JNZ	RET19
	MOV	BYTE [EBX+data_base],4
	MOV	BX,RELOC
	MOV	AL,[EBX+data_base]
	MOV	BYTE [EBX+data_base],0
	MOV	DI,[IY]
	MOV	[EDI],AL
	MOV	BX,[CODE]
	CMP	[HEAP],BX
JABORT:	JBE	ABORT
	MOV	[IY],BX
	INC	BX
	MOV	[CODE],BX
	RET

PUTINC:
	INC	WORD [PC]
PUTCD:
	MOV	DI,[CODE]
	CMP	[HEAP],DI
	JBE	JABORT
	STOB
	MOV	[CODE],DI
	RET

PUTWOR:
;Save the word value described by [DLABEL] and [DATA] as code. If defined,
;two bytes of pure code will be produced. Otherwise, appropriate intermediate
;code will be generated.
	PUSH	CX
	MOV	CH,80H
	PUSH	DX
	PUSH	BX
	JP	PUTBW

PUTBYT:
;Same as PUTWOR, above, but for byte value.
	PUSH	CX
	MOV	CH,40H
	PUSH	DX
	PUSH	BX
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	JNZ	PUTBW
	MOV	BX,[DATA]
	OR	AL,BH
	JZ	PUTBW
	INC	BH
	JZ	PUTBW
	MOV	CL,31
	JMP	ERROR
PUTBW:
	MOV	DX,[DLABEL]
	MOV	BX,[DATA]
PUTCHK:
	OR	DX,DX
	JZ	NOUNDEF
	MOV	AL,DL
	CALL	PUTCD
	MOV	AL,DH
	CALL	PUTCD
	MOV	AL,BL
	CALL	PUTINC
	MOV	AL,BH
	TEST	CH,080H
	JZ	SMPUT
	CALL	GEN
	JP	PRET
SMPUT:
	CALL	PUTCD
	CALL	GEN1
PRET:
	POP	BX
	POP	DX
	POP	CX
	RET

NOUNDEF:
	MOV	AL,BL
	MOV	CL,BH
	PUSH	CX
	MOV	CH,0
	CALL	GEN
	POP	CX
	MOV	AL,CL
	TEST	CH,080H
	MOV	CH,0
	JZ	PRET
	CALL	GEN
	JP	PRET

PUTADD:
;Save complete addressing mode. Addressing mode is in AL; if this is a register
;operation (>=C0), then the one byte will be saved as pure code. Otherwise,
;the details of the addressing mode will be investigated and the optional one-
;or two-byte displacement will be added, as described by [ADDR] and [ALABEL].
	PUSH	CX
	PUSH	DX
	PUSH	BX
	MOV	CH,0
	MOV	CL,AL
	CALL	GEN		;Save the addressing mode as pure code
	MOV	AL,CL
	MOV	CH,80H
	AND	AL,0C7H
	CMP	AL,6
	JZ	TWOBT		;Direct address?
	AND	AL,0C0H
	JZ	PRET		;Indirect through reg, no displacement?
	CMP	AL,0C0H
	JZ	PRET		;Register to register operation?
	MOV	CH,AL		;Save whether one- or two-byte displacement
TWOBT:
	MOV	BX,[ADDR]
	MOV	DX,[ALABEL]
	JMP	PUTCHK

GRP2:
	CALL	GETOP
	MOV	CX,0FF30H
	CMP	AL,UNDEFID
	JZ	PMEM
	MOV	CH,50H
	CMP	AL,XREG
	JZ	PXREG
	MOV	CH,6
	CMP	AL,SREG
	JZ	NEAR PACKREG
	MOV	CL,20
	JMP	ERROR

PMEM:
	MOV	AL,CH
	CALL	$PUT
	MOV	AL,CL
	OR	AL,DL
	JMP	NEAR PUTADD

PXREG:
	MOV	AL,CH
	OR	AL,DL
	JMP	$PUT

GRP3:
	CALL	GETOP
	PUSH	DX
	CALL	GETOP2
	POP	BX
	MOV	CX,8614H
	MOV	AL,SREG
	CMP	AL,BH
	JZ	ERR6
	CMP	AL,DH
	JZ	ERR6
	MOV	AL,CONST
	CMP	AL,BH
	JZ	ERR6
	CMP	AL,DH
	JZ	ERR6
	MOV	AL,UNDEFID
	CMP	AL,BH
	JZ	EXMEM
	CMP	AL,DH
	JZ	EXMEM1
	MOV	AL,BH
	CMP	AL,DH
	MOV	CL,22
	JNZ	ERR6
	CMP	AL,XREG
	JZ	L0008
	CALL	RR1
L0008:			;RR1 never returns
	MOV	AL,BL
	OR	AL,AL
	JZ	EXACC
	XCHG	BX,DX
	MOV	AL,BL
	OR	AL,AL
	MOV	AL,BH
	JZ	EXACC
	CALL	RR1
EXACC:
	MOV	AL,90H
	OR	AL,DL
	JMP	$PUT

EXMEM:
	XCHG	BX,DX
EXMEM1:
	CMP	AL,BH
	JZ	ERR6
	MOV	CL,1	;Flag word as OK
	CALL	NOTAC	;NOTAC never returns
ERR6:	JMP	ERROR

GRP4:
	PUSH	AX
	CALL	GETOP
	POP	CX
	XCHG	CL,CH
	CMP	AL,CONST
	JZ	FIXED
	SUB	AL,XREG
	DEC	DL
	DEC	DL
	OR	AL,DL
	MOV	CL,20
	JNZ	ERR6
	MOV	AL,CH
	OR	AL,8
	JMP	$PUT
FIXED:
	MOV	AL,CH
	CALL	$PUT
	JMP	PUTBYT

GRP5:
	PUSH	AX
	CALL	GETOP
	MOV	CL,20
	CMP	AL,CONST
	JNZ	ERR6
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	MOV	CL,30
	JNZ	ERR6
	MOV	BX,[DATA]
	POP	AX
	OR	AL,AL
	JZ	$ORG
	DEC	AL
	JZ	DSJ
	DEC	AL
	JZ	$EQU
	DEC	AL
	JNZ	NEAR IF
PUTOP:
	MOV	AL,-3
	JP	NEWLOC
$ALIGN:
	MOV	AL,[PC]
	AND	AL,1
	JZ	RET14
	MOV	BX,1
DSJ:
	XCHG	BX,DX
	MOV	BX,[PC]
	ADD	BX,DX
	MOV	[PC],BX
	XCHG	BX,DX
	MOV	AL,-4
	JP	NEWLOC
$EQU:
	XCHG	BX,DX
	MOV	BX,[LABPT]
	MOV	AL,BH
	OR	AL,BL
	MOV	CL,34
	JZ	ERR7
	MOV	[EBX+data_base],DL
	INC	BX
	MOV	[EBX+data_base],DH
RET14:	RET
$ORG:
	MOV	[PC],BX
	TEST	BYTE [STATE],STHASORG
	JNZ	SKIPORGV
	OR	BYTE [STATE],STHASORG
	MOV	[ORGV],BX
SKIPORGV:
	MOV	AL,-2
NEWLOC:
	CALL	PUTCD
	MOV	AL,BL
	CALL	PUTCD
	MOV	AL,BH
	CALL	PUTCD
	MOV	CH,0C0H
	JMP	GEN1
GRP6:
	MOV	CH,AL
	MOV	CL,4
	CALL	MROPS
	MOV	CL,23
ERR7:	JMP	ERROR
GRP7:
	MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,80H
	MOV	DX,[DLABEL]
	MOV	AL,DH
	OR	AL,DL
	JNZ	ACCJ
	XCHG	BX,DX
	MOV	BX,[DATA]
	MOV	AL,BL
	CBW
	CMP	AX,BX
	XCHG	BX,DX
	JNZ	ACCJ
	TEST	CL,1		;Is immediate of word size?
	JNZ	ACCI
	TEST	BH,1		;Is instruction of word size?
	JNZ	ACCI
	TEST	BYTE [FLAGS], NFLAG
	JNZ	ACCJ
ACCI:	OR	CL,002H
ACCJ:	JMP	ACCIMM
GRP8:
	MOV	CL,AL
	MOV	CH,0FEH
	JP	ONEOP
GRP9:
	MOV	CL,AL
	MOV	CH,0F6H
ONEOP:
	PUSH	CX
	CALL	GETOP
ONE:
	MOV	CL,26
	CMP	AL,CONST
	JZ	ERR7
	CMP	AL,SREG
	MOV	CL,22
	JZ	ERR7
	POP	CX
	CMP	AL,UNDEFID
	JZ	MOP
	AND	AL,1
	JZ	ROP
	TEST	CL,001H
	JZ	ROP
	MOV	AL,CL
	AND	AL,0F8H
	OR	AL,DL
	JMP	$PUT
MOP:
	MOV	AL,[FLAG]
	AND	AL,1
	OR	AL,CH
	CALL	$PUT
	MOV	AL,CL
	AND	AL,38H
	OR	AL,DL
	JMP	PUTADD
ROP:
	OR	AL,CH
	CALL	$PUT
	MOV	AL,CL
	AND	AL,38H
	OR	AL,0C0H
	OR	AL,DL
	JMP	$PUT
GRP10:
	MOV	CL,AL
	MOV	CH,0F6H
	PUSH	CX
	CALL	GETOP
	MOV	CL,20
	MOV	AL,DL
	OR	AL,AL
	JNZ	ERRJ1
	MOV	AL,DH
	CMP	AL,XREG
	JZ	G10
	CMP	AL,REG
ERRJ1:	JNZ	NEAR ERR8
G10:
	PUSH	AX
	CALL	GETOP
	POP	AX
	AND	AL,1
	MOV	[FLAG],AL
	MOV	AL,DH
ONEJ:	JMP	ONE
GRP11:
	CALL	$PUT
	MOV	AL,0AH
	JMP	$PUT
GRP12:
	MOV	CL,AL
	MOV	CH,0D0H
	PUSH	CX
	CALL	GETOP
	MOV	AL,[SYM]
	CMP	AL,','
	MOV	AL,DH
	JNZ	ONEJ
	PUSH	DX
	CALL	GETOP
	SUB	AL,REG
	MOV	CL,20
	DEC	DL
	OR	AL,DL
	JNZ	ERR8
	POP	DX
	MOV	AL,DH
	POP	CX
	OR	CH,002H
	PUSH	CX
	JMP	ONE
GRP13:
	MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,80H
ACCIMM:
	CALL	IMMED
	OR	CH,004H
	AND	CH,0FDH
AIMM:
	MOV	AL,BH
	AND	AL,1
	LAHF
	PUSH	AX
	OR	AL,CH
	CALL	$PUT
	POP	AX
	SAHF
	JZ	NEAR PUTBYT
	JMP	PUTWOR

ERR8:	JMP	ERROR

GRP14:
;JMP and CALL mnemonics
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	MOV	BYTE [MAXFLG],3	;Allow "L" flag
	CALL	GETOP
	CMP	AL,CONST
	JZ	DIRECT
	MOV	CL,20
	CMP	AL,REG
	JZ	ERR8
	CMP	AL,SREG
	JZ	ERR8
	CMP	AL,XREG
	JNZ	NOTRG
	OR	DL,0C0H
NOTRG:
;Indirect jump. DL has addressing mode.
	MOV	AL,0FFH
	CALL	$PUT
	POP	AX
	XCHG	AH,AL
	SAHF
	AND	AL,38H
	OR	AL,DL
	MOV	CH,[FLAG]
	CMP	CH,3		;Flag "L" present?
	JZ	PUTADDJ		;If so, do inter-segment
	MOV	CL,27H
	CMP	CH,-1		;Better not be a flag
	JNZ	ERR8
	AND	AL,0F7H		;Convert to intra-segment
PUTADDJ:
	JMP	PUTADD
DIRECT:
	MOV	AL,[SYM]
	CMP	AL,','
	JZ	LONGJ
	POP	AX
	XCHG	AH,AL
	SAHF
	DEC	AL
	CMP	AL,0E9H
	JZ	GOTOP
	MOV	AL,0E8H
GOTOP:
	CALL	$PUT
	MOV	DX,[PC]
	INC	DX
	INC	DX
	SUB	[DATA],DX
	JMP	PUTWOR
LONGJ:
	POP	AX
	XCHG	AH,AL
	SAHF
	CALL	$PUT
	CALL	PUTWOR
	CALL	GETOP
	MOV	CL,20
	CMP	AL,CONST
	JNZ	ERR8
	JMP	PUTWOR

GRP16:
;RET mnemonic
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
	CALL	GETSYM
	CMP	AL,5
	JZ	LONGR
	CMP	AL,EOL
	JZ	NODEC
	CMP	AL,';'
	JZ	NODEC
GETSP:
	CALL	GETOP1
	POP	CX
	CMP	AL,CONST
	MOV	CL,20
	JNZ	NEAR ERR9
	MOV	AL,CH
	AND	AL,0FEH
	CALL	$PUT
	JMP	PUTWOR
LONGR:
	CMP	DL,3		;Is flag "L"?
	MOV	CL,27H
	JNZ	NEAR ERR10	;If not, bad flag
	POP	AX
	XCHG	AH,AL
	SAHF
	OR	AL,8
	LAHF
	XCHG	AH,AL
	PUSH	AX
	XCHG	AH,AL
NOTLON:
	CALL	GETSYM
	CMP	AL,EOL
	JZ	DORET
	CMP	AL,';'
	JZ	DORET
	CMP	AL,','
	JNZ	L0011
	CALL	GETSYM
L0011:	
	JP	GETSP
NODEC:
;Return is intra-segment (short) without add to SP. 
;Record position for RET symbol.
	MOV	BX,[PC]
	MOV	[LSTRET],BX
	XCHG	BX,DX
	MOV	BX,[RETPT]
	MOV	AL,BH
	OR	AL,BL
	JZ	DORET
	MOV	BYTE [EBX+data_base],1
	INC	BX
	MOV	[EBX+data_base],DX
	MOV	BX,0
	MOV	[RETPT],BX
DORET:
	POP	AX
	XCHG	AH,AL
	SAHF
	JMP	$PUT

GRP17:
	CALL	$PUT
	CALL	GETOP
	CMP	AL,CONST
	MOV	CL,20
ERR9:	JNZ	ERR10
	MOV	BX,[DATA]
	MOV	DX,[PC]
	INC	DX
	SUB	BX,DX
	MOV	[DATA],BX
	CALL	PUTBYT
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	JNZ	RET15
	MOV	BX,[DATA]
	MOV	AL,BL
	CBW
	CMP	AX,BX		;Signed 8-bit number?
	JZ	RET15
	MOV	CL,31
ERR10:	JMP	ERROR
RET15:	RET
GRP18:
	CALL	GETOP
	CMP	AL,CONST
	MOV	CL,20
	JNZ	ERR10
	MOV	BX,[DLABEL]
	MOV	AL,BH
	OR	AL,BL
	JNZ	GENINT
	MOV	BX,[DATA]
	MOV	DX,3
	SBB	BX,DX
	JNZ	GENINT
	MOV	AL,0CCH
	JMP	$PUT
GENINT:
	MOV	AL,0CDH
	CALL	$PUT
	JMP	PUTBYT

GRP19:	;ESC opcode
	CALL	GETOP
	MOV	CL,20
	CMP	AL,CONST
	JNZ	ERRJ		;First operand must be immediate
	MOV	CL,1EH
	TEST	WORD [DLABEL],-1	;See if all labels have been defined
	JNZ	ERRJ
	MOV	AX,[DATA]
	CMP	AX,STRICT WORD 64		;Must only be 6 bits
	MOV	CL,1FH
	JNB	ERRJ
	MOV	BL,AL		;Save for second byte
	SHR	AL
	SHR	AL
	SHR	AL
	OR	AL,0D8H		;ESC opcode
	CALL	$PUT
	PUSH	BX
	CALL	GETOP2
	POP	BX
	AND	BL,7		;Low 3 bits of first operand
	SHL	BL
	SHL	BL
	SHL	BL
	CMP	AL,UNDEFID	;Check for memory operand
	JZ	ESCMEM
	CMP	AL,CONST	;Check for another immediate
	JZ	ESCIMM
	MOV	CL,20
ERRJ:	JMP	ERROR

ESCMEM:
	OR	BL,DL		;Combine mode with first operand
	MOV	AL,BL
	JMP	PUTADD

ESCIMM:
	MOV	CL,1EH
	TEST	WORD [DLABEL],-1	;See if second operand is fully defined
	JNZ	ERRJ
	MOV	AX,[DATA]
	MOV	CL,1FH
	CMP	AX,STRICT WORD 8		;Must only be 3 bit value
	JNB	ERRJ
	OR	AL,BL		;Combine first and second operands
	OR	AL,0C0H		;Force "register" mode
	JMP	$PUT

GRP20:
	MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,0F6H
	CALL	IMMED
	MOV	CH,0A8H
	JMP	AIMM
GRP21:
	CALL	GETOP
	CMP	AL,SREG
	MOV	CL,28
	JNZ	ERRJ
	MOV	CH,26H
PACKREG:
	MOV	AL,DL
	ADD	AL,AL
	ADD	AL,AL
	ADD	AL,AL
	OR	AL,CH
	JMP	$PUT
GRP22:
	CALL	GETOP
	MOV	CX,8F00H
	CMP	AL,UNDEFID
	JZ	NEAR PMEM
	MOV	CH,58H
	CMP	AL,XREG
	JZ	NEAR PXREG
	MOV	CH,7
	CMP	AL,SREG
	JZ	PACKREG
	MOV	CL,20
ERR11:	JMP	ERROR
GRP23:
	MOV	[DATSIZ],AL
GETDAT:
	CALL	GETSYM
	MOV	AL,2
	CALL	VAL1
	MOV	AL,[SYM]
	CMP	AL,','
	MOV	AL,[DATSIZ]
	JNZ	ENDDAT
	CALL	SAVDAT
	JP	GETDAT
ENDDAT:
	CMP	AL,2
	JNZ	SAVDAT
	MOV	BX,[DATA]
	LAHF
	OR	BL,080H
	SAHF
	MOV	[DATA],BX
SAVDAT:
	OR	AL,AL
	JNZ	NEAR PUTBYT
	JMP	PUTWOR
IF:
	OR	BX,BX
	JZ	SKIPCD
	INC	BYTE [IFFLG]
	RET

SKIPCD:
	INC	BYTE [CHKLAB]
SKIPLP:
	XOR	AL,AL
	CALL	NEXLIN
	CALL	NEXTCHR
	CMP	AL,1AH
	JZ	END
	CALL	GETLAB
	JC	SKIPLP
	MOV	DI,LENID
	MOV	SI,IFEND
	MOV	CH,0
	MOV	CL,[EDI]
	INC	CL
	REPE
	CMPB
	JZ	ENDCOND
	MOV	DI,LENID
	MOV	SI,IFNEST
	MOV	CL,[EDI]
	INC	CL
	REPE
	CMPB
	JNZ	SKIPLP
	INC	BYTE [CHKLAB]
	JP	SKIPLP

ENDCOND:
	DEC	BYTE [CHKLAB]
	JNZ	SKIPLP
	RET

ENDIF:
	MOV	AL,[IFFLG]
	MOV	CL,36
	DEC	AL
	JS	ERRJMP
	MOV	[IFFLG],AL
	RET

ERRJMP:	JMP	ERROR

;*********************************************************************
;
;	PASS 2
;
;*********************************************************************

END:
	MOV	BX,SRCFD
	CALL	FFCLOSE
	MOV	DL,4
WREND:
	MOV	CH,0FFH
	MOV	AL,CH
	CALL	GEN
	DEC	DL
	JNZ	WREND
	;MOV	WORD [UNGETP],UNGET  ; Not needed, because we read the whole input.
	MOV	WORD [BUFPT],SRCBUFSIZ
	MOV	BYTE [HEXCNT],-5	;FLAG HEX BUFFER AS EMPTY
	;MOV	WORD [LSTPNT],0  ; Already initialized in .bss.
	;MOV	WORD [HEXPNT],0  ; Already initialized in .bss.
	TEST	BYTE [FLAGS],HFLAG
	JZ	DONEHEX
	MOV	AX,'h'|('e'<<8)  ; .hex.
	MOV	CL,'x'
	MOV	DX,HEXFD
	CALL	FFCREATE
DONEHEX:
	MOV	AX,'b'|('i'<<8)  ; .bin.
	MOV	CL,'n'
	CMP	WORD [ORGV], 100H
	JNE	DONEBIN
	MOV	AX,'c'|('o'<<8)  ; .com.
	MOV	CL,'m'
DONEBIN:
	MOV	DX,BINFD
	CALL	FFCREATE
	CMP	BYTE [LSTDEV], 0
	JE	DONEOPENLST
	MOV	AX,'l'|('s'<<8)  ; .lst.
	MOV	CL,'t'
	MOV	DX,LSTFD
	CALL	FFCREATE
DONEOPENLST:
	XOR	AX,AX
	;MOV	[ERRCNT],AX	;ERRCNT is still 0 until now, pass 1 doesn't change it.
	MOV	[PC],AX
	MOV	[LINE],AX	;Current line number
	MOV	DX,OBJECT	;The default value 100H here is useless, because it doesn't match the default ORG value (0).
	MOV	WORD [HEXADD],DX
	TEST	BYTE [FLAGS],PFLAG
	JNZ	SKIPWITHPFLAG
	INC	BYTE [STATE]	;Set bit STHASHEXADD == 1.
	MOV	[OLDHEXADD],DX	;WORD [HEXADD]
	MOV	[MAXHEXADD],DX
SKIPWITHPFLAG:
	CALL	FFOPENSRC
	MOV	BYTE [NEXTCHRSTATE], 0
	XOR	AX,AX
	;MOV	[FCB+12],AX	;Set CURRENT BLOCK to zero
	;MOV	[FCB+20H],AL	;Set NEXT RECORD field to zero
	;MOV	WORD [FCB+14],SRCBUFSIZ
	MOV	[COUNT],AL
	MOV	CH,1
	MOV	SI,START
FIXLINE:
	MOV	DI,START	;Store code over used up intermediate code
	XOR	AL,AL
	MOV	[SPC],AL	;No "special" yet ($ORG, $PUT, DS)
	MOV	[ERR],AL	;No second pass errors yet
NEXBT:
	SHL	CL		;Shift out last bit of previous code
	DEC	CH		;Still have codes left?
	JNZ	TESTTYP
	LODB			;Get next flag byte
	MOV	CL,AL
	MOV	CH,4
TESTTYP:
	SHL	CL		;Set flags based on two bits
	JO	FIXUP
	LODB
	JC	EMARK
OBJBT:
	STOB
	JP	NEXBT

FIXUP:
;Either a word or byte fixup is needed from a forward reference
	LODW			;Get pointer to symbol
	XCHG	AX,BX
	LODW			;Get constant part
	ADD	AX,[EBX+data_base+1]	;Add symbol value to constant part
	CMP	BYTE [EBX+data_base],0	;See if symbol got defined
	JNZ	HAVDEF
	MOV	BYTE [ERR],100	;Undefined - flag error
	XOR	AX,AX
HAVDEF:
	OR	CL,CL		;See if word or byte fixup
	JS	DEFBYT
	STOW
	JP	NEXBT

DEFBYT:
	MOV	DX,AX
	CBW			;Extend sign
	CMP	AX,DX		;See if in range +127 to -128
	JZ	OBJBT		;If so, it's always OK
	NOT	AH		;Check for range +255 to -256
	CMP	AH,DH
	JNZ	RNGERR		;Must always be in this range
;Check for short jump. If so, we're out of range; otherwise we're OK
	CMP	DI,START+1	;Only one other byte on line?
	JNZ	OBJBT		;Can't be short jump if not
	MOV	AL,[START]	;Get the first byte of this line
	CMP	AL,0EBH		;Direct short jump?
	JZ	RNGERR
	AND	AL,0FCH
	CMP	AL,0E0H		;LOOP or JCXZ instruction?
	JZ	RNGERR
	AND	AL,0F0H
	CMP	AL,70H		;Conditional jump?
	MOV	AL,DL		;Get code byte in AL
	JNZ	OBJBT		;If not, we're OK
RNGERR:
	MOV	BYTE [ERR],101	;Value out of range
	JP	OBJBT

FINIJ:	JMP	FINI

EMARK:
	CMP	AL,-1		;End of file?
	JZ	FINIJ
	CMP	AL,-10		;Special item?
	JA	NEAR SPEND
	PUSH	CX
	PUSH	SI
	PUSH	AX		;Save error code
	MOV	AH,[LSTDEV]
	AND	AH,0FEH		;Do not force LIST output to console anymore.
	OR	AL,[ERR]	;See if any errors on this line
	JZ	NOERR
	OR	AH,1
	; Read and discard previous lines from the source file, so that when
	; LIST prints the line with the error, it will print the correct line.
	PUSH	CX
	PUSH	SI
	PUSH	AX
EREADLN:
	MOV	AX,[LINEREADC]
	CMP	AX,[LINE]
	JE	EREADDONE
	INC	AX
	MOV	[LINEREADC],AX
EREADCHR:
	CALL	NEXTCHR
	CMP	AL,10		;Output until linefeed found
	JNZ	EREADCHR
	JP	EREADLN
EREADDONE:
	POP	AX
	POP	SI
	POP	CX
NOERR:
	MOV	[LSTDEV],AH	;If error has occure in this line, force LIST output to console.
	MOV	CX,DI
	CALL	STRTLIN		;Print address of line
	MOV	SI,START
	SUB	CX,SI		;Get count of bytes of code
	JZ	SHOLIN
CODLP:
	LODB
	CALL	SAVCD		;Ouput code to .hex and .lst files
	LOOP	CODLP		;LOOP (with ECX) is OK, because ECX is always positive here.
SHOLIN:
	MOV	AL,0
	XCHG	AL,[COUNT]
	MOV	CX,7		;Allow 7 bytes of code per line
	SUB	CL,AL
	MOV	AL,' '
	JZ	NOFIL
BLNK:				;Put in 3 blanks for each byte not present
	CALL	LIST
	CALL	LIST
	CALL	LIST
	LOOP	BLNK		;LOOP (with ECX) is OK, because ECX is always positive here.
NOFIL:
	CALL	OUTLIN
	POP	AX		;Restore error code
	CALL	REPERR
	MOV	AL,[ERR]
	CALL	REPERR
	POP	SI
	POP	CX
	MOV	AL,[SPC]	;Any special funtion?
	OR	AL,AL
	JNZ	SPCFUN
	JMP	FIXLINE

SPEND:
	MOV	[SPC],AL	;Record special function
	LODW			;Get it's data
	MOV	[DATA],AX
	JMP	NEXBT

SPCFUN:
	MOV	DX,[DATA]
	CMP	AL,-2
	JZ	DORG
	CMP	AL,-3
	JZ	DPUT
DDS:
;Handle DS pseudo-op
	ADD	[PC],DX
	ADD	[HEXADD],DX
	JMP	FIXLINE

DORG:
;Handle ORG pseudo-op
;$ORG is called in pass 1 instead.
	MOV	[PC],DX
	JMP	FIXLINE

DPUT:
;Handle PUT pseudo-op
	MOV	[HEXADD],DX
	JMP	FIXLINE

OUTLIN:
;Copy the source line to the ouput device. Line will be preceded by
;assembler-generated line number. This routine may be called several times
;on one line (once for each line of object code bytes), so it sets a flag
;so the line will only be output on the first call.
;
; Typical output line in the .lst file:
;
; 0102 BA 08 01              0005 	MOV DX, MSG
;
; The beginning of this line is already printed, OUTLIN will print the
; `0005 	MOV DX, MSG`.

	MOV	AL,-1
	XCHG	AL,[LINFLG]
	OR	AL,AL
	JNZ	CRLF		;Output line only if first time
	MOV	AX,[LINE]
	INC	AX
	MOV	[LINE],AX
	MOV	BH,0		;No leading zero suppression
	CALL	OUT10
	MOV	AL," "
	CALL	LIST		;Print space between line number and source line.
	CMP	BYTE [LSTDEV],0
	JE	LINRET		;Don't call NEXTCHR if listing suppressed
	INC	WORD [LINEREADC]
	PUSH	SI		;Save the only register destroyed by NEXTCHR
OUTLN:
	CALL	NEXTCHR
	CALL	LIST
	CMP	AL,10		;Output until linefeed found
	JNZ	OUTLN
	POP	SI
LINRET:	RET

PRTCNT:
	MOV	AX,[ERRCNT]
	MOV	BX,ERCNTM
PRNT10:
	PUSH	AX
	CALL	PRINT
	POP	AX
	MOV	BH,"0"-" "	;Enable leading zero suppression
	CALL	OUT10
CRLF:
	MOV	AL,13
	CALL	LIST
	MOV	AL,10
	JP	LIST

OUT10:
;Print unsigned integer in AX as 5 decimal bytes with LIST; add BH to each
;leading space.
	XOR	DX,DX
	MOV	DI,10000
	DIV	AX,DI
	OR	AL,AL		;>10,000?
	JZ	LEAD
	MOV	BH,0		;Use '0' instead of ' ' in subsequent digits.
	ADD	AL,"0"-" "	;Will convert leading zero to '0'.
LEAD:	ADD	AL," "		;Convert leading zero to ' ' or '0'.
	CALL	LIST
	XCHG	AX,DX
	MOV	BL,100
	DIV	AL,BL
	MOV	BL,AH
	CALL	HIDIG		;Convert to decimal and print 1000s digit
	CALL	DIGIT		;Print 100s digit
	MOV	AL,BL
	CALL	HIDIG		;Convert to decimal and print 10s digit
	MOV	BH,0		;Ensure leading zero suppression is off
	JP	DIGIT
HIDIG:	AAM			;Convert binary to unpacked BCD
	OR	AX,3030H	;Add "0" bias
DIGIT:	XCHG	AL,AH
	CMP	AL,"0"
	JZ	SUPZ
	MOV	BH,0		;Turn off zero suppression if not zero
SUPZ:	SUB	AL,BH		;Convert leading zeros to blanks
	JP	LIST

STRTLIN:
	MOV	BYTE [LINFLG],0
	MOV	BX,[PC]
	MOV	AL,BH
	CALL	PHEX
	MOV	AL,BL
PHEXB:
	CALL	PHEX
	MOV	AL,' '
LIST:  ; Print single character in AL. This usually goes to the .lst file.
	PUSH	AX
	PUSH	DX
	AND	AL,7FH
	MOV	DL,AL
	TEST	BYTE [LSTDEV],3	;See if output goes to console. Any of: 1: error-in-this-line bit; 2: -c flag.
	JZ	FILCHK
	CALL	PUTCHAR
	CMP	AL,10
	JNE	FILCHK
	CALL	FLUSHCON	;Flush output buffer at the end of the line. This implements line buffering. Also sets DX := 0.
FILCHK:
	MOV	AL,DL
	POP	DX
	TEST	BYTE [LSTDEV],80H	;See if output goes to a file
	JZ	LISTRET
	CALL	WRTBUF
LISTRET:
	POP	AX
	RET

WRTBUF:
	PUSH	DI
	MOV	DI,[LSTPNT]
	MOV	[EDI+LSTBUF-data_base],AL
	INC	EDI		;`INC DI', but shorter. It won't overflow here.
	CMP	DI,LSTBUFSIZ
	JNZ	SAVPT
	PUSH	AX
	PUSH	CX
	PUSH	DX
	CALL	FLUSHBUF
	POP	DX
	POP	CX
	POP	AX
SAVPT:
	MOV	[LSTPNT],DI
	POP	DI
	RET

PHEX:
	PUSH	EAX			;Save AL.
	CALL	UHALF
	CALL	LIST
	POP	EAX			;Restore AL.
	CALL	LHALF
	JP	LIST

FLUSHBINRELSEEK:
;Flush the .bin file and seek relatively EDX bytes.
;Ruins AX and BX. Sets BX to BINFD.
	PUSH	ECX
	PUSH	EDX
	MOV	ECX,BINBUF
	MOVZX	EDX,WORD [BINPNT]	;Count.
	MOV	BX,BINFD
	CALL	FFWRITED		;Ruins AX and DX.
	POP	EDX
	AND	WORD [BINPNT],BYTE 0
	CALL	FFRELSEEK
	POP	ECX
	RET

FINI:
	XOR	EDX,EDX			;Don't seek.
	CALL	FLUSHBINRELSEEK
	CALL	FFCLOSE
	OR	BYTE [LSTDEV],1		;Subsequent LIST output goes to console as well.
	CALL	PRTCNT
	MOV	BX,SYMSIZE
	MOV	AX,HEAPENDVAL
	SUB	AX,[HEAP]		;Size of symbol table
	CALL	PRNT10
	MOV	BX,FRESIZE
	MOV	AX,[HEAP]
	SUB	AX,[CODE]		;Free space remaining
	CALL	PRNT10
	AND	BYTE [LSTDEV],0FEH	;Subsequent LIST output doesn't go to console.
	TEST	BYTE [FLAGS],HFLAG
	JZ	SYMDMP
	MOV	AL,[HEXCNT]
	CMP	AL,-5
	JZ	L0012
	CALL	ENHEXL
L0012:	
	MOV	AL,':'
	CALL	PUTCHR
	MOV	CH,10
HEXEND:
	PUSH	CX
	MOV	AL,'0'
	CALL	PUTCHR		;Also sets DI.
	POP	CX
	DEC	CH
	JNZ	HEXEND
	MOV	AL,13
	CALL	PUTCHR
	MOV	AL,10
	CALL	PUTCHR
	MOV	AL,1AH
	CALL	PUTCHR
	CALL	WRTHEX		;Flush HEX file buffer
	MOV	BX,HEXFD
	CALL	FFCLOSE		;Not reached if HFLAG is not active.
SYMDMP:
	TEST	BYTE [FLAGS],SFLAG
	JZ	ENDSYM
	MOV	AL,[LSTDEV]
	OR	AL,AL		;Any output device for symbol table dump?
	JNZ	DOSYMTAB
	OR	AL,1		;If not, send it to console
	MOV	[LSTDEV],AL
DOSYMTAB:
	MOV	BX,SYMMES
	CALL	PRINT
	MOV	DX,[BASE]
	MOV	AL,DH
	OR	AL,DL
	JZ	ENDSYM
	MOV	BYTE [SYMLIN],SYMWID  ;No symbols on this line yet
	MOV	BX,[HEAP]
	;MOV	SP,BX		;Need maximum stack for recursive tree walk. Linux stack is large enough, no need.
	CALL	NODE
	CALL	CRLF
ENDSYM:
	TEST	BYTE [LSTDEV],80H	;Print listing to file?
	JZ	EXIT		;Jump if not to file.
	MOV	AL,1AH
	CALL	WRTBUF		;Write end-of-file mark
	MOV	DI,[LSTPNT]
	CALL	FLUSHBUF
	MOV	BX,LSTFD
	CALL	FFCLOSE
EXIT:	CMP	WORD [ERRCNT], BYTE 0
	JE	EXITOK
EXERR:	PUSH	BYTE 2
	POP	EBX
	JP	EXITL
EXITOK:	XOR	EBX,EBX		;EXIT_SUCCESS.
EXITL:	XOR	EAX,EAX
	INC	EAX		;SYS_exit.
	CALL	FLUSHCON	;Also sets DX := 0.
	SYSCALL			;Linux or FreeBSD i386 syscall.

NODE:
	XCHG	BX,DX
	PUSH	BX
	MOV	DL,[EBX+data_base]
	MOV	DH,0
	INC	BX
	ADD	BX,DX
	MOV	DX,[EBX+data_base]
	OR	DX,DX
	JZ	L0014
	CALL	NODE
L0014:	
	POP	BX
	MOV	AL,[EBX+data_base]
	INC	BX
	MOV	CH,AL
	ADD	AL,24
	SHR	AL
	SHR	AL
	SHR	AL
	MOV	CL,AL
	INC	CL		;Invert last bit
	AND	CL,1		;Number of extra tabs needed (0 or 1)
	SHR	AL		;Number of positions wide this symbol needs
	SUB	[SYMLIN],AL
	JNC	WRTSYM		;Will it fit?
	SUB	AL,SYMWID
	NEG	AL
	MOV	[SYMLIN],AL
	CALL	CRLF		;Start new line if not
WRTSYM:
	MOV	AL,[EBX+data_base]
	INC	BX
	CALL	LIST
	DEC	CH
	JNZ	WRTSYM
	INC	CL
TABVAL:
	MOV	AL,9
	CALL	LIST
	LOOP	TABVAL		;LOOP (with ECX) is OK, because ECX is always positive here.
	INC	BX
	INC	BX
	PUSH	BX
	MOV	AL,[EBX+data_base+4]
	CALL	PHEX
	MOV	AL,[EBX+data_base+3]
	CALL	PHEX
	CMP	BYTE [SYMLIN],0	;Will any more fit on line?
	JZ	NEXSYMLIN
	MOV	AL,9
	CALL	LIST
	JP	RIGHTSON
NEXSYMLIN:
	CALL	CRLF
	MOV	BYTE [SYMLIN],SYMWID
RIGHTSON:
	POP	BX
	MOV	DX,[EBX+data_base]
	OR	DX,DX
	JNZ	NODE
	RET

SAVCD:
; Encode and append code or data byte in AL to the .hex and .lst files.
	MOV	[PREV],AL
	PUSH	BX
	PUSH	CX
	PUSH	AX
	PUSH	DX
	CALL	CODBYT
	POP	DX
	MOV	BX,COUNT
	INC	BYTE [EBX+data_base]
	MOV	AL,[EBX+data_base]
	CMP	AL,8
	JNZ	NOEXT
	MOV	BYTE [EBX+data_base],1
	CALL	OUTLIN
	MOV	AL,' '
	MOV	CH,5
TAB:
	CALL	LIST
	DEC	CH
	JNZ	TAB
NOEXT:
	POP	AX
	CALL	PHEXB
	POP	CX
	INC	WORD [PC]
	INC	WORD [HEXADD]
	POP	BX
RET16:	RET

REPERR:
	OR	AL,AL		;Did an error occur?
	JZ	RET16
	INC	WORD [ERRCNT]
	JNZ	ERRNOSAT
	DEC	WORD [ERRCNT]	;Saturate, don't let 65535+1 errors be 0, so we can use it as an exit code.
ERRNOSAT:
	PUSH	AX
	MOV	BX,ERRMES	;Print "ERROR"
	CALL	PRINT
	POP	AX
;We have error number in AL. See if there's an error message for it
	MOV	DI,ERRTAB
	MOV	BL,80H
ERRLOOK:
	SCASB			;Do we have the error message
	JBE	HAVMES		;Quit looking if we have it or passed it
	XCHG	AX,BX		;Put 80H in AL to look for end of this message
NEXTMES:
	SCASB			;Look for high bit set in message
	JA	NEXTMES		;   which means we've reached the end
	XCHG	AX,BX		;Restore error number to AL
	JMPS	ERRLOOK		;Keep looking

HAVMES:
	MOV	BX,DI		;Put address of message in BX
	JZ	PRNERR		;Do we have a message for this error?
	CALL	PHEX		;If not, just print error number
	JMP	CRLF

PRNERR:
	CALL	PRINT
	JMP	CRLF

PRINT:  ; Print high-bit-terminated string starting at BX.
	MOV	AL,[EBX+data_base]
	CALL	LIST
	OR	AL,AL
	JS	RET16
	INC	BX
	JP	PRINT
	MOV	DL,AL
	AND	DL,7FH
	CALL	PUTCHAR
RET17:	RET

WRITETOBIN:
;Writes a single byte in AL to the .bin file.
;Ruins: BX, CX, DX, DI, flags. Actually, it doesn't ruin CX or DI.
	MOV	DX,[BINPNT]
	CMP	DX,STRICT WORD BINBUFSIZ
	JNE	BINFLUSHED
	PUSH	ECX
	MOV	ECX,BINBUF
	PUSH	EAX
	MOV	BX,BINFD
	CALL	FFWRITED
	POP	EAX
	POP	ECX
	XOR	EDX,EDX
BINFLUSHED:
	MOV	[EDX+BINBUF],AL  ;Write AL to .bin file output buffer.
	INC	EDX		;`INC DX', but shorter. It won't overflow here.
	MOV	WORD [BINPNT],DX
	RET

CODBYT:
;Encode and append code or data byte in AL to the .bin and .hex files. Ruins BX.
;Ruins BX and DX etc.
	TEST	BYTE [STATE],STHASHEXADD
	JNZ	HASHEXADD1
	INC	BYTE [STATE]	;Set bit STHASHEXADD == 1.
	MOV	BX,[HEXADD]
	MOV	[OLDHEXADD],BX
	MOV	[MAXHEXADD],BX
	JP	HASHEXADD2
HASHEXADD1:
	PUSH	AX
	MOV	BX,[OLDHEXADD]
	MOV	DX,[HEXADD]
	;INC	BX
	CMP	BX,DX
	JE	DONEHEXADD	;No need to seek or to add bytes.
	; Seek forward or backward in the .bin file.
	CMP	DX,[MAXHEXADD]
	JNA	FULLSEEKHEXADD
	MOV	DX,[MAXHEXADD]
FULLSEEKHEXADD:
	PUSH	EDX		;Save, will be restored to EBX.
	SUB	EDX,EBX		;Result can be positive or negative.
	CALL	FLUSHBINRELSEEK
	POP	EBX		;Restore.
	XOR	EDX,EDX		;Ensure that the high word is 0.
NULXHEXADD:
	; Write a bunch of NUL or bytes to the .bin file, previously skipped by ALIGN and DS.
	MOV	AL,0
	TEST	BYTE [FLAGS],XFLAG
	JZ	NEXTHEXADD
	MOV	AL,'X'
NEXTHEXADD:
	CMP	BX,[HEXADD]	;DX doesn't contain [HEXADD] anymore, WRITETOBIN may have ruined it.
	JE	DONEHEXADD
	PUSH	BX
	CALL	WRITETOBIN	;Write NUL or 'X' byte.
	POP	BX
	INC	BX
	JP	NEXTHEXADD
DONEHEXADD:
	INC	BX
	MOV	[OLDHEXADD],BX
	CMP	BX,[MAXHEXADD]
	JNA	KEEPMAXHEXADD
	MOV	[MAXHEXADD],BX
KEEPMAXHEXADD:
	DEC	BX
	POP	AX
HASHEXADD2:
	; Then write AL to the .bin file.
	CALL	WRITETOBIN
	; Then write AL to the .hex file.
	TEST	BYTE [FLAGS],HFLAG
	JZ	RET17		;No .hex file, skip write.
	PUSH	AX
	MOV	DX,[LASTAD]
	MOV	BX,[HEXADD]
	MOV	[LASTAD],BX
	INC	DX
	MOV	AL,[HEXCNT]
	CMP	AL,-5
	JZ	NEWLIN
	CMP	BX,DX
	JZ	AFHEX
	CALL	ENHEXL
NEWLIN:
	MOV	AL,':'
	CALL	PUTCHR
	MOV	AL,-4
	MOV	[HEXCNT],AL
	XOR	AL,AL
	MOV	[CHKSUM],AL
	MOV	BX,[HEXPNT]
	MOV	[HEXLEN],BX
	CALL	HEXBYT
	MOV	AL,[HEXADD+1]
	CALL	HEXBYT
	MOV	AL,[HEXADD]
	CALL	HEXBYT
	XOR	AL,AL
	CALL	HEXBYT
AFHEX:
	POP	AX
HEXBYT:  ; We may ruin CH here.
	ADD	[CHKSUM],AL
	PUSH	EAX		;Save AL.
	CALL	UHALF
	CALL	PUTCHR
	POP	EAX		;Restore AL.
	CALL	LHALF
	CALL	PUTCHR
	INC	BYTE [HEXCNT]
	MOV	AL,[HEXCNT]
	CMP	AL,26
	JNZ	RET17
ENHEXL:  ; Writes the length byte. We may ruin CH here.
	MOV	DI,[HEXLEN]
	PUSH	EAX		;Save AL.
	AAM	10H
	CALL	LHALF
	XCHG	AL,AH
	CALL	LHALF
	MOV	[EDI+HEXBUF-data_base],AX  ;Write 2 nibbles of length byte.
	POP	EAX		;Restore AL.
	MOV	BYTE [HEXCNT],-6
	ADD	AL,[CHKSUM]
	NEG	AL
	CALL	HEXBYT
	MOV	AL,13
	CALL	PUTCHR
	MOV	AL,10
	CALL	PUTCHR
WRTHEX:
;Flush HEX file buffer between HEXBUF and DI (assuming DI == WORD [HEXPNT]
;<= WORD [HEXLEN]) to the .hex file HEXFD. The contents of HEXBUF now
;already contains a single line (up to 1AH raw bytes) encoded in Intel HEX
;format, starting with ':' and ending with CRLF.
;
;Ruins AX, BX, CX, DX, DI etc.
	;PUSH	BX
	MOV	BX,HEXFD
	PUSH	ECX
	MOV	ECX,HEXBUF
	MOV	DX,DI
	CALL	FFWRITED
	POP	ECX
	;POP	BX
	AND	WORD [HEXPNT],BYTE 0
	RET

PUTCHR:
	MOV	DI,[HEXPNT]
	MOV	[EDI+HEXBUF-data_base],AL
	INC	EDI		;`INC DI', but shorter. It won't overflow here.
	MOV	[HEXPNT],DI
RET20:	RET

FLUSHBUF:
;As a side effect, sets DI := 0.
;
;Ruins AX, BX, CX, DX etc.
	TEST	EDI,EDI
	JZ	RET20		;Buffer empty?
	MOV	DX,DI
	XOR	DI,DI
	;PUSH	BX
	MOV     BX,LSTFD
	PUSH	ECX
	MOV	ECX,LSTBUF
	CALL	FFWRITED
	POP	ECX
	;POP	BX
	RET

UHALF:
	SHR	AL,4
LHALF:
	AND	AL,0FH
	OR	AL,30H
	CMP	AL,'9'+1
	JC	RET20
	ADD	AL,7
	RET

; --- .rodata which can be below the big 64 KiB.
;
; It's mostly messages printed by PRINTMSGD, which has the MOVSX, so it
; doesn't require the big 64 KiB for address calculations.

NOSPAC:	DB	13,10,'File creation error',13,10,"$"
NOMEM:	DB	13,10,'Insufficient memory',13,10,'$'
NOFILE:	DB	13,10,'File not found',13,10,'$'
WRTERR:	DB	13,10,'Write error',13,10,'$'
RDERR:	DB	13,10,'Read error',13,10,'$'
BADDSK:	DB	13,10,'Bad disk specifier',13,10,'$'

; --- .rodata

; Check that the amount of headers+code so far is at least code1_size bytes.
; We need that, so that data (with .rodata) can start at data_base + a low
; 16-bit offset.
%if -($-$$-code1_size)<100 && -($-$$-code1_size)>0
; This is a hack for `nasm -O9...'. Without that, the times below would be
; -2 in the first pass. In subsequent passes and with `nasm -O0', the %if
; above is false, so this `times ... nop' is not done.
times -($-$$-code1_size) nop
%endif
times ($-$$-code1_size) times 0 nop

; Error message table.
ERRTAB:
	DM	1,"Register not allowed in immediate valu", "e"
	DM	2,"Index or base register must be BP, BX, SI, or D", "I"
	DM	3,"Only one base register (BX, BP) allowe", "d"
	DM	4,"Only one index register (SI or DI) allowe", "d"
	DM	5,"Only addition allowed on register or undefined labe", "l"
	DM	6,"Only one undefined label per expression allowe", "d"
	DM	7,"Illegal digit in hexadecimal numbe", "r"
	DM	8,"Illegal digit in decimal numbe", "r"
	DM	10,"Illegal character in label or opcod", "e"
	DM	11,"Label defined twic", "e"
	DM	12,"Opcode not recognize", "d"
	DM	20,"Invalid operan", "d"
	DM	21,,'"," and second operand expecte', 'd'
	DM	22,"Register mismatc", "h"
	DM	23,"Immediate operand not allowe", 'd'
	DM	24,'"]" expecte', 'd'
	DM	25,"Two memory operands not allowe", "d"
	DM	26,"Destination must not be immediate valu", "e"
	DM	27,"Both operands must not be register", "s"
	DM	28,"Operand must be segment registe", "r"
	DM	29,"First operand must be registe", "r"
	DM	30,"Undefined label not allowe", "d"
	DM	31,"Value out of rang", "e"
	DM	32,"Missing or illegal operand size fla", "g"
	DM	33,"Must have label on same lin", "e"
	DM	35,"Zero-length string illega", "l"
	DM	36,"ENDIF without I", "F"
	DM	37,"One-character strings onl", "y"
	DM	38,"Illegal expressio", "n"
	DM	39,"End of string not foun", "d"
	DM	100,"Undefined labe", "l"
	DM	101,"Value out of range (forward", ")"
	DB	255

ERRMES:	DM	'***** ERROR: ', ' '
ERCNTM:	DM	13,10,13,10,'Error Count ', '='
SYMSIZE	DM	13,10,'Symbol Table size =', ' '
FRESIZE	DM	'Free space =       ', ' '
SYMMES:	DM	13,10,'Symbol Table',13,10
IFEND:	DB	5,'endif'
IFNEST:	DB	2,'if'
REGTAB:	DB	'bdca'
SEGTAB:	DB	'dsce'
FLGTAB:	DB	'tlswb'
FORMATTAB:
;There are 16 entries in this table. The 4-bit index is built like this:
;	Bit 3		0 for normal memory ops, 1 if extended is OK
;	Bit 2		0 for integer, 1 for real
;	Bit 0 & 1	Flag: 00=W, 01=S, 10=L, 11=T
;
;The entries in the table are used as two 3-bit fields. Bits 0-2 are ORed
;into the first byte of the opcode for the Memory Format field. Bits 3-6
;are ORed into the second byte to modify the opcode for extended operands.
;If bit 7 is set, then that combination is illegal.
	DB	6,2,80H,80H	;Normal integers
	DB	80H,0,4,80H	;Normal reals
	DB	6,2,2EH,80H	;Extended integers
	DB	80H,0,4,2BH	;Extended reals

; 8086 MNEMONIC TABLE

; This table is actually a sequence of subtables, each starting with a label.
; The label signifies which mnemonics the subtable applies to--A3, for example,
; means all 3-letter mnemonics beginning with A.

A3:
	DB	7
	DB	'dd'
	DW	GRP7-func_base
	DB	2
	DB	'nd'
	DW	GRP13-func_base
	DB	22H
	DB	'dc'
	DW	GRP7-func_base
	DB	12H
	DB	'aa'
	DW	$PUT-func_base
	DB	37H
	DB	'as'
	DW	$PUT-func_base
	DB	3FH
	DB	'am'
	DW	GRP11-func_base
	DB	0D4H
	DB	'ad'
	DW	GRP11-func_base
	DB	0D5H
A5:
	DB	1
	DB	'lign'
	DW	$ALIGN-func_base
	DB	0
C3:
	DB	7
	DB	'mp'
	DW	GRP7-func_base
	DB	3AH
	DB	'lc'
	DW	$PUT-func_base
	DB	0F8H
	DB	'ld'
	DW	$PUT-func_base
	DB	0FCH
	DB	'li'
	DW	$PUT-func_base
	DB	0FAH
	DB	'mc'
	DW	$PUT-func_base
	DB	0F5H
	DB	'bw'
	DW	$PUT-func_base
	DB	98H
	DB	'wd'
	DW	$PUT-func_base
	DB	99H
C4:
	DB	3
	DB	'all'
	DW	GRP14-func_base
	DB	9AH
	DB	'mpb'
	DW	$PUT-func_base
	DB	0A6H
	DB	'mpw'
	DW	$PUT-func_base
	DB	0A7H
C5:
	DB	2
	DB	'mpsb'
	DW	$PUT-func_base
	DB	0A6H
	DB	'mpsw'
	DW	$PUT-func_base
	DB	0A7H
D2:
	DB	5
	DB	'b'
	DW	GRP23-func_base
	DB	1
	DB	'w'
	DW	GRP23-func_base
	DB	0
	DB	'm'
	DW	GRP23-func_base
	DB	2
	DB	's'
	DW	GRP5-func_base
	DB	1
	DB	'i'
	DW	$PUT-func_base
	DB	0FAH
D3:
	DB	4
	DB	'ec'
	DW	GRP8-func_base
	DB	49H
	DB	'iv'
	DW	GRP10-func_base
	DB	30H
	DB	'aa'
	DW	$PUT-func_base
	DB	27H
	DB	'as'
	DW	$PUT-func_base
	DB	2FH
D4:
	DB	1
	DB	'own'
	DW	$PUT-func_base
	DB	0FDH
E2:
	DB	1
	DB	'i'
	DW	$PUT-func_base
	DB	0FBH
E3:
	DB	3
	DB	'qu'
	DW	GRP5-func_base
	DB	2
	DB	'sc'
	DW	GRP19-func_base
	DB	0D8H
	DB	'nd'
	DW	END-func_base
	DB	0
E5:
	DB	1
	DB	'ndif'
	DW	ENDIF-func_base
	DB	0
H3:
	DB	1
	DB	'lt'
	DW	$PUT-func_base
	DB	0F4H
H4:
	DB	1
	DB	'alt'
	DW	$PUT-func_base
	DB	0F4H
I2:
	DB	2
	DB	'n'
	DW	GRP4-func_base
	DB	0E4H
	DB	'f'
	DW	GRP5-func_base
	DB	4
I3:
	DB	4
	DB	'nc'
	DW	GRP8-func_base
	DB	41H
	DB	'nb'
	DW	GRP4-func_base
	DB	0E4H
	DB	'nw'
	DW	GRP4-func_base
	DB	0E5H
	DB	'nt'
	DW	GRP18-func_base
	DB	0CCH
I4:
	DB	4
	DB	'mul'
	DW	GRP10-func_base
	DB	28H
	DB	'div'
	DW	GRP10-func_base
	DB	38H
	DB	'ret'
	DW	$PUT-func_base
	DB	0CFH
	DB	'nto'
	DW	$PUT-func_base
	DB	0CEH
J2:
	DB	10
	DB	'p'
	DW	GRP17-func_base
	DB	0EBH
	DB	'z'
	DW	GRP17-func_base
	DB	74H
	DB	'e'
	DW	GRP17-func_base
	DB	74H
	DB	'l'
	DW	GRP17-func_base
	DB	7CH
	DB	'b'
	DW	GRP17-func_base
	DB	72H
	DB	'a'
	DW	GRP17-func_base
	DB	77H
	DB	'g'
	DW	GRP17-func_base
	DB	7FH
	DB	'o'
	DW	GRP17-func_base
	DB	70H
	DB	's'
	DW	GRP17-func_base
	DB	78H
	DB	'c'
	DW	GRP17-func_base
	DB	72H
J3:
	DB	17
	DB	'mp'
	DW	GRP14-func_base
	DB	0EAH
	DB	'nz'
	DW	GRP17-func_base
	DB	75H
	DB	'ne'
	DW	GRP17-func_base
	DB	75H
	DB	'nl'
	DW	GRP17-func_base
	DB	7DH
	DB	'ge'
	DW	GRP17-func_base
	DB	7DH
	DB	'nb'
	DW	GRP17-func_base
	DB	73H
	DB	'ae'
	DW	GRP17-func_base
	DB	73H
	DB	'nc'
	DW	GRP17-func_base
	DB	73H
	DB	'ng'
	DW	GRP17-func_base
	DB	7EH
	DB	'le'
	DW	GRP17-func_base
	DB	7EH
	DB	'na'
	DW	GRP17-func_base
	DB	76H
	DB	'be'
	DW	GRP17-func_base
	DB	76H
	DB	'pe'
	DW	GRP17-func_base
	DB	7AH
	DB	'np'
	DW	GRP17-func_base
	DB	7BH
	DB	'po'
	DW	GRP17-func_base
	DB	7BH
	DB	'no'
	DW	GRP17-func_base
	DB	71H
	DB	'ns'
	DW	GRP17-func_base
	DB	79H
J4:
	DB	6
	DB	'mps'
	DW	GRP17-func_base
	DB	0EBH
	DB	'cxz'
	DW	GRP17-func_base
	DB	0E3H
	DB	'nge'
	DW	GRP17-func_base
	DB	7CH
	DB	'nae'
	DW	GRP17-func_base
	DB	72H
	DB	'nbe'
	DW	GRP17-func_base
	DB	77H
	DB	'nle'
	DW	GRP17-func_base
	DB	7FH
L3:
	DB	3
	DB	'ea'
	DW	GRP6-func_base
	DB	8DH
	DB	'ds'
	DW	GRP6-func_base
	DB	0C5H
	DB	'es'
	DW	GRP6-func_base
	DB	0C4H
L4:
	DB	5
	DB	'oop'
	DW	GRP17-func_base
	DB	0E2H
	DB	'odb'
	DW	$PUT-func_base
	DB	0ACH
	DB	'odw'
	DW	$PUT-func_base
	DB	0ADH
	DB	'ahf'
	DW	$PUT-func_base
	DB	9FH
	DB	'ock'
	DW	$PUT-func_base
	DB	0F0H
L5:
	DB	4
	DB	'oope'
	DW	GRP17-func_base
	DB	0E1H
	DB	'oopz'
	DW	GRP17-func_base
	DB	0E1H
	DB	'odsb'
	DW	$PUT-func_base
	DB	0ACH
	DB	'odsw'
	DW	$PUT-func_base
	DB	0ADH
L6:
	DB	2
	DB	'oopne'
	DW	GRP17-func_base
	DB	0E0H
	DB	'oopnz'
	DW	GRP17-func_base
	DB	0E0H
M3:
	DB	2
	DB	'ov'
	DW	GRP1-func_base
	DB	88H
	DB	'ul'
	DW	GRP10-func_base
	DB	20H
M4:
	DB	2
	DB	'ovb'
	DW	$PUT-func_base
	DB	0A4H
	DB	'ovw'
	DW	$PUT-func_base
	DB	0A5H
M5:
	DB	2
	DB	'ovsb'
	DW	$PUT-func_base
	DB	0A4H
	DB	'ovsw'
	DW	$PUT-func_base
	DB	0A5H
N3:
	DB	3
	DB	'ot'
	DW	GRP9-func_base
	DB	10H
	DB	'eg'
	DW	GRP9-func_base
	DB	18H
	DB	'op'
	DW	$PUT-func_base
	DB	90H
O2:
	DB	1
	DB	'r'
	DW	GRP13-func_base
	DB	0AH
O3:
	DB	2
	DB	'ut'
	DW	GRP4-func_base
	DB	0E6H
	DB	'rg'
	DW	GRP5-func_base
NUL:	DB	0
O4:
	DB	2
	DB	'utb'
	DW	GRP4-func_base
	DB	0E6H
	DB	'utw'
	DW	GRP4-func_base
	DB	0E7H
P3:
	DB	2
	DB	'op'
	DW	GRP22-func_base
	DB	8FH
	DB	'ut'
	DW	GRP5-func_base
	DB	3
P4:
	DB	2
	DB	'ush'
	DW	GRP2-func_base
	DB	0FFH
	DB	'opf'
	DW	$PUT-func_base
	DB	9DH
P5:
	DB	1
	DB	'ushf'
	DW	$PUT-func_base
	DB	9CH
R3:
	DB	6
	DB	'et'
	DW	GRP16-func_base
	DB	0C3H
	DB	'ep'
	DW	$PUT-func_base
	DB	0F3H
	DB	'ol'
	DW	GRP12-func_base
	DB	0
	DB	'or'
	DW	GRP12-func_base
	DB	8
	DB	'cl'
	DW	GRP12-func_base
	DB	10H
	DB	'cr'
	DW	GRP12-func_base
	DB	18H
R4:
	DB	2
	DB	'epz'
	DW	$PUT-func_base
	DB	0F3H
	DB	'epe'
	DW	$PUT-func_base
	DB	0F3H
R5:
	DB	2
	DB	'epnz'
	DW	$PUT-func_base
	DB	0F2H
	DB	'epne'
	DW	$PUT-func_base
	DB	0F2H
S3:
	DB	11
	DB	'ub'
	DW	GRP7-func_base
	DB	2AH
	DB	'bb'
	DW	GRP7-func_base
	DB	1AH
	DB	'bc'
	DW	GRP7-func_base
	DB	1AH
	DB	'tc'
	DW	$PUT-func_base
	DB	0F9H
	DB	'td'
	DW	$PUT-func_base
	DB	0FDH
	DB	'ti'
	DW	$PUT-func_base
	DB	0FBH
	DB	'hl'
	DW	GRP12-func_base
	DB	20H
	DB	'hr'
	DW	GRP12-func_base
	DB	28H
	DB	'al'
	DW	GRP12-func_base
	DB	20H
	DB	'ar'
	DW	GRP12-func_base
	DB	38H
	DB	'eg'
	DW	GRP21-func_base
	DB	26H
S4:
	DB	5
	DB	'cab'
	DW	$PUT-func_base
	DB	0AEH
	DB	'caw'
	DW	$PUT-func_base
	DB	0AFH
	DB	'tob'
	DW	$PUT-func_base
	DB	0AAH
	DB	'tow'
	DW	$PUT-func_base
	DB	0ABH
	DB	'ahf'
	DW	$PUT-func_base
	DB	9EH
S5:
	DB	4
	DB	'casb'
	DW	$PUT-func_base
	DB	0AEH
	DB	'casw'
	DW	$PUT-func_base
	DB	0AFH
	DB	'tosb'
	DW	$PUT-func_base
	DB	0AAH
	DB	'tosw'
	DW	$PUT-func_base
	DB	0ABH
T4:
	DB	1
	DB	'est'
	DW	GRP20-func_base
	DB	84H
U2:
	DB	1
	DB	'p'
	DW	$PUT-func_base
	DB	0FCH
W4:
	DB	1
	DB	'ait'
	DW	$PUT-func_base
	DB	9BH
X3:
	DB	1
	DB	'or'
	DW	GRP13-func_base
	DB	32H
X4:
	DB	2
	DB	'chg'
	DW	GRP3-func_base
	DB	86H
	DB	'lat'
	DW	$PUT-func_base
	DB	0D7H


; 8087 MNEMONIC TABLE
; Similar to 8086 table above, except NOT distinguished by opcode length

XM1:	;F2XM1
	DB	1		;One opcode
	DM	"xm", "1"
	DB	1,0F0H

NDPA:
	DB	3
	DM	"d", "d"
	DB	6+ARITH,0C1H
	DM	"dd", "p"
	DB	NEEDOP+STACKOP,0
	DM	"b", "s"
	DB	1,0E1H

NDPB:
	DB	2
	DM	"l", "d"
	DB	7+NEEDOP+MEMORY,20H
	DM	"st", "p"
	DB	7+NEEDOP+MEMORY,30H

NDPC:
	DB	5
	DM	"o", "m"
	DB	0+ONEREG+REAL,0D1H
	DM	"om", "p"
	DB	0+ONEREG+REAL,0D9H
	DM	"h", "s"
	DB	1,0E0H
	DM	"omp", "p"
	DB	6,0D9H
	DM	"le", "x"
	DB	3,0E2H

NDPD:
	DB	6
	DM	"i", "v"
	DB	6+ARITH,0F1H
	DM	"iv", "p"
	DB	NEEDOP+STACKOP,30H
	DM	"iv", "r"
	DB	6+ARITH,0F9H
	DM	"ivr", "p"
	DB	NEEDOP+STACKOP,38H
	DM	"ecst", "p"
	DB	1,0F6H
	DM	"is", "i"
	DB	3,0E1H

NDPE:
	DB	1
	DM	"n", "i"
	DB	3,0E0H

NDPF:
	DB	1
	DM	"re", "e"
	DB	5+NEEDOP+ONEREG,0

NDPI:
	DB	13
	DM	"ad", "d"
	DB	2+NEEDOP+INTEGER,0
	DM	"l", "d"
	DB	3+NEEDOP+INTEGER+EXTENDED,0
	DM	"su", "b"
	DB	2+NEEDOP+INTEGER,20H
	DM	"st", "p"
	DB	3+NEEDOP+INTEGER+EXTENDED,18H
	DM	"s", "t"
	DB	3+NEEDOP+INTEGER,10H
	DM	"mu", "l"
	DB	2+NEEDOP+INTEGER,8
	DM	"di", "v"
	DB	2+NEEDOP+INTEGER,30H
	DM	"sub", "r"
	DB	2+NEEDOP+INTEGER,28H
	DM	"div", "r"
	DB	2+NEEDOP+INTEGER,38H
	DM	"co", "m"
	DB	2+NEEDOP+INTEGER,10H
	DM	"com", "p"
	DB	2+NEEDOP+INTEGER,18H
	DM	"ncst", "p"
	DB	1,0F7H
	DM	"ni", "t"
	DB	3,0E3H

NDPL:
	DB	10
	DM	"", "d"
	DB	1+NEEDOP+ONEREG+REAL+EXTENDED,0
	DM	"d", "z"
	DB	1,0EEH
	DM	"d", "1"
	DB	1,0E8H
	DM	"dp", "i"
	DB	1,0EBH
	DM	"dl2", "t"
	DB	1,0E9H
	DM	"dl2", "e"
	DB	1,0EAH
	DM	"dlg", "2"
	DB	1,0ECH
	DM	"dln", "2"
	DB	1,0EDH
	DM	"dc", "w"
	DB	1+NEEDOP+MEMORY,28H
	DM	"den", "v"
	DB	1+NEEDOP+MEMORY,20H

NDPM:
	DB	2
	DM	"u", "l"
	DB	6+ARITH,0C9H
	DM	"ul", "p"
	DB	NEEDOP+STACKOP,8

NDPO:
	DB	1
	DM	"", "p"
	DB	NEEDOP+1,0	;Flag special handling

NDPN:
	DB	1
	DM	"o", "p"
	DB	1,0D0H

NDPP:
	DB	3
	DM	"re", "m"
	DB	1,0F8H
	DM	"ta", "n"
	DB	1,0F2H
	DM	"ata", "n"
	DB	1,0F3H

NDPR:
	DB	2
	DM	"ndin", "t"
	DB	1,0FCH
	DM	"sto", "r"
	DB	5+NEEDOP+MEMORY,20H

NDPS:
	DB	12
	DM	"", "t"
	DB	5+NEEDOP+ONEREG+REAL,0D0H
	DM	"t", "p"
	DB	7+NEEDOP+ONEREG+REAL+EXTENDED,0D8H
	DM	"u", "b"
	DB	6+ARITH,0E1H
	DM	"ub", "p"
	DB	NEEDOP+STACKOP,0E0H
	DM	"ub", "r"
	DB	6+ARITH,0E9H
	DM	"ubr", "p"
	DB	NEEDOP+STACKOP,0E8H
	DM	"qr", "t"
	DB	1,0FAH
	DM	"cal", "e"  ; This is `fscale". There is no `fsin". that appeared in the 387 (https://www2.math.uni-wuppertal.de/~fpf/Uebungen/GdR-SS02/opcode_f.html).
	DB	1,0FDH
	DM	"av", "e"
	DB	5+NEEDOP+MEMORY,30H
	DM	"tc", "w"
	DB	1+NEEDOP+MEMORY,38H
	DM	"ten", "v"
	DB	1+NEEDOP+MEMORY,30H
	DM	"ts", "w"
	DB	5+NEEDOP+MEMORY,38H

NDPT:
	DB	1
	DM	"s", "t"
	DB	1,0E4H

NDPW:
	DB	1
	DM	"ai", "t"
	DB	NEEDOP,0	;Flag special handling

NDPX:
	DB	3
	DM	"c", "h"
	DB	1+ONEREG,0C9H
	DM	"a", "m"
	DB	1,0E5H
	DM	"trac", "t"
	DB	1,0F4H

NDPY:
	DB	2
	DM	"l2", "x"
	DB	1,0F1H
	DM	"l2xp", "1"
	DB	1,0F9H

	align 2
OPTAB:
; Table of pointers  to mnemonics. For each letter of the alphabet (the
; starting letter of the mnemonic), there are 5 entries. Each entry
; corresponds to a mnemonic whose length is 2, 3, 4, 5, and 6 characters
; long, respectively. If there are no mnemonics for a given combination
; of first letter and length (such as A-2), then the corresponding entry
; points to NONE. Otherwise, it points to a place in the mnemonic table
; for that type.

; This table only needs to be modified if a mnemonic is added to a group
; previously marked NONE. Change the NONE to a label made up of the first
; letter of the mnemonic and its length, then add a new subsection to
; the mnemonic table in alphabetical order.

	check_align_2
	DW	NONE
	DW	A3
	DW	NONE
	DW	A5
	DW	NONE
	DW	NONE	;B
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;C
	DW	C3
	DW	C4
	DW	C5
	DW	NONE
	DW	D2	;D
	DW	D3
	DW	D4
	DW	NONE
	DW	NONE
	DW	E2	;E
	DW	E3
	DW	NONE
	DW	E5
	DW	NONE
	DW	NONE	;F
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;G
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;H
	DW	H3
	DW	H4
	DW	NONE
	DW	NONE
	DW	I2	;I
	DW	I3
	DW	I4
	DW	NONE
	DW	NONE
	DW	J2	;J
	DW	J3
	DW	J4
	DW	NONE
	DW	NONE
	DW	NONE	;K
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;L
	DW	L3
	DW	L4
	DW	L5
	DW	L6
	DW	NONE	;M
	DW	M3
	DW	M4
	DW	M5
	DW	NONE
	DW	NONE	;N
	DW	N3
	DW	NONE
	DW	NONE
	DW	NONE
	DW	O2	;O
	DW	O3
	DW	O4
	DW	NONE
	DW	NONE
	DW	NONE	;P
	DW	P3
	DW	P4
	DW	P5
	DW	NONE
	DW	NONE	;Q
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;R
	DW	R3
	DW	R4
	DW	R5
	DW	NONE
	DW	NONE	;S
	DW	S3
	DW	S4
	DW	S5
	DW	NONE
	DW	NONE	;T
	DW	NONE
	DW	T4
	DW	NONE
	DW	NONE
	DW	U2	;U
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;V
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;W
	DW	NONE
	DW	W4
	DW	NONE
	DW	NONE
	DW	NONE	;X
	DW	X3
	DW	X4
	DW	NONE
	DW	NONE
	DW	NONE	;Y
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE	;Z
	DW	NONE
	DW	NONE
	DW	NONE
	DW	NONE

NDPTAB:
;Lookup table for 8087 mnemonics. There is one entry for each letter of the
;alphabet
	DW	NDPA
	DW	NDPB
	DW	NDPC
	DW	NDPD
	DW	NDPE
	DW	NDPF
	DW	NONE	;G
	DW	NONE	;H
	DW	NDPI
	DW	NONE	;J
	DW	NONE	;K
	DW	NDPL
	DW	NDPM
	DW	NDPN
	DW	NDPO
	DW	NDPP
	DW	NONE	;Q
	DW	NDPR
	DW	NDPS
	DW	NDPT
	DW	NONE	;U
	DW	NONE	;V
	DW	NDPW
	DW	NDPX
	DW	NDPY
	DW	NONE	;Z

; --- .data

	check_align_2
FPUINSTSTRUC:	DW FPUINST-func_base  ; The next 2 byte don't matter, they are read-only.
BUFPT:	DW	SRCBUFSIZ
CODE:	DW	START+1
IY:	DW	START
UNGETP:	DW	UNGET
LSTRET:	DW	-1
BCOUNT:	DW	4

; --- .bss

; Limit total code+data size to less than 32 KiB. This is needed for the
; MOVSX+ADD instructions to compute the correct dword-sized address from a
; word-sized address.
times 7fffh-($-$$) times 0 nop

BSS:	EQU $+(($$-$)&3)  ; Move forward, align to 2 for fast STOW.
; USAGE will be overwritten by NUL bytes for .bss variables.
USAGE:	DB	'Usage: asm244i <input>[.asm] [[-]flag...]',13,10  ; `/' instead of `-' would not work with 86-DOS filename parser.
	DB	'Output file is <input>.com or <input>.bin',13,10
	DB	'Flags:',13,10
	DB	'l generate listing file (<input>.lst)',13,10
	;DB	'e generate listing file, but errors to console only',13,10  ; This wasn't implemented even asm244.asm.
	;DB	'p generate listing to printer',13,10  ; Not implemented on Linux.
	DB	'c generate listing to console',13,10
	DB	'h generate Intel HEX file (.hex)',13,10
	DB	's generate symbol listing',13,10
	DB	'n emit instructions understood by ndisasm(1)',13,10
	DB	'x emit X instead of NUL for DS bytes',13,10
	DB	'p do not assume initial PUT 100H+DB',13,10
	;DB	'1 use DOS >=1.x or 86-DOS >=1.10 ABI',13,10  ; Not applicable on Linux.
	DB	'$'

BSS0:	absolute $  ; NASM: don't emit any more bytes, start .bss.
; First add .bss variables which don't benefit from word alignment.
bssvar FLAG, 1
bssvar MAXFLG, 1
bssvar CHR, 1
bssvar SYM, 1
bssvar SYMLIN, 1
bssvar DATSIZ, 1
bssvar RELOC, 1
bssvar COUNT, 1
bssvar ERR, 1  ; Error code for the current line. Used in pass 2 only.
bssvar HEXCNT, 1
bssvar CHKSUM, 1
bssvar LINFLG, 1
bssvar PREV, 1
bssvar IFFLG, 1
bssvar CHKLAB, 1
bssvar FLAGS, 1  ; A bitmask of SFLAG, HFLAG, NFLAG. Must preced LSTDEV.
bssvar LSTDEV, 1
bssvar SPC, 1
bssvar NOWAIT, 1
bssvar NEXTCHRSTATE, 1
bssvar STATE, 1
bssvar UNGET, 6
bssvar NONE, 1
bssvar LENID, 1  ; Must predede ID.
bssvar ID, 80  ; Must come after LENID.

bss_align 2  ; Then add .bss variables which get a speed benefit from word alignment.
bssvar ORGV, 2
bssvar PC, 2
bssvar OLDPC, 2
bssvar LABPT, 2
bssvar ADDR, 2
bssvar ALABEL, 2
bssvar DATA, 2
bssvar DLABEL, 2
bssvar CON, 2
bssvar UNDEF, 2
bssvar BASE, 2
bssvar HEAP, 2
bssvar LINE, 2
bssvar HEXLEN, 2
bssvar HEXADD, 2
bssvar LASTAD, 2
bssvar ERRCNT, 2
bssvar RETPT, 2
bssvar OLDHEXADD, 2
bssvar MAXHEXADD, 2
bssvar IX, 2
bssvar HEXPNT, 2
bssvar LSTPNT, 2
bssvar BINPNT, 2
bssvar CONPNT, 4  ; Number pending bytes CONFLUSH has to flush to stdout.
bssvar LINEREADC, 2  ; Number of lines read from the source file in pass 2.
bssvar EXPRSTACKLIMIT, 4

bssvar BSS1, 0  ; From here on it's not necessary to initialize .bss variables with NUL.

bss_align 4
bssvar SRCEXTSAVE, 4
bssvar SRCEXT, 4
bssvar SRCFN, 0  ; Same as STACKEND.
bssvar STACKEND, 4
bssvar SRCFD, 4
bssvar HEXFD, 4
bssvar BINFD, 4
bssvar LSTFD, 4
%ifdef FREEBSD
bssvar ISFREEBSD, 1  ; Is the program running on FreeBSD (rather than Linux)?
%endif

bss_align 2  ; The stack gets a speed benefit from word alignment.
bssvar START, 0

resb ($$-$+code1_size)&0ffffh  ; Use all 64 KiB. After .bss, it will be the patch table and the symbol table.
; Variables below are further away than 64 KiB from $$, so they cannot be accessed using a word-sized addresse.
SRCBUF:	resb SRCBUFSIZ
BINBUF:	resb BINBUFSIZ
LSTBUF:	resb LSTBUFSIZ
HEXBUF: resb HEXBUFSIZ  ; This is a short buffer, it gets flushed for each output line (<=26 data bytes) in the .hex file.
CONBUF: resb CONBUFSIZ

mem_end:
