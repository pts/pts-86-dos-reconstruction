; I/O System for 86-DOS version 1.10 and later. Revised 12-3-81.

; Assumes a CPU Support card at F0 hex for character I/O,
; with disk drivers for Tarbell, Cromemco, or North Star controllers.

; Select whether the auxiliary port is the Support Card parallel port
; or on channel 1 of a Multiport Serial card addressed at 10H.
PARALLELAUX:	EQU	1
SERIALAUX:	EQU	0

; Select whether the printer is connected to the Support card parallel
; output port (standard) or channel 0 of a Multiport Serial card
; addressed at 10H.
PARALLELPRN:	EQU	1
SERIALPRN:	EQU	0

; If the Multiport Serial was chosen for either the auxiliary or the
; printer, select the baud rate here. Refer to Multiport Serial manual
; page 11 to pick the correct value for a given baud rate.
PRNBAUD:EQU	7		; 1200 baud
AUXBAUD:EQU	0FH		; 19200 baud

; Select disk controller here.
SCP:		EQU	0
TARBELLSD:	EQU	0
TARBELLDD:	EQU	1
CROMEMCO4FDC:	EQU	0
CROMEMCO16FDC:	EQU	0
NORTHSTARSD:	EQU	0

TARBELL:EQU	TARBELLSD+TARBELLDD
CROMEMCO:EQU	CROMEMCO4FDC+CROMEMCO16FDC

; If North Star controller is selected, stop here. If 1771/1793-type
; controller is selected, configuration options must be selected below:

	IF	SCP+TARBELL+CROMEMCO

; Select disk configuration:
LARGE:	EQU	1		; Four large drives.
COMBIN:	EQU	0		; Two 8-inch and one 5.25-inch.
SMALL:	EQU	0		; Three 5.25-inch drives.
CUSTOM:	EQU	0		; User defined.

; If 8-inch drives are PerSci, select FASTSEEK here:
; Fastseek with Tarbell controllers doesn't work yet.
FASTSEEK:	EQU	0

; For double-density controllers, select double-sided operation of
; 8-inch disks in double-density mode.
LARGEDS:	EQU	1

; For double-density controllers, select double-sided operation of
; 5.25-inch disks in double-density mode.
SMALLDS:	EQU	0

; Use table below to select head step speed. Step times for 5" drives
; are double that shown in the table. Times for Fast Seek mode (using
; PerSci drives) is very small - 200-400 microseconds.

; Step value	1771	1791

;     0		 6ms	 3ms
;     1		 6ms	 6ms
;     2		10ms	10ms
;     3		20ms	15ms

STPSPD:	EQU	2

;**********************************************************************

	IF	LARGE+COMBIN	; Drive A is 8-inch.
DOSLEN:	EQU	56		; Length of 86-DOS in 128-byte sectors.
DOSSECT:EQU	52+6+6+16	; Allow for reserved tracks, 2 FATs, directory
	ENDIF

	IF	SMALL		; Drive A is 5.25-inch.
DOSLEN:	EQU	56
DOSSECT:EQU	54+4+4+16
	ENDIF

	IF	CUSTOM		; Drive A is custom.
DOSLEN:	EQU	0		; Specify DOS length in sectors.
DOSSECT:EQU	0		; Specify beginning sector on disk.
	ENDIF

	ENDIF

	IF	NORTHSTARSD
DOSLEN:	EQU	28
DOSSECT:EQU	30+2+2+8
	ENDIF

	ORG	0
	PUT	100H

BASE:	EQU	0F0H
SIOBASE:EQU	10H
STAT:	EQU	BASE+7
DATA:	EQU	BASE+6
DAV:	EQU	2
TBMT:	EQU	1
SERIAL:	EQU	SERIALPRN+SERIALAUX
STCDATA:EQU	BASE+4		; Ports for 9513 Timer chip.
STCCOM:	EQU	BASE+5

	IF	SERIALAUX
AUXSTAT:EQU	SIOBASE+3
AUXDATA:EQU	SIOBASE+2
	ENDIF

	IF	PARALLELAUX
AUXSTAT:EQU	BASE+13
AUXDATA:EQU	BASE+12
	ENDIF

	IF	SERIALPRN
PRNSTAT:EQU	SIOBASE+1
PRNDATA:EQU	SIOBASE+0
	ENDIF

	IF	PARALLELPRN
PRNSTAT:EQU	BASE+13
PRNDATA:EQU	BASE+12
	ENDIF

	JMP	INIT
	JMP	STATUS
	JMP	INP
	JMP	OUTP
	JMP	PRINT
	JMP	AUXIN
	JMP	AUXOUT
	JMP	READ
	JMP	WRITE
	JMP	DSKCHG
	JMP	SETDATE
	JMP	SETTIME
	JMP	GETTIME

INIT:
	MOV	AL,0FFH		;Mask all interrupts
	OUT	BASE+3		;Send mask to slave
	XOR	AX,AX
	MOV	SS,AX
	MOV	SP,400H		;Set stack just below I/O system
	PUSH	CS
	POP	DS

; Initialize time-of-day clock.

	MOV	SI,STCTAB
	MOV	CX,4		;Initialize 4 registers
INITSTC:
	LODB
	OUT	STCCOM		;Select register to initialize
	LODB
	OUT	STCDATA
	LODB
	OUT	STCDATA
	LOOP	INITSTC

	IF	SERIAL
	MOV	CX,4
SERINIT:
	LODB
	OUT	SIOBASE+1
	OUT	SIOBASE+3
	LOOP	SERINIT
	LODB			;Baud rate for channel 0
	OUT	SIOBASE+8
	LODB			;Baud rate for channel 1
	OUT	SIOBASE+9
	ENDIF

; Load 86-DOS

	PUSH	DS
	MOV	AX,DOSSEG	; Set segment register for loading DOS.
	MOV	DS,AX
	XOR	BX,BX		; Offset in DOSSEG is zero.
	MOV	AL,BL		; Drive 0.
	MOV	CX,DOSLEN
	MOV	DX,DOSSECT
	CALL	READ,40H
	POP	DS

	MOV	SI,INITTAB
	CALL	0,DOSSEG
	MOV	DX,100H
	MOV	AH,26		;Set DMA address
	INT	21H
	MOV	CX,[6]		;Get size of segment
	MOV	BX,DS		;Save segment for later
;DS must be set to CS so we can point to the FCB
	MOV	AX,CS
	MOV	DS,AX
	MOV	DX,FCB		;File Control Block for COMMAND.COM
	MOV	AH,15
	INT	21H		;Open COMMAND.COM
	OR	AL,AL
	JNZ	COMERR		;Error if file not found
	XOR	AX,AX
	MOV	[FCB+33],AX	;Set 4-byte Random Record field to
	MOV	[FCB+35],AX	;   beginning of file
	INC	AX
	MOV	[FCB+14],AX	;Set record length field
	MOV	AH,39		;Block read (CX already set)
	INT	21H
	JCXZ	COMERR		;Error if no records read
	TEST	AL,1
	JZ	COMERR		;Error if not end-of-file
