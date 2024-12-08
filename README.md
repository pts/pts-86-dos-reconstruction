# pts-86-dos-reconstruction: building bootable 86-DOS floppy disk images on modern systems

pts-86-dos-reconstruction is a retrocomputing software reconstruction
project for building 86-DOS system floppy disk images on modern systems from
sources, reversed sources and binaries. The final result of each build is
floppy disk image (.img) file identical to one of the images found on
Internet Archive.

## DOS history recap

86-DOS was written by Tim Paterson in 1980 and 1981 (and early 1982), in
assembly language, for computers with a 8086 CPU and floppy disk drives, but
not PC-compatibles, because the IBM PC hasn't been released at that time.
Eventually, in late 1981, Microsoft purchased non-excusive rights to 86-DOS,
and sold it under MS-DOS (starting in 1982-04). IBM also developed and sold
IBM PC DOS (targeting their new computer, the IBM PC). MS-DOS and PC DOS
shared most of their code base, only the device drivers were different.

Tim Paterson also wrote assemblers targeting the 8086: first a
cross-assembler which ran on CP/M and the Z80 CPU, and then a self-compiling
assembler which ran on SCP (Seattle Computer Products) computers with a 8086
CPU, then he ported the assembler so that the same program (*asm.com* and
*hex2bin.com*) ran on 86-DOS and early versions of MS-DOS and IBM PC DOS as
well. These assemblers (collectively named SCP assemblers, named after the
company) have the same source syntax, and generate bitwise identical binary
code for most sources. Any of them is able to compile any version of 86-DOS
from its source code.

