;
; asm244.nasm: NASM port of the SCP assembler 2.44
; originally written by Tim Paterson between 1979 and 1983-05-09
; NASM port by pts@fazekas.hu started on 2024-11-26
;
; Compile with: nasm -o asm244n.com asm244.nasm
; Compile with: nasm -w+orphan-labels -f bin -O0 -o asm244n.com asm244.nasm
; It produces identical output with `nasm -O0' and `nasm -O999999999'.
; It compiles with NASM >=0.97. Recommended: NASM >=0.98.39.
; The output asm244n.com is bitwise identical to asm244.com (which is the
; output of asm244.com and hex102.asm from asm244.asm).
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
; 04/01/81  2.21  Fix date in HEX and PRN files; modify buffer handling
; 04/03/81  2.22  Fix 2.21 buffer handling
; 04/13/81  2.23  Re-open source file for listing to allow assembling CON:
; 04/28/81  2.24  Allow nested IFs
; 07/30/81  2.25  Add Intel string mnemonics; clean up a little
; 08/02/81  2.30  Re-write pass 2:
;			Always report errors to console
;			Exact byte lengths for HEX and PRN files
; 11/08/81  2.40  Add 8087 mnemonics; print full error messages;
;		  allow expressions with *, /, and ()
; 07/04/82  2.41  Fix Intel's 8087 "reverse-bit" bug; don't copy date
; 08/18/82  2.42  Increase stack from 80 to 256 (Damn! Overflowed again!)
; 01/05/83  2.43  Correct over-zealous optimization in 2.42
; 05/09/83  2.44  Add memory usage report
;
;* * * * * * * * * * * * * * * * * * * * *
;

; --- NASM compatibility by pts@fazekas.hu at Tue Nov 26 18:56:58 CET 2024
;
; There are 598 bytes of instruction encoding differences between
; asm244m.com and asm244n.com with -DNASMINST. Without -DNASMINST, they are
; identical.
;
; Porting issues to NASM 0.97 (as compared to modern NASM >=0.98.39):
;
; * Everything below was worked around conditionally, using `%ifdef` and
;   `if`. It's possible to detect the NASM version, e.g.
;   `%if __NASM_MINOR__>98`.
; * NASM 0.97 doesn't support a `%macro` definition with a false `%i...`.
; * NASM 0.97 doesn't support the *xlat* instruction. Solution: use *xlatb*,
;   it produces the same code.
; * NASM 0.97 doesn't support `cmp ax, strict word ...`. Solution: use *db*
;   and *dw* to encode this instruction.
; * NASM 0.97 doesn't support `jmp strict near ...`. Solution: use *db*
;   and *dw* to encode this instruction.
; * NASM 0.97 doesn't support *cpu* (`cpu 8087`). Solution: omit it.
; * NASM 0.97 doesn't support the command-line flag `-O...` (optimization).
;   It defaults to `-O0` (no optimization).
; * NASM 0.97 doesn't support the command-line flag `-D...` (single-line
;   macro definition).
; * NASM 0.97 drops the `_' between multiline macro arguments, e.g. `foo
;   %1_%2` is the same as `foo %1%2`. Solution: rename the target symbols by
;   omitting the `_` explicitly from their name.
; * NASM 0.97 doesn't do single-line macro (i.e. `%define`) lookups on words
;   built from multiline macro aguments, e.g. `_OR_%1%2`. Solution: use
;   *equ* instead of `%define`.
; 

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
; Modern NASM (>=0.98.39).
%macro _JMP 1
  jmp strict near %1
%endm
%macro _CMP_AX 1
  cmp ax, strict word (%1)
%endm
; Old NASM (e.g. 0.97).
%macro __JMP 1  ; Fallback for NASM 0.97: it doesn't support `jmp strict short LABEL'.
  db 0xe9
  dw (%1)-$-2
%endm
%macro __CMP_AX 1
  db 0x3d
  dw (%1)
%endm
%ifdef IS_MODERN_NASM
  cpu 8086
%else  ; Use fallbacks on non-modern NASM.
  %define _JMP __JMP
  %define _CMP_AX __CMP_AX
%endif

%macro PUT 1
%endm

; Like DB, but flip the highest bit of the last byte.
; This was really undocumented, the source had to be reverse engineered.
; DM 'hello' is equivalent to: db 'hell', 'o'|0x80
; We do it by separating the last byte, e.g.: DM 'he', 'll', 'o'
%macro DM 2
  db %1
  db (%2)|0x80
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

%macro SHR 1
  shr %1, 1
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
%macro _CMP_CH 1
  cmp ch, %1
%endm
%macro _CMP_CL 1
  cmp cl, %1
%endm
%macro _CMP_DL 1
  cmp dl, %1
%endm
%macro _CMP_BBX 1
  cmp byte [bx], %1
%endm
%macro _CMP_BDIS 2
  cmp byte [%1], %2
%endm
; This is the default scpasm 2.44 instruction encoding, incompatible with ndisasm(1).
%macro __CMP_CH 1
  db 0x82, 0xFD, %1
%endm
%macro __CMP_CL 1
  db 0x82, 0xF9, %1
%endm
%macro __CMP_DL 1
  db 0x82, 0xFA, %1
%endm
%macro __CMP_BBX 1
  db 0x82, 0x3F, %1
%endm
%macro __CMP_BDIS 2
  dw 0x3E82, %1
  db %2
%endm
%ifndef NDISASMINST ; Without `nasm -DNDISASMINST', use the scpasm 2.44 instruction encoding.
  %define _CMP_CH __CMP_CH
  %define _CMP_CL __CMP_CL
  %define _CMP_DL __CMP_DL
  %define _CMP_BBX __CMP_BBX
  %define _CMP_BDIS __CMP_BDIS
%endif

; Specify `nasm -DNASMINST' to get modern (NASM 0.98.39) instruction encoding.
%macro _OR 2
  or %1, %2
%endm
%macro _SBB 2
  sbb %1, %2
%endm
%macro _ADD 2
  add %1, %2
%endm
%macro _AND 2
  and %1, %2
%endm
%macro _SUB 2
  sub %1, %2
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
_ADD_ALAL equ 0xC002
_ADD_ALCL equ 0xC102
_ADD_ALDL equ 0xC202
_ADD_ALCH equ 0xC502
_ADD_BLAL equ 0xD802
_ADD_DXBX equ 0xD303
_ADD_BXDX equ 0xDA03
_OR_ALAL equ 0xC00A
_OR_ALCL equ 0xC10A
_OR_ALDL equ 0xC20A
_OR_ALBL equ 0xC30A
_OR_ALCH equ 0xC50A
_OR_ALDH equ 0xC60A
_OR_ALBH equ 0xC70A
_OR_CLCL equ 0xC90A
_OR_BLDL equ 0xDA0A
_OR_BLBL equ 0xDB0A
_OR_AHAL equ 0xE00A
_OR_AHDL equ 0xE20A
_OR_AHAH equ 0xE40A
_OR_DXDX equ 0xD20B
_OR_BXBX equ 0xDB0B
_SBB_BXDX equ 0xDA1B
_AND_ALCL equ 0xC122
_AND_ALDH equ 0xC622
_AND_CHAL equ 0xE822
_SUB_ALDH equ 0xC62A
_SUB_ALBH equ 0xC72A
_SUB_CLAL equ 0xC82A
_SUB_CXDX equ 0xCA2B
_SUB_CXSI equ 0xCE2B
_SUB_BXDX equ 0xDA2B
_SUB_DIDX equ 0xFA2B
_XOR_ALAL equ 0xC032
_XOR_AXAX equ 0xC033
_XOR_DXDX equ 0xD233
_CMP_ALCL equ 0xC13A
_CMP_ALCH equ 0xC53A
_CMP_ALDH equ 0xC63A
_CMP_ALBH equ 0xC73A
_CMP_AHDH equ 0xE63A
_CMP_AXDX equ 0xC23B
_CMP_AXBX equ 0xC33B
_CMP_BXDX equ 0xDA3B
_MOV_ALCL equ 0xC18A
_MOV_ALDL equ 0xC28A
_MOV_ALBL equ 0xC38A
_MOV_ALAH equ 0xC48A
_MOV_ALCH equ 0xC58A
_MOV_ALDH equ 0xC68A
_MOV_ALBH equ 0xC78A
_MOV_CLAL equ 0xC88A
_MOV_CLCH equ 0xCD8A
_MOV_CLDH equ 0xCE8A
_MOV_CLBH equ 0xCF8A
_MOV_DLAL equ 0xD08A
_MOV_DLCL equ 0xD18A
_MOV_DLCH equ 0xD58A
_MOV_BLAL equ 0xD88A
_MOV_BLAH equ 0xDC8A
_MOV_AHAL equ 0xE08A
_MOV_CHAL equ 0xE88A
_MOV_CHCL equ 0xE98A
_MOV_CXDX equ 0xCA8B
_MOV_CXDI equ 0xCF8B
_MOV_DXAX equ 0xD08B
_MOV_DXBX equ 0xD38B
_MOV_DXSI equ 0xD68B
_MOV_DXDI equ 0xD78B
_MOV_BXDX equ 0xDA8B
_MOV_BXSI equ 0xDE8B
_MOV_BXDI equ 0xDF8B
_MOV_SPBX equ 0xE38B
_MOV_SIDX equ 0xF28B
_MOV_SIBX equ 0xF38B
_MOV_SIDI equ 0xF78B
_MOV_DIDX equ 0xFA8B
_MOV_DIBX equ 0xFB8B
_MOV_DISI equ 0xFE8B
%macro __OR 2
  dw _OR_%1%2
%endm
%macro __SBB 2
  dw _SBB_%1%2
%endm
%macro __ADD 2
  dw _ADD_%1%2
%endm
%macro __AND 2
  dw _AND_%1%2
%endm
%macro __SUB 2
  dw _SUB_%1%2
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
  %define _SBB __SBB
  %define _ADD __ADD
  %define _AND __AND
  %define _SUB __SUB
  %define _XOR __XOR
  %define _CMP __CMP
  %define _MOV __MOV
%endif

; ---

