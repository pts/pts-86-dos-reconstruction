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
for f in cpmtab.asm mon.asm; do
  ./asm244i "$f"
  # No official .com.orig file to compare to.
done
for f in init.asm hex2bin.asm trans.asm; do
  ./asm244i "$f"
  cmp "${f%.*}.com.orig" "${f%.*}.com"
done
nasm -w+orphan-labels -f bin -O0 -o 86dos114.img 86dos114.nasm
if test -f 86dos11t.img; then
  cmp 86dos11t.img 86dos114.img 
fi
nasm -w+orphan-labels -f bin -O0 -Djunk -o 86dos114_nojunk.img 86dos114.nasm
nasm -w+orphan-labels -f bin -O0 -Djunk -DNO_SKIP -o 86dos114_nojunkskip.img 86dos114.nasm

: "$0" OK.
