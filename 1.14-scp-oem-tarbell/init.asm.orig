; Disk initialization routine for 1771/1793 type disk controllers.
; Runs on 8086 under 86-DOS.  Revised 11-24-81.
;
; Translated from the Z80 on 12-19-80 and subsequently upgraded to handle
; all of the following controllers. Set switch to one to select.
;
; Note:  tables for the SCP controller or the Cromemco 16FDC with small
; drives do not exist yet.  Do not select these combinations.
;
SCP:		EQU	0	; Seattle Computer Products controller.
TARBELLSINGLE:	EQU	0	; Tarbell single-density controller.
TARBELLDOUBLE:	EQU	1	; Tarbell double-density controller.
CROMEMCO4FDC:	EQU	0	; Cromemco 4FDC.
CROMEMCO16FDC:	EQU	0	; Cromemco 16FDC.

LARGE:	EQU	1		; All 8-inch disks.
COMBIN:	EQU	0		; Some 8-inch and some 5.25-inch.
SMALL:	EQU	0		; All 5.25-inch disks.
CUSTOM:	EQU	0		; Custom drive configuration.

LARGEDS:EQU	1		; Set to 1 if large disks are double-sided.
SMALLDS:EQU	0		; Set to 1 if small disks are double-sided.

STPSPD:	EQU	2

;********************************************************************

TARBELL:	EQU	TARBELLSINGLE + TARBELLDOUBLE
CROMEMCO:	EQU	CROMEMCO4FDC + CROMEMCO16FDC

	IF	SCP
DISK:	EQU	0E0H
DONEBIT:EQU	01H
SMALLBIT:EQU	10H
BACKBIT:EQU	04H
DDENBIT:EQU	08H
	ENDIF

	IF	TARBELL
DISK:	EQU	78H
DONEBIT:EQU	80H
BACKBIT:EQU	40H
DDENBIT:EQU	08H
	ENDIF

	IF	CROMEMCO
DISK:	EQU	30H
DONEBIT:EQU	1
SMALLBIT:EQU	10H
BACKBIT:EQU	0FDH			; Send this to port 4 to select back.
DDENBIT:EQU	40H
	ENDIF

CONIN:	EQU	1
OUTSTR:	EQU	9
SELDRV:	EQU	14

	ORG	100H
	PUT	100H

	JP	INIT
HEADER:
	DB	13,10,'Disk INIT version 1.1',13,10,'$',26
INIT:
	MOV	AH,OUTSTR
	MOV	DX,HEADER
	INT	33
	MOV	DX,WARNING
	INT	33
EACH:
	MOV	SP,5CH
	MOV	AH,OUTSTR
	MOV	DX,DRVMES
	INT	33
	MOV	AH,CONIN
	INT	33		; Get drive letter from console.
	CMP	AL,13		; Return to 86-DOS if CR.
	JNE	CHECKDRIVE
	INT	32
CHECKDRIVE:
	AND	AL,5FH		; Force upper case.
	SUB	AL,'A'
	JC	EACH

; Check if valid drive.

	MOV	DH,AL
	MOV	DL,-1
	MOV	AH,SELDRV
	INT	33		; Get number of drives.
	CMP	DH,AL
	JAE	EACH		; Jump if drive number too big.
	MOV	AL,DH		; Set DI to drive number.
	CBW
	MOV	DI,AX
	MOV	SI,AX		; SI = twice drive number to point to words.
	SAL	SI

; Create basic pattern for a track.

	MOV	BX,PATTERN
	MOV	DX,[SI+INDEXT]	; DX points to index pattern.
	CALL	MAKE		; Make pattern for index mark and one sector
	MOV	CL,[DI+SECCNT]	; Get sector count for this sector.
	DEC	CL		; Repeat sector pattern for remaining sectors.
MAKSEC:
	MOV	DX,[SI+SECTAB]	; DX point to sector pattern.
	CALL	MAKE
	DEC	CL
	JNZ	MAKSEC
	CALL	MAKE		; Fill out rest of track.

