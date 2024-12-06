;
; 86dos114.nasm: reconstruct the 86-DOS 0.11 FAT12-shortdir disk image
; by pts@fazekas.hu at Fri Dec  6 19:17:10 CET 2024
;
; Compile with: nasm -O0 -o 86dos114.img 86dos114.nasm
; Minimum NASM version required: 0.98.39.
; Specify -Djunk=pad to avoid reading junk bytes from the FSJUNKDAT.
;
; This program creates the FAT12 filesystem data structures automatically
; (including the two FATs) based on the included input files it receives via
; `incfile'. Please not that this FAT12 filesystem is not compatible with
; DOS 2.x or mtools(1), because it lacks the superblock (boot sector
; headers, BPB). However, a valid one could be created by providing those
; headers, overwriting the boot code.
;
; You can add your own files to the generated image, just scroll to the
; bottom, and add an `incfile 0, ...' line.
;
; The output file 86dos114.img is identical to the original 86dos11t.img in:
;
;   $ wget -O '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD).rar' https://archive.org/download/86-dos-1.14/86-DOS%201.14%20%5BSCP%20OEM%5D%20%5BSCP%20Tarbell%5D%20%2812-11-1981%29%20%288%20inch%20SSSD%29.rar
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

%macro junk_between 2  ; %1 is junk start offset (must be within clusters); %2 is junk end offset.
  section .clusters
  %if $-$$+CLUSTERS_OFS<=(%2)
    %if $-$$+CLUSTERS_OFS<=(%1)
      db_until (%1)-CLUSTERS_OFS, 0xe5  ; Fill before the juk.
    %endif
    junkbin $-$$+CLUSTERS_OFS, (%2)-($-$$+CLUSTERS_OFS)  ; Even more junk.
  %endif
%endm

%define FAT_DATE(year, month, day) (((year)-1980)<<9|(month)<<5|(day))  ; dw.
%macro entry 6  ; entry 'name part1', 'name part2', attrs, mdate (FAT_DATE(...)), start_cluster, size
  section .rootdir
  %%entry:
  db %1, %2
  assert_at %%entry+0xb-$$
  db %3
  dd 0, 0, 0
  dw %4, %5
  dd %6
  assert_at %%entry+0x20-$$
%endm
%macro entry 4  ; entry 'name 11', LABEL, attrs, mdate (FAT_DATE(...))
  entry '', %1, %3, %4, (((%2)-_clusters)>>SSS)+2, (%2.size)
%endm

%define FSJUNKDATPOS 0
%macro junkbin 3  ; %1 is the junk size available in FSJUNKDAT, %3 is offset in JUNKIMG, %3 is junk size.
  ; Same as: incbin JUNKIMG, %2, %3
  ;incbin JUNKIMG, %2, %3
  incbin FSJUNKDAT, FSJUNKDATPOS+(%1)-(%3), %3
  %assign FSJUNKDATPOS FSJUNKDATPOS+(%1)
%endm
%macro junkbin 2  ; %1 is offset in JUNKIMG, %2 is junk size.
  junkbin %2, %1, %2
%endm

%macro incres 3  ; %1 is the junk size available in FSJUNKDAT.
  %%res: incbin %2
  %ifdef junk  ; `nasm -Djunk=pad'.
    times (%3)-$+%%res db 0
  %elif %1
    %ifdef FSJUNKDAT
      %if (%1)<((%3)-$+%%res)  ; If too little junk is available, put it to the end.
        times -(%1)+((%3)-$+%%res) db 0
        junkbin %1, $-$$, %1
      %else
        junkbin %1, $-$$+(%1)-((%3)-$+%%res), (%3)-$+%%res
      %endif
    %else
      times (%3)-$+%%res db 0
    %endif
  %else
    times (%3)-$+%%res db 0
  %endif
  assert_at %%res+(%3)+(-(%3)&0x7f)-$$  ; Check approximate file size: number of 0x80 block must match.
%endm
%macro incfile_and_junk 3  ; %1 is the junk size available in FSJUNKDAT.
  section .clusters
  %2:
  %if (($-$$)>>SSS)+2==SKIPCLF
    incbin %3, 0, (SKIPCLA-SKIPCLF)<<9
    junkbin $-$$+CLUSTERS_OFS, (SKIPCLB-SKIPCLA)<<9
    incbin %3, (SKIPCLA-SKIPCLF)<<9
    %2.size equ $-(%2)-((SKIPCLB-SKIPCLA)<<9)
  %else
    incbin %3, 0
    %2.size equ $-(%2)
  %endif
  %2.fatsize equ $-(%2)
  %2.padsize equ ($$-$)&0x7f
  %ifdef junk  ; `nasm -Djunk=pad'.
    times %2.padsize db 0xe5
  %elif %1
    %ifdef FSJUNKDAT
      %if (%1)<(%2.padsize)  ; If too little junk is available, put it to the end.
        times -(%1)+(%2.padsize) db 0
        junkbin %1, $-$$+CLUSTERS_OFS, %1
      %else
        junkbin %1, $-$$+CLUSTERS_OFS+(%1)-(%2.padsize), (%2.padsize)
      %endif
    %else
      times %2.padsize db 0xe5
    %endif
  %else
    times %2.padsize db 0xe5
  %endif
  db_until ($-$$)+(($$-$)&0x1ff), 0xe5
  section .header
