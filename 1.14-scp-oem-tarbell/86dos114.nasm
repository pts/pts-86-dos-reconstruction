;
; 86dos114.nasm: reconstruct the 86-DOS 0.11 FAT12-shortdir disk image
; by pts@fazekas.hu at Fri Dec  6 19:17:10 CET 2024
;
; Compile with: nasm -O0 -o 86dos114.img 86dos114.nasm
; Minimum NASM version required: 0.98.39.
; Specify -DNO_JUNK to avoid reading junk bytes from the FSJUNKDAT.
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
    junkbin $-$$+CLUSTERS_OFS, (%2)-($-$$+CLUSTERS_OFS), 0xe5  ; Even more junk.
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
%macro junkbin 4  ; %1 is the junk size available in FSJUNKDAT, %3 is offset in JUNKIMG, %3 is the desired junk size; %4 is the filler byte.
  %ifdef NO_JUNK  ; `nasm -DNO_JUNK'.
    times (%3) db %4
  %elif %3
    ; Same as: incbin JUNKIMG, (%2), (%3)
    %if (%1)<(%3)
      times (%3)-(%1) db %4  ; If too little junk is available, put it to the end.
      incbin FSJUNKDAT, FSJUNKDATPOS, %1
    %else
      incbin FSJUNKDAT, FSJUNKDATPOS+(%1)-(%3), %1
    %endif
    %assign FSJUNKDATPOS FSJUNKDATPOS+(%1)
  %else
    times (%3) db %4
  %endif
%endm
%macro junkbin 3  ; %1 is offset in JUNKIMG, %2 is junk size, %3 is the filler byte.
  junkbin %2, %1, %2, %3
%endm

%macro incres 3  ; %1 is the junk size available in FSJUNKDAT.
  %%res: incbin %2
  junkbin %1, $-$$, (%3)-$+%%res, 0
  assert_at %%res+(%3)-$$  ; Check approximate file size: number of 0x80 block must match.
%endm
%macro incfile_and_junk 3  ; %1 is the junk size available in FSJUNKDAT.
  section .clusters
  %2:
  %if (($-$$)>>SSS)+2==SKIPCLF
    incbin %3, 0, (SKIPCLA-SKIPCLF)<<9
    junkbin $-$$+CLUSTERS_OFS, (SKIPCLB-SKIPCLA)<<9, 0xe5
    incbin %3, (SKIPCLA-SKIPCLF)<<9
    %2.size equ $-(%2)-((SKIPCLB-SKIPCLA)<<9)
  %else
    incbin %3, 0
    %2.size equ $-(%2)
  %endif
  %2.fatsize equ $-(%2)
  junkbin %1, $-$$+CLUSTERS_OFS, ($$-$)&0x7f, 0xe5
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
  fat12p -2, -1  ; First two FAT12 entries are always void.
%endm
%macro fat12p_file 1  ; %1 is the size in bytes.
  %assign FAT12PFC ((%1)+0x1ff)>>9
  %if FAT12PFC
    %rep FAT12PFC-1
      %if FAT12PC+1==(SKIPCLA) && (SKIPCLB)>(SKIPCLA)
        fat12p (SKIPCLB)
      %elif FAT12PC+1>(SKIPCLA) && (FAT12PC+1)<=(SKIPCLB)
        fat12p 0
      %else
        fat12p FAT12PC+1
      %endif
    %endrep
    fat12p -1
  %endif
%endm

%macro incfile 7  ; %1 is the junk size (0 for no junk, i.e. just padding); %2 is 11 bytes of padded 86-DOS filename; %3 is the host filename for incbin; %4 is the file attribute bitmask; %5 is the last-modification year; %6 is the month; %7 is the day.
  %assign DATE FAT_DATE(%5, %6, %7)
  entry %2, %%label, %4, DATE
  incfile_and_junk %1, %%label, %3
  fat12p_file %%label.fatsize
%endm

SSS equ 9  ; Sector size shift. Sector size is 1<<SSS bytes. Not configurable.

%macro fatfs_start 4
  %ifndef FSJUNKDAT
    %define NO_JUNK
  %endif

  HEADER_SIZE equ %1
  FAT_CLUSTER_COUNT equ %2
  MAX_FILE_COUNT equ %3
  TAIL_SIZE equ %4  ; Number of bytes after the last cluster.
  FAT_SIZE equ (((FAT_CLUSTER_COUNT*3+1)>>1)+0xff)&~0xff  ; &0x3f, &0x7f, &0x7f works, &0x1f is too little, &0x1ff is too large.
  ROOTDIR_OFS equ HEADER_SIZE+(FAT_SIZE<<1)  ; File offset of the root directory.
  CLUSTERS_OFS equ ROOTDIR_OFS+(MAX_FILE_COUNT<<5)  ; File offset of first cluster.
  IMG_SIZE equ CLUSTERS_OFS+((FAT_CLUSTER_COUNT-2)<<SSS)+TAIL_SIZE

  section .fat1 follows=.header
  section .fat2 follows=.fat1

  fat12p_init

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

; Junk bytes are read from this file unless `nasm -DNO_JUNK' is used.
;%define JUNKIMG '86dos11t.img'
%define FSJUNKDAT 'fsjunk.dat.orig'
%ifdef NO_SKIP  ; `nasm -DNO_SKIP'
  SKIPCLA equ 0
  SKIPCLB equ 0
  SKIPCLF equ 0
%else
  SKIPCLA equ 0x108  ; First cluster to skip from being allocated. Skipped region must be within a single file.
  SKIPCLB equ 0x113  ; First cluster after SKIPCLA not to skip anymore. To disable, set SKIPCLA and SKIPCLB to the same value.
  SKIPCLF equ 0xfe  ; This is the file 'readthis.doc.orig'. First cluster of the containing the SKIPCLA...SKIPCLF region. To disable, set it to 0.
%endif
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
incfile 0x69, 'MON     ASM', 'mon.asm',           0, 1981, 05, 26  ; , 0x00aa ++ dd 0x8b17
incfile 0x50, 'CPMTAB  ASM', 'cpmtab.asm',        0, 1981, 12, 11  ; , 0x00f0 ++ dd 0x0430
incfile 0x57, 'BOOT    ASM', 'boot.asm',          0, 1981, 08, 26  ; , 0x00f3 ++ dd 0x0a29
incfile 0x02, 'NEWS    DOC', 'news.doc.orig',     0, 1981, 11, 24  ; , 0x00f9 ++ dd 0x097e
incfile 0x3b, 'READTHISDOC', 'readthis.doc.orig', 0, 1981, 12, 11  ; , 0x00fe ++ dd 0x1545  ; This file is affected by SKIPCLF.
%assign DATE FAT_DATE(1981, 12, 11)
entry 0xe5, 'OSIO   HEX', 0, DATE, 0x0108, 0x08f6  ; A deleted file. This entry is junk.
%ifndef NO_JUNK
  junk_between 0x24c00, 0x2c480
%endif
fatfs_end