; Put in sequential sector numbers.

	MOV	AL,1		; Start with sector number 1
	MOV	CL,AL		; Add one to each succeeding sector number
	MOV	BX,[SI+TRKNUM]	; Get offset from beginning of pattern to first
	INC	BX		;  track number.  Increment to side,
	INC	BX		;  then sector.
	ADD	BX,PATTERN	; Compute actual memory address.
	CALL	PUTSEC
;
; Select drive and restore head to track 0.
;
	IF	CROMEMCO16FDC
	IN	DISK+4		; Get "disk flags".
	TEST	AL,08H		; See if motor on.
	ENDIF

	MOV	AL,[DI+DRVTAB]	; Get drive-select byte.
	OUT	DISK+4		; Send it out.

	IF	CROMEMCO16FDC
	JNZ	MOTORSON	; If motors already on, don't wait.
	MOV	CX,43716	; Loop count, 1 second for loop below.
MOTORDELAY:			;  (8 MHz, 16-bit memory).
	AAM			; 83 clocks.
	AAM			; 83 clocks.
	LOOP	MOTORDELAY	; 17 clocks.
MOTORSON:
	ENDIF

	MOV	AL,08H+STPSPD	; Restore without verify
	MOV	CH,0D0H		; Accept "not ready", "write protect", & "seek
	CALL	DCOM		;  error" errors.
	XOR	DL,DL		; Start with track 0.
TRACKLOOP:
	MOV	AL,DL		; Get track number.
	MOV	BX,[SI+TRKNUM]	; Get offset from beginning of pattern to first
	ADD	BX,PATTERN	;  track number and add address of pattern.
	MOV	CL,0
	CALL	PUTSEC		; Put track number in each sector.

	IF	SCP+TARBELLDOUBLE
	MOV	AL,[DI+DRVTAB]	; Get drive-select byte.
	OUT	DISK+4		; Select side.
	AND	AL,BACKBIT	; Compute side number.
	JZ	GOTSIDE
	MOV	AL,1		; If not zero, then 1.
GOTSIDE:
	MOV	DH,AL		; Save side number in DH.
	ENDIF

	IF	CROMEMCO16FDC
	MOV	AL,0FFH		; Select front side if 16FDC.
	OUT	04H
	ENDIF

	IF	TARBELLSINGLE+CROMEMCO
	MOV	DH,0		; These controllers always start with side 0.
	ENDIF

SIDELOOP:
	MOV	AL,DH		; Get side number.
	MOV	BX,[SI+TRKNUM]	; Get offset from beginning of pattern to first
	INC	BX		;  track number.  Increment to side.
	ADD	BX,PATTERN	; Compute actual memory address.
	MOV	CL,0
	CALL	PUTSEC		; Put side byte in each sector
;
; Write a track.
;
	CALL	TRACK
	MOV	SI,DI		; Fix up SI (TRACK messed it up).
	SAL	SI

	IF	(SCP+CROMEMCO16FDC)*(LARGEDS+SMALLDS)+TARBELLDOUBLE*LARGEDS
	MOV	AL,[DI+DRVTAB]	; Get drive-select byte.
 	TEST	AL,DDENBIT	; See if double-density.
	JZ	NEXTRACK	; Jump if not.
	ENDIF

	IF	SCP*LARGEDS*(SMALLDS-1)+CROMEMCO16FDC*SMALLDS*(LARGEDS-1)
	TEST	AL,SMALLBIT	; Check for small disk.
	JNZ	NEXTRACK	; Jump if small because SMALLDS is off or,
	ENDIF			; jump if large because LARGEDS is off.

	IF	SCP*(LARGEDS-1)*SMALLDS+CROMEMCO16FDC*(SMALLDS-1)*LARGEDS
	TEST	AL,SMALLBIT	; Check for large disk.
	JZ	NEXTRACK	; Jump if large because LARGEDS is off or,
	ENDIF			; jump if small because SMALLDS is off.

	IF	(SCP+CROMEMCO16FDC)*(LARGEDS+SMALLDS)+TARBELLDOUBLE*LARGEDS
	INC	DH		; Next side.
	CMP	DH,2		; See if too big.
	JAE	NEXTRACK	; Finished this track, on to the next.

	IF	SCP+TARBELL
	OR	AL,BACKBIT	; Select back side.
	OUT	DISK+4
	ENDIF

	IF	CROMEMCO
	MOV	AL,BACKBIT	; Select back side.
	OUT	04H
	ENDIF

	JP	SIDELOOP	; Do the back side.