;Make all segment registers the same
	MOV	DS,BX
	MOV	ES,BX
	MOV	SS,BX
	MOV	SP,5CH		;Set stack to standard value
	XOR	AX,AX
	PUSH	AX		;Put zero on top of stack for return
	MOV	DX,80H
	MOV	AH,26
	INT	21H		;Set default transfer address (DS:0080)
	PUSH	BX		;Put segment on stack
	MOV	AX,100H
	PUSH	AX		;Put address to execute within segment on stack
	RET	L		;Jump to COMMAND

COMERR:
	MOV	DX,BADCOM
	MOV	AH,9		;Print string
	INT	21H
	EI
STALL:	JP	STALL

STCTAB:	DB	17H		;Select master mode register
	DW	84F3H		;Enable time-of-day
	DB	1		;Counter 1 mode register
	DW	0138H
	DB	2
	DW	0038H
	DB	3
	DW	0008H		;Set counter 3 to count days

	IF	SERIAL
	DB	0B7H, 77H, 4EH, 37H, PRNBAUD, AUXBAUD
	ENDIF

BADCOM:	DB	13,10,"Error in loading Command Interpreter",13,10,"$"
FCB:	DB	1,"COMMAND COM"
	DS	25

GETTIME:
	MOV	AL,0A7H		;Save counters 1,2,3
	OUT	STCCOM
	MOV	AL,0E0H		;Enable data pointer sequencing
	OUT	STCCOM
	MOV	AL,19H		;Select hold 1 / hold cycle
	OUT	STCCOM
	CALL	STCTIME		;Get seconds & 1/100's
	XCHG	AX,DX
	CALL	STCTIME		;Get hours & minutes
	XCHG	AX,CX
	IN	STCDATA
	MOV	AH,AL
	IN	STCDATA
	XCHG	AL,AH		;Count of days
	JP	POINTSTAT

STCTIME:
	CALL	STCBYTE
	MOV	CL,AH
STCBYTE:
	IN	STCDATA
	MOV	AH,AL
	SHR	AH
	SHR	AH
	SHR	AH
	SHR	AH
	AND	AL,0FH		;Unpack BCD digits
	AAD			;Convert to binary
	MOV	AH,AL
	MOV	AL,CL
	RET

SETTIME:
	PUSH	CX
	PUSH	DX
	CALL	LOAD0		;Put 0 into load registers to condition timer
	MOV	AL,43H		;Load counters 1 & 2
	OUT	STCCOM
	POP	DX
	POP	CX
	CALL	LOAD
	MOV	AL,43H
	OUT	STCCOM		;Load counters 1&2
	CALL	LOAD0
	MOV	AL,27H		;Arm counters 1,2,3
	OUT	STCCOM
	JP	POINTSTAT

LOAD0:
	XOR	CX,CX
	MOV	DX,CX
LOAD:
	MOV	AL,09		;Counter 1 load register
	CALL	OUTDX
	MOV	AL,0AH		;Counter 2 load register
	MOV	DX,CX
OUTDX:
	OUT	STCCOM		;Select a load register
	MOV	AL,DL
	CALL	OUTBCD
	MOV	AL,DH
OUTBCD:
	AAM			;Convert binary to unpacked BCD
	SHL	AH
	SHL	AH
	SHL	AH
	SHL	AH
	OR	AL,AH		;Packed BCD
	OUT	STCDATA
	RET

SETDATE:
	XCHG	AX,DX		;Put date in DX
	MOV	AL,0BH		;Select Counter 3 load register
	OUT	STCCOM
	XCHG	AX,DX
	OUT	STCDATA
	MOV	AL,AH
	OUT	STCDATA
	MOV	AL,44H		;Load counter 3
	OUT	STCCOM
POINTSTAT:
	PUSH	AX
	MOV	AL,1FH		;Point to status register
	OUT	STCCOM		;   so power-off glitches won't hurt
	POP	AX
	RET	L

STATUS:
	IN	STAT
	AND	AL,DAV
	RET	L

INP:
	IN	STAT
	AND	AL,DAV
	JZ	INP
	IN	DATA
	AND	AL,7FH
	RET	L

OUTP:
	PUSH	AX
OUTLP:
	IN	STAT
	AND	AL,TBMT
	JZ	OUTLP
	POP	AX
	OUT	DATA
	RET	L

PRINT:
	PUSH	AX
PRINLP:
	IN	PRNSTAT
	AND	AL,TBMT
	JZ	PRINLP
	POP	AX
	OUT	PRNDATA
	RET	L

AUXIN:
	IN	AUXSTAT
	AND	AL,DAV
	JZ	AUXIN
	IN	AUXDATA
	RET	L

AUXOUT:
	PUSH	AX
AUXLP:
	IN	AUXSTAT
	AND	AL,TBMT
	JZ	AUXLP
	POP	AX
	OUT	AUXDATA
	RET	L

;* * * * * * * * * * * * * * * * * * * * * * * * * * * *

	IF	SCP+TARBELL+CROMEMCO

WD1791:	EQU	SCP+TARBELLDD+CROMEMCO16FDC
WD1771:	EQU	TARBELLSD+CROMEMCO4FDC

	IF	WD1791
READCOM:EQU	80H
WRITECOM:EQU	0A0H
	ENDIF

	IF	WD1771
READCOM:EQU	88H
WRITECOM:EQU	0A8H
	ENDIF

	IF	SCP
SMALLBIT:EQU	10H
BACKBIT:EQU	04H
DDENBIT:EQU	08H
DONEBIT:EQU	01H
DISK:	EQU	0E0H
DLYTIM:	EQU	22
	ENDIF

	IF	TARBELL
BACKBIT:EQU	40H
DDENBIT:EQU	08H
DONEBIT:EQU	80H
DISK:	EQU	78H
DLYTIM:	EQU	10		; 24 usec delay after force interrupt
	ENDIF

	IF	CROMEMCO
SMALLBIT:EQU	10H
BACKBIT:EQU	0FDH		; Send this to port 4 to select back.
DDENBIT:EQU	40H
DONEBIT:EQU	01H
DISK:	EQU	30H
DLYTIM:	EQU	22		; 52 usec delay after force interrupt
	ENDIF

	IF	SMALLDS-1
SMALLDDSECT:	EQU	8
	ENDIF

	IF	SMALLDS
SMALLDDSECT:	EQU	16
	ENDIF

	IF	LARGEDS-1
LARGEDDSECT:	EQU	8
	ENDIF

	IF	LARGEDS