SYMWID:	EQU	5	;5 symbols per line in dump
FCB:	EQU	5CH
BUFSIZ:	EQU	1024	;Source code buffer
LSTBUFSIZ:EQU	BUFSIZ	;List file buffer
HEXBUFSIZ:EQU	70	;Hex file buffer (26*2 + 5*2 + 3 + EXTRA)
EOL:	EQU	13	;ASCII carriage return
OBJECT:	EQU	100H	;DEFAULT "PUT" ADDRESS

;System call function codes
PRINTMES: EQU	9
OPEN:	EQU	15
CLOSE:	EQU	16
READ:	EQU	20
SETDMA:	EQU	26
MAKE:	EQU	22
BLKWRT:	EQU	40

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

	ORG	100H
	PUT	100H

	JMPS	BEGIN

HEADER:	DB	13,10,'Seattle Computer Products 8086 Assembler Version 2.44'
	DB	13,10,'Copyright 1979-1983 by Seattle Computer Products, Inc.'
	DB	13,10,13,10,'$'

BEGIN:
	MOV	SP,STACK
	MOV	DX,HEADER
	MOV	AH,PRINTMES
	INT	33
	MOV	AL,[FCB+17]
	MOV	[SYMFLG],AL	;Save symbol table request flag
	MOV	SI,FCB+9	;Point to file extension
	LODB			;Get source drive letter
	CALL	CHKDSK		;Valid drive?
	_OR	AL,AL
	JZ	$DEFAULT	;If no extension, use existing drive spec
	MOV	[FCB],AL
$DEFAULT:
	LODB			;Get HEX file drive letter
	CMP	AL,'Z'		;Suppress HEX file?
	JZ	L0000
	CALL	CHKDSK
L0000:	
	MOV	[HEXFCB],AL
	LODB			;Get PRN file drive letter
	MOV	AH,0		;Signal no PRN file
	CMP	AL,'Z'		;Suppress PRN file?
	JZ	NOPRN
	CMP	AL,'Y'		;Print errors only on console?
	JZ	NOPRN
	MOV	AH,2
	CMP	AL,'X'		;PRN file to console?
	JZ	NOPRN
	MOV	AH,4
	CMP	AL,'P'		;PRN file to printer?
	JZ	NOPRN
	CALL	CHKDSK
	MOV	AH,80H
NOPRN:
	MOV	[LSTFCB],AL
	MOV	[LSTDEV],AH	;Flag device for list ouput
	MOV	SI,EXTEND
	MOV	DI,FCB+9
	MOVW
	MOVB			;Set extension to ASM
	MOVW			;Zero extent field
	MOV	DX,FCB
	MOV	AH,OPEN
	INT	33
	MOV	BX,NOFILE
	_OR	AL,AL
	JZ	$+5
	_JMP	PRERR
	MOV	DX,HEXFCB
	CALL	MAKFIL
	MOV	DX,LSTFCB
	CALL	MAKFIL
	_XOR	AX,AX
	MOV	[FCB+12],AX	;Zero CURRENT BLOCK field
	MOV	[FCB+32],AL	;Zero Next Record field
	MOV	WORD [FCB+14],BUFSIZ	;Set record size
	MOV	WORD [BUFPT],SRCBUF	;Initialize buffer pointer
	MOV	WORD [CODE],START+1	;POINTER TO NEXT BYTE OF INTERMEDIATE CODE
	MOV	WORD [IY],START	;POINTER TO CURRENT RELOCATION BYTE
	_XOR	AX,AX
	MOV	[PC],AX		;DEFAULT PROGRAM COUNTER
	MOV	[BASE],AX	;POINTER TO ROOT OF ID TREE=NIL
	MOV	[RETPT],AX	;Pointer to last RET record
	MOV	[IFFLG],AL	;NOT WITHIN IF/ENDIF
	MOV	[CHKLAB],AL	;LOOKUP ALL LABELS
	DEC	AX
	MOV	[LSTRET],AX	;Location of last RET
	MOV	AX,[6]		;HL=END OF MEMORY
	MOV	[HEAP],AX	;BACK END OF SYMBOL TABLE SPACE. Will grow downward.
	MOV	WORD [BCOUNT],4	;CODE BYTES PER RELOCATION BYTE

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
	_XOR	AL,AL		;Flag no errors on line
ENDLIN:
;AL = error code for line. Stack depth unknown
	MOV	SP,STACK
	CALL	NEXLIN
	JP	$LOOP

NEXLIN:
	MOV	CH,0C0H		;Put end of line marker and error code (AL)
	CALL	PUTCD
	CALL	GEN1
	MOV	AL,[CHR]
GETEOL:
	CMP	AL,10
	JZ	RET1
	CMP	AL,1AH
	JZ	ENDJ
	CALL	NEXTCHR		;Scan over comments for linefeed
	JP	GETEOL

	; Fall through to ABORT.

ABORT:
	MOV	BX,NOMEM
PRERR:
	_MOV	DX,BX
	MOV	AH,PRINTMES
	INT	33
	INT	32

MAKFIL:
	_MOV	SI,DX
	LODB			;Get drive select byte
	CMP	AL,20H		;If not valid, don't make file
	JNC	RET1
	MOV	CX,4
	_MOV	DI,SI
	MOV	SI,FCB+1
	REP
	MOVW			;Copy source file name
	MOV	AH,MAKE
	INT	33
	MOV	WORD [DI-9+14],1	;Set record length to 1 byte
	MOV	BX,NOSPAC
	_OR	AL,AL		;Success?
	JNZ	PRERR
RET1:	RET

CHKDSK:
	SUB	AL,' '		;If not present, set zero flag
	JZ	RET1
	SUB	AL,20H
	JZ	DSKERR		;Must be in range A-O
	CMP	AL,'P'-'@'
	JC	RET1
DSKERR:
	MOV	BX,BADDSK
	JP	PRERR

ERROR:
	_MOV	AL,CL
	_JMP	ENDLIN

NEXTCHR:
	MOV	SI,[BUFPT]
	CMP	SI,SRCBUF
	JNZ	GETCH
;Buffer empty so refill it
	PUSH	DX
	PUSH	AX		;AH must be saved
	_MOV	DX,SI
	MOV	AH,SETDMA
	INT	33
	MOV	DX,FCB
	MOV	AH,READ
	INT	33
	XCHG	AX,DX		;Put error code in DL
	POP	AX		;Restore AH
	_MOV	AL,DL		;Error code back in AL
	POP	DX
	; Actually, AL=3, for a partial read. Then SRCBUF will be NUL-padded, and there is no way to get the actual byte size.
	CMP	AL,1
	MOV	AL,1AH		;Possibly signal End of File
	JZ	NOMOD		;If nothing read
GETCH:
	LODB
	CMP	SI,SRCBUF+BUFSIZ
	JNZ	NOMOD
	MOV	SI,SRCBUF
NOMOD:
	MOV	[BUFPT],SI
	MOV	[CHR],AL
RET2:	RET


MROPS:

; Get two operands and check for certain types, according to flag byte
; in CL. OP code in CH. Returns only if immediate operation.

	PUSH	CX		;Save type flags
	CALL	GETOP
	PUSH	DX		;Save first operand
	CALL	GETOP2
	POP	BX		;First op in BX, second op in DX
	MOV	AL,SREG		;Check for a segment register
	_CMP	AL,BH
	JZ	SEGCHK
	_CMP	AL,DH
	JZ	SEGCHK
	MOV	AL,CONST	;Check if the first operand is immediate
	MOV	CL,26
	_CMP	AL,BH
	JZ	ERROR		;Error if so
	POP	CX		;Restore type flags
	_CMP	AL,DH		;If second operand is immediate, then done
	JZ	RET2
	MOV	AL,UNDEFID	;Check for memory reference
	_CMP	AL,BH
	JZ	STORE		;Is destination memory?
	_CMP	AL,DH
	JZ	LOAD		;Is source memory?
	TEST	CL,1		;Check if register-to-register operation OK
	MOV	CL,27
	JZ	ERROR
	_MOV	AL,DH
	_CMP	AL,BH		;Registers must be of same length
RR:
	MOV	CL,22
	JNZ	ERROR
RR1:
	AND	AL,1		;Get register length (1=16 bits)
	_OR	AL,CH		;Or in to OP code
	CALL	$PUT		;And write it
	POP	CX		;Dump return address
	_MOV	AL,BL
	_ADD	AL,AL		;Rotate register number into middle position
	_ADD	AL,AL
	_ADD	AL,AL
	OR	AL,0C0H		;Set register-to-register mode
	_OR	AL,DL		;Combine with other register number
	JMP	$PUT

SEGCHK:
;Come here if at least one operand is a segment register
	POP	CX		;Restore flags
	TEST	CL,8		;Check if segment register OK
	MOV	CL,22
	JZ	ERR1
	MOV	CX,8E03H	;Segment register move OP code
	MOV	AL,UNDEFID
	_CMP	AL,DH		;Check if source is memory
	JZ	LOAD
	_CMP	AL,BH		;Check if destination is memory
	JZ	STORE
	MOV	AL,XREG
	_SUB	AL,DH		;Check if source is 16-bit register
	JZ	RR		;If so, AL must be zero
	MOV	CH,8CH		;Change direction
	XCHG	BX,DX		;Flip which operand is first and second
	MOV	AL,XREG
	_SUB	AL,DH		;Let RR perform finish the test
	JP	RR

STORE:
	TEST	CL,004H		;Check if storing is OK
	JNZ	STERR
	XCHG	BX,DX		;If so, flip operands
	AND	CH,0FDH		;   and zero direction bit
LOAD:
	MOV	DH,25
	_CMP	AL,BH		;Check if memory-to-memory
	JZ	MRERR
	_MOV	AL,BH
	CMP	AL,REG		;Check if 8-bit operation
	JNZ	XRG
	MOV	DH,22
	TEST	CL,1		;See if 8-bit operation is OK
	JZ	MRERR
XRG:
	_MOV	AL,DL
	SUB	AL,6		;Check for R/M mode 6 and register 0
	_OR	AL,BL		;   meaning direct load/store of accumulator
	JNZ	NOTAC
	TEST	CL,8		;See if direct load/store of accumulator
	JZ	NOTAC		;   means anything in this case