NEXTRACK:
	ENDIF

	INC	DL		; Next track.
	CMP	DL,[DI+TRKCNT]	; See if done.
	JAE	FINI
	MOV	AL,58H+STPSPD	; Step in to next track
	MOV	CH,0C0H		; Accept "not ready" or "write protect" errors.
	CALL	DCOM
	JP	TRACKLOOP
FINI:
	JMP	EACH

PUTSEC:
	PUSH	DX
	MOV	CH,[DI+SECCNT]	; CH = number of sectors.
	MOV	DX,[SI+SECSIZ]	; DX = number of bytes in sector pattern.
SEC:
	MOV	[BX],AL		; Poke number in sector ID.
	ADD	BX,DX
	ADD	AL,CL		; Increment sector, side, or track number.
	DEC	CH
	JNZ	SEC
	POP	DX
	RET

MAKE:
	PUSH	SI
	MOV	SI,DX
MAKELOOP:
	UP
	LODB			; Get byte count.
	OR	AL,AL		; Return if zero.
	JZ	MAKERETURN
	MOV	CH,AL		; Count to CH.
	LODB			; Get byte for pattern.
PUTPAT:
	MOV	[BX],AL		; Put byte in pattern.
	INC	BX
	DEC	CH
	JNZ	PUTPAT
	JP	MAKELOOP
MAKERETURN:
	POP	SI
	RET

TRACK:

	IF	CROMEMCO
	MOV	AL,[DI+DRVTAB]	; Get drive-select byte.
	OR	AL,80H		; Turn on auto-wait.
	OUT	DISK+4
	ENDIF

	MOV	AL,0F4H
	OUT	DISK
	MOV	SI,PATTERN
	MOV	CH,0E4H		; Accept "not ready", "write protect", "write
				;  fault", & "lost data" errors.
	AAM			; Delay 10 microseconds INTRQ to go off.
WRTLP:

	IF	SCP
	IN	DISK+5		; Wait for DRQ or INTRQ.
	ENDIF

	IF	TARBELL+CROMEMCO
	IN	DISK+4
	ENDIF

	IF	TARBELL
	SHL	AL
	JNC	WAIT
	ENDIF

	IF	SCP+CROMEMCO
	SHR	AL
	JC	WAIT
	ENDIF

	LODB
	OUT	DISK+3
	JP	WRTLP

DCOM:
	OUTB	DISK
	AAM			;10 Microsecond delay
WAIT:
	INB	DISK+4
	TEST	AL,DONEBIT

	IF	SCP+CROMEMCO
	JZ	WAIT
	ENDIF

	IF	TARBELL
	JNZ	WAIT
	ENDIF

	IN	DISK		; Get status from disk.
	AND	AL,CH
	JZ	RET
	MOV	AH,OUTSTR
	MOV	DX,ERRMES
	INT	33
	JMP	EACH

WARNING:DB	"Completely re-formats any bad disk - "
	DB	"destroying its contents, of course!",13,10,"$"
DRVMES:	DB	13,10,"Initialize disk in which drive? $"
ERRMES:	DB	13,10,10,"ERROR - Not ready or write protected",13,10,"$"