However, the syntax is sufficiently different from other assemblers (such as
MASM 1.00, which has been released by Microsoft in 1981, or TASM), so it
needs significant manual conversion effort to convert it first. (See [more
details](https://stackoverflow.com/questions/63596347/what-are-di-ei-and-up-instructions-in-original-ms-dos-source-code)
about the syntax.) Microsoft and IBM did the conversion internally, and by
the time they released their first DOS (MS-DOS 1.25 and IBM PC DOS 1.1), all
programs were compiled by MASM. The SCP assemblers haven't been widely used
ever since.

## 86-DOS releases since 2020

Since 2020 few bootable floppy disk images of 86-DOS have been uploaded to
the Internet Archive. However, these are not bootable on IBM PC compatibles
(or emulators of those such as QEMU, PCem and 86Box), but on earlier
computers with the 8086 CPU, such as computers sold by SCP in 1979 and the
early 1980s. Emulators for some of these computers are available, see for
example in the video [Showing how to use the earliest known copy of
86-DOS](https://www.youtube.com/watch?v=Zd7T5euID1E).

Also, in 2018, Microsoft has
[released](https://github.com/microsoft/MS-DOS/tree/main/v1.25/source) some
early DOS source files and binaries under the MIT License, including some
source files which can be useful for compiling 86-DOS programs. It included
the full source code of latest known version of the SCP assembler (2.44,
1983-05-09) by Tim Paterson, running on any of 86-DOS, MS-DOS, IBM PC DOS
and DOS emulators (including [DOSBox](https://www.dosbox.com/),
[emu2](https://github.com/dmsc/emu2) and
[kvikdos](https://github.com/pts/kvikdos)). In addition to the assembler
release, there are the sources of *command.com*, *io.sys* and *msdos.sys*,
however most of these are already written in MASM, and they contain (new)
MS-DOS code rather than (old) 86-DOS code.

86-DOS includes the assembly source code of a few simple programs, such as
the device drivers. However, apart from the SCP assembler released by
Microsoft, most of the 86-DOS source code hasn't been released, it hasn't
even surfaced. There have been some desire in the community to reverse
engineer the binaries, and produce a workable source code for SCP assembler,
to reproduce the same binaries (bitwise identical). The most famous
community efforts and successes are:

* [TheBrokenPipe/86-DOS-0.11](https://github.com/TheBrokenPipe/86-DOS-0.11):
  Full source reversing of 86-DOS 0.11 completed, assembly source files
  released (SCP assembler syntax). This is the same user as PorkyPiggy and
  Piggy63, see also this
  [forum thread](https://forum.vcfed.org/index.php?threads/earliest-known-copies-of-86-dos.1246146/).
  It also contains version 2.00 of the SCP assembler reversed. It
  includes a fascinating
  [howto](https://github.com/TheBrokenPipe/86-DOS-0.11/blob/main/Building.md)
  for building 86-DOS 0.11 on then-contemporary (1980) hardware: actually 2
  kinds of computers: one with Z80 CPU and one with 8086 CPU.

* By the same author,
  [TheBrokenPipe/86-DOS_PCAdaptation](https://github.com/TheBrokenPipe/86-DOS_PCAdaptation)
  contains the assembly source code (just the diffs) of a newly developed
  port of 86-DOS to the IBM PC. The same
  [forum thread](https://forum.vcfed.org/index.php?threads/earliest-known-copies-of-86-dos.1246146/)
  also contains binary releases (floppy disk images).
  (Historically, 86-DOS was not ported, the IBM PC received IBM PC DOS 1.1
  and later versions, including MS-DOS >=4.0.)

* [LucasBrooks/DOS-Disassembly](https://github.com/LucasBrooks/DOS-Disassembly/tree/main/86-DOS/1.14)
  contains the full reversing of the 86-DOS 1.14 kernel (but not any other
  tools).

* This repository,
  [pts/pts-86-dos-reconstruction](https://github.com/pts/pts-86-dos-reconstruction)
  contains the reversing of two small development tools part of 86-DOS 1.14:
  [hex2bin.asm](1.14-scp-oem-tarbell/hex2bin.asm) and
  [trans.asm](1.14-scp-oem-tarbell/trans.asm).

* Michal Necasek has succeeded in building some parts (including the kernel
  and *command.com*) of PC DOS 1.1 from sources, and he shared the results
  and a [nice
  writeup](https://www.os2museum.com/wp/pc-dos-1-1-from-scratch/). However,
  this is not directly relevant for 86-DOS, because he used the MASM 1.00
  assembler to make the output bitwise identical to the IBM PC DOS 1.1
  binaries; and also IBM PC DOS has changed quite a lot since it has been
  forked from MS-DOS and 86-DOS.

## What does pts-86-dos-reconstruction add?

The goal of pts-86-dos-reconstruction is to provide tools to automatically
build 86-DOS floppy disk images (bitwise identical to the .img files
released on Internet Archive), on modern hardware, i.e. anything since 1985,
including commodity PC hardware and operating systems in 2024, without
emulation.

The following goals have been achieved:

* 86-DOS 0.11 [can now be built](0.11-nojunk/compile.sh) from source on
  Linux i386. (It would be easy to extend this end-to-end to FreeBSD i386
  and Win32.) The build tools are provided, most of them are built from
  source. The NASM assembler is used to compile these build tools for Linux
  i386 host. For the compilation to work, the cross assembler
  [asm244l.nasm](asm244l.nasm) has been developed and is provided: it is
  written in NASM assembly language, it runs on Linux i386 (and FreeBSD
  i386), it targets the 8086, and it accepts the SCP assembler syntax. The
  NASM assembler with the source file
  [86dos011.nasm](0.11-nojunk/86dos011.nasm) is also used to build the
  bootable floppy disk image files (with the 86-DOS custom FAT12-shortdir
  filesystem) from the individual binaries just compiled.

  The result of the build is bitwise identical to the original floppy disk
  image *86-DOS Version 0.1-C - Serial #11 (ORIGINAL DISK).img* available
  [on the Internet
  Archive](https://archive.org/details/86-dos-version-0.1-c-serial-11-original-disk).
  The build also faithfully reproduces the following junk bytes:

  * junk bytes in the last cluster of some files, after the last data byte:
    This was generated by the FAT12 filesystem driver in 86-DOS copying
    bytes from unzeroed memory when writing the last cluster of the file to
    disk. These junk strings are shorter than 128 bytes, because that's the
    buffer size of the filesystem driver.
  * junk bytes within the .com program files, generated by *hex2bin.com*,
    for each *DS* assembly pseudo-instruction: the *DS* instruction tells
    the assebler (and *hex2bin*) to skip ahead a few bytes without modifying
    the output file; eventually *hex2bin* writes its buffer to a *.com*
    program file on this, but the bytes skipped over by the *DS* instruction are
    left in whaver state the previous prgram left them, thus they are junk.
    There are some recognizable source code and program fragments, but they
    don't belong to that *.com* program.
  * See this [analysis of uninitialized
    data](https://github.com/TheBrokenPipe/86-DOS-0.11/blob/main/Building.md#analysis-of-uninitialized-data).
    for more details.

  A floppy disk image with the junk bytes replaced by NUL or some
  filesystem-specific filler byte is also built. It is functionally
  identical to the original image.

* Similarly, 86-DOS 1.14 [can now be built](1.14-scp-oem-tarbell/) from
  source code on Linux i386. However, most files don't have a source yet,
  only the kernel *86dos.sys*, the two small development tools *hex2bin.com*
  and *trans.com*, and some smaller programs such as device drivers have it.
  For files without source, the precompiled (officially released) binaries
  are copied to the floppy disk image.

  The result of the build is bitwise identical to the original floppy disk
  image *86dos11t.img* available [on
  the Internet Archive](https://archive.org/details/86-dos-1.14).
  The build also faithfully reproduces the following junk bytes:

  * junk bytes in the last cluster of some files, after the last data byte:
    Same as in 86-DOS 0.14, also each string is shorter than 128 bytes.
  * no junk bytes within the .com program files emitted by the *DS*
    instruction: A newer version of *hex2bin.com* has been used to compile
    the programs, and that one clears its buffer with NUL bytes upon
    startup, preventing any junk from being generated.
  * Some unallocated FAT12 clusters (sector-sized disk blocks) contain junk.
    Most probably they had contained file data, but those files have been
    deleted before the release.
  * junk in the FAT12 directory entries describing a deleted file:
    All 32 bytes are intact, except that the first character in the filename
    has been replaced by 0xe5 indicating deletion.
  * void pointers in the FAT12 table corresponding to the deleted clusters:
    This makes another, single file noncontiguous: a run of 0 pointer values
    are inserted to the middle of the FAT12 chain of the other filem, making
    it fragmented.

* 86-DOS 0.11 [can now be built](0.11-nojunk/compile_qemu_pcdos320.sh) from
  source on IBM PC DOS 3.20 (released on 1986-04-02) or later, running in
  QEMU. The build tools are provided, most of them are built from source.
  The NASM assembler is used to compile these build tools for IBM PC DOS
  host. For the compilation to work, a NASM port of the SCP assembler,
  [asm244.nasm](asm244.nasm) has been developed and is provided: it contains
  no changes to the SCP assembler 2.44 written by Tim Paterson, but it has
  been converted to NASM syntax, and the binary is bitwise identical to the
  result of the SCP assembler compiling its original source code. Thus,
  since it is identical, this assembler runs on 86-DOS, MS-DOS and IBM PC
  DOS, it targets the 8086, and it accepts the SCP assembler syntax. The
  NASM assembler with the source file
  [86dos011.nasm](0.11-nojunk/86dos011.nasm) is also used to build the
  bootable floppy disk image files (with the 86-DOS custom FAT12-shortdir
  filesystem) from the individual binaries just compiled. Special tricks
  were used to stay under the 640 KiB memory limit (actually, much less,
  because DOS itself also uses >100 KiB), such as genarating the final
  filler bytes outside NASM, in a much more memory-efficient tool,
  [fullimg.nasm](fullimg.nasm).

* The build process is automated as much as possible. Most builds can be
  done by running a single Linux shell script and waiting for it to finish
  (it takes less than 1 second on modern systems). Most tools are provided
  in the Git repository for reproducible results. They are statically linked
  (thus libc-independent and distribution-independent) Linux i386 executable
  programs.

* Linux shell scripts (with some use of NASM) are provided to extract the
  files from the original floppy disk images released on Internet Archive:
  both for 86-DOS [0.11](0.11-nojunk/extract.sh) and
  [1.14](1.14-scp-oem-tarbell/extract.sh). These are especially useful,
  because 86-DOS uses ancient variants of the FAT12 filesystem not readily
  supported by modern filesystem and disk imaging tools.

It is not a goal of this work to build on then-contemporary (1980) hardware,
or to write the floppy disk images to actual, 8" floppy disks. This is left
as an excercise to the reader.