LARGEDDSECT:	EQU	16
	ENDIF

;
; I/O system disk change function.
; AL = disk drive number.
; Return AH = -1 if disk is changed.
;        AH = 0 if don't know.
;        AH = 1 if not changed.
;
DSKCHG:
	MOV	AH,0
	SEG	CS
	CMP	AL,[CURDRV]
	JNZ	RETL
	IN	DISK
	AND	AL,20H		; Look at head load bit
	JZ	RETL
	MOV	AH,1
RETL:	RET	L

READ:
	CALL	SEEK		;Position head
	JC	ERROR
RDLP:
	PUSH	CX
	CALL	READSECT	;Perform sector read
	POP	CX
	JC	ERROR
	INC	DH		;Next sector number
	LOOP	RDLP		;Read each sector requested
	OR	AL,AL
	RET	L

WRITE:
	CALL	SEEK		;Position head
	JC	ERROR
WRTLP:
	PUSH	CX
	CALL	WRITESECT	;Perform sector write
	POP	CX
	JC	ERROR
	INC	DH		;Bump sector counter
	LOOP	WRTLP		;Write CX sectors
	OR	AL,AL
	RET	L

ERROR:
	MOV	BL,-1
	SEG	CS
	MOV	[DI],BL
	MOV	SI,ERRTAB
GETCOD:
	INC	BL
	SEG	CS
	LODB
	TEST	AH,AL
	JZ	GETCOD
	MOV	AL,BL
	SHL	AL
	STC
	RET	L

ERRTAB:
	DB	40H		;Write protect error
	DB	80H		;Not ready error
	DB	8		;CRC error
	DB	2		;Seek error
	DB	10H		;Sector not found
	DB	20H		;Write fault
	DB	7		;Data error

SEEK:

; Inputs:
;	AL = Drive number
;	BX = Disk transfer address in DS
;	CX = Number of sectors to transfer
;	DX = Logical record number of transfer
; Function:
;	Seeks to proper track.
; Outputs:
;	AH = Drive select byte
;	DL = Track number
;	DH = Sector number
;	SI = Disk transfer address in DS
;	DI = pointer to drive's track counter in CS
;	CX unchanged.

	MOV	AH,AL
	SEG	CS
	XCHG	AL,[CURDRV]
	CMP	AL,AH		;Changing drives?
	JZ	SAMDRV
;If changing drives, unload head so the head load delay one-shot
;will fire again. Do it by seeking to same track the H bit reset.
	IN	DISK+1		;Get current track number
	OUT	DISK+3		;Make it the track to seek to
	MOV	AL,10H		;Seek and unload head
	CALL	DCOM
	MOV	AL,AH		;Restore current drive number
SAMDRV:
	MOV	SI,BX		; Save transfer address
	CBW
	MOV	BX,AX		; Prepare to index on drive number

	IF	CROMEMCO16FDC
	IN	DISK+4		; See if the motor is on.
	TEST	AL,08H
	ENDIF

	SEG	CS
	MOV	AL,[BX+DRVTAB]	; Get drive-select byte.
	OUT	DISK+4		; Select drive

	IF	CROMEMCO16FDC
	JNZ	MOTORSON	; No delay if motors already on.
	PUSH	AX
	PUSH	CX
	MOV	CX,43716	; Loop count for 1 second.
MOTORDELAY:			;  (8 MHz, 16-bit memory).
	AAM			; 83 clocks.
	AAM			; 83 clocks.
	LOOP	MOTORDELAY	; 17 clocks.
	POP	CX
	POP	AX
MOTORSON:
	ENDIF

	IF	CROMEMCO
	OR	AL,80H		; Set auto-wait bit
	ENDIF

	MOV	AH,AL		; Save drive-select byte in AH.
	XCHG	AX,DX		; AX = logical sector number.
	MOV	DL,26		; 26 sectors/track unless changed below

	IF	SCP
	TEST	DH,SMALLBIT	; Check if small disk.
	JZ	BIGONE		; Jump if big disk.
	MOV	DL,18		; Assume 18 sectors on small track.
	TEST	DH,DDENBIT	; Check if double-density.
	JZ	HAVSECT		; Jump if not.
	MOV	DL,SMALLDDSECT	; Number of sectors on small DD track.
	JP	HAVSECT
BIGONE:
	TEST	DH,DDENBIT	; Check if double-density.
	JZ	HAVSECT		; Jump if not.
	MOV	DL,LARGEDDSECT	; Number of sectors on big DD track.
	ENDIF

	IF	TARBELLDD	; Tarbell DD controller.
	TEST	DH,DDENBIT	; Check for double-density.
	JZ	HAVSECT
	MOV	DL,LARGEDDSECT	; Number of sectors on DD track.
	ENDIF

	IF	CROMEMCO4FDC
	TEST	DH,SMALLBIT	; Check if small disk.
	JNZ	HAVSECT		; Jump if not.
	MOV	DL,18		; 18 sectors on small disk track.
	ENDIF

	IF	CROMEMCO16FDC
	TEST	DH,SMALLBIT	; Check if small disk.
	JNZ	BIGONE		; Jump if big disk.
	MOV	DL,18		; Assume 18 sectors on small track.
	TEST	DH,DDENBIT	; Check if double-density.
	JZ	HAVSECT		; Jump if not.
	MOV	DL,SMALLDDSECT	; Number of sectors on small DD track.
	JP	HAVSECT
BIGONE:
	TEST	DH,DDENBIT	; Check if double-density.
	JZ	HAVSECT		; Jump if not.
	MOV	DL,LARGEDDSECT	; Number of sectors on big DD track.
	ENDIF

HAVSECT:
	DIV	AL,DL		; AL = track, AH = sector.
	XCHG	AX,DX		; AH has drive-select byte, DX = track & sector.
	INC	DH		; Sectors start at one, not zero.
	SEG	CS
	MOV	BL,[BX+TRKPT]	; Get this drive's displacement into track table.
	ADD	BX,TRKTAB	; BX now points to track counter for this drive.
	MOV	DI,BX
	MOV	AL,DL		; Move new track number into AL.
	SEG	CS
	XCHG	AL,[DI]		; Xchange current track with desired track
	OUT	DISK+1		; Inform controller chip of current track
	CMP	AL,DL		; See if we're at the right track.
	JZ	RET
	MOV	BH,2		; Seek retry count
	CMP	AL,-1		; Head position known?
	JNZ	NOHOME		; If not, home head
TRYSK:
	CALL	HOME
	JC	SEEKERR
NOHOME:
	MOV	AL,DL		; AL = new track number.
	OUT	DISK+3
	MOV	AL,1CH+STPSPD	; Seek command.
	CALL	MOVHEAD
	AND	AL,98H		; Accept not ready, seek, & CRC error bits.
	JZ	RET
	JS	SEEKERR		; No retries if not ready
	DEC	BH
	JNZ	TRYSK