; Process direct load/store of accumulator
	_MOV	AL,CH
	AND	AL,2		;Preserve direction bit only
	XOR	AL,2		;   but flip it
	OR	AL,0A0H		;Combine with OP code
	_MOV	CH,AL
	_MOV	AL,BH		;Check byte/word operation
	AND	AL,1
	_OR	AL,CH
	POP	CX		;Dump return address
	JMP	PUTADD		;Write the address

NOTAC:
	_MOV	AL,BH
	AND	AL,1		;Get byte/word bit
	_AND	AL,CL		;But don't use it in word-only operations
	_OR	AL,CH		;Combine with OP code
	CALL	$PUT
	_MOV	AL,BL
	_ADD	AL,AL		;Rotate to middle position
	_ADD	AL,AL
	_ADD	AL,AL
	_OR	AL,DL		;Combine register field
	POP	CX		;Dump return address
	JMP	PUTADD		;Write the address

STERR:
	MOV	DH,29
MRERR:
	_MOV	CL,DH

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
	_XOR	AL,AL		;No addressing modes allowed
VAL1:
	CALL	GETVAL
	MOV	AX,[CON]	;Defined part
	MOV	[DATA],AX
	MOV	AX,[UNDEF]	;Undefined part
	MOV	[DLABEL],AX
	_MOV	DL,CH
	MOV	DH,CONST
	_MOV	AL,DH
	RET
NREG:
	PUSH	DX
	CALL	GETSYM
	POP	DX
	_MOV	AL,DH
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
	_MOV	DL,CH
	MOV	DH,UNDEFID
	_MOV	AL,DH
RET21:	RET
FLG:
	CMP	DL,[MAXFLG]	;Invalid flag for this operation?
	MOV	CL,27H
	JG	ERR1
	CALL	GETSYM
	CMP	AL,','
	JZ	GETOP
	JP	GETOP1


GETVAL:

; Expression analyzer. On entry, if AL=0 then do not allow base or index
; registers. If AL=1, we are analyzing a memory reference, so allow base
; and index registers, and compute addressing mode when done. The constant
; part of the expression will be found in CON. If an undefined label is to
; be added to this, a pointer to its information fields will be found in
; UNDEF.

	_MOV	AH,AL		;Flag is kept in AH
	MOV	WORD [UNDEF],0
	MOV	AL,[SYM]
	CALL	EXPRESSION
	MOV	[CON],DX
	_MOV	AL,AH
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
	_MOV	AL,BL
	CBW			;Extend sign
	_CMP	AX,BX		;Is it a signed 8-bit number?
	JNZ	RET21		;If not, use 16-bit displacement
	AND	CH,07FH		;Reset 16-bit displacement
	OR	CH,040H		;Set 8-bit displacement
	_OR	BX,BX
	JNZ	RET21		;Use it if not zero displacement
	AND	CH,7		;Specify no displacement
	_CMP_CH 6		;Check for BP+0 addressing mode
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
	MOV	CH,-1		;Initial type
	_MOV	DI,DX
	_XOR	DX,DX		;Initial value
	CMP	AL,'+'
	JZ	PLSMNS
	CMP	AL,'-'
	JZ	PLSMNS
	MOV	CL,'+'
	PUSH	DX
	PUSH	CX
	_MOV	DX,DI
	JP	OPERATE
PLSMNS:
	_MOV	CL,AL
	PUSH	DX
	PUSH	CX
	OR	AH,4		;Flag that a sign was found
	CALL	GETSYM
OPERATE:
	CALL	TERM
	POP	CX		;Recover operator
	POP	BX		;Recover current value
	XCHG	BX,DX
	_AND	CH,AL
	_OR	AL,AL		;Is it register or undefined label?
	JZ	NOCON		;If so, then no constant part
	_CMP_CL "-"		;Subtract it?
	JNZ	$ADD
	NEG	BX
$ADD:
	_ADD	DX,BX
NEXTERM:
	MOV	AL,[SYM]
	CMP	AL,'+'
	JZ	PLSMNS
	CMP	AL,'-'
	JZ	PLSMNS
	_MOV	AL,CH
	RET
NOCON:
	_CMP_CL "-"
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
	_OR	CL,CL		;Can we operate on this type?
	JZ	BADOP
	PUSH	AX		;Save operator
	CALL	GETSYM		;Get past operator
	CALL	FACTOR
	_OR	AL,AL
	JZ	BADOP
	POP	CX		;Recover operator
	POP	BP		;And current value
	XCHG	AX,BP		;Save AH in BP
	_CMP_CL "/"		;Do we divide?
	JNZ	DOMUL
	_OR	DX,DX		;Dividing by zero?
	MOV	CL,29H
	JZ	ERR2
	_MOV	BX,DX
	_XOR	DX,DX		;Make 32-bit dividend
	DIV	AX,BX
	JMPS	NEXFACT
DOMUL:
	MUL	AX,DX
NEXFACT:
	_MOV	DX,AX		;Result in DX
	XCHG	AX,BP		;Restore flags to AH
	MOV	AL,-1		;Indicate a number
	JMPS	MULOP
ENDTERM:
	POP	DX
	_MOV	AL,CL
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
	_MOV	AL,DL
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
	CALL	GETSYM		;Eat the "("
	CALL	EXPRESSION
	_CMP_BDIS SYM,")"	;Better have closing paren
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
	_MOV	CH,AL
	MOV	AL,[CHR]
	_CMP	AL,CH
	MOV	CL,35
	_MOV	DL,AL
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
	_MOV	AL,DL
	CMP	AL,EOL
	MOV	CL,39
	JZ	ERR30
	CALL	$PUT
	MOV	AL,[DATSIZ]
	_OR	AL,AL
	JNZ	BYTSIZ
	_MOV	AL,DH
	CALL	$PUT
BYTSIZ:
	MOV	AL,[CHR]
	_MOV	DL,AL
	CALL	GETCHR
	JP	STRGDAT

ZERLEN:
	CALL	NEXTCHR
	_CMP	AL,CH
	JNZ	ERR30
RET22:	RET

GETCHR:
	CALL	NEXTCHR
	_CMP	AL,CH
	JNZ	RET22
	CALL	NEXTCHR
	_CMP	AL,CH
	JZ	RET22
	POP	BX		;Kill return address to STRGDAT loop
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
	JC	$+5
	_JMP	LETTER
	CMP	AL,'9'+1
	JNC	NEXTCHJ
	CMP	AL,'0'
	JC	NEXTCHJ
	MOV	BX,SYM
	MOV	BYTE [BX],CONST
	CALL	READID
	DEC	BX
	MOV	AL,[BX]
	MOV	CL,7
	MOV	BX,0
	CMP	AL,'h'
	JNZ	$+5
	_JMP	HEX
	INC	CL
	MOV	WORD [IX],ID
$DEC:
	MOV	SI,[IX]
	MOV	AL,[SI]
	INC	WORD [IX]
	CMP	AL,'9'+1
	JC	$+5
	_JMP	ERROR
	SUB	AL,'0'
	_MOV	DX,BX
	SHL	BX
	SHL	BX
	_ADD	BX,DX
	SHL	BX
	_MOV	DL,AL
	MOV	DH,0
	_ADD	BX,DX
	DEC	CH
	JNZ	$DEC
	XCHG	BX,DX
	RET

HEX:
	MOV	DX,ID
	DEC	CH
HEX1:
	_MOV	SI,DX
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
	_ADD	BL,AL
	DEC	CH
	JNZ	HEX1
	XCHG	BX,DX
RET7:	RET

ERR4:	JMP	ERROR

GETLET:
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
READID:
	MOV	BX,ID
	MOV	CH,0
MOREID:
	MOV	[BX],AL
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
	_MOV	CL,AL
	_MOV	AL,CH
	MOV	[LENID],AL
	_OR	AL,AL
	_MOV	AL,CL
	RET

LETTER:
	CALL	READID
	_MOV	AL,CH
	DEC	AL
	JNZ	NOFLG
	MOV	AL,[ID]
	MOV	CX,5
	MOV	DI,FLGTAB
	UP
	REPNE
	SCAB			;See if one of B,W,S,L,T
	JZ	SAVFLG		;Go save flag
	_XOR	AL,AL
	MOV	CH,[LENID]
NOFLG:
	DEC	AL
	PUSH	BX
	JNZ	L0004
	CALL	REGCHK
L0004:	
	POP	BX
	_MOV	AL,DH
	JZ	SYMSAV
	CALL	LOOKRET
SYMSAV:
	MOV	[SYM],AL
	RET

SAVFLG:
	_MOV	DL,CL		;Need flag type in DL
	XCHG	[FLAG],CL
	_CMP_CL -1
	MOV	CL,32
	MOV	AL,5
	JZ	SYMSAV
ERRJ3:	JMP	ERROR

FLGTAB:	DB	"tlswb"

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
	_XOR	AL,AL		;Zero set means register found
RET8:	RET

REGCHK:
	MOV	BX,ID
	CMP	WORD [BX],"s"+7400H	;"st"
	JZ	FPREG
	MOV	CL,[BX]
	INC	BX
	MOV	AL,[BX]
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
	_MOV	AL,CL
	CMP	AL,'s'
	JZ	RET8
	INC	DL
	CMP	AL,'d'
RET5:	RET
PREG:
	MOV	DL,4
	_MOV	AL,CL
	CMP	AL,'s'
	JZ	RET5
	INC	DL
	CMP	AL,'b'
RET13:	RET
SCANREG:
	_MOV	AL,CL
	MOV	CX,4
	UP
	_MOV	DI,BX
	REPNZ
	SCAB
	_MOV	BX,DI
	JNZ	RET13
	_MOV	AL,CL
	_ADD	AL,DL
	_MOV	DL,AL
	_XOR	AL,AL
RET9:	RET

REGTAB:	DB	'bdca'

SEGTAB:	DB	'dsce'