%endm

%macro fat12p2 2  ; Add two FAT12 pointers.
  db (%1)&0xff
  db ((%1)>>8)&0xf | ((%2)<<4)&0xf0
  db ((%2)>>4)&0xff
%endm

%define FAT12NBUF1 -1
%define FAT12NBUF2 -1
%macro fat12p_flush 1  ; %1 is the FAT number: 1 or 2.
  %if FAT12NBUF%1>=0
    db (FAT12NBUF%1)&0xff
    db ((FAT12NBUF%1)>>8)&0xf  ;| ((%2)<<4)&0xf0
    %define FAT12NBUF%1 -1
  %endif
%endm
%macro fat12p 2-*  ; %1 is the FAT number: 1 or 2.
  %assign FAT12NBUF FAT12NBUF%1
  %assign FAT12PC   FAT12PC%1
  %rotate 1
  %rep %0-1
    %if FAT12NBUF>=0
      fat12p2 FAT12NBUF, %1
      %define FAT12NBUF -1
    %else
      %assign FAT12NBUF (%1)&0xfff
    %endif
    %assign FAT12PC FAT12PC+1
    %rotate 1
  %endrep
  %assign FAT12NBUF%1 FAT12NBUF
  %assign FAT12PC%1   FAT12PC
%endm
%macro fat12p_init 1  ; %1 is the FAT number: 1 or 2.
  %define FAT12PC%1 0
  fat12p %1, -2, -1  ; First two FAT12 entries are always void.
%endm
%macro fat12p_file 2  ; %1 is the FAT number: 1 or 2. %2 is the size in bytes.
  %assign FAT12PFC ((%2)+0x1ff)>>9
  %if FAT12PFC
    %rep FAT12PFC-1
      %if FAT12PC%1+1==(SKIPCLA) && (SKIPCLB)>(SKIPCLA)
        fat12p %1, (SKIPCLB)
      %elif FAT12PC%1+1>(SKIPCLA) && (FAT12PC%1+1)<=(SKIPCLB)
        fat12p %1, 0
      %else
        fat12p %1, FAT12PC%1+1
      %endif
    %endrep
    fat12p %1, -1
  %endif
%endm

%macro incfile 7  ; %1 is the junk size (0 for no junk, i.e. just padding); %2 is 11 bytes of padded 86-DOS filename; %3 is the host filename for incbin; %4 is the file attribute bitmask; %5 is the last-modification year; %6 is the month; %7 is the day.
  %assign DATE FAT_DATE(%5, %6, %7)
  entry %2, %%label, %4, DATE
  incfile_and_junk %1, %%label, %3
  section .fat1
  fat12p_file 1, %%label.fatsize
  section .fat2
  fat12p_file 2, %%label.fatsize
%endm

SSS equ 9  ; Sector size shift. Sector size is 1<<SSS bytes. Not configurable.

%macro fatfs_start 4
  HEADER_SIZE equ %1
  FAT_CLUSTER_COUNT equ %2
  MAX_FILE_COUNT equ %3
  TAIL_SIZE equ %4  ; Number of bytes after the last cluster.
  FAT_SIZE equ (((FAT_CLUSTER_COUNT*3+1)>>1)+0xff)&~0xff  ; &0x3f, &0x7f, &0x7f works, &0x1f is too little, &0x1ff is too large.
  ROOTDIR_OFS equ HEADER_SIZE+(FAT_SIZE<<1)  ; File offset of the root directory.
  CLUSTERS_OFS equ ROOTDIR_OFS+(MAX_FILE_COUNT<<5)  ; File offset of first cluster.
  IMG_SIZE equ CLUSTERS_OFS+((FAT_CLUSTER_COUNT-2)<<SSS)+TAIL_SIZE

  section .fat1 follows=.header
  fat12p_init 1

  section .fat2 follows=.fat1
  fat12p_init 2

  section .rootdir follows=.fat2

  section .clusters follows=.rootdir
  _clusters:

  section .header start=0
  times (SKIPCLB)-(SKIPCLA) times 0 nop  ; Assert that SKIPCLA<=SKIPCLB.
  assert_at 0  ; Keep .header as active section for the caller.
%endm

