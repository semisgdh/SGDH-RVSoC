set -x
set -e
make
cp ../devicetree_104mhz/devicetree.dtb .
cp ../riscv-pk/build/bbl .
riscv32-buildroot-linux-gnu-objcopy -S -O binary bbl bbl.bin
make run