SEEKERR:
	MOV	AH,AL		; Put status in AH.
	TEST	AL,80H		; See if it was a Not Ready error.
	STC
	JNZ	RET		; Status is OK for Not Ready error.
	MOV	AH,2		; Everything else is seek error.
	RET

SETUP:
	MOV	BL,DH		; Move sector number to BL to play with

	IF	SCP+CROMEMCO16FDC
	TEST	AH,DDENBIT	; Check for double density.
	JZ	CHECKSMALL	; Not DD, check size for SD.
	ENDIF

	IF	TARBELLDD
	TEST	AH,DDENBIT	; Check for double density.
	JZ	CHECK26		; Not DD.
	ENDIF

	IF	WD1791

	IF	(SCP+TARBELL)*LARGEDS+SCP*SMALLDS
	MOV	AL,AH		; Select front side of disk.
	OUT	DISK+4
	ENDIF

	IF	CROMEMCO*(LARGEDS+SMALLDS)
	MOV	AL,0FFH		; Select front side of disk.
	OUT	04H
	ENDIF

	CMP	BL,8		; See if legal DD sector number.
	JBE	PUTSEC		; Jump if ok.

	IF	(LARGEDS-1)*((SMALLDS*(SCP+CROMEMCO))-1)
	JP	STEP		; If only SS drives, we gotta step.
	ENDIF

	IF	SCP*LARGEDS*(SMALLDS-1)
	TEST	AH,SMALLBIT	; Check for 5.25 inch disk.
	JNZ	STEP		; Jump if small because SMALLDS is off.
	ENDIF

	IF	SCP*SMALLDS*(LARGEDS-1)
	TEST	AH,SMALLBIT	; Check for 8 inch disk.
	JZ	STEP		; Jump if large because LARGEDS is off.
	ENDIF

	IF	CROMEMCO16FDC*LARGEDS*(SMALLDS-1)
	TEST	AH,SMALLBIT	; Check for 5.25 inch disk.
	JZ	STEP		; Jump if small because SMALLDS is off.
	ENDIF

	IF	CROMEMCO16FDC*SMALLDS*(LARGEDS-1)
	TEST	AH,SMALLBIT	; Check for 8 inch disk.
	JNZ	STEP		; Jump if large because LARGEDS is off.
	ENDIF

	IF	LARGEDS+SMALLDS*(SCP+CROMEMCO)
	SUB	BL,8		; Find true sector for back side.
	CMP	BL,8		; See if ok now.
	JA	STEP		; Have to step if still too big.

	IF	SCP+TARBELLDD
	MOV	AL,AH		; Move drive select byte into AL.
	OR	AL,BACKBIT	; Select back side.
	OUT	DISK+4
	ENDIF

	IF	CROMEMCO16FDC
	MOV	AL,BACKBIT	; Select back side.
	OUT	04H
	ENDIF

	JP	PUTSEC
	ENDIF

	ENDIF

	IF	SCP
CHECKSMALL:
	TEST	AH,SMALLBIT	; See if big disk.
	JZ	CHECK26		; Jump if big.
	ENDIF

	IF	CROMEMCO
CHECKSMALL:
	TEST	AH,SMALLBIT	; See if big disk.
	JNZ	CHECK26		; Jump if big.
	ENDIF

	IF 	SCP+CROMEMCO
	CMP	BL,18		; See if legal small SD/SS sector.
	JA	STEP		; Jump if not.
	ENDIF

CHECK26:
	CMP	BL,26		; See if legal large SD/SS sector.
	JBE	PUTSEC		; Jump if ok.
STEP:
	INC	DL		; Increment track number.
	MOV	AL,58H		; Step in with update.
	CALL	DCOM
	SEG	CS
	INC	B,[DI]		; Increment the track pointer.
	MOV	DH,1		; After step, do first sector.
	MOV	BL,DH		; Fix temporary sector number also.
PUTSEC:
	MOV	AL,BL		; Output sector number to controller.
	OUT	DISK+2
	DI			; Interrupts not allowed until I/O done
	IN	DISK		; Get head load bit
	NOT	AL
	AND	AL,20H		; Check head load status
	JZ	RET
	MOV	AL,4
	RET

READSECT:
	CALL	SETUP
	MOV	BL,10
RDAGN:
	OR	AL,READCOM
	OUT	DISK

	IF	CROMEMCO
	MOV	AL,AH		; Turn on auto-wait.
	OUT	DISK+4
	ENDIF

	MOV	BP,SI
RLOOP:

	IF	SCP
	IN	DISK+5		; Wait for DRQ or INTRQ.
	ENDIF

	IF	TARBELL+CROMEMCO
	IN	DISK+4
	ENDIF

	IF	TARBELL
	SHL	AL
	JNC	RDONE
	ENDIF

	IF	SCP+CROMEMCO
	SHR	AL
	JC	RDONE
	ENDIF

	IN	DISK+3
	MOV	[SI],AL
	INC	SI
	JP	RLOOP
RDONE:
	EI			; Interrupts OK now
	CALL	GETSTAT
	AND	AL,9CH
	JZ	FORCINT
	MOV	SI,BP
	MOV	BH,AL		;Save error status for report
	MOV	AL,0
	DEC	BL
	JNZ	RDAGN
	MOV	AH,BH		; Put error status in AH.
	STC
FORCINT:
	MOV	AL,0D0H		;Force Interrupt command for type I status
	OUT	DISK
	MOV	AL,DLYTIM
INTDLY:
	DEC	AL		;Does not affect carry
	JNZ	INTDLY		;Minimum loop time (19 clocks)=2.375 usec
	RET

WRITESECT:
	CALL	SETUP
	MOV	BL,10
WRTAGN:
	OR	AL,WRITECOM
	OUT	DISK

	IF	CROMEMCO
	MOV	AL,AH		; Turn on auto-wait.
	OUT	DISK+4
	ENDIF

	MOV	BP,SI
WRLOOP:

	IF	SCP
	IN	DISK+5		; Wait for DRQ or INTRQ.
	ENDIF

	IF	TARBELL+CROMEMCO
	IN	DISK+4
	ENDIF
	
	IF	TARBELL
	SHL	AL
	JNC	WRDONE
	ENDIF

	IF	SCP+CROMEMCO
	SHR	AL
	JC	WRDONE
	ENDIF

	LODB
	OUT	DISK+3
	JP	WRLOOP
WRDONE:
	EI
	CALL	GETSTAT
	AND	AL,0FCH
	JZ	FORCINT
	MOV	SI,BP
	MOV	BH,AL
	MOV	AL,0
	DEC	BL
	JNZ	WRTAGN
	MOV	AH,BH		; Error status to AH.
	STC
	JP	FORCINT

	IF	SCP+(FASTSEEK-1)*TARBELL+CROMEMCO
