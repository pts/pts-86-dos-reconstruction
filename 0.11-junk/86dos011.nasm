;
; 86dos011.nasm: reconstruct the 86-DOS 0.11 FAT12-shortdir disk image
; by pts@fazekas.hu at Thu Dec  5 20:33:37 CET 2024
;
; Compile with: nasm -O0 -o 86dos011.img 86dos011.nasm
; Minimum NASM version required: 0.98.39.
; Specify -Djunk=pad to avoid reading junk bytes from the FSJUNKDAT.
;
; This program creates the FAT12-shortdir filesystem data structures
; automatically (including the two FATs) based on the included input files
; it receives via `incres_and_junk' and `incfile'.
;
; You can add your own files to the generated image, just scroll to the
; bottom, and add an `incfile 0, ...' line.
;
; The output file 86dos011.img is identical to the original:
;
;   $ wget -O '86-DOS Version 0.1-C - Serial #11 (ORIGINAL DISK).img' https://archive.org/download/86-dos-version-0.1-c-serial-11-original-disk/86-DOS%20Version%200.1-C%20-%20Serial%20%2311%20%28ORIGINAL%20DISK%29.img
;

bits 16
cpu 8086

%macro assert_at 1  ; Checks that we've generated %1 bytes so far in the currect section.
  times +$-$$-(%1) times 0 db 0
  times -$+$$+(%1) times 0 db 0
%endm

%macro db_until 2
  times (%1)-$+$$ db (%2)+0
%endm

%macro entry 3  ; entry 'name 11', start_cluster, size
  section .rootdir
  %%entry:
  db %1
  assert_at %%entry+0xb-$$
  dw (%2)+0
  dw (%3)&0xffff
  db (%3)>>16
  assert_at %%entry+0x10-$$
%endm
%macro entry 2  ; entry 'name 11', LABEL
  entry %1, (((%2)-_clusters)>>SSS)+2, (%2.sizewithjunk)
%endm

%define FSJUNKDATPOS 0
%macro junkbin 3  ; %1 is the junk size available in FSJUNKDAT.
  ; Same as: incbin JUNKIMG, %2, %3
  incbin FSJUNKDAT, FSJUNKDATPOS+(%1)-(%3), %3
  %assign FSJUNKDATPOS FSJUNKDATPOS+(%1)
%endm

%macro incres 3  ; %1 is the junk size available in FSJUNKDAT.
  %%res: incbin %2
  %ifdef junk  ; `nasm -Djunk=pad'.
    times (%3)-$+%%res db 0x1a
  %elif %1
    %ifdef FSJUNKDAT
      %if (%1)<((%3)-$+%%res)  ; If too little junk is available, put it to the end.
        times -(%1)+((%3)-$+%%res) db 0
        junkbin %1, $-$$, %1
      %else
        junkbin %1, $-$$+(%1)-((%3)-$+%%res), (%3)-$+%%res
      %endif
    %else
      times (%3)-$+%%res db 0x1a
    %endif
  %else
    times (%3)-$+%%res db 0x1a
  %endif
  assert_at %%res+(%3)+(-(%3)&0x7f)-$$  ; Check approximate file size: number of 0x80 block must match.