;
; How the tables below work:
; DRVTAB is a bunch of bytes which are sent to the disk controller as
; drive-select bytes, they are used it to specify which physical drive
; the logical drive number refers to.  The first entry is for logical
; drive 0, the next for logical drive 1, etc.  The drive select byte
; must also have the correct bits set for density (single or double),
; size (5.25-inch or 8-inch), and side (if initializing one side only;
; logical drives which are double-density double-sided MUST have the
; drive-select byte select side zero).  Exactly which bit does what
; depends on the actual disk controller used.
;
; SECCNT indicates how many sectors per track for each drive.
; (Each entry is one byte - use DB).
;	5.25-inch single-density -> 18
;	5.25-inch double-density ->  8
;	8-inch single-density    -> 26
;	8-inch double-density    ->  8
;
; TRKCNT indicates how many tracks are on each drive.
; (1 byte each entry - use DB).
;
; TRKNUM indicates how many bytes from the beginning of the track
; pattern the first sector ID number is.
; (Each entry is two bytes - use DW).
;	5.25-inch single-density -> 12
;	5.25-inch double-density -> don't know yet for sure
;	8-inch single-density    -> 80
;	8-inch double-density    -> 162
;
; SECSIZ indicates how many bytes are in each the pattern for each
; sector.  (Each entry is two bytes - use DW).
;
; INDEXT points to the index pattern to be used for each drive.
; (Each entry is two bytes - use DW).
;	5.25-inch single-density -> SSINDEX
;	5.25-inch double-density -> SDINDEX
;	8-inch single-density    -> LSINDEX
;	8-inch double-density    -> LDINDEX
;
; SECTAB points to the sector pattern to be used for each drive.
; (Each entry is two bytes - use DW).
;	5.25-inch single-density -> SSSECTOR
;	5.25-inch double-density -> SDSECTOR
;	8-inch single-density    -> LSSECTOR
;	8-inch double-density    -> LDSECTOR
;
	IF	TARBELLDOUBLE*(LARGEDS-1)
DRVTAB:	DB	0,10H,08H,18H,28H,38H
SECCNT:	DB	26,26,8,8,8,8
TRKCNT:	DB	77,77,77,77,77,77
TRKNUM:	DW	80,80,162,162,162,162
SECSIZ:	DW	186,186,1138,1138,1138,1138
INDEXT:	DW	LSINDEX,LSINDEX,LDINDEX,LDINDEX,LDINDEX,LDINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,LDSECTOR,LDSECTOR,LDSECTOR,LDSECTOR
	ENDIF

	IF	TARBELLDOUBLE*LARGEDS
DRVTAB:	DB	0,40H,10H,50H,08H,18H
SECCNT:	DB	26,26,26,26,8,8
TRKCNT:	DB	77,77,77,77,77,77
TRKNUM:	DW	80,80,80,80,162,162
SECSIZ:	DW	186,186,186,186,1138,1138
INDEXT:	DW	LSINDEX,LSINDEX,LSINDEX,LSINDEX,LDINDEX,LDINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,LSSECTOR,LSSECTOR,LDSECTOR,LDSECTOR
	ENDIF

	IF	TARBELLSINGLE
DRVTAB:	DB	0F2H,0E2H,0D2H,0C0H
SECCNT:	DB	26,26,26,26
TRKCNT:	DB	77,77,77,77
TRKNUM:	DW	80,80,80,80
SECSIZ:	DW	186,186,186,186
INDEXT:	DW	LSINDEX,LSINDEX,LSINDEX,LSINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,LSSECTOR,LSSECTOR
	ENDIF

	IF	CROMEMCO4FDC*LARGE
DRVTAB:	DB	31H,32H,34H,38H
SECCNT:	DB	26,26,26,26
TRKCNT:	DB	77,77,77,77
TRKNUM:	DW	80,80,80,80
SECSIZ:	DW	186,186,186,186
INDEXT:	DW	LSINDEX,LSINDEX,LSINDEX,LSINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,LSSECTOR,LSSECTOR
	ENDIF

	IF	CROMEMCO4FDC*SMALL
DRVTAB:	DB	21H,22H,24H,28H
SECCNT:	DB	18,18,18,18
TRKCNT:	DB	40,40,40,40
TRKNUM:	DW	12,12,12,12
SECSIZ:	DW	165,165,165,165
INDEXT:	DW	SSINDEX,SSINDEX,SSINDEX,SSINDEX
SECTAB:	DW	SSSECTOR,SSSECTOR,SSSECTOR,SSSECTOR
	ENDIF

	IF	CROMEMCO4FDC*COMBIN