LOOK:
	MOV	CH,[BX]
	INC	BX
	MOV	DX,ID
	CALL	CPSLP
	JZ	RET9
	XOR	AL,80H
	ROL	AL		;Make end-of-symbol bit least significant
	_MOV	CL,AL
	DEC	BX
	MOV	AL,[BX]
	XOR	AL,80H
	ROL	AL
	_CMP	AL,CL
	JNC	SMALL
	INC	CH
	INC	CH
SMALL:
	_MOV	DL,CH
	MOV	DH,0
	_ADD	BX,DX
	MOV	DX,[BX]
	INC	BX
	_MOV	AL,DL
	_OR	AL,DH
	STC
	JZ	RET9
	XCHG	BX,DX
	JP	LOOK

LOOKRET:
	_MOV	AL,CH
	CMP	AL,3	;RET has 3 letters
	JNZ	LOOKUP
	DEC	BX
	OR	BYTE [BX],080H
	MOV	DX,RETSTR+2
CHKRET:
	_MOV	SI,DX
	LODB
	CMP	AL,[BX]
	JNZ	LOOKIT
	DEC	BX
	DEC	DX
	DEC	CH
	JNZ	CHKRET
	MOV	DX,[LSTRET]
	_MOV	AL,DL
	_AND	AL,DH
	INC	AL
	JZ	ALLRET
	MOV	BX,[PC]
	_SUB	BX,DX
	_MOV	AL,BL
	CBW
	_CMP	AX,BX		;Signed 8-bit number?
	MOV	AL,1
	JZ	RET9
ALLRET:
	MOV	BX,[RETPT]
	_MOV	AL,BH
	_OR	AL,BL
	MOV	AL,0
	JNZ	RET9
	MOV	BX,[HEAP]
	DEC	BX
	DEC	BX
	DEC	BX
	MOV	[HEAP],BX
	_XOR	AL,AL
	MOV	[BX],AL
	MOV	[RETPT],BX
RET10:	RET

LOOKUP:
	DEC	BX
	OR	BYTE [BX],080H
LOOKIT:
	MOV	BX,[BASE]
	_MOV	AL,BH
	_OR	AL,BL
	JZ	EMPTY
	CALL	LOOK
	JC	$ENTER
	MOV	DX,4
	_ADD	BX,DX
	MOV	AL,[BX]
	_OR	AL,AL
	JZ	RET10
	INC	BX
	MOV	DX,[BX]
	INC	BX
	RET

$ENTER:
	PUSH	BX		;Save pointer to link field
	CALL	CREATE		;Add the node
	POP	SI
	MOV	[SI-1],DX	;Link new node
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
	_MOV	DL,AL
	MOV	DH,0
	_SUB	BX,DX		;Heap grows downward
	MOV	[HEAP],BX
	XCHG	BX,DX
	MOV	BX,[CODE]	;Check to make sure there's enough
	_CMP	BX,DX
	JB	$+5
	_JMP	ABORT
	PUSH	DX
	MOV	BX,LENID
	MOV	CL,[BX]
	INC	CL
	MOV	CH,0
	UP
	_MOV	SI,BX
	_MOV	DI,DX
	REP
	MOVB			;Move identifier and length into node
	_MOV	DX,DI
	_MOV	BX,SI
	MOV	CH,4
	XCHG	BX,DX
NILIFY:
	MOV	[BX],CL		;Zero left and right links
	INC	BX
	DEC	CH
	JNZ	NILIFY
	_XOR	AL,AL		;Set zero flag
	MOV	[BX],AL		;Zero defined flag
	POP	DX		;Restore pointer to node
RET18:	RET

CPSLP:
	_MOV	SI,DX
	LODB
	CMP	AL,[BX]
	LAHF
	INC	DX
	INC	BX
	SAHF
	JNZ	RET18
	DEC	CH
	JNZ	CPSLP
RET11:	RET

GETLAB:
	MOV	BX,0
	MOV	[LABPT],BX
	MOV	BYTE [FLAG],-1
	MOV	DH,0
	MOV	AL,[CHR]
	CMP	AL,' '+1
	JC	NOT1
	OR	DH,001H
NOT1:
	CALL	GETLET
	JC	RET11
	CMP	AL,':'
	JNZ	LABCHK
	CALL	NEXTCHR
	JP	LABEL
LABCHK:
	_OR	AL,AL
	TEST	DH,001H
	JZ	RET11
LABEL:
	MOV	AL,[CHKLAB]
	_OR	AL,AL
	JZ	$+5
	_JMP	GETLET
	CALL	LOOKUP
	MOV	CL,11
	JNZ	ERR5
	MOV	DX,[PC]
	MOV	BYTE [BX],1
	INC	BX
	MOV	[BX],DX
	MOV	[LABPT],BX
	JMP	GETLET

ERR5:	JMP	ERROR

ASMLIN:
	MOV	BYTE [MAXFLG],1	;Allow only B and W flags normally
	MOV	BX,[PC]
	MOV	[OLDPC],BX
	CALL	GETLAB
	JNC	$+5
	_JMP	ENDLN
	MOV	BX,LENID
	MOV	AL,[BX]
	MOV	CL,12
	SUB	AL,2
	_MOV	CH,AL
	JC	ERR5
	INC	BX
	_CMP_BBX "f"	;See if an 8087 mnemonic
	JZ	NDPOP
	CMP	AL,5
	JNC	ERR5
	MOV	AL,[BX]
	SUB	AL,'a'
	_MOV	CL,AL
	_ADD	AL,AL
	_ADD	AL,AL
	_ADD	AL,CL
	_ADD	AL,CH
	_ADD	AL,AL
	MOV	BX,OPTAB
	_MOV	DL,AL
	MOV	DH,0
	_ADD	BX,DX
	MOV	BX,[BX]
	INC	CH
	_MOV	CL,CH
	MOV	AH,[BX]
	INC	BX
	_OR	AH,AH
	JZ	OPERR
FINDOP:
	_MOV	CH,CL
	MOV	DX,ID+1
	XCHG	AX,BP		;Save count of opcodes in BP
	CALL	CPSLP
	JZ	HAVOP
	XCHG	AX,BP
	MOV	DH,0
	_MOV	DL,CH
	INC	DX
	INC	DX
	_ADD	BX,DX
	DEC	AH
	JNZ	FINDOP
OPERR:
	MOV	CL,12
	JMP	ERROR

HAVOP:
	MOV	AL,[BX+2]	;Get opcode
	JMP	[BX]

NDPOP:	;First letter is "F" so must be 8087 opcode ("Numeric Data Processor")
	MOV	BYTE [MAXFLG],4	;Allow all type flags
	INC	BX
	_CMP_BBX "n"	;"No-wait" form?
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
	_MOV	SI,DX
	OR	BYTE [SI+BX],80H	;Set high bit of last character
	MOV	AL,[BX]		;Get first char of opcode
	INC	BX
	SUB	AL,"a"
	JB	TRY2XM1		;Go see if opcode starts with "2"
	CMP	AL,"z"-"a"
	JA	OPERR
	CBW
	SHL	AX		;Double to index into address table
	XCHG	AX,SI		;Put in index register
	MOV	DI,[SI+NDPTAB]	;Get start of opcode table for this letter
LOOKNDP:
	MOV	AH,[DI]		;Number of opcodes starting with this letter
	_OR	AH,AH
	JZ	OPERR		;Any start with this letter?
FNDNDP:
	INC	DI
	_MOV	SI,BX		;Pointer to start of opcode
	_MOV	CX,DX		;Get length of opcode
	REPE
	CMPB			;Compare opcode to table entry
	JZ	HAVNDP
	DEC	DI		;Back up in case that was last letter
	MOV	AL,80H		;Look for char with high bit set
ENDOP:
	SCASB
	JA	ENDOP
	INC	DI		;Skip over info about opcode
	DEC	AH
	JNZ	FNDNDP
OPERRJ:	JP	OPERR

TRY2XM1:
	CMP	AL,"2"-"a"
	JNZ	OPERR
	MOV	DI,XM1
	JP	LOOKNDP

SPECIALOP:
	AND	AL,7		;Mask to special op number
	JZ	$FWAIT		;If zero, go handle FWAIT
;Handle FNOP
	_CMP_BDIS NOWAIT,0	;Was "N" present (If not opcode was "FOP")
	JZ	OPERR
	MOV	AL,9BH		;Need Wait opcode after all
	CALL	$PUT
	MOV	AL,0D9H
	CALL	$PUT
	MOV	AL,0D0H
	JMP	$PUT

$FWAIT:
	_CMP_BDIS NOWAIT,0	;"FNWAIT" not legal
	JNZ	OPERRJ
	RET			;Nothing to do - "WAIT" already sent

HAVNDP:
	_MOV	SI,DI
	_CMP_BDIS NOWAIT,0
	JNZ	NWAIT
	MOV	AL,9BH		;Wait opcode
	CALL	$PUT
NWAIT:
	LODW			;Get opcode info
	TEST	AL,0F8H		;Any operand bits set?
	JZ	NOOPS		;If no operands, output code
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
	JNZ	MEMOP
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
	_OR	BL,BL		;Is first register ST(0)?
	JZ	ST0DEST
	XCHG	BX,DX
	_OR	BL,BL		;One of these must be ST(0)
	JNZ	ERRJ4
	XOR	AL,4		;Flip direction
	JMPS	PUTREG
ST0DEST:
	TEST	AL,2		;Is POP bit set?
	JNZ	ERRJ4		;Don't allow destination ST(0) then pop
PUTREG:
	AND	AH,0F8H		;Zero out register field
	_OR	AH,DL
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
	_MOV	AL,AH
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
	_MOV	CH,AL		;Save opcode byte
	SHR	AL		;Put format bits in bits 2 & 3
	AND	AL,0CH
	_OR	AL,CL		;Combine format bits with flag
	MOV	BX,FORMATTAB
	XLATB
	_OR	AL,AL		;Valid combination?
	JS	BADFLAG
	_OR	AH,AL		;Possibly set new bits in second byte
	_OR	AL,CH		;Set memory format bits
PUTMEM:
	AND	AL,7
	OR	AL,0D8H
	CALL	$PUT
	_MOV	AL,AH
	AND	AL,38H
	_OR	AL,DL		;Combine addressing mode
	JMP	PUTADD

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

GRP1:
	MOV	CX,8A09H
	CALL	MROPS
	MOV	CX,0C6H
	_MOV	AL,BH
	CMP	AL,UNDEFID
	JNZ	L0006
	CALL	STIMM
L0006:	
	AND	AL,1
	JZ	BYTIMM
	MOV	AL,0B8H
	_OR	AL,BL
	CALL	$PUT
	JMP	PUTWOR

BYTIMM:
	MOV	AL,0B0H
	_OR	AL,BL
	CALL	$PUT
PUTBJ:	JMP	PUTBYT

IMMED:
	_MOV	AL,BH
	CMP	AL,UNDEFID
	JZ	STIMM
	_MOV	AL,BL
	_OR	AL,AL
	JZ	RET12
	_MOV	AL,BH
	CALL	IMM
	OR	AL,0C0H
	CALL	$PUT
FINIMM:
	_MOV	AL,CL
	POP	CX
	TEST	AL,1
	JZ	PUTBJ
	CMP	AL,83H
	JZ	PUTBJ
	_JMP	PUTWOR

STIMM:
	MOV	AL,[FLAG]
	CALL	IMM
	CALL	PUTADD
	JP	FINIMM

IMM:
	AND	AL,1
	_OR	AL,CL
	_MOV	CL,AL
	CALL	$PUT
	_MOV	AL,CH
	AND	AL,38H
	_OR	AL,BL
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
	CALL	PUTINC		;Save it and bump code pointer
GEN1:
	MOV	AL,[RELOC]
	RCL	CH
	RCL	AL
	RCL	CH
	RCL	AL
	MOV	[RELOC],AL
	MOV	BX,BCOUNT
	DEC	BYTE [BX]
	JNZ	RET19
	MOV	BYTE [BX],4
	MOV	BX,RELOC
	MOV	AL,[BX]
	MOV	BYTE [BX],0
	MOV	DI,[IY]
	MOV	[DI],AL
	MOV	BX,[CODE]
	MOV	[IY],BX
	INC	BX
	MOV	[CODE],BX
	RET

PUTINC:
	INC	WORD [PC]
PUTCD:
	MOV	DI,[CODE]
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
	_MOV	AL,BH
	_OR	AL,BL
	JNZ	PUTBW
	MOV	BX,[DATA]
	_OR	AL,BH
	JZ	PUTBW
	INC	BH
	JZ	PUTBW
	MOV	CL,31
	JMP	ERROR
PUTBW:
	MOV	DX,[DLABEL]
	MOV	BX,[DATA]
PUTCHK:
	_OR	DX,DX
	JZ	NOUNDEF
	_MOV	AL,DL
	CALL	PUTCD
	_MOV	AL,DH
	CALL	PUTCD
	_MOV	AL,BL
	CALL	PUTINC
	_MOV	AL,BH
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
	_MOV	AL,BL
	_MOV	CL,BH
	PUSH	CX
	MOV	CH,0
	CALL	GEN
	POP	CX
	_MOV	AL,CL
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
	_MOV	CL,AL
	CALL	GEN		;Save the addressing mode as pure code
	_MOV	AL,CL
	MOV	CH,80H
	AND	AL,0C7H
	CMP	AL,6
	JZ	TWOBT		;Direct address?
	AND	AL,0C0H
	JZ	PRET		;Indirect through reg, no displacement?
	CMP	AL,0C0H
	JZ	PRET		;Register to register operation?
	_MOV	CH,AL		;Save whether one- or two-byte displacement
TWOBT:
	MOV	BX,[ADDR]
	MOV	DX,[ALABEL]
	JP	PUTCHK

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
	JNZ	$+5
	_JMP	PACKREG
	MOV	CL,20
	JMP	ERROR

PMEM:
	_MOV	AL,CH
	CALL	$PUT
	_MOV	AL,CL
	_OR	AL,DL
	_JMP	PUTADD

PXREG:
	_MOV	AL,CH
	_OR	AL,DL
	JMP	$PUT

GRP3:
	CALL	GETOP
	PUSH	DX
	CALL	GETOP2
	POP	BX
	MOV	CX,8614H
	MOV	AL,SREG
	_CMP	AL,BH
	JZ	ERR6
	_CMP	AL,DH
	JZ	ERR6
	MOV	AL,CONST
	_CMP	AL,BH
	JZ	ERR6
	_CMP	AL,DH
	JZ	ERR6
	MOV	AL,UNDEFID
	_CMP	AL,BH
	JZ	EXMEM
	_CMP	AL,DH
	JZ	EXMEM1
	_MOV	AL,BH
	_CMP	AL,DH
	MOV	CL,22
	JNZ	ERR6
	CMP	AL,XREG
	JZ	L0008
	CALL	RR1
L0008:			;RR1 never returns
	_MOV	AL,BL
	_OR	AL,AL
	JZ	EXACC
	XCHG	BX,DX
	_MOV	AL,BL
	_OR	AL,AL
	_MOV	AL,BH
	JZ	EXACC
	CALL	RR1
EXACC:
	MOV	AL,90H
	_OR	AL,DL
	JMP	$PUT

EXMEM:
	XCHG	BX,DX
EXMEM1:
	_CMP	AL,BH
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
	_OR	AL,DL
	MOV	CL,20
	JNZ	ERR6
	_MOV	AL,CH
	OR	AL,8
	JMP	$PUT
FIXED:
	_MOV	AL,CH
	CALL	$PUT
	JMP	PUTBYT

GRP5:
	PUSH	AX
	CALL	GETOP
	MOV	CL,20
	CMP	AL,CONST
	JNZ	ERR6
	MOV	BX,[DLABEL]
	_MOV	AL,BH
	_OR	AL,BL
	MOV	CL,30
	JNZ	ERR6
	MOV	BX,[DATA]
	POP	AX
	_OR	AL,AL
	JZ	$ORG
	DEC	AL
	JZ	DSJ
	DEC	AL
	JZ	$EQU
	DEC	AL
	JZ	$+5
	_JMP	IF
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
	_ADD	BX,DX
	MOV	[PC],BX
	XCHG	BX,DX
	MOV	AL,-4
	JP	NEWLOC
$EQU:
	XCHG	BX,DX
	MOV	BX,[LABPT]
	_MOV	AL,BH
	_OR	AL,BL
	MOV	CL,34
	JZ	ERR7
	MOV	[BX],DL
	INC	BX
	MOV	[BX],DH
RET14:	RET
$ORG:
	MOV	[PC],BX
	MOV	AL,-2
NEWLOC:
	CALL	PUTCD
	_MOV	AL,BL
	CALL	PUTCD
	_MOV	AL,BH
	CALL	PUTCD
	MOV	CH,0C0H
	JMP	GEN1
GRP6:
	_MOV	CH,AL
	MOV	CL,4
	CALL	MROPS
	MOV	CL,23
ERR7:	JMP	ERROR
GRP7:
	_MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,80H
	MOV	DX,[DLABEL]
	_MOV	AL,DH
	_OR	AL,DL
	JNZ	ACCJ
	XCHG	BX,DX
	MOV	BX,[DATA]
	_MOV	AL,BL
	CBW
	_CMP	AX,BX
	XCHG	BX,DX
	JNZ	ACCJ
	OR	CL,002H
ACCJ:	JMP	ACCIMM
GRP8:
	_MOV	CL,AL
	MOV	CH,0FEH
	JP	ONEOP
GRP9:
	_MOV	CL,AL
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
	_MOV	AL,CL
	AND	AL,0F8H
	_OR	AL,DL
	JMP	$PUT
MOP:
	MOV	AL,[FLAG]
	AND	AL,1
	_OR	AL,CH
	CALL	$PUT
	_MOV	AL,CL
	AND	AL,38H
	_OR	AL,DL
	JMP	PUTADD
ROP:
	_OR	AL,CH
	CALL	$PUT
	_MOV	AL,CL
	AND	AL,38H
	OR	AL,0C0H
	_OR	AL,DL
	JMP	$PUT
GRP10:
	_MOV	CL,AL
	MOV	CH,0F6H
	PUSH	CX
	CALL	GETOP
	MOV	CL,20
	_MOV	AL,DL
	_OR	AL,AL
	JNZ	ERRJ1
	_MOV	AL,DH
	CMP	AL,XREG
	JZ	G10
	CMP	AL,REG
ERRJ1:	JNZ	ERR8
G10:
	PUSH	AX
	CALL	GETOP
	POP	AX
	AND	AL,1
	MOV	[FLAG],AL
	_MOV	AL,DH
ONEJ:	JP	ONE
GRP11:
	CALL	$PUT
	MOV	AL,0AH
	JMP	$PUT
GRP12:
	_MOV	CL,AL
	MOV	CH,0D0H
	PUSH	CX
	CALL	GETOP
	MOV	AL,[SYM]
	CMP	AL,','
	_MOV	AL,DH
	JNZ	ONEJ
	PUSH	DX
	CALL	GETOP
	SUB	AL,REG
	MOV	CL,20
	DEC	DL
	_OR	AL,DL
	JNZ	ERR8
	POP	DX
	_MOV	AL,DH
	POP	CX
	OR	CH,002H
	PUSH	CX
	JMP	ONE
GRP13:
	_MOV	CH,AL
	MOV	CL,1
	CALL	MROPS
	MOV	CL,80H
ACCIMM:
	CALL	IMMED
	OR	CH,004H
	AND	CH,0FDH
AIMM:
	_MOV	AL,BH
	AND	AL,1
	LAHF
	PUSH	AX
	_OR	AL,CH
	CALL	$PUT
	POP	AX
	SAHF
	JNZ	$+5
	_JMP	PUTBYT
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
	_OR	AL,DL
	MOV	CH,[FLAG]
	_CMP_CH 3		;Flag "L" present?
	JZ	PUTADDJ		;If so, do inter-segment
	MOV	CL,27H
	_CMP_CH -1		;Better not be a flag
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
	JNZ	ERR9
	_MOV	AL,CH
	AND	AL,0FEH
	CALL	$PUT
	JMP	PUTWOR
LONGR:
	_CMP_DL 3		;Is flag "L"?
	MOV	CL,27H
	JNZ	ERR10		;If not, bad flag
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
	_MOV	AL,BH
	_OR	AL,BL
	JZ	DORET
	MOV	BYTE [BX],1
	INC	BX
	MOV	[BX],DX
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
	_SUB	BX,DX
	MOV	[DATA],BX
	CALL	PUTBYT
	MOV	BX,[DLABEL]
	_MOV	AL,BH
	_OR	AL,BL
	JNZ	RET15
	MOV	BX,[DATA]
	_MOV	AL,BL
	CBW
	_CMP	AX,BX		;Signed 8-bit number?
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
	_MOV	AL,BH
	_OR	AL,BL
	JNZ	GENINT
	MOV	BX,[DATA]
	MOV	DX,3
	_SBB	BX,DX
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
	_CMP_AX	64		;Must only be 6 bits
	MOV	CL,1FH
	JNB	ERRJ
	_MOV	BL,AL		;Save for second byte
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
	_OR	BL,DL		;Combine mode with first operand
	_MOV	AL,BL
	JMP	PUTADD

ESCIMM:
	MOV	CL,1EH
	TEST	WORD [DLABEL],-1	;See if second operand is fully defined
	JNZ	ERRJ
	MOV	AX,[DATA]
	MOV	CL,1FH
	_CMP_AX	8		;Must only be 3 bit value
	JNB	ERRJ
	_OR	AL,BL		;Combine first and second operands
	OR	AL,0C0H		;Force "register" mode
	JMP	$PUT

GRP20:
	_MOV	CH,AL
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
	_MOV	AL,DL
	_ADD	AL,AL
	_ADD	AL,AL
	_ADD	AL,AL
	_OR	AL,CH
	JMP	$PUT
GRP22:
	CALL	GETOP
	MOV	CX,8F00H
	CMP	AL,UNDEFID
	JNZ	$+5
	_JMP	PMEM
	MOV	CH,58H
	CMP	AL,XREG
	JNZ	$+5
	_JMP	PXREG
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
	_OR	AL,AL
	JZ	$+5
	_JMP	PUTBYT
	JMP	PUTWOR
IF:
	_OR	BX,BX
	JZ	SKIPCD
	INC	BYTE [IFFLG]
	RET

SKIPCD:
	INC	BYTE [CHKLAB]
SKIPLP:
	_XOR	AL,AL
	CALL	NEXLIN
	CALL	NEXTCHR
	CMP	AL,1AH
	JZ	END
	CALL	GETLAB
	JC	SKIPLP
	MOV	DI,LENID
	MOV	SI,IFEND
	MOV	CH,0
	MOV	CL,[DI]
	INC	CL
	REPE
	CMPB
	JZ	ENDCOND
	MOV	DI,LENID
	MOV	SI,IFNEST
	MOV	CL,[DI]
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
	MOV	DL,4
WREND:
	MOV	CH,0FFH
	_MOV	AL,CH
	CALL	GEN
	DEC	DL
	JNZ	WREND
	MOV	WORD [BUFPT],SRCBUF
	MOV	BYTE [HEXCNT],-5	;FLAG HEX BUFFER AS EMPTY
	MOV	WORD [LSTPNT],LSTBUF
	MOV	WORD [HEXPNT],HEXBUF
	_XOR	AX,AX
	MOV	[ERRCNT],AX
	MOV	[PC],AX
	MOV	[LINE],AX	;Current line number
	MOV	WORD [HEXADD],OBJECT
	MOV	DX,FCB
	MOV	AH,OPEN
	INT	33		;Re-open source file
	_XOR	AX,AX
	MOV	[FCB+12],AX	;Set CURRENT BLOCK to zero
	MOV	[FCB+20H],AL	;Set NEXT RECORD field to zero
	MOV	WORD [FCB+14],BUFSIZ
	MOV	[COUNT],AL
	MOV	CH,1
	MOV	SI,START
FIXLINE:
	MOV	DI,START	;Store code over used up intermediate code
	_XOR	AL,AL
	MOV	[SPC],AL	;No "special" yet ($ORG, $PUT, DS)
	MOV	[ERR],AL	;No second pass errors yet
NEXBT:
	SHL	CL		;Shift out last bit of previous code
	DEC	CH		;Still have codes left?
	JNZ	TESTTYP
	LODB			;Get next flag byte
	_MOV	CL,AL
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
	ADD	AX,[BX+1]	;Add symbol value to constant part
	_CMP_BBX 0	;See if symbol got defined
	JNZ	HAVDEF
	MOV	BYTE [ERR],100	;Undefined - flag error
	_XOR	AX,AX
HAVDEF:
	_OR	CL,CL		;See if word or byte fixup
	JS	DEFBYT
	STOW
	JP	NEXBT

DEFBYT:
	_MOV	DX,AX
	CBW			;Extend sign
	_CMP	AX,DX		;See if in range +127 to -128
	JZ	OBJBT		;If so, it's always OK
	NOT	AH		;Check for range +255 to -256
	_CMP	AH,DH
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
	_MOV	AL,DL		;Get code byte in AL
	JNZ	OBJBT		;If not, we're OK
RNGERR:
	MOV	BYTE [ERR],101	;Value out of range
	JP	OBJBT

FINIJ:	JMP	FINI

EMARK:
	CMP	AL,-1		;End of file?
	JZ	FINIJ
	CMP	AL,-10		;Special item?
	JA	SPEND
	PUSH	CX
	PUSH	SI
	PUSH	AX		;Save error code
	MOV	AH,[LSTDEV]
	AND	AH,0FEH		;Reset error indicator
	OR	AL,[ERR]	;See if any errors on this line
	JZ	NOERR
	OR	AH,1		;Send line to console if error occured
NOERR:
	MOV	[LSTDEV],AH
	_MOV	CX,DI
	CALL	STRTLIN		;Print address of line
	MOV	SI,START
	_SUB	CX,SI		;Get count of bytes of code
	JZ	SHOLIN
CODLP:
	LODB
	CALL	SAVCD		;Ouput code to HEX and PRN files
	LOOP	CODLP
SHOLIN:
	MOV	AL,0
	XCHG	AL,[COUNT]
	MOV	CX,7		;Allow 7 bytes of code per line
	_SUB	CL,AL
	MOV	AL,' '
	JZ	NOFIL
BLNK:				;Put in 3 blanks for each byte not present
	CALL	LIST
	CALL	LIST
	CALL	LIST
	LOOP	BLNK
NOFIL:
	CALL	OUTLIN
	POP	AX		;Restore error code
	CALL	REPERR
	MOV	AL,[ERR]
	CALL	REPERR
	POP	SI
	POP	CX
	MOV	AL,[SPC]	;Any special funtion?
	_OR	AL,AL
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
	MOV	AL,-1
	XCHG	AL,[LINFLG]
	_OR	AL,AL
	JNZ	CRLF		;Output line only if first time
	MOV	AX,[LINE]
	INC	AX
	MOV	[LINE],AX
	MOV	BH,0		;No leading zero suppression
	CALL	OUT10
	MOV	AL," "
	CALL	LIST
	MOV	AL,[LSTFCB]
	CMP	AL,'Z'
	JZ	CRLF		;Don't call NEXTCHR if listing suppressed
	PUSH	SI		;Save the only register destroyed by NEXTCHR
OUTLN:
	CALL	NEXTCHR
	CALL	LIST
	CMP	AL,10		;Output until linefeed found
	JNZ	OUTLN
	POP	SI
	RET

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
	_XOR	DX,DX
	MOV	DI,10000
	DIV	AX,DI
	_OR	AL,AL		;>10,000?
	JNZ	LEAD
	SUB	AL,"0"-" "	;Convert leading zero to blank
LEAD:
	ADD	AL,"0"
	CALL	LIST
	XCHG	AX,DX
	MOV	BL,100
	DIV	AL,BL
	_MOV	BL,AH
	CALL	HIDIG		;Convert to decimal and print 1000s digit
	CALL	DIGIT		;Print 100s digit
	_MOV	AL,BL
	CALL	HIDIG		;Convert to decimal and print 10s digit
	MOV	BH,0		;Ensure leading zero suppression is off
	JP	DIGIT

HIDIG:
	AAM			;Convert binary to unpacked BCD
	OR	AX,3030H	;Add "0" bias
DIGIT:
	XCHG	AL,AH
	CMP	AL,"0"
	JZ	SUPZ
	MOV	BH,0		;Turn off zero suppression if not zero
SUPZ:
	_SUB	AL,BH		;Convert leading zeros to blanks
	JP	LIST

STRTLIN:
	MOV	BYTE [LINFLG],0
	MOV	BX,[PC]
	_MOV	AL,BH
	CALL	PHEX
	_MOV	AL,BL
PHEXB:
	CALL	PHEX
	MOV	AL,' '
LIST:  ; Print signle character in AL.
	PUSH	AX
	PUSH	DX
	AND	AL,7FH
	_MOV	DL,AL
	TEST	BYTE [LSTDEV],3	;See if output goes to console
	JZ	PRNCHK
	MOV	AH,2
	INT	33		;Output to console
PRNCHK:
	TEST	BYTE [LSTDEV],4	;See if output goes to printer
	JZ	FILCHK
	MOV	AH,5
	INT	33		;Output to printer
FILCHK:
	_MOV	AL,DL
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
	STOB
	CMP	DI,LSTBUF+LSTBUFSIZ
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
	PUSH	AX
	CALL	UHALF
	CALL	LIST
	POP	AX
	CALL	LHALF
	JP	LIST

FINI:
	OR	BYTE [LSTDEV],1
	CALL	PRTCNT
	MOV	BX,SYMSIZE
	MOV	AX,[6]
	SUB	AX,[HEAP]		;Size of symbol table
	CALL	PRNT10
	MOV	BX,FRESIZE
	MOV	AX,[HEAP]
	SUB	AX,[CODE]		;Free space remaining
	CALL	PRNT10
	AND	BYTE [LSTDEV],0FEH
	MOV	AL,[HEXFCB]
	CMP	AL,'Z'
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
	CALL	PUTCHR
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
	MOV	DX,HEXFCB
	MOV	AH,CLOSE
	INT	33