%endm
%macro incfile_and_junk 3  ; %1 is the junk size available in FSJUNKDAT.
  section .clusters
  %2: incbin %3
  %2.size equ $-(%2)
  %2.padsize equ ($$-$)&0x7f
  %ifdef junk  ; `nasm -Djunk=pad'.
    times %2.padsize db 0x1a
  %elif %1
    %ifdef FSJUNKDAT
      %if (%1)<(%2.padsize)  ; If too little junk is available, put it to the end.
        times -(%1)+(%2.padsize) db 0
        junkbin %1, $-$$+CLUSTERS_OFS, %1
      %else
        junkbin %1, $-$$+CLUSTERS_OFS+(%1)-(%2.padsize), (%2.padsize)
      %endif
    %else
      times %2.padsize db 0x1a
    %endif
  %else
    times %2.padsize db 0x1a
  %endif
  db_until ($-$$)+(($$-$)&0x7f), 0x1a
  %2.sizewithjunk equ $-(%2)
  db_until ($-$$)+(($$-$)&0x1ff), 0xe5
  section .header
%endm

%macro fat12p2 2  ; Add two FAT12 pointers.
  section .fat1
  db (%1)&0xff, ((%1)>>8)&0xf | ((%2)<<4)&0xf0, ((%2)>>4)&0xff
  section .fat2
  db (%1)&0xff, ((%1)>>8)&0xf | ((%2)<<4)&0xf0, ((%2)>>4)&0xff
%endm
%macro fat12p_flush 0
  %if FAT12NBUF>=0
    section .fat1
    db (FAT12NBUF)&0xff, ((FAT12NBUF)>>8)&0xf  ;| ((%2)<<4)&0xf0
    section .fat2
    db (FAT12NBUF)&0xff, ((FAT12NBUF)>>8)&0xf  ;| ((%2)<<4)&0xf0
    %define FAT12NBUF -1
  %endif
%endm
%macro fat12p 1-*
  %rep %0
    %if FAT12NBUF>=0
      fat12p2 FAT12NBUF, %1
      %define FAT12NBUF -1
    %else
      %assign FAT12NBUF (%1)&0xfff
    %endif
    %assign FAT12PC FAT12PC+1
    %rotate 1
  %endrep
%endm
%macro fat12p_init 0
  %define FAT12PC 0
  %define FAT12NBUF -1
  fat12p -1, -1  ; First two FAT12 entries are always void.
%endm
%macro fat12p_file 1  ; %1 is the size in bytes.
  %assign FAT12PFC ((%1)+0x1ff)>>9
  %if FAT12PFC
    %rep FAT12PFC-1
      fat12p FAT12PC+1
    %endrep
    fat12p -1
  %endif
%endm

%macro incfile 3  ; %1 is the junk size (0 for no junk, i.e. just padding); %2 is 11 bytes of padded 86-DOS filename; %3 is the host filename for incbin.
  entry %2, %%label
  incfile_and_junk %1, %%label, %3
  fat12p_file %%label.size
%endm

SSS equ 9  ; Sector size shift. Sector size is 1<<SSS bytes. Not configurable.

%macro fatfs_start 4
  HEADER_SIZE equ %1
  FAT_CLUSTER_COUNT equ %2
  MAX_FILE_COUNT equ %3
  TAIL_SIZE equ %4  ; Number of bytes after the last cluster.
  FAT_SIZE equ (((FAT_CLUSTER_COUNT*3+1)>>1)+0xff)&~0xff  ; &0x3f, &0x7f, &0x7f works, &0x1f is too little, &0x1ff is too large.
  ROOTDIR_OFS equ HEADER_SIZE+(FAT_SIZE<<1)  ; File offset of the root directory.
  CLUSTERS_OFS equ ROOTDIR_OFS+(MAX_FILE_COUNT<<4)  ; File offset of first cluster.
  IMG_SIZE equ CLUSTERS_OFS+((FAT_CLUSTER_COUNT-2)<<SSS)+TAIL_SIZE

  section .fat1 follows=.header
  section .fat2 follows=.fat1

  fat12p_init

  section .rootdir follows=.fat2

  section .clusters follows=.rootdir
  _clusters:

  section .header start=0
  assert_at 0  ; Keep .header as active section for the caller.
%endm

%macro fatfs_end 0
  section .header
  db_until HEADER_SIZE, 0

  section .clusters
  db_until IMG_SIZE-CLUSTERS_OFS, 0xe5

  fat12p_flush

  section .fat1
  db_until ((FAT_CLUSTER_COUNT*3+1)>>1), 0
  db_until FAT_SIZE, 0xe5
  assert_at FAT_SIZE

  section .fat2
  db_until ((FAT_CLUSTER_COUNT*3+1)>>1), 0
  db_until FAT_SIZE, 0xe5

  section .rootdir
  db_until CLUSTERS_OFS-ROOTDIR_OFS, 0xe5
%endm

; ---

; Junk bytes are read from this file unless `nasm -Djunk=pad' is used.
%define FSJUNKDAT 'fsjunk.dat.orig'
fatfs_start 0x1a00, 0x1e4, 0x40, 0x100

incres 0x20, 'boot.com.orig', 0x80  ; Contains junk in the end.
incres 0x4f, 'dosio.com.orig', 0x300  ; Junk.
db_until 0x480, 0
incbin '86dos.sys.orig'
incfile 0x54, 'COMMAND COM', 'command.com.orig'
incfile 0,    'RDCPM   COM', 'rdcpm.com.orig'
incfile 0,    'HEX2BIN COM', 'hex2bin.com.orig'
incfile 0x6f, 'ASM     COM', 'asm.com.orig'  
incfile 0x70, 'TRANS   COM', 'trans.com.orig'
incfile 0x67, 'SYS     COM', 'sys.com.orig'  
incfile 0x5,  'EDLIN   COM', 'edlin.com.orig'
incfile 0x2a, 'CHESS   COM', 'chess.com.orig'
incfile 0,    'CHESS   DOC', 'chess.doc.orig'
fatfs_end
