#! /bin/sh --
#
# extract.sh: extract files from the original 86-DOS 1.14 disk image
# by pts@fazekas.hu at Fri Dec  6 15:10:31 CET 2024
#
# Download the original 86-DOS 1.14 disk image first:
#
#   $ wget -O '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD).rar' https://archive.org/download/86-dos-1.14/86-DOS%201.14%20%5BSCP%20OEM%5D%20%5BSCP%20Tarbell%5D%20%2812-11-1981%29%20%288%20inch%20SSSD%29.rar
#
set -ex
test "$0" = "${0%/*}" || cd "${0%/*}"

export PATH="../tools:$PATH"  # nasm, unrar and disk-analyse.

if ! test -f 86dos11t.img; then
  if ! test -f 86dos11t.imd; then
    test -f '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD).rar'
    unrar x '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD).rar' '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD)/86dos11t.imd'
    mv '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD)/86dos11t.imd' 86dos11t.imd
    rmdir '86-DOS 1.14 [SCP OEM] [SCP Tarbell] (12-11-1981) (8 inch SSSD)' ||:
    test -f 86dos11t.imd
  fi
  disk-analyse 86dos11t.imd 86dos11t.img  # This is very slow (~20s), because it uses a slow algorithm.
  test -f 86dos11t.img
fi

if false; then  # Analyze the FAT12 chain.
  perl -0777 -wne 'use integer; use strict;
      my @next;
      for (my $i = 0x1a00; $i < 0x1ba8; $i += 3) {
        my($a, $b, $c) = (vec($_, $i, 8), vec($_, $i + 1, 8), vec($_, $i + 2, 8));
        push @next, $a|($b&0xf)<<8, ($b&0xf0)>>4|$c<<4;
      }
      my %prev;
      for (my $p = 2; $p < @next; ++$p) {
        my $q = $next[$p];
        $prev{$q} = $p if $q and $q < 0xffe;
      }
      for (my $p = 2; $p < @next; ++$p) {
        next if exists($prev{$p});
        my @chain;
        my $q = $p;
        while ($q and $q < 0xffe) { push @chain, $q; $q = $next[$q] }
        next if !($q and $q == 0xfff);
        my $prev = $chain[0] - 1;
        push @chain, 0;
        my $s = join("", sprintf("0x%03x", $chain[0]), map { my $prev0 = $prev; $prev = $_; ($_ == $prev0 + 1 ? "" : sprintf("..0x%03x 0x%03x", $prev0, $_)) } @chain);
        die if $s !~ s@ 0x000\Z(?!\n)@@;
        print "$s;\n";
      }
      ' <86dos11t.img
  # Result: 0x002..0x00d; 0x00e..0x013; 0x014..0x01e; 0x01f..0x02e;
  # 0x02f..0x02f; 0x030..0x030; 0x031..0x031; 0x032..0x036; 0x037..0x039;
  # 0x03a..0x03c; 0x03d..0x03d; 0x03e..0x044; 0x045..0x045; 0x046..0x047;
  # 0x048..0x061; 0x062..0x0a9; 0x0aa..0x0ef; 0x0f0..0x0f2; 0x0f3..0x0f8;
  # 0x0f9..0x0fd; 0x0fe..0x107 0x113..0x113.
  #
  # Only the last file is noncontiguous.
fi

if false; then  # Manual analysis of the files (root directory entries).
# attr: 2==hidden 6=system
# mdate (last modification date): (year-1980)<<9|month<<5|day. month>=1, day>=1.
# 
#    name                attr                  mdate        startc       size      mdate2        FAT12 chain
# ------------------------------------------------------------------------------------------------------------------------
  db '86DOS   SYS' ++ db 6 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x0002 ++ dd 0x172e ++ 1981-12-11
  db 'COMMAND COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x0315 ++ dw 0x000e ++ dd 0x0bc9 ++ 1981-08-21
  db 'DEBUG   COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x0315 ++ dw 0x0014 ++ dd 0x1599 ++ 1981-08-21
  db 'ASM     COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x0368 ++ dw 0x001f ++ dd 0x1ff0 ++ 1981-11-08
  db 'SYS     COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x030c ++ dw 0x002f ++ dd 0x01d4 ++ 1981-08-12
  db 'TIME    COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x02f3 ++ dw 0x0030 ++ dd 0x00f1 ++ 1981-07-19
  db 'DATE    COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x02f1 ++ dw 0x0031 ++ dd 0x012f ++ 1981-07-17
  db 'EDLIN   COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x02fd ++ dw 0x0032 ++ dd 0x0900 ++ 1981-07-29
  db 'CHKDSK  COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x02fc ++ dw 0x0037 ++ dd 0x04b5 ++ 1981-07-28
  db 'RDCPM   COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x003a ++ dd 0x051e ++ 1981-12-11
  db 'MAKRDCPMCOM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x029e ++ dw 0x003d ++ dd 0x012f ++ 1981-04-30
  db 'TRANS   COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x0354 ++ dw 0x003e ++ dd 0x0c12 ++ 1981-10-20
  db 'HEX2BIN COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x0292 ++ dw 0x0045 ++ dd 0x01e3 ++ 1981-04-18
  db 'INIT    COM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x0046 ++ dd 0x027f ++ 1981-12-11
  db 'INIT    ASM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x0048 ++ dd 0x336e ++ 1981-12-11
  db 'DOSIO   ASM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x0062 ++ dd 0x8e4b ++ 1981-12-11
  db 'MON     ASM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x02ba ++ dw 0x00aa ++ dd 0x8b17 ++ 1981-05-26
  db 'CPMTAB  ASM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x00f0 ++ dd 0x0430 ++ 1981-12-11
  db 'BOOT    ASM' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x031a ++ dw 0x00f3 ++ dd 0x0a29 ++ 1981-08-26
  db 'NEWS    DOC' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x0378 ++ dw 0x00f9 ++ dd 0x097e ++ 1981-11-24
  db 'READTHISDOC' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x00fe ++ dd 0x1545 ++ 1981-12-11 ++ 0x0fe..0x107 0x113..0x113
  db '?OSIO   HEX' ++ db 0 ++ dd 0, 0, 0 ++ dw 0x038b ++ dw 0x0108 ++ dd 0x08f6 ++ 1981-12-11 ++ none, file deleted
