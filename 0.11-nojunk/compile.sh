#! /bin/sh --
set -ex
test "$0" = "${0%/*}" || cd "${0%/*}"

export PATH="../tools:$PATH"

nasm -w+orphan-labels -f bin -O0 -o asm244i ../asm244l.nasm
chmod +x asm244i
rm -f ./*.bin ./*.com ./*.sys
./asm244i 86dos.asm
mv 86dos.bin 86dos.sys
cmp 86dos.sys 86dos.sys.orig
./asm244i boot.asm
mv boot.bin boot.com
cmp boot.com.orig boot.com
./asm244i dosio.asm
mv dosio.bin dosio.com
cmp dosio.com.orig dosio.com
for f in asm.asm chess.asm command.asm edlin.asm hex2bin.asm rdcpm.asm sys.asm trans.asm; do
  ./asm244i "$f"
  cmp "${f%.*}.com.orig" "${f%.*}.com"
done

: "$0" OK.