%macro fatfs_end 0
  section .header
  db_until HEADER_SIZE, 0

  section .clusters
  db_until IMG_SIZE-CLUSTERS_OFS, 0xe5

  section .fat1
  fat12p_flush 1
  db_until ((FAT_CLUSTER_COUNT*3+1)>>1), 0
  db_until FAT_SIZE, 0xe5
  assert_at FAT_SIZE

  section .fat2
  fat12p_flush 2
  db_until ((FAT_CLUSTER_COUNT*3+1)>>1), 0
  db_until FAT_SIZE, 0xe5

  section .rootdir
  db_until CLUSTERS_OFS-ROOTDIR_OFS, 0xe5
%endm

; ---

; Junk bytes are read from this file unless `nasm -Djunk=pad' is used.
;%define JUNKIMG '86dos11t.img'
%define FSJUNKDAT 'fsjunk.dat.orig'
SKIPCLA equ 0x108  ; First cluster to skip from being allocated. Skipped region must be within a single file.
SKIPCLB equ 0x113  ; First cluster after SKIPCLA not to skip anymore. To disable, set SKIPCLA and SKIPCLB to the same value.
SKIPCLF equ 0xfe  ; This is the file 'readthis.doc.orig'. First cluster of the containing the SKIPCLA...SKIPCLF region. To disable, set it to 0.
fatfs_start 0x1a00, 0x1e2, 0x40, 0x100
incres 0, 'boot.com', 0x80
incres 0, 'dosio.com', 0x400
db_until 0x480, 0
incfile 0x52, '86DOS   SYS', '86dos.sys',         6, 1981, 12, 11  ; , 0x0002 ++ dd 0x172e
incfile 0x37, 'COMMAND COM', 'command.com.orig',  0, 1981, 08, 21  ; , 0x000e ++ dd 0x0bc9
incfile 0x67, 'DEBUG   COM', 'debug.com.orig',    0, 1981, 08, 21  ; , 0x0014 ++ dd 0x1599
incfile 0x10, 'ASM     COM', 'asm.com.orig',      0, 1981, 11, 08  ; , 0x001f ++ dd 0x1ff0
incfile 0x2c, 'SYS     COM', 'sys.com.orig',      0, 1981, 08, 12  ; , 0x002f ++ dd 0x01d4
incfile 0x0f, 'TIME    COM', 'time.com.orig',     0, 1981, 07, 19  ; , 0x0030 ++ dd 0x00f1
incfile 0x51, 'DATE    COM', 'date.com.orig',     0, 1981, 07, 17  ; , 0x0031 ++ dd 0x012f
incfile 0x00, 'EDLIN   COM', 'edlin.com.orig',    0, 1981, 07, 29  ; , 0x0032 ++ dd 0x0900
incfile 0x4b, 'CHKDSK  COM', 'chkdsk.com.orig',   0, 1981, 07, 28  ; , 0x0037 ++ dd 0x04b5
incfile 0x62, 'RDCPM   COM', 'rdcpm.com.orig',    0, 1981, 12, 11  ; , 0x003a ++ dd 0x051e
incfile 0x51, 'MAKRDCPMCOM', 'makrdcpm.com.orig', 0, 1981, 04, 30  ; , 0x003d ++ dd 0x012f
incfile 0x6e, 'TRANS   COM', 'trans.com',         0, 1981, 10, 20  ; , 0x003e ++ dd 0x0c12
incfile 0x1d, 'HEX2BIN COM', 'hex2bin.com',       0, 1981, 04, 18  ; , 0x0045 ++ dd 0x01e3
incfile 0x01, 'INIT    COM', 'init.com',          0, 1981, 12, 11  ; , 0x0046 ++ dd 0x027f
incfile 0x12, 'INIT    ASM', 'init.asm',          0, 1981, 12, 11  ; , 0x0048 ++ dd 0x336e
incfile 0x35, 'DOSIO   ASM', 'dosio.asm',         0, 1981, 12, 11  ; , 0x0062 ++ dd 0x8e4b
incfile 0x69, 'MON     ASM', 'mon.asm.orig',      0, 1981, 05, 26  ; , 0x00aa ++ dd 0x8b17  ; !! Change mon.asm back, so we can copy it here instead of mon.asm.orig.
incfile 0x50, 'CPMTAB  ASM', 'cpmtab.asm',        0, 1981, 12, 11  ; , 0x00f0 ++ dd 0x0430
incfile 0x57, 'BOOT    ASM', 'boot.asm',          0, 1981, 08, 26  ; , 0x00f3 ++ dd 0x0a29
incfile 0x02, 'NEWS    DOC', 'news.doc.orig',     0, 1981, 11, 24  ; , 0x00f9 ++ dd 0x097e
incfile 0x3b, 'READTHISDOC', 'readthis.doc.orig', 0, 1981, 12, 11  ; , 0x00fe ++ dd 0x1545  ; This file is affected by SKIPCLF.
%assign DATE FAT_DATE(1981, 12, 11)
entry 0xe5, 'OSIO   HEX', 0, DATE, 0x0108, 0x08f6  ; A deleted file. This entry is junk.
junk_between 0x24c00, 0x2c480
fatfs_end