HOME:
	ENDIF

	IF	FASTSEEK*SCP
	TEST	AH,SMALLBIT	; Check for big disk.
	JZ	RESTORE		; Big disks are PerSci.
	ENDIF

	IF	FASTSEEK*CROMEMCO
	TEST	AH,SMALLBIT	; Check for large disk.
	JNZ	RESTORE		; Big disks are fast seek PerSci.
	ENDIF

	MOV	BL,3
TRYHOM:
	MOV	AL,0CH+STPSPD
	CALL	DCOM
	AND	AL,98H
	JZ	RET
	JS	HOMERR		; No retries if not ready
	MOV	AL,58H+STPSPD	; Step in with update
	CALL	DCOM
	DEC	BL
	JNZ	TRYHOM
HOMERR:
	STC
	RET

	IF	SCP+(FASTSEEK-1)*TARBELL+CROMEMCO
MOVHEAD:
	ENDIF

	IF	CROMEMCO
	TEST	AH,SMALLBIT	; Check for PerSci.
	JNZ	FASTSK
	ENDIF

DCOM:
	OUT	DISK
	PUSH	AX
	AAM			;Delay 10 microseconds
	POP	AX
GETSTAT:
	IN	DISK+4
	TEST	AL,DONEBIT

	IF	TARBELL
	JNZ	GETSTAT
	ENDIF

	IF	SCP+CROMEMCO
	JZ	GETSTAT
	ENDIF

	IN	DISK
	RET

;
; RESTORE for PerSci drives.
; Doesn't exist yet for Tarbell controllers.
; Cromemco 4FDC restore is used for 16FDC which isn't real efficient
; but it works.  Some ambitious person could fix this.
;

	IF	FASTSEEK*SCP
RESTORE:
	MOV	AL,AH		; Get drive-select byte.
	OR	AL,80H		; Turn on restore.
	OUTB	DISK+4
SKWAIT:
	INB	DISK+4		; Wait for seek complete.
	TEST	AL,40H
	JZ	SKWAIT
	MOV	AL,AH		; Turn off restore.
	OUTB	DISK+4
	XOR	AL,AL		; Tell 1793 we're on track 0.
	OUTB	DISK+1
	RET
	ENDIF

	IF	FASTSEEK*TARBELL
HOME:
RESTORE:
	RET
	ENDIF

	IF	FASTSEEK*CROMEMCO
RESTORE:
	MOV	AL,0C4H		;READ ADDRESS command to keep head loaded
	OUT	DISK
	MOV	AL,77H
	OUT	4
CHKRES:
	IN	4
	AND	AL,40H
	JZ	RESDONE
	IN	DISK+4
	TEST	AL,DONEBIT
	JZ	CHKRES
	IN	DISK
	JP	RESTORE		;Reload head
RESDONE:
	MOV	AL,7FH
	OUT	4
	CALL	GETSTAT
	MOV	AL,0
	OUT	DISK+1		;Tell 1771 we're now on track 0
	RET
	ENDIF

;
; Fast seek code for PerSci drives.
; Tarbell not installed yet.
;

	IF	FASTSEEK*TARBELL
MOVHEAD:
FASTSK:
	RET
	ENDIF

	IF	FASTSEEK*CROMEMCO
FASTSK:
	MOV	AL,6FH
	OUT	4
	MOV	AL,18H
	CALL	DCOM
SKWAIT:
	IN	4
	TEST	AL,40H
	JNZ	SKWAIT
	MOV	AL,7FH
	OUT	4
	MOV	AL,0
	RET
	ENDIF

CURDRV:	DS	1
;
; Explanation of tables below.
;
; DRVTAB is a table of bytes which are sent to the disk controller as
; drive-select bytes to choose which physical drive is selected for
; each logical drive.  It also selects whether the disk is 5.25-inch or
; 8-inch, single-density or double-density, to use side 0 or side 1 for
; single-sided operation.  (Note:  always select side 0 in the drive-
; select byte if double-sided double-density operation is desired).
; There should be one entry in the DRVTAB table for each logical drive.
; Exactly which bits in the drive-select byte do what depends on which
; disk controller is used.
;
; TRKTAB is a table of bytes used to store which track the read/write
; head of each drive is on.  Each physical drive should have its own
; entry in TRKTAB.
;
; TRKPT is a table of bytes which indicates which TRKTAB entry each
; logical drive should use.  Since each physical drive may be used for
; more than one logical drive, more than one entry in TRKPT may point
; to the same entry in TRKTAB.  Drives such as PerSci 277s which use
; the same head positioner for more than one drive should share entrys
; in TRKTAB.
;
; INITTAB is the initialization table for 86-DOS as described in the
; 86-DOS Programer's Manual under "Customizing the I/O System."
;
	IF	SCP*COMBIN*FASTSEEK
DRVTAB:	DB	00H,01H,10H,08H,09H,18H
TRKPT:	DB	0,0,1,0,0,1
TRKTAB:	DB	-1,-1
INITTAB:DB	6
	DW	LSDRIVE
	DW	LSDRIVE
	DW	SSDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	SDDRIVE
	DW	0
	DW	30
	ENDIF

	IF	SCP*LARGEDS*(FASTSEEK-1)
; Drive A is drive 0, side 0, single-density.
; Drive B is drive 0, side 1, single-density.
; Drive C is drive 1, side 0, single-density.
; Drive D is drive 1, side 1, single-density.
; Drive E is drive 0, both sides, double density.
; Drive F is drive 1, both sides, double density.
DRVTAB:	DB	00H,04H,01H,05H,08H,09H
TRKPT:	DB	0,0,1,1,0,1
TRKTAB:	DB	-1,-1
INITTAB:DB	6
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	0		; Reserved buffer space.
	DW	30		; Reserved stack space.
	ENDIF

	IF	TARBELLDD*(LARGEDS-1)
;Drive A is drive 0, single density
;Drive B is drive 1, single density
;Drives C to F are drive 0 to 3, double density
DRVTAB:	DB	0,10H,8,18H,28H,38H
TRKPT:	DB	0,1,0,1,2,3
TRKTAB:	DB	-1,-1,-1,-1
INITTAB:DB	6
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	0
	DW	30
	ENDIF

	IF	TARBELLDD*LARGEDS
;Drive A is drive 0, side 0, single density
;Drive B is drive 0, side 1, single density
;Drive C is drive 1, side 0, single density
;Drive D is drive 1, side 1, single density
;Drive E is drive 0, both sides, double density
;Drive F is drive 1, both sides, double density
DRVTAB:	DB	0,40H,10H,50H,8H,18H
TRKPT:	DB	0,0,1,1,0,1
TRKTAB:	DB	-1,-1
INITTAB:DB	6
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	0
	DW	30
	ENDIF

	IF	TARBELLSD