SYMDMP:
	MOV	AL,[SYMFLG]
	CMP	AL,'S'
	JNZ	ENDSYM
	MOV	AL,[LSTDEV]
	_OR	AL,AL		;Any output device for symbol table dump?
	JNZ	DOSYMTAB
	OR	AL,1		;If not, send it to console
	MOV	[LSTDEV],AL
DOSYMTAB:
	MOV	BX,SYMMES
	CALL	PRINT
	MOV	DX,[BASE]
	_MOV	AL,DH
	_OR	AL,DL
	JZ	ENDSYM
	MOV	BYTE [SYMLIN],SYMWID  ;No symbols on this line yet
	MOV	BX,[HEAP]
	_MOV	SP,BX		;Need maximum stack for recursive tree walk
	CALL	NODE
ENDSYM:
	TEST	BYTE [LSTDEV],80H	;Print listing to file?
	JZ	EXIT
	MOV	AL,1AH
	CALL	WRTBUF		;Write end-of-file mark
	MOV	DI,[LSTPNT]
	CALL	FLUSHBUF
	MOV	AH,CLOSE
	INT	33
EXIT:	JMP	0

NODE:
	XCHG	BX,DX
	PUSH	BX
	MOV	DL,[BX]
	MOV	DH,0
	INC	BX
	_ADD	BX,DX
	MOV	DX,[BX]
	_OR	DX,DX
	JZ	L0014
	CALL	NODE
L0014:	
	POP	BX
	MOV	AL,[BX]
	INC	BX
	_MOV	CH,AL
	ADD	AL,24
	SHR	AL
	SHR	AL
	SHR	AL
	_MOV	CL,AL
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
	MOV	AL,[BX]
	INC	BX
	CALL	LIST
	DEC	CH
	JNZ	WRTSYM
	INC	CL
TABVAL:
	MOV	AL,9
	CALL	LIST
	LOOP	TABVAL
	INC	BX
	INC	BX
	PUSH	BX
	MOV	AL,[BX+4]
	CALL	PHEX
	MOV	AL,[BX+3]
	CALL	PHEX
	_CMP_BDIS SYMLIN,0	;Will any more fit on line?
	JZ	NEXSYMLIN
	MOV	AL,9
	CALL	LIST
	JP	RIGHTSON
NEXSYMLIN:
	CALL	CRLF
	MOV	BYTE [SYMLIN],SYMWID
RIGHTSON:
	POP	BX
	MOV	DX,[BX]
	_OR	DX,DX
	JNZ	NODE
	RET

SAVCD:
	MOV	[PREV],AL
	PUSH	BX
	PUSH	CX
	PUSH	AX
	PUSH	DX
	CALL	CODBYT
	POP	DX
	MOV	BX,COUNT
	INC	BYTE [BX]
	MOV	AL,[BX]
	CMP	AL,8
	JNZ	NOEXT
	MOV	BYTE [BX],1
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
	_OR	AL,AL		;Did an error occur?
	JZ	RET16
	INC	WORD [ERRCNT]
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
	_MOV	BX,DI		;Put address of message in BX
	JZ	PRNERR		;Do we have a message for this error?
	CALL	PHEX		;If not, just print error number
	JMP	CRLF

PRNERR:
	CALL	PRINT
	JMP	CRLF

PRINT:  ; Print high-bit-terminated string starting at BX.
	MOV	AL,[BX]
	CALL	LIST
	_OR	AL,AL
	JS	RET16
	INC	BX
	JP	PRINT

OUTA:
	_MOV	DL,AL
$OUT:
	AND	DL,7FH
	MOV	CL,2
SYSTEM:
	CALL	5
RET17:	RET

CODBYT:
	_CMP_BDIS HEXFCB,"Z"
	JZ	RET17
	PUSH	AX
	MOV	DX,[LASTAD]
	MOV	BX,[HEXADD]
	MOV	[LASTAD],BX
	INC	DX
	MOV	AL,[HEXCNT]
	CMP	AL,-5
	JZ	NEWLIN
	_CMP	BX,DX
	JZ	AFHEX
	CALL	ENHEXL
NEWLIN:
	MOV	AL,':'
	CALL	PUTCHR
	MOV	AL,-4
	MOV	[HEXCNT],AL
	_XOR	AL,AL
	MOV	[CHKSUM],AL
	MOV	BX,[HEXPNT]
	MOV	[HEXLEN],BX
	CALL	HEXBYT
	MOV	AL,[HEXADD+1]
	CALL	HEXBYT
	MOV	AL,[HEXADD]
	CALL	HEXBYT
	_XOR	AL,AL
	CALL	HEXBYT
AFHEX:
	POP	AX
HEXBYT:
	_MOV	CH,AL
	MOV	BX,CHKSUM
	ADD	AL,[BX]
	MOV	[BX],AL
	_MOV	AL,CH
	CALL	UHALF
	CALL	PUTCHR
	_MOV	AL,CH
	CALL	LHALF
	CALL	PUTCHR
	MOV	BX,HEXCNT
	INC	BYTE [BX]
	MOV	AL,[BX]
	CMP	AL,26
	JNZ	RET17
ENHEXL:
	MOV	DI,[HEXLEN]
	_MOV	CH,AL
	CALL	UHALF
	STOB
	_MOV	AL,CH
	CALL	LHALF
	STOB
	MOV	AL,-6
	MOV	[HEXCNT],AL
	MOV	AL,[CHKSUM]
	_ADD	AL,CH
	NEG	AL
	CALL	HEXBYT
	MOV	AL,13
	CALL	PUTCHR
	MOV	AL,10
	CALL	PUTCHR
WRTHEX:
;Write out the line
	MOV	DX,HEXBUF
	MOV	[HEXPNT],DX
	MOV	AH,SETDMA
	INT	33
	_SUB	DI,DX		;Length of buffer
	_MOV	CX,DI
	MOV	DX,HEXFCB
	MOV	AH,BLKWRT
	INT	33
	_OR	AL,AL
	JNZ	DSKFUL
	RET

PUTCHR:
	MOV	DI,[HEXPNT]
	STOB
	MOV	[HEXPNT],DI
RET20:	RET

FLUSHBUF:
	_MOV	CX,DI
	MOV	DX,LSTBUF
	_MOV	DI,DX
	_SUB	CX,DX
	JZ	RET20		;Buffer empty?
	MOV	AH,SETDMA
	INT	33
	MOV	DX,LSTFCB
	MOV	AH,BLKWRT
	INT	33
	_OR	AL,AL
	JZ	RET20
DSKFUL:
	MOV	BX,WRTERR
	JMP	PRERR

UHALF:
	RCR	AL
	RCR	AL
	RCR	AL
	RCR	AL
LHALF:
	AND	AL,0FH
	OR	AL,30H
	CMP	AL,'9'+1
	JC	RET20
	ADD	AL,7
	RET

NONE:	DB	0

; 8086 MNEMONIC TABLE

; This table is actually a sequence of subtables, each starting with a label.
; The label signifies which mnemonics the subtable applies to--A3, for example,
; means all 3-letter mnemonics beginning with A.

A3:
	DB	7
	DB	'dd'
	DW	GRP7
	DB	2
	DB	'nd'
	DW	GRP13
	DB	22H
	DB	'dc'
	DW	GRP7
	DB	12H
	DB	'aa'
	DW	$PUT
	DB	37H
	DB	'as'
	DW	$PUT
	DB	3FH
	DB	'am'
	DW	GRP11
	DB	0D4H
	DB	'ad'
	DW	GRP11
	DB	0D5H
A5:
	DB	1
	DB	'lign'
	DW	$ALIGN
	DB	0
C3:
	DB	7
	DB	'mp'
	DW	GRP7
	DB	3AH
	DB	'lc'
	DW	$PUT
	DB	0F8H
	DB	'ld'
	DW	$PUT
	DB	0FCH
	DB	'li'
	DW	$PUT
	DB	0FAH
	DB	'mc'
	DW	$PUT
	DB	0F5H
	DB	'bw'
	DW	$PUT
	DB	98H
	DB	'wd'
	DW	$PUT
	DB	99H
C4:
	DB	3
	DB	'all'
	DW	GRP14
	DB	9AH
	DB	'mpb'
	DW	$PUT
	DB	0A6H
	DB	'mpw'
	DW	$PUT
	DB	0A7H
C5:
	DB	2
	DB	'mpsb'
	DW	$PUT
	DB	0A6H
	DB	'mpsw'
	DW	$PUT
	DB	0A7H
D2:
	DB	5
	DB	'b'
	DW	GRP23
	DB	1
	DB	'w'
	DW	GRP23
	DB	0
	DB	'm'
	DW	GRP23
	DB	2
	DB	's'
	DW	GRP5
	DB	1
	DB	'i'
	DW	$PUT
	DB	0FAH
D3:
	DB	4
	DB	'ec'
	DW	GRP8
	DB	49H
	DB	'iv'
	DW	GRP10
	DB	30H
	DB	'aa'
	DW	$PUT
	DB	27H
	DB	'as'
	DW	$PUT
	DB	2FH
D4:
	DB	1
	DB	'own'
	DW	$PUT
	DB	0FDH
E2:
	DB	1
	DB	'i'
	DW	$PUT
	DB	0FBH
E3:
	DB	3
	DB	'qu'
	DW	GRP5
	DB	2
	DB	'sc'
	DW	GRP19
	DB	0D8H
	DB	'nd'
	DW	END
	DB	0
E5:
	DB	1
	DB	'ndif'
	DW	ENDIF
	DB	0
H3:
	DB	1
	DB	'lt'
	DW	$PUT
	DB	0F4H
H4:
	DB	1
	DB	'alt'
	DW	$PUT
	DB	0F4H
I2:
	DB	2
	DB	'n'
	DW	GRP4
	DB	0E4H
	DB	'f'
	DW	GRP5
	DB	4
I3:
	DB	4
	DB	'nc'
	DW	GRP8
	DB	41H
	DB	'nb'
	DW	GRP4
	DB	0E4H
	DB	'nw'
	DW	GRP4
	DB	0E5H
	DB	'nt'
	DW	GRP18
	DB	0CCH