DRVTAB:	DB	31H,32H,24H
SECCNT:	DB	26,26,18
TRKCNT:	DB	77,77,40
TRKNUM:	DW	80,80,12
SECSIZ:	DW	186,186,165
INDEXT:	DW	LSINDEX,LSINDEX,SSINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,SSSECTOR
	ENDIF

	IF	CROMEMCO16FDC*LARGE
DRVTAB:	DB	31H,32H,71H,72H,74H,78H
SECCNT:	DB	26,26,8,8,8,8
TRKCNT:	DB	77,77,77,77,77,77
TRKNUM:	DW	80,80,162,162,162,162
SECSIZ:	DW	186,186,1138,1138,1138,1138
INDEXT:	DW	LSINDEX,LSINDEX,LDINDEX,LDINDEX,LDINDEX,LDINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,LDSECTOR,LDSECTOR,LDSECTOR,LDSECTOR
	ENDIF

	IF	CROMEMCO16FDC*COMBIN
DRVTAB:	DB	31H,32H,24H,71H,72H,64H
SECCNT:	DB	26,26,18,8,8,8
TRKCNT:	DB	77,77,40,77,77,40
TRKNUM:	DW	80,80,12,162,162,?
SECSIZ:	DW	186,186,165,1138,1138,?
INDEXT:	DW	LSINDEX,LSINDEX,SSINDEX,LDINDEX,LDINDEX,SDINDEX
SECTAB:	DW	LSSECTOR,LSSECTOR,SSSECTOR,LDSECTOR,LDSECTOR,SDSECTOR
	ENDIF

	IF	(SCP+CROMEMCO16FDC)*(LARGE+COMBIN)+TARBELLDOUBLE
LDINDEX:			; Pattern for 8-inch double-density.
	DB	80,4EH
	DB	12,0
	DB	3,0F6H
	DB	1,0FCH
	DB	50,4EH
LDSECTOR:
	DB	12,0
	DB	3,0F5H
	DB	1,0FEH
	DB	3,0		;Track, side, and sector
	DB	1,3		;Sector size=1024
	DB	1,0F7H
	DB	22,4EH
	DB	12,0
	DB	3,0F5H
	DB	1,0FBH
	DB	255,0E5H
	DB	255,0E5H
	DB	255,0E5H
	DB	255,0E5H
	DB	4,0E5H
	DB	1,0F7H
	DB	54,4EH
	DB	0

	DB	255,4EH
	DB	255,4EH
	DB	255,4EH
	DB	0
	ENDIF

	IF	(SCP+CROMEMCO16FDC)*(LARGE+COMBIN)+TARBELLDOUBLE
LSINDEX:			; Pattern for 8-inch single-density with 1793.
	DB	40,-1
	DB	6,0
	DB	1,0FCH
	DB	26,-1
LSSECTOR:
	DB	6,0
	DB	1,0FEH
	DB	4,0
	DB	1,0F7H
	DB	11,-1
	DB	6,0
	DB	1,0FBH
	DB	128,0E5H
	DB	1,0F7H
	DB	27,-1
	DB	0

	DB	255,-1
	DB	255,-1
	DB	0
	ENDIF

	IF	CROMEMCO4FDC*(LARGE+COMBIN)+TARBELLSINGLE
LSINDEX:			; Pattern for 8-inch single-density with 1771.
	DB	46,0
	DB	1,0FCH
	DB	26,0
LSSECTOR:
	DB	6,0
	DB	1,0FEH
	DB	4,0
	DB	1,0F7H
	DB	17,0
	DB	1,0FBH
	DB	128,0E5H
	DB	1,0F7H
	DB	27,0
	DB	0

	DB	255,0
	DB	255,0
	DB	0
	ENDIF

	IF	CROMEMCO4FDC*(SMALL+COMBIN)
SSINDEX:			; Pattern for 5.25-inch single-density w/1771.
SSSECTOR:			; No index mark on small disk
	DB	7,-1
	DB	4,0
	DB	1,0FEH
	DB	4,0
	DB	1,0F7H
	DB	11,-1
	DB	6,0
	DB	1,0FBH
	DB	128,0E5H
	DB	1,0F7H
	DB	1,-1
	DB	0

	DB	255,0
	DB	255,0
	DB	0
	ENDIF

PATTERN:
