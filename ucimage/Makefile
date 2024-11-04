###############################################################################
##### SimRV/RISC-V since 2018-07-05                  ArchLab. TokyoTech   #####
###############################################################################

#RISCV_PREFIX = /opt/riscv/bin/riscv32-unknown-elf-
RISCV_PREFIX = /usr/local/share/gcc-riscv32-unknown-elf/bin/riscv32-unknown-elf-
CCFLAGS      = -O2 -march=rv32i -mabi=ilp32 
TARGET       = main
OBJS         = main.o simrv.o startup.o

.SUFFIXES: .o .c .S
.PHONY: all clean dump

###############################################################################

all:
	make bin
	make hex4
	cp main.hex ucimage.hex

bin: $(TARGET).bin hex-to-tcl

$(TARGET).elf: main.lds $(OBJS)
	$(RISCV_PREFIX)ld -T $< -o $@ $(OBJS)

$(TARGET).bin: $(TARGET).elf
	$(RISCV_PREFIX)objcopy -O binary $< $@

.c.o:
	$(RISCV_PREFIX)gcc $(CCFLAGS) -o $@ -c $<

.S.o:
	$(RISCV_PREFIX)gcc $(CCFLAGS) -o $@ -c $<

hex-to-tcl: hex-to-tcl.c
	gcc hex-to-tcl.c -o hex-to-tcl.out
###############################################################################

clean:
	rm -f *.o *.elf *.bin *.dump simrv.o *.hex *.out *.tcl

dump:
	$(RISCV_PREFIX)objdump -D $(TARGET).elf > $(TARGET).dump

hex:
	hexdump -v -e '1/1 "%02x" "\n"' $(TARGET).bin > $(TARGET).hex

hex2:
	hexdump -v -e '1/2 "%04x" "\n"' $(TARGET).bin > $(TARGET).hex

hex4:
	hexdump -v -e '1/4 "%08x" "\n"' $(TARGET).bin > $(TARGET).hex