I4:
	DB	4
	DB	'mul'
	DW	GRP10
	DB	28H
	DB	'div'
	DW	GRP10
	DB	38H
	DB	'ret'
	DW	$PUT
	DB	0CFH
	DB	'nto'
	DW	$PUT
	DB	0CEH
J2:
	DB	10
	DB	'p'
	DW	GRP17
	DB	0EBH
	DB	'z'
	DW	GRP17
	DB	74H
	DB	'e'
	DW	GRP17
	DB	74H
	DB	'l'
	DW	GRP17
	DB	7CH
	DB	'b'
	DW	GRP17
	DB	72H
	DB	'a'
	DW	GRP17
	DB	77H
	DB	'g'
	DW	GRP17
	DB	7FH
	DB	'o'
	DW	GRP17
	DB	70H
	DB	's'
	DW	GRP17
	DB	78H
	DB	'c'
	DW	GRP17
	DB	72H
J3:
	DB	17
	DB	'mp'
	DW	GRP14
	DB	0EAH
	DB	'nz'
	DW	GRP17
	DB	75H
	DB	'ne'
	DW	GRP17
	DB	75H
	DB	'nl'
	DW	GRP17
	DB	7DH
	DB	'ge'
	DW	GRP17
	DB	7DH
	DB	'nb'
	DW	GRP17
	DB	73H
	DB	'ae'
	DW	GRP17
	DB	73H
	DB	'nc'
	DW	GRP17
	DB	73H
	DB	'ng'
	DW	GRP17
	DB	7EH
	DB	'le'
	DW	GRP17
	DB	7EH
	DB	'na'
	DW	GRP17
	DB	76H
	DB	'be'
	DW	GRP17
	DB	76H
	DB	'pe'
	DW	GRP17
	DB	7AH
	DB	'np'
	DW	GRP17
	DB	7BH
	DB	'po'
	DW	GRP17
	DB	7BH
	DB	'no'
	DW	GRP17
	DB	71H
	DB	'ns'
	DW	GRP17
	DB	79H
J4:
	DB	6
	DB	'mps'
	DW	GRP17
	DB	0EBH
	DB	'cxz'
	DW	GRP17
	DB	0E3H
	DB	'nge'
	DW	GRP17
	DB	7CH
	DB	'nae'
	DW	GRP17
	DB	72H
	DB	'nbe'
	DW	GRP17
	DB	77H
	DB	'nle'
	DW	GRP17
	DB	7FH
L3:
	DB	3
	DB	'ea'
	DW	GRP6
	DB	8DH
	DB	'ds'
	DW	GRP6
	DB	0C5H
	DB	'es'
	DW	GRP6
	DB	0C4H
L4:
	DB	5
	DB	'oop'
	DW	GRP17
	DB	0E2H
	DB	'odb'
	DW	$PUT
	DB	0ACH
	DB	'odw'
	DW	$PUT
	DB	0ADH
	DB	'ahf'
	DW	$PUT
	DB	9FH
	DB	'ock'
	DW	$PUT
	DB	0F0H
L5:
	DB	4
	DB	'oope'
	DW	GRP17
	DB	0E1H
	DB	'oopz'
	DW	GRP17
	DB	0E1H
	DB	'odsb'
	DW	$PUT
	DB	0ACH
	DB	'odsw'
	DW	$PUT
	DB	0ADH
L6:
	DB	2
	DB	'oopne'
	DW	GRP17
	DB	0E0H
	DB	'oopnz'
	DW	GRP17
	DB	0E0H
M3:
	DB	2
	DB	'ov'
	DW	GRP1
	DB	88H
	DB	'ul'
	DW	GRP10
	DB	20H
M4:
	DB	2
	DB	'ovb'
	DW	$PUT
	DB	0A4H
	DB	'ovw'
	DW	$PUT
	DB	0A5H
M5:
	DB	2
	DB	'ovsb'
	DW	$PUT
	DB	0A4H
	DB	'ovsw'
	DW	$PUT
	DB	0A5H
N3:
	DB	3
	DB	'ot'
	DW	GRP9
	DB	10H
	DB	'eg'
	DW	GRP9
	DB	18H
	DB	'op'
	DW	$PUT
	DB	90H
O2:
	DB	1
	DB	'r'
	DW	GRP13
	DB	0AH
O3:
	DB	2
	DB	'ut'
	DW	GRP4
	DB	0E6H
	DB	'rg'
	DW	GRP5
	DB	0
O4:
	DB	2
	DB	'utb'
	DW	GRP4
	DB	0E6H
	DB	'utw'
	DW	GRP4
	DB	0E7H
P3:
	DB	2
	DB	'op'
	DW	GRP22
	DB	8FH
	DB	'ut'
	DW	GRP5
	DB	3
P4:
	DB	2
	DB	'ush'
	DW	GRP2
	DB	0FFH
	DB	'opf'
	DW	$PUT
	DB	9DH
P5:
	DB	1
	DB	'ushf'
	DW	$PUT
	DB	9CH
R3:
	DB	6
	DB	'et'
	DW	GRP16
	DB	0C3H
	DB	'ep'
	DW	$PUT
	DB	0F3H
	DB	'ol'
	DW	GRP12
	DB	0
	DB	'or'
	DW	GRP12
	DB	8
	DB	'cl'
	DW	GRP12
	DB	10H
	DB	'cr'
	DW	GRP12
	DB	18H
R4:
	DB	2
	DB	'epz'
	DW	$PUT
	DB	0F3H
	DB	'epe'
	DW	$PUT
	DB	0F3H
R5:
	DB	2
	DB	'epnz'
	DW	$PUT
	DB	0F2H
	DB	'epne'
	DW	$PUT
	DB	0F2H
S3:
	DB	11
	DB	'ub'
	DW	GRP7
	DB	2AH
	DB	'bb'
	DW	GRP7
	DB	1AH
	DB	'bc'
	DW	GRP7
	DB	1AH
	DB	'tc'
	DW	$PUT
	DB	0F9H
	DB	'td'
	DW	$PUT
	DB	0FDH
	DB	'ti'
	DW	$PUT
	DB	0FBH
	DB	'hl'
	DW	GRP12
	DB	20H
	DB	'hr'
	DW	GRP12
	DB	28H
	DB	'al'
	DW	GRP12
	DB	20H
	DB	'ar'
	DW	GRP12
	DB	38H
	DB	'eg'
	DW	GRP21
	DB	26H
S4:
	DB	5
	DB	'cab'
	DW	$PUT
	DB	0AEH
	DB	'caw'
	DW	$PUT
	DB	0AFH
	DB	'tob'
	DW	$PUT
	DB	0AAH
	DB	'tow'
	DW	$PUT
	DB	0ABH
	DB	'ahf'
	DW	$PUT
	DB	9EH
S5:
	DB	4
	DB	'casb'
	DW	$PUT
	DB	0AEH
	DB	'casw'
	DW	$PUT
	DB	0AFH
	DB	'tosb'
	DW	$PUT
	DB	0AAH
	DB	'tosw'
	DW	$PUT
	DB	0ABH
T4:
	DB	1
	DB	'est'
	DW	GRP20
	DB	84H
U2:
	DB	1
	DB	'p'
	DW	$PUT
	DB	0FCH
W4:
	DB	1
	DB	'ait'
	DW	$PUT
	DB	9BH
X3:
	DB	1
	DB	'or'
	DW	GRP13
	DB	32H
X4:
	DB	2
	DB	'chg'
	DW	GRP3
	DB	86H
	DB	'lat'
	DW	$PUT
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

;Error message table

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
NOSPAC:	DB	13,10,'File creation error',13,10,"$"
NOMEM:	DB	13,10,'Insufficient memory',13,10,'$'
NOFILE:	DB	13,10,'File not found',13,10,'$'
WRTERR:	DB	13,10,'Disk full',13,10,'$'
BADDSK:	DB	13,10,'Bad disk specifier',13,10,'$'
ERCNTM:	DM	13,10,13,10,'Error Count ', '='
SYMSIZE	DM	13,10,'Symbol Table size =', ' '
FRESIZE	DM	'Free space =       ', ' '
SYMMES:	DM	13,10,'Symbol Table',13,10,13,10
EXTEND:	DB	'ASM',0,0
IFEND:	DB	5,'endif'
IFNEST:	DB	2,'if'
RETSTR:	DM	're', 't'
HEXFCB:	DB	0,'        HEX',0,0,0,0
	DS	16
	DB	0,0,0,0,0
LSTFCB:	DB	0,'        PRN',0,0,0,0
	DS	16
	DB	0,0,0,0,0
absolute $  ; NASM: don't emit any more bytes, start .bss.
%define DS resb
PC:	DS	2
OLDPC:	DS	2
LABPT:	DS	2
FLAG:	DS	1
MAXFLG:	DS	1
ADDR:	DS	2
ALABEL:	DS	2
DATA:	DS	2
DLABEL:	DS	2
CON:	DS	2
UNDEF:	DS	2
LENID:	DS	1
ID:	DS	80
CHR:	DS	1
SYM:	DS	1
BASE:	DS	2
HEAP:	DS	2
SYMFLG:	DS	1
SYMLIN:	DS	1
CODE:	DS	2
DATSIZ:	DS	1
RELOC:	DS	1
BCOUNT:	DS	1
COUNT:	DS	1
ERR:	DS	1
LINE:	DS	2
HEXLEN:	DS	2
HEXADD:	DS	2
LASTAD:	DS	2
HEXCNT:	DS	1
CHKSUM:	DS	1
LINFLG:	DS	1
PREV:	DS	1
IFFLG:	DS	1
CHKLAB:	DS	1
ERRCNT:	DS	2
LSTRET:	DS	2
RETPT:	DS	2
LSTDEV:	DS	2
SPC:	DS	1
NOWAIT:	DS	1
IX:	DS	2
IY:	DS	2
HEXPNT:	DS	2
LSTPNT:	DS	2
HEXBUF:	DS	HEXBUFSIZ
LSTBUF:	DS	LSTBUFSIZ
BUFPT:	DS	2
SRCBUF:	DS	BUFSIZ
	DS	100H
	alignb 2
STACK:
START:
