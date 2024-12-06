#! /bin/sh --
#
# extract.sh: extract files from the original 86-DOS 0.11 disk image
# by pts@fazekas.hu at Fri Dec  6 01:22:58 CET 2024
#
# Download the original 86-DOS 0.11 disk image first:
#
#   $ wget -O '86-DOS Version 0.1-C - Serial #11 (ORIGINAL DISK).img' https://archive.org/download/86-dos-version-0.1-c-serial-11-original-disk/86-DOS%20Version%200.1-C%20-%20Serial%20%2311%20%28ORIGINAL%20DISK%29.img
#
set -ex
test "$0" = "${0%/*}" || cd "${0%/*}"

export PATH="../tools:$PATH"

echo "
%define F86DOS011IMG '86-DOS Version 0.1-C - Serial #11 (ORIGINAL DISK).img'
%ifdef FSJUNK_DAT  ; Extract junk bytes after various files within 86dos011.img. 86dos011.nasm will copy them to the image it builds.
  incbin F86DOS011IMG, 0x60, 0x20
  incbin F86DOS011IMG, 0x331, 0x4f
  incbin F86DOS011IMG, 0x28ac, 0x54
  incbin F86DOS011IMG, 0x4991, 0x6f
  incbin F86DOS011IMG, 0x5610, 0x70
  incbin F86DOS011IMG, 0x5899, 0x67
  incbin F86DOS011IMG, 0x5efb, 0x5
  incbin F86DOS011IMG, 0x78d6, 0x2a
%elifdef X  ; Extract a contiguous file from the FAT12-shortdir filesystem.
  %define DELTA 0x2000
  %define SSS 9  ; Sector size shift.
  incbin F86DOS011IMG, DELTA+((X)<<SSS), S  ; \`nasm -DX=start_cluster -DS=file_size'.
%else  ; Extract file from reserved sectors.
  incbin F86DOS011IMG, R, S  ; \`nasm -DR=start_ofs -DS=file_size'.
%endif" >extract.nasm

nasm -O0 -o fsjunk.dat.orig  -DFSJUNK_DAT         extract.nasm
nasm -O0 -o boot.com.orig    -DR=0x0   -DS=0x0060 extract.nasm
nasm -O0 -o dosio.com.orig   -DR=0x80  -DS=0x02b1 extract.nasm
nasm -O0 -o 86dos.sys.orig   -DR=0x480 -DS=0x0cdd extract.nasm
nasm -O0 -o command.com.orig -DX=0x02  -DS=0x04ac extract.nasm
nasm -O0 -o rdcpm.com.orig   -DX=0x05  -DS=0x034d extract.nasm
nasm -O0 -o hex2bin.com.orig -DX=0x07  -DS=0x0171 extract.nasm
nasm -O0 -o asm.com.orig     -DX=0x08  -DS=0x1991 extract.nasm
nasm -O0 -o trans.com.orig   -DX=0x15  -DS=0x0c10 extract.nasm
nasm -O0 -o sys.com.orig     -DX=0x1c  -DS=0x0099 extract.nasm
nasm -O0 -o edlin.com.orig   -DX=0x1d  -DS=0x04fb extract.nasm
nasm -O0 -o chess.com.orig   -DX=0x20  -DS=0x18d6 extract.nasm
nasm -O0 -o chess.doc.orig   -DX=0x2d  -DS=0x0380 extract.nasm
rm -f extract.nasm

: "$0" OK.
