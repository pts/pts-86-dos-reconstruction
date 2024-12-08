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
[emu2](https://github.com/dmsc/emu2), but not
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

  To reproduce it, run [0.11/compile.sh](0.11/compile.sh) on a Linux x86
  (i386 or amd64) system, in a terminal window.

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

  To reproduce it, run [1.14/compile.sh](1.14/compile.sh) on a Linux x86
  (i386 or amd64) system, in a terminal window.

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

## Interesting observations about the 86-DOS code

All the programs in 86-DOS have been written in assembly language. This has
been the norm in the early 1980s for decades. Notable exceptions were the
following programming languages between 1957 and 1982: FORTRAN (1957), COBOL
(1959), LISP (1960), BASIC (1964), PL/I (1964), Pascal (1970) and C (1972).
Out of these languages, PL/I, Pascal and C have been low-level enough (i.e.
letting the programmer specify exactly what should happen and how, and how
much memory should be used) for systems programming. However, compilers for
these languages needed powerful computers (such as minicomputers or even
larger ones) to run, a microcomputer (or a personal computer, PC) in the
early 1980s just wasn't good enough, so operating systems not written in
assembly language couldn't be self-hosting (i.e. source code of the OS
compilable on the machine running the OS).

As a comparison, initially
[Unix](https://en.wikipedia.org/wiki/Research_Unix) (1969), including the
kernel and userland, was written in assembly language for the computers and
CPUs it was ported to (PDP-7, PDP-11, VAX, then more). The C programming
language has been invented in the same research lab where Unix was
developed, with the purpose of replacing assembly with a higher-level
systems language for increased developer productivity. Please note that some
low-level routines including the early bootloader still remained in
assembly. C has fullfilled this goal and has been the most popular systems
language ever since (with the Linux kernel written exclusively in C, with a
few low-level routines in assembly, between its start in 1991 until 2022,
then Rust code was also allowed). While more than half of Unix V6 (6th
Edition release, 1975) was still written in assembly, V7 (1979) had most
tools rewritten in C. However the computers running Unix and the C compiler
before 1982 were much more powerful than the computers 86-DOS targeted.

Byte size of 86-DOS program binaries is tiny compared to its successors.
Some sizes are:

| program      | 86-DOS 0.11 | 86-DOS 1.14 | MS-DOS 1.25 | MS-DOS 2.00 | MS-DOS 3.00 |
| :----------- | ----------: | ----------: | ----------: | ----------: | ----------: |
| month        | 1980-08     | 1981-12-11  | 1982-04     | 1983-10     | 1985-04     |
| boot+kernel  |        4078 |        6972 |        8480 |       29312 |       37552 |
| command.com  |        1196 |        3017 |        4959 |       15480 |       22747 |
| edlin.com    |        1275 |        2304 |        2432 |        4389 |        7183 |
| sys.com      |         153 |         468 |         645 |         850 |        3791 |
| chkdsk.com   |         --- |        1205 |        1770 |        6330 |        9419 |

Just by looking at the code size increase, we can see that Microsoft has
worked a lot on MS-DOS software development, even though they haven't
written the original one (but Tim Paterson wrote it, and Microsoft licensed
it with source code from SCP).

By looking at the disassembly of these programs, it looks like all of them
(including MS-DOS 3.00) have been written in assembly. (Typical code
generated by the C compiler has many instances of a *push bp* instruction
followed by *mov bp, sp*, and *command.com* doesn't have thos.) The disassembly
also confirms that 86-DOS has been compiled using the SCP assembler, and
MS-DOS and PC DOS have been compiled with MASH (as evidenced by many
instances of a short jump followed by a *nop* instruction).

The source code of 86-DOS, MS-DOS and PC DOS hasn't been released in the
1980s and 1990s, with the exception of the bootloader and the device driver
part of the kernel (i.e. the source of *dosio.com*, *io.sys* and
*ibmbio.com*), whose source has been given to OEMs, so that they can port
MS-DOS to their computers. IBM did the porting in-house for the IBM PCs,
releasing PC DOS.

The SCP assembler is much faster than NASM (even with optimizations disabled
in the latter). This can be felt in an emulator, when *asm.asm* with the SCP
assembler (1979--1983) versus compiling [asm244.nasm](asm244.nasm) with NASM
0.98.39 (2005-01-15). NASM is written in C, and uses many pointer
indirections and dynamic allocations. The SCP assembler has much less of
those.

Very few of the 86-DOS tools (such as the SCP assembler 2.40) also run on
any of 86-DOS, MS-DOS, IBM PC DOS and DOS emulators (including
[DOSBox](https://www.dosbox.com/), [emu2](https://github.com/dmsc/emu2), but
not [kvikdos](https://github.com/pts/kvikdos)).

We have a plausible explanation on how Tim Paterson may have written the
very first version of 86-DOS, without access to any operating systems or
user programs running on the brand new Intel 8086 CPU. He probably did it
like this:

1. For development, he was using a [Cromemco
   Z-2D](https://wikipedia.org/wiki/Cromemco_Z-2#Cromemco_Z-2D) computer with
   the Z80 CPU, running CP/M. (See more in [this
   writeup](https://github.com/TheBrokenPipe/86-DOS-0.11/blob/main/Building.md)
   about building 86-DOS 0.11 on that machine and other then-contemporary
   harware.) He had access to an assembler for writing programs which ran on
   this computer. However, he needed an assembler which targets the 8086 CPU.
2. He wrote a cross assembler for the Z80, targeting the 8086. A [scanned
   copy](https://archive.org/details/bitsavers_seattleComsemblerPreliminary_611077)
   of the manual of this program is available on Internet Archive.
3. He wrote 86-DOS in the syntax of that assembler, and compiled it on the
   Cromemco Z-2D. Thus he had the 86-DOS binaries.
4. He wrote an assembly source code translator from Z80 to 8086. This
   translaton was distributed as part of 86-DOS, as *trans.com*, also
   open-sourced by Microsoft in 2018 as
   [trans.asm](https://github.com/microsoft/MS-DOS/blob/main/v1.25/source/TRANS.ASM))
   It is possible to automate most of the translation, because the 8086 has
   more registers than the Z80, and instructions work very simiarly. (This
   is not a surprise, both of them are based on the Intel 8080 CPU.)
5. With the translator working on the Cromemco Z-2D, he translated the
   source code of all his Z80 programs so far (mostly the cross assembler
   and the translator) to 8086 instructions.
6. He compiled the translated sources to 8086 binary programs using the
   cross assembler. He also changed a few system-specific parts manually.
   Thus he had a self-compiling (non-cross) assembler for the 8086. He
   included it as *asm.com* in the 86-DOS releases.

This process was repeated on actual hardware, and old Comemco Z-2D, and also
in an emulator after 2020 by TheBrokenPipe (part of the 86-DOS hacking
community), see the
[writeup](https://github.com/TheBrokenPipe/86-DOS-0.11/blob/main/Building.md#the-first-egg).

The process also explains why the 86-DOS syscalls are so similar to the CP/M
syscalls: syscall numbers are the same, and there is a correspondance of
registers. The reason is that by providing the same syscall API, Tim
Paterson's machine-translated programs (from Z80 to 8086 assembly) work
without needing too many system-specific changes.

As an example for the API-specifc similarity, the [C_WRITESTR
function](https://www.seasip.info/Cpm/bdos.html) on CP/M Z80 can be invoked
by loading 9 to the C register, loading the address of a `$`-terminated
string to DE, and calling to address 5 (the system call entry point). And on
86-DOS 8086 (API designed by Tim Paterson) it can be invoked by loading 9 to
the AH register, loading the address of a `$`-terminated string to DX, and
calling to address 5.

The DOS syscall API has been extended a lot since 1980 with function not
available in CP/M, and the ABI of those functions are very different. Also
*int 21h* has been introduced (already in 86-DOS) as an equivalent
alternative of *call 5*, and most DOS programs use *int 21h* rather than the
historically useful *call 5* as the entry point.

Decades after 1980, the source code of 86-DOS and CP/M become available
online, and by looking it both it looks very unlikely that Tim Paterson
copied source code from CP/M to 86-DOS. Also he probably didn't have access
to the source of CP/M when he was writing 86-DOS. He only copied the syscall
API, probably because that was convenient for him when porting the first
few of his programs from CP/M Z80 to 86-DOS 8086.

Software development tools were much less powerful and convenient between
1979 and 1983 than what we are used today, and even what was available in
1990. The cycle is still the same over the decades: write-compile-run-debug.
But in the early 1980s the use of full-screen text editors in which it's
possible to move the cursor to any character, and change or insert text
visually at its own place, was not widespread. (*vi*, one of the first such
interactive editors has been available since 1976, but its use was not
widespread.) Editors like the Unix *ed*, the Unix *ex* and the CP/M *ed*
were line-based: the user entered a line number, and then he had to retype
the entire line to change it. Tim Paterson wrote the
[edlin.com](https://en.wikipedia.org/wiki/Edlin) editor in 1980, with
similar features for line-based editing only.

Debugging was also different, because symbolic debugging didn't exist. If
the execution of the program was stopeed in a debugger for inspecting
program state, the developer was only seeing memory addresses as numeric
constants, not variable or function names. To do that mapping (from address
to function name), before running a program, the programmer asked the
compiler for a listing (the SCP assembler produces the listing by default as
a .prn file), printed out the listing, and while debugging they were looking
at the printout, which (for assembly-language programs) displayed
corresponding memory address, source file line number, label (variable or
function name), source file line contents, and encoding instruction bytes in
the same line, so it was easy to do the mapping by finding the source line
in the listing printout, and then looking at it.

Development was also much slower: there were minute-long waiting times for
the compiler and floppy disk I/O. After that, sometimes the floppy disk had
to be ejected and moved to another computer for trying the newly compiled
program.