DRVTAB:	DB	0F2H,0E2H,0D2H,0C0H
TRKPT:	DB	0,1,2,3
TRKTAB:	DB	-1,-1,-1,-1
INITTAB:DB	4
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	0
	DW	30
	ENDIF

; Cromemco drive select byte is derived as follows:
;	Bit 7 = 0
;	Bit 6 = 1 if double density (if 16FDC)
;	Bit 5 = 1 (motor on)
;	Bit 4 = 0 for 5", 1 for 8" drives
;	Bit 3 = 1 for drive 3
;	Bit 2 = 1 for drive 2
;	Bit 1 = 1 for drive 1
;	Bit 0 = 1 for drive 0

	IF	CROMEMCO4FDC*LARGE
; Table for four large drives
DRVTAB:	DB	31H,32H,34H,38H
TRKPT:	DB	0,0,1,1
TRKTAB:	DB	-1,-1
INITTAB:DB	4	;Number of drives
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LSDRIVE
	DW	0
	DW	30
	ENDIF

	IF	CROMEMCO4FDC*COMBIN
; Table for two large drives and one small one
DRVTAB:	DB	31H,32H,24H
TRKPT:	DB	0,0,1
TRKTAB:	DB	-1,-1
INITTAB:DB	3	;Number of drives
	DW	LSDRIVE
	DW	LSDRIVE
	DW	SSDRIVE
	DW	0
	DW	30
	ENDIF

	IF	CROMEMCO4FDC*SMALL
; Table for 3 small drives
DRVTAB:	DB	21H,22H,24H
TRKPT:	DB	0,1,2
TRKTAB:	DB	-1,-1,-1
INITTAB:DB	3
	DW	SSDRIVE
	DW	SSDRIVE
	DW	SSDRIVE
	DW	0
	DW	30
	ENDIF

	IF	CUSTOM
; Table for 2 large drives without fast seek and a Cromemco 4FDC.
DRVTAB:	DB	31H,32H
TRKPT:	DB	0,1
TRKTAB:	DB	-1,-1
INITTAB:DB	2
	DW	LCDRIVE
	DW	LSDRIVE
	DW	0
	DW	30
	ENDIF

	IF	CROMEMCO16FDC*SMALL
; Table for three small drives.
; A, B, & C are single density, D, E, & F are double density.
DRVTAB:	DB	21H,22H,24H,61H,62H,64H
TRKPT:	DB	0,1,2,0,1,2
TRKTAB:	DB	-1,-1,-1
INITTAB:DB	6
	DW	SSDRIVE
	DW	SSDRIVE
	DW	SSDRIVE
	DW	SDDRIVE
	DW	SDDRIVE
	DW	SDDRIVE
	DW	0
	DW	30
	ENDIF

	IF	CROMEMCO16FDC*COMBIN
; Table for 2 large drives (a PerSci 277 or 299), and one small.
; Drives A & B are the PerSci single density,
; C is the small drive single density,
; D & E are the PerSci double density,
; and F is the small drive double density.
DRVTAB:	DB	31H,32H,24H,71H,72H,64H
TRKPT:	DB	0,0,1,0,0,1
TRKTAB:	DB	-1,-1
INITTAB:DB	6
	DW	LSDRIVE
	DW	LSDRIVE
	DW	SSDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	SDDRIVE
	DW	0
	DW	30
	ENDIF

	IF	CROMEMCO16FDC*LARGE
; Table for four large drives (2 PerSci 277s or 299s).
; Drives A - B are single density, C - F are double density.
DRVTAB:	DB	31H,32H,71H,72H,74H,78H
TRKPT:	DB	0,0,0,0,1,1
TRKTAB:	DB	-1,-1
INITTAB:DB	6
	DW	LSDRIVE
	DW	LSDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	LDDRIVE
	DW	0
	DW	30
	ENDIF

	IF	SMALL+COMBIN
SSDRIVE:
	DW	128		; Sector size in bytes.
	DB	2		; Sector per allocation unit.
	DW	54		; Reserved sectors.
	DB	2		; Number of allocation tables.
	DW	64		; Number of directory entrys.
	DW	720		; Number of sectors on the disk.

	IF	SMALLDS-1
SDDRIVE:			; This is the IBM Personal Computer
	DW	512		; disk format.
	DB	1
	DW	1
	DB	2
	DW	64
	DW	320
	ENDIF

	IF	SMALLDS
SDDRIVE:
	DW	512
	DB	2
	DW	1
	DB	2
	DW	64		; 64 directory entrys for small DDDS?
	DW	640
	ENDIF

	ENDIF			; End of small drive DPTs.

	IF	COMBIN+LARGE
LSDRIVE:
	DW	128
	DB	4
	DW	52
	DB	2
	DW	64
	DW	2002

	IF	LARGEDS-1
LDDRIVE:
	DW	1024
	DB	1
	DW	1
	DB	2
	DW	96
	DW	616
	ENDIF

	IF	LARGEDS
LDDRIVE:
	DW	1024
	DB	1
	DW	1
	DB	2
	DW	128
	DW	1232
	ENDIF

	ENDIF			; End of large drive DPTs.

	ENDIF			; End of 1771/1793 disk drivers.

; * * * * * * * * * * * * * * * * * * * * * * *

	IF	NORTHSTARSD

; North Star disk controller addresses.
;
DSKSEG:	EQU	0FE80H		; `F' is for extended address modification.
WRTADR:	EQU	200H
CMMND:	EQU	300H
DRVSEL:	EQU	1H
WRTSEC:	EQU	4H
STPOFF:	EQU	8H
STPON:	EQU	9H
NOP:	EQU	10H
RSETSF:	EQU	14H
STPOUT:	EQU	1CH
STPIN:	EQU	1DH
BSTAT:	EQU	20H
RDBYTE:	EQU	40H
MOTOR:	EQU	80H
;
; Status bits.
;
TK0:	EQU	01H		; Track 0 bit.
WP:	EQU	02H		; Write protect bit.
BDY:	EQU	04H		; Data body (sync byte) found.
WRT:	EQU	08H		; Write bytes status flag.
MO:	EQU	10H		; Motor on.
SF:	EQU	80H		; Indicates sector hole was detected.
;
; Delay times in sectors for various disk functions.
;
MOTORD:	EQU	31		; Motor up-to-speed time (1 second).
HEADD:	EQU	14		; Head-load settle time.  Actually, the head
				;  doesn't require this much time to settle,
				;  but this much time is required to
				;  synchronize the sector counter.
STEPD:	EQU	2		; Step time.  One or two only.
				;  1 -> 20mS, 2 -> 40mS.
;
; Various numbers of things.
;
NSECT:	EQU	10		; 10 North Star sectors per track.
NTRACK:	EQU	35		; 35 tracks on standard SA-400 drive.
ERRLIM:	EQU	10		; Number of soft errors.
;
; READ and WRITE functions.
; AL = drive number.
; CX = Number of sectors to transfer.
; DX = Logical record number.
; DS:BX = Transfer address.
;
READ:	
	MOV	AH,1		; AH = 1 to read.
	JP	READWRITE
WRITE:
	MOV	AH,0		; AH = 0 to write.
READWRITE:
	CMP	DX,350		; See if too large a sector number is requested
	JB	SECTOROK	; Jump if OK.
	MOV	AL,0CH		; Error type C, "data error".
	STC			; Set CY flag to indicate error.
	RET	L		; Quit immediatly.
SECTOROK:
	MOV	SI,BX		; Transfer address to SI & DI.
	MOV	DI,BX
	UP			; Set direction flag for autoincrement.
	PUSH	ES		; Store extra segment.
	MOV	BX,DS		; Put data segment in extra segment.
	MOV	ES,BX
	PUSH	DS		; Save data segment.
	MOV	BX,DSKSEG	; DS is North Star controller segment.
	MOV	DS,BX
	PUSH	AX		; Store read/write flag.
	CBW			; Drive number is sixteen bits.
	MOV	BX,AX		; Put in BX.
	MOV	AX,DX		; Compute track & sector.
	MOV	DL,NSECT	; Ten sectors/track.
	DIV	AL,DL		; AL = track number, AH = sector number.
	MOV	CH,AH		; Sector number to CH.
	PUSH	CX		; Save sector number & number of sectors.
	MOV	DH,AL		; Put track number in DH.
	SEG	CS		; TRACKTAB is in the code segment.
	MOV	AH,[BX+TRACKTAB]	; Find out what the current track is.
	SEG	CS
	MOV	[BX+TRACKTAB],DH	; Update TRACKTAB.
	MOV	BP,CMMND+MOTOR+STPIN	; Assume step direction is in.
	MOV	CL,DH		; Put track number in CL.
	SUB	CL,AH		; Calculate how many steps required.
	JAE	DIRECTION	; Direction is correct if >= 0.
	DEC	BP		; Direction is out (STPOUT = STPIN-1).
	NEG	CL		; Make number of steps positive.
DIRECTION:
	IF	STEPD-1		; Multiply number of steps by two if step delay
	SAL	CL		;  is 40mS per step.
	ENDIF
	TEST	B,[CMMND+MOTOR+NOP],MO	; Turn motors on & check MO status.
	JZ	MOTORS		; If motors were off, wait for them to start.
	SEG	CS		; OLDDRIVE is in the code segment.
	CMP	BL,[OLDDRIVE]	; See if the correct drive is selected.
	JNZ	SELECT		; If wrong drive is selected, select right one.
	JP	SEEK		; Motors on, drive selected, go and step.
MOTORS:
	MOV	DL,MOTORD	; Wait for motors to come up to speed.
	CALL	WSECTOR
SELECT:
	CALL	ONESECT		; Wait for write gate to go off.
	MOV	AL,[BX+CMMND+MOTOR+DRVSEL]	; Select new drive.
	SEG	CS		; OLDDRIVE is in code segment.
	MOV	[OLDDRIVE],BL	; Update OLDDRIVE.
	MOV	DL,HEADD-1	; Full head load delay (-1 because waiting for
				;  the correct sector delays at least one more)
	MOV	AL,CL		; See if we've ever used the drive before.
	IF	STEPD-1		; Compute the actual number of steps if 40mS
	SAR	AL		;  step delay is used.
	ENDIF
	CMP	AL,NTRACK	; If the number of steps is >= NTRACK, we can't
	JAE	HEADDELAY	;  count on step time for head load delay.
	SUB	DL,CL		; Subtract stepping time.
	JB	SEEK		; Don't wait if we'll step long enough for the
				;  head to settle & the sector counter to sync.
HEADDELAY:
	CALL	WSECTOR
SEEK:
	IF	STEPD-1		; Convert back to the actual number of steps
	SAR	CL		;  rather than step time if the step time
	ENDIF			;  is 40mS per step.
	XOR	CH,CH		; CX = CL.
	JCXZ	SEEKCOMPLETE	; Jump if we're already there.
	SEG	DS		; BP normally uses stack segment.
	MOV	AL,[BP]		; Set the step direction.
	CALL	ONESECT		; Wait for the write gate to turn off.
;
; Step routine.  Step direction has already been given to the disk
; controller.  DH has destination track number.
; CX has number of sectors to step, >= 1.
; If track zero is ever reached, the head position is recalibrated using DH.
;
STEP:
	MOV	AL,[CMMND+MOTOR+NOP]	; Get `A' status.
	ROR	AL		; Track 0 bit to CF.
	JNC	STEPOK		; Recalibrate if track zero.
	MOV	CL,DH		; Track # to step count.
	JCXZ	SEEKCOMPLETE	; If destinination = 0, we're there.
	MOV	AL,[CMMND+MOTOR+STPIN]	; Set direction.
STEPOK:
	MOV	AL,[CMMND+MOTOR+STPON]
	AAM			; Waste time for > 10 uS.
	MOV	AL,[CMMND+MOTOR+STPOFF]
	MOV	DL,STEPD	; Step time (sectors).
	CALL	WSECTOR
	LOOP	STEP		; Loop till we get there.
SEEKCOMPLETE:
	POP	CX		; Restore sector number & number of sectors.
	MOV	BP,BX		; Put drive number in BP.
SECTORLOOP:
	MOV	DH,ERRLIM	; Soft error limit.
ERRORRETRY:
	DI			; Interrupts illegal till after read, write,
WAITSECTOR:			;  or error.
	CALL	ONESECT		; Wait for next sector to come by.
	MOV	AL,[CMMND+MOTOR+BSTAT+NOP]	; Get `B' status.
	AND	AL,0FH		; Mask to sector number.
	CMP	AL,CH
	JNE	WAITSECTOR	; Wait till the one we want comes by.
	POP	AX		; Get function.
	PUSH	AX		; Back on the stack for next time.
	AND	AH,AH		; AH = 1 -> read, AH = 0 -> write.
	JZ	WRITESECTOR	; Jump if write.
;
READSECTOR:
	MOV	SI,CMMND+MOTOR+RDBYTE+NOP
	PUSH	CX		; Save sector number and number of sectors.
	MOV	CX,352		; Time limit for sync byte.  352 passes through
				;  the loop @ 35 clocks/pass = 24 byte times.
RSYNCLP:
	TEST	B,[CMMND+MOTOR+NOP],BDY
	LOOPZ	RSYNCLP		; Test for sync byte. Loop till sync or timeout
	JNZ	READSECT	; Found sync byte, read data bytes.
	MOV	AL,8		; Error number 8, "Record Not Found".
	JP	ERROR
READSECT:
	MOV	CX,256		; Byte count.
	MOV	DL,CL		; CRC = 0.
READLOOP:
	AAD			; Waste time >= 7.5 uS.
	MOV	AL,[SI]		; Read a byte.
	STOB			; Store byte.
	XOR	DL,AL		; Compute CRC.
	ROL	DL
	LOOP	READLOOP	; Loop for 256 bytes.
	AAD			; Waste time >= 7.5 uS.
	MOV	AL,[SI]		; Get CRC from disk.
	CMP	AL,DL		; Same as computed?
	JE	NEXTSECTOR	; Jump if sucessful read.
	SUB	DI,256		; Back-up the index for retry.
	MOV	AL,4		; Error number 4, "CRC Error".
ERROR:
	EI			; Interrupts OK now.
	POP	CX		; Get sector number & number of sectors.
	DEC	DH		; Decrement error count.
	JNZ	ERRORRETRY	; Wait for the sector to come by again.
	POP	BX		; Pop junk off the stack.
	POP	DS		; Pop segment registers.
	POP	ES
	XOR	CH,CH		; CX is number of sectors left to read.
	STC			; Set CY flag to indicate error.
	RET	L		; Return.
;
WRITESECTOR:
	TEST	B,[CMMND+MOTOR+NOP],WP
	JZ	NOTPROT		; Jump if not protected.
	EI			; Interrupts OK now.
	POP	AX		; Pop junk off the stack.
	POP	DS
	POP	ES
	XOR	CH,CH		; CX = number of sectors left to write.
	MOV	AL,CH		; AL = 0 to indicate write protect.
	STC			; Set CY flag to indicate error.
	RET	L
NOTPROT:
	PUSH	CX		; Save sector number and number of sectors.
	MOV	AL,[CMMND+MOTOR+WRTSEC]
WWRT:
	TEST	B,[CMMND+MOTOR+NOP],WRT
	JZ	WWRT		; Loop till WRT bit goes high.
	MOV	CX,15		; Number of zeros to write.
	MOV	BX,WRTADR	; Address to write zeros.
WRTZERO:
	MOV	AL,[BX]		; Write a zero.
	AAD			; Waste time for >= 7.5 uS.
	LOOP	WRTZERO		; Write 15 of them.
	MOV	BL,0FBH		; Sync byte.
	MOV	AL,[BX]		; Write sync byte.
	AAD			; Waste time for >= 7.5 uS.
	MOV	CX,256		; Byte count.
	MOV	DL,CL		; CRC = 0.
WRTBYTE:
	SEG	ES		; Data is in extra segment.
	LODB			; Get write data.
	MOV	BL,AL		; Data to BL to write.
	MOV	AL,[BX]		; Write it.
	AAD			; Waste time for >= 7.5 uS.
	XOR	DL,BL		; Compute CRC.
	ROL	DL
	LOOP	WRTBYTE		; Write 256 bytes.
	MOV	BL,DL		; Write CRC byte.
	MOV	AL,[BX]
;
NEXTSECTOR:
	EI			; Interrupts OK now.
	POP	CX		; Get sector count.
	DEC	CL		; Decrement sector count.
	JZ	OKRETURN	; Return if done.
	INC	CH		; Increment sector number.
	CMP	CH,10		; Compare with number of sectors on track.
	JAE	NEEDSTEP
	JMP	SECTORLOOP	; Read another sector from same track.
NEEDSTEP:
	MOV	CH,0		; Reset sector number.
	CALL	ONESECT		; Wait for write gate to go off.
	MOV	AL,[CMMND+MOTOR+STPIN]
	MOV	AL,[CMMND+MOTOR+STPON]
	AAM			; Wait > 10 uS for step pulse width.
	MOV	AL,[CMMND+MOTOR+STPOFF]
	SEG	CS		; BP normally uses stack segment.
	INC	B,[BP+TRACKTAB]	; Increment the track table.
				; We don't have to wait for STEPD because
				;  waiting for the write gate to go off caused
				;  us to blow the sector and we have to wait
				;  a whole revolution anyway.
	JMP	SECTORLOOP	; Read a sector from the new track.
OKRETURN:
	POP	AX		; Get function, AH=0 -> write, AH=1 -> read.
	POP	DS		; Get original data & extra segments.
	POP	ES
	CLC			; No errors.
	RET	L
;
; Wait for sector routine.  ONESECT waits for the next sector.
; WSECTOR waits the number of sectors given by DL.
;
ONESECT:
	MOV	DL,1		; Wait for next sector.
WSECTOR:
	MOV	AL,[CMMND+MOTOR+RSETSF]
SECTLOOP:
	MOV	AL,[CMMND+MOTOR+NOP]
	TEST	AL,SF		; Check sector flag.
	JZ	SECTLOOP	; Loop till new sector.
	DEC	DL		; Decrement sector count.
	JNZ	WSECTOR		; Loop till zero.
	RET
;
DSKCHG:
	MOV	AH,0		; AH = 0 in case we don't know.
	SEG	CS
	CMP	AL,[OLDDRIVE]	; See if that's the last drive used.
	JNE	RETL		; Return if not.
	PUSH	DS		; See if the motors are still on.
	PUSH	BX
	MOV	BX,DSKSEG
	MOV	DS,BX
	TEST	B,[CMMND+NOP],MO	
	POP	BX
	POP	DS
	JZ	RETL		; Motors off, disk could be changed.
	MOV	AH,1		; If motors on, assume disk not changed.
RETL:
	RET	L
;
; Disk initialization tables.
;
INITTAB:
	DB	3		; Three drives.
	DW	DPT,DPT,DPT	; Address of disk parameter tables.
	DW	0		; Minimum buffer space
	DW	30		; Stack space
;
DPT:
	DW	256		; Sector size.
	DB	1		; One sector per allocation unit.
	DW	30		; Number of sectors allocated to system.
	DB	2		; Two allocation tables.
	DW	64		; Number of directory entries.
	DW	350		; Number of sectors on the disk.
;
; Storage locations for the disk drivers.
;
OLDDRIVE:
	DB	0		; Old drive will be number 0 after boot.
TRACKTAB:
	DB	2		; Drive 0 will be on track 2 after boot.
	DB	NTRACK-1+NTRACK-1+24	; Number of steps to restore the head
	DB	NTRACK-1+NTRACK-1+24	;  if never used before.

	ENDIF			; End North Star disk drivers

DOSSEG:	EQU	($+15)/16+40H	; Compute segment to use for 86-DOS.
