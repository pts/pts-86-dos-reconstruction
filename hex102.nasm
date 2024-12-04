;
; hex102.nasm: NASM port of the SCP hex-to-bin conversion tool 1.02
; originally written by Tim Paterson between 1979 and 1983-05-09
; NASM port by pts@fazekas.hu started on 2024-11-26
;
; Compile with: nasm -o hex102n.com hex102.nasm
; Compile with: nasm -w+orphan-labels -f bin -O0 -o hex102n.com hex102.nasm
; It produces identical output with `nasm -O0' and `nasm -O999999999'.
; It compiles with NASM >=0.97. Recommended: NASM >=0.98.39.
; The output hex102n.com is bitwise identical to hex102.com (which is the
; output of asm244.com and hex102.asm from hex102.asm).
;
; [MIT License](https://github.com/microsoft/MS-DOS/blob/main/LICENSE)
;
; --- NASM compatibility by pts@fazekas.hu at Tue Nov 26 18:56:58 CET 2024
;
; There are 32 bytes of instruction encoding differences between
; asm244m.com and asm244n.com with -DNASMINST. Without -DNASMINST, they are
; identical.
;

;%undef IS_MODERN_NASM  ; NASM 0.97 doesn't have %undef.
%ifdef __NASM_SUBMINOR__
  %ifndef NO_MODERN_NASM
    %if __NASM_MAJOR__>0 || __NASM_MINOR__>98 || __NASM_SUBMINOR__>=39
      %define IS_MODERN_NASM  ; NASM >=0.98.39 is considered modern.
    %endif
  %endif
%endif

bits 16
%macro _JMP 1
  jmp strict near %1
%endm
%macro __JMP 1  ; Fallback for NASM 0.97: it doesn't support `jmp strict short LABEL'.
  db 0xe9
  dw (%1)-$-2
%endm
%ifdef IS_MODERN_NASM
  cpu 8086
%else  ; Use fallbacks on non-modern NASM.
  %define _JMP __JMP
%endif

%macro PUT 1
%endm

%macro JP 1
  jmp short %1
%endm

%macro SEG 1
  %1
%endm

%macro SHL 1
  shl %1, 1
%endm
%macro SHL 2  ; Pacify NASM 2.13.02 -w+macro-params.
  shl %1, %2
%endm

%macro SHR 1
  shr %1, 1
%endm

%define LODB lodsb
%define LODW lodsw
%define MOVB movsb
%define MOVW movsw
%define SCAB scasb
%define SCAW scasw
%define CMPB cmpsb
%define CMPW cmpsw
%define STOB stosb
%define STOW stosw

; --- Implement scpasm 2.44 instruction encoding using NASM macros.

%ifdef NASMINST
  %define NDISASMINST
%endif

; Specify `nasm -DNDISASMINST' to make ndisasm(1) be able to disassemble the output. Without it, ndisasm(1) emits `db 0x82'.
%macro _CMP_BDI 1
  cmp byte [di], %1
%endm
; This is the default scpasm 2.44 instruction encoding, incompatible with ndisasm(1).
%macro __CMP_BDI 1
  db 0x82, 0x3D, %1
%endm
%ifndef NDISASMINST ; Without `nasm -DNDISASMINST', use the scpasm 2.44 instruction encoding.
  %define _CMP_BDI __CMP_BDI
%endif

; Specify `nasm -DNASMINST' to get modern (NASM 0.98.39) instruction encoding.
%macro _OR 2
  or %1, %2
%endm
%macro _ADD 2
  add %1, %2
%endm
%macro _XOR 2
  xor %1, %2
%endm
%macro _CMP 2
  cmp %1, %2
%endm
%macro _MOV 2
  mov %1, %2
%endm
; This is the default scpasm 2.44 instruction encoding.
_ADD_DXAX equ 0xD003
_CMP_DIBP equ 0xFD3B
_MOV_BHAL equ 0xF88A
_MOV_BLAL equ 0xD88A
_MOV_BPAX equ 0xE88B
_MOV_BPDI equ 0xEF8B
_MOV_CLAL equ 0xC88A
_MOV_CXBP equ 0xCD8B
_MOV_DIAX equ 0xF88B
_MOV_DIBX equ 0xFB8B
_OR_ALAL equ 0xC00A
_OR_ALBL equ 0xC30A
_OR_BLAL equ 0xD80A
_XOR_AXAX equ 0xC033
_XOR_BXBX equ 0xDB33
_XOR_DXDX equ 0xD233
%macro __OR 2
  dw _OR_%1%2
%endm
%macro __ADD 2
  dw _ADD_%1%2
%endm
%macro __XOR 2
  dw _XOR_%1%2
%endm
%macro __CMP 2
  dw _CMP_%1%2
%endm
%macro __MOV 2
  dw _MOV_%1%2
%endm
%ifndef NASMINST ; Without `nasm -DNASMINST', use the scpasm 2.44 instruction encoding.
  %define _OR __OR
  %define _ADD __ADD
  %define _XOR __XOR
  %define _CMP __CMP
  %define _MOV __MOV
%endif

; ---

; HEX2BIN  version 1.02
; Converts Intel hex format files to straight binary

FCB:	EQU	5CH
READ:	EQU	20
SETDMA:	EQU	26
OPEN:	EQU	15
CLOSE:	EQU	16
CREATE:	EQU	22
DELETE:	EQU	19
BLKWRT:	EQU	40
GETSEG:	EQU	38
BUFSIZ:	EQU	1024

	ORG	100H
	PUT	100H

HEX2BIN:
	MOV	DI,FCB+9
	_CMP_BDI " "
	JNZ	HAVEXT
	MOV	SI,HEX
	MOVB
	MOVW
HAVEXT:
;Get load offset (default is -100H)
	MOV	CL,4		;Needed for shifts
	MOV	WORD [OFFSET],-100H
	MOV	SI,FCB+11H	;Scan second FCB for offset
	LODB
	CMP	AL," "		;Check if offset present
	JZ	HAVOFF
	MOV	BYTE [SIGN],0	;Assume positive sign for now
	CMP	AL,"+"
	JZ	GETOFF		;Get a positive offset
	CMP	AL,"-"
	JNZ	GETOFF1		;If not + or -, then not signed
	MOV	BYTE [SIGN],1	;Flag as negative offset
GETOFF:
	LODB			;Eat sign
GETOFF1:
	CALL	HEXCHK		;Check for valid hex character
	JC	HAVOFF		;No offset if not valid
	_XOR	BX,BX		;Intialize offset sum to 0
CONVOFF:
	SHL	BX,CL		;Multiply current sum by 16
	_OR	BL,AL		;Add in current hex digit
	LODB			;Get next digit
	CALL	HEXCHK		;And convert it to binary
	JNC	CONVOFF		;Loop until all hex digits read
	TEST	BYTE [SIGN],-1	;Check if offset was to be negative
	JZ	SAVOFF
	NEG	BX
SAVOFF:
	MOV	[OFFSET],BX
HAVOFF:
	MOV	DX,STARTSEG
	MOV	AX,DS
	_ADD	DX,AX		;Compute load segment
	MOV	AH,GETSEG
	INT	33
	MOV	ES,DX
	SEG	ES
	MOV	CX,[6]		;Get size of segment
	MOV	[SEGSIZ],CX
	_XOR	AX,AX
	_MOV	DI,AX
	_MOV	BP,AX
	SHR	CX
	REP
	STOW			;Fill entire segment with zeros
	MOV	AH,OPEN
	MOV	DX,FCB
	INT	21H
	_OR	AL,AL
	JNZ	NOFIL
	MOV	BYTE [FCB+32],0
	MOV	WORD [FCB+14],BUFSIZ	;Set record size to buffer size
	MOV	DX,BUFFER
	MOV	AH,SETDMA
	INT	33
	MOV	AH,READ
	MOV	DX,FCB		;All set up for sequential reads
	MOV	SI,BUFFER+BUFSIZ ;Flag input buffer as empty
READHEX:
	CALL	GETCH
	CMP	AL,":"		;Search for : to start line
	JNZ	READHEX
	CALL	GETBYT		;Get byte count
	_MOV	CL,AL
	MOV	CH,0
	JCXZ	DONE
	CALL	GETBYT		;Get high byte of load address
	_MOV	BH,AL
	CALL	GETBYT		;Get low byte of load address
	_MOV	BL,AL
	ADD	BX,[OFFSET]	;Add in offset
	_MOV	DI,BX
	CALL	GETBYT		;Throw away type byte
READLN:
	CMP	DI,[SEGSIZ]
	JAE	ADERR
	CALL	GETBYT		;Get data byte
	STOB
	_CMP	DI,BP		;Check if this is the largest address so far
	JBE	HAVBIG
	_MOV	BP,DI		;Save new largest
HAVBIG:
	LOOP	READLN
	JP	READHEX

NOFIL:
	MOV	DX,NOFILE
QUIT:
	MOV	AH,9
	INT	21H
	INT	20H

ADERR:
	MOV	DX,ADDR
	_JMP	SHOWERR  ; `JMP SHORT' would also work, but we copy the near jump from SCP.

GETCH:
	CMP	SI,BUFFER+BUFSIZ
	JNZ	NOREAD
	INT	21H
	CMP	AL,1
	JZ	ERROR
	MOV	SI,BUFFER
NOREAD:
	LODB
	CMP	AL,1AH
	JZ	DONE
	RET

GETBYT:
	CALL	HEXDIG
	_MOV	BL,AL
	CALL	HEXDIG
	SHL	BL
	SHL	BL
	SHL	BL
	SHL	BL
	_OR	AL,BL
RET1:	RET

HEXCHK:
	SUB	AL,"0"
	JC	RET1
	CMP	AL,10
	JC	CMCRET
	SUB	AL,"A"-"0"-10
	JC	RET1
	CMP	AL,16
CMCRET:
	CMC
RET2:	RET

HEXDIG:
	CALL	GETCH
	CALL	HEXCHK
	JNC	RET2
ERROR:
	MOV	DX,ERRMES
SHOWERR:
	MOV	AH,9
	INT	21H
DONE:
	MOV	WORD [FCB+9],4F00H+"C"	;"CO"
	MOV	BYTE [FCB+11],"M"
	MOV	DX,FCB
	MOV	AH,CREATE
	INT	21H
	_OR	AL,AL
	JNZ	NOROOM
	_XOR	AX,AX
	MOV	[FCB+33],AX
	MOV	[FCB+35],AX	;Set RR field
	INC	AX
	MOV	[FCB+14],AX	;Set record size
	_XOR	DX,DX
	PUSH	DS
	PUSH	ES
	POP	DS		;Get load segment
	MOV	AH,SETDMA
	INT	21H
	POP	DS
	_MOV	CX,BP
	MOV	AH,BLKWRT
	MOV	DX,FCB
	INT	21H
	MOV	AH,CLOSE
	INT	21H
EXIT:
	INT	20H

NOROOM:
	MOV	DX,DIRFUL
	JMP	QUIT

HEX:	DB	"HEX"
ERRMES:	DB	"Error in HEX file--conversion aborted$"
NOFILE:	DB	"File not found$"
ADDR:	DB	"Address out of range--conversion aborted$"
DIRFUL:	DB	"Disk directory full$"
absolute $  ; NASM: don't emit any more bytes, start .bss.
%define DS resb
OFFSET:	DS	2
SEGSIZ:	DS	2
SIGN:	DS	1
BUFFER:	DS	BUFSIZ

START:
STARTSEG EQU	(START-HEX2BIN+0x100+15)/16
