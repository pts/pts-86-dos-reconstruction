@echo off
del *.hex
rem del *.com
del *.prn
del *.bin
del 86dos.sys
del 86dos011.img
@echo on
nasm -o asm244.com asm244.nas
nasm -o hex102.com hex102.nas
nasm -o fullimg.com fullimg.nas

asm244 86dos
hex102 86dos
ren 86dos.com 86dos.sys
asm244 boot
hex102 boot
asm244 dosio
hex102 dosio
asm244 asm
hex102 asm
asm244 chess
hex102 chess
ren command.asm comman.asm
asm244 comman
hex102 comman
ren comman.asm command.asm
ren comman.com command.dos
asm244 edlin
hex102 edlin
asm244 hex2bin
hex102 hex2bin
asm244 rdcpm
hex102 rdcpm
asm244 sys
hex102 sys
del *.hex
del *.prn
asm244 trans
hex102 trans
del *.hex
del *.prn

nasm -DDOSHOST -DNOEND -o 86dos011.img 86dos011.nas
fullimg 86dos011.img
dir 86dos011.img

rem run this to exit QEMU: o
exit