fi 

echo "
%define F86DOS114IMG '86dos11t.img'
%define DELTA 0x2400
%define SSS 9  ; Sector size shift.
%ifdef X  ; Extract a contiguous file from the FAT12 filesystem.
  incbin F86DOS114IMG, DELTA+((X)<<SSS), S  ; \`nasm -DX=start_cluster -DS=file_size'.
%elifdef READTHIS_DOC  ; The single noncontiguous file on this FAT12 filesystem.
  incbin F86DOS114IMG, DELTA+(0xfe<<SSS), 10<<SSS
  incbin F86DOS114IMG, DELTA+(0x113<<SSS), 0x1545-(10<<SSS)
%else  ; Extract file from reserved sectors.
  incbin F86DOS114IMG, R, S  ; \`nasm -DR=start_ofs -DS=file_size'.
%endif" >extract.nasm

nasm -O0 -o boot.com.orig     -DR=0x0  -DS=0x006a extract.nasm
nasm -O0 -o dosio.com.orig    -DR=0x80 -DS=0x03a4 extract.nasm
nasm -O0 -o 86dos.sys.orig    -DX=0x02 -DS=0x172e extract.nasm
nasm -O0 -o command.com.orig  -DX=0x0e -DS=0x0bc9 extract.nasm
nasm -O0 -o debug.com.orig    -DX=0x14 -DS=0x1599 extract.nasm
nasm -O0 -o asm.com.orig      -DX=0x1f -DS=0x1ff0 extract.nasm
nasm -O0 -o sys.com.orig      -DX=0x2f -DS=0x01d4 extract.nasm
nasm -O0 -o time.com.orig     -DX=0x30 -DS=0x00f1 extract.nasm
nasm -O0 -o date.com.orig     -DX=0x31 -DS=0x012f extract.nasm
nasm -O0 -o edlin.com.orig    -DX=0x32 -DS=0x0900 extract.nasm
nasm -O0 -o chkdsk.com.orig   -DX=0x37 -DS=0x04b5 extract.nasm
nasm -O0 -o rdcpm.com.orig    -DX=0x3a -DS=0x051e extract.nasm
nasm -O0 -o makrdcpm.com.orig -DX=0x3d -DS=0x012f extract.nasm
nasm -O0 -o trans.com.orig    -DX=0x3e -DS=0x0c12 extract.nasm
nasm -O0 -o hex2bin.com.orig  -DX=0x45 -DS=0x01e3 extract.nasm
nasm -O0 -o init.com.orig     -DX=0x46 -DS=0x027f extract.nasm
nasm -O0 -o init.asm.orig     -DX=0x48 -DS=0x336e extract.nasm
nasm -O0 -o dosio.asm.orig    -DX=0x62 -DS=0x8e4b extract.nasm
nasm -O0 -o mon.asm.orig      -DX=0xaa -DS=0x8b17 extract.nasm
nasm -O0 -o cpmtab.asm.orig   -DX=0xf0 -DS=0x0430 extract.nasm
nasm -O0 -o boot.asm.orig     -DX=0xf3 -DS=0x0a29 extract.nasm
nasm -O0 -o news.doc.orig     -DX=0xf9 -DS=0x097e extract.nasm
nasm -O0 -o readthis.doc.orig -DREADTHIS_DOC      extract.nasm
rm -f extract.nasm

touch -d '1981-08-26 12:00:00 GMT' boot.com.orig  # Use the date of boot.asm.orig.
touch -d '1981-12-11 12:00:00 GMT' dosio.com.orig  # Use the date of dosio.asm.orig.
touch -d '1981-04-18 12:00:00 GMT' hex2bin.com.orig
touch -d '1981-04-30 12:00:00 GMT' makrdcpm.com.orig
touch -d '1981-05-26 12:00:00 GMT' mon.asm.orig
touch -d '1981-07-17 12:00:00 GMT' date.com.orig
touch -d '1981-07-19 12:00:00 GMT' time.com.orig
touch -d '1981-07-28 12:00:00 GMT' chkdsk.com.orig
touch -d '1981-07-29 12:00:00 GMT' edlin.com.orig
touch -d '1981-08-12 12:00:00 GMT' sys.com.orig
touch -d '1981-08-21 12:00:00 GMT' command.com.orig debug.com.orig
touch -d '1981-08-26 12:00:00 GMT' boot.asm.orig
touch -d '1981-10-20 12:00:00 GMT' trans.com.orig
touch -d '1981-11-08 12:00:00 GMT' asm.com.orig
touch -d '1981-11-24 12:00:00 GMT' news.doc.orig
touch -d '1981-12-11 12:00:00 GMT' 86dos.sys.orig cpmtab.asm.orig dosio.asm.orig init.asm.orig init.com.orig rdcpm.com.orig readthis.doc.orig

: "$0" OK.
