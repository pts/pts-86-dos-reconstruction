#! /bin/sh --
#
# compile_qemu_pcdos320.sh: build 86-DOS 0.11 on IBM PC DOS 3.20 in QEMU
# by pts@fazekas.hu at Sat Dec  7 04:51:08 CET 2024
#
# This script works on a Linux system with a GUI, with qemu-system-i386
# installed (on Debian and Ubuntu, run: `sudo apt-get
# installqemu-system-x86`). Also you need to download IBM PC DOS 3.20 or
# later (e.g. from here: https://winworldpc.com/product/pc-dos/3x), and save
# the image of the 1st floppy disk as pcdos320.img.
#
# Earlier versions of DOS (such as IBM PC DOS 3.00 and 3.10) don't work,
# because they don't seem to support 1.2 MB virtual floppy disks in QEMU
# (but they do in 86Box 4.2.1, which is also much slower), and 320 kB floppy
# disks are way too small for this build. See
# https://retrocomputing.stackexchange.com/q/31008 for more details.
#
# A working set of 86Box 4.2.1 settings is:
#
# 1. In Tools / Settings / Machine: Machine type: [1997] Socket 7 (Dual
#    Voltage)
# 2. Machine: [i430VX] Shuttle HOT-557
# 3. Tools / Settings / Floppy & CD-ROM drives: 5.25" 1.2 MB
# 4. At boot, DEL / STANDARD CMOS SETUP / DRIVE A:: 1.2 M , 5.25 in.
#
# To run the build with QEMU, run this script from a GUI terminal emulator,
# and follow the instructions. Eventually the QEMU window will appear, and
# follow instruction there as well. The final output is the 86-DOS floppy
# image file 86dos011_bydos.img.
#
# This build doesn't seem to work with a 720 kB floppy, even if `del ...`
# commands are added to the middle of compdos.bat to delete unusued sorce
# files etc. to avoid the disk from getting full. The final output becomes
# different from 86dos011.img.
#
set -ex
test "$0" = "${0%/*}" || cd "${0%/*}"

export PATH="../tools:$PATH"  # mtools.

# Extract the syetem files from the IBM PC DOS boot floppy.
mtools -c mcopy -i pcdos320.img -n -m ::IBMBIO.COM ./
mtools -c mcopy -i pcdos320.img -n -m ::IBMDOS.COM ./
mtools -c mcopy -i pcdos320.img -n -m ::COMMAND.COM ./

# * PC DOS 3.00 and 3.10: 1.2 MB floppy should work, but it doesn't, even
#   `format b:` can't format it.
# * PC DOS 3.20 (1986-04-02): works
# * PC DOS 3.30 (1987-04-02): works
dd if=/dev/zero of=mydos.img bs=10240 count=120
mtools -c mformat -i mydos.img -f 1200 ::

# Copy boot code from PC DOS .img to mydos.img.
dd if=pcdos320.img of=mydos.img bs=3 count=1 conv=notrunc,sync
dd if=pcdos320.img of=mydos.img bs=1 skip=44 seek=44 count=468 conv=notrunc,sync
# The disk must not have a label (mformat didn't add one, good), and the
# 1st file must be IBMBIO.COM, the 2nd file must be IBMDOS.COM (good).
mtools -c mcopy -i mydos.img -n -m IBMBIO.COM ::
mtools -c mcopy -i mydos.img -n -m IBMDOS.COM ::
mtools -c mcopy -i mydos.img -n -m COMMAND.COM ::

# Add an empty autoexec.bat to prevent DOS from asking for the date and time.
# The `@' doesn't work yet.
(echo 'ver'; echo 'rem run: compdos') >autoexec.bat
mtools -c mcopy -i mydos.img -n -m autoexec.bat ::AUTOEXEC.BAT
rm -f autoexec.bat

# Running it makes qemu-system-i386 exit.
mtools -c mcopy -i mydos.img -n -m ../dostools/atxoff.com ::ATXOFF.COM
mtools -c mcopy -i mydos.img -n -m ../dostools/atxoff.com ::O.COM

mtools -c mcopy -i mydos.img -n -m ../dostools/nasm.exe.upx ::NASM.EXE
mtools -c mcopy -i mydos.img -n -m compdos.bat ::COMPDOS.BAT
mtools -c mcopy -i mydos.img -n -m 86dos011.nasm ::86DOS011.NAS
mtools -c mcopy -i mydos.img -n -m ../fullimg.nasm ::FULLIMG.NAS
mtools -c mcopy -i mydos.img -n -m ../asm244.nasm ::ASM244.NAS
mtools -c mcopy -i mydos.img -n -m ../hex102.nasm ::HEX102.NAS
mtools -c mcopy -i mydos.img -n -m chess.doc.orig ::CHESS.DOS
mtools -c mcopy -i mydos.img -n -m 86dos.asm ::
mtools -c mcopy -i mydos.img -n -m asm.asm ::
mtools -c mcopy -i mydos.img -n -m boot.asm ::
mtools -c mcopy -i mydos.img -n -m chess.asm ::
mtools -c mcopy -i mydos.img -n -m command.asm ::
mtools -c mcopy -i mydos.img -n -m dosio.asm ::
mtools -c mcopy -i mydos.img -n -m edlin.asm ::
mtools -c mcopy -i mydos.img -n -m hex2bin.asm ::
mtools -c mcopy -i mydos.img -n -m rdcpm.asm ::
mtools -c mcopy -i mydos.img -n -m sys.asm ::
mtools -c mcopy -i mydos.img -n -m trans.asm ::

: "At the A> prompt, compdos; then run o to exit QEMU."
qemu-system-i386 -drive file=mydos.img,format=raw,if=floppy -machine pc-1.0 -m 1 -boot a -net none

mtools -c mcopy -i mydos.img -n -m ::86DOS011.IMG 86dos011_bydos.img
if test -f 86dos011.img; then
  cmp 86dos011.img 86dos011_bydos.img
fi

: "$0" OK.
