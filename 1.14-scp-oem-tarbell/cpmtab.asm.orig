;Source code for drive tables used by RDCPM

	ORG	0
	PUT	100H

	DW	END		;Address of first free byte

;Table of addresses of the parameter block for each of 16 drives.
;Note that 16 entries are ALWAYS required, with unused drives 0.

	DW	IBM,IBM,IBM,IBM
	DW	0,0,0,0
	DW	0,0,0,0
	DW	0,0,0,0

;Below is the definition for standard single-density 8" drives

IBM:
	DW	26	;Sectors per track
	DB	3	;Block shift
	DB	7	;Block mask
	DB	0	;Extent mask
	DW	242	;Disk size - 1
	DW	63	;Directory entries - 1
	DS	4	;Not used
	DW	2	;Tracks to skip
	DW	MOD6	;Modulo-6 sector translate table

MOD6:
	DB	0,6,12,18,24
	DB	4,10,16,22
	DB	2,8,14,20
	DB	1,7,13,19,25
	DB	5,11,17,23
	DB	3,9,15,21

;This is the table for Cromemco 5" drives.
SMALL:
	DW	18	;Sectors per track
	DB	3	;Block shift
	DB	7	;Block mask
	DB	0	;Extent mask
	DW	82	;Disk size - 1
	DW	63	;Directory entries - 1
	DS	4	;Not used
	DW	3	;Tracks to skip
	DW	MOD5	;Modulo-5 sector translate table

MOD5:
	DB	0,5,10,15
	DB	2,7,12,17
	DB	4,9,14
	DB	1,6,11,16
	DB	3,8,13

END:
