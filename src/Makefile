# Modified by Laurentiu-Cristian Duca, 2021-12-20
# - allow simulation in icarus on SIM_MODE, 
#   but ICARUS must be defined in defines.vh
# - tried SIM_MAIN in icarus but it is not allowd to simulate Xilinx secureip
#
####################################################################################################
##### RVSoC (Mini Kuroda#RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   #####
##### Make File v0.01                                                                          #####
####################################################################################################
# General
TOPSOURCE = top.v
TOPSOURCE-SIM-MAIN = main.v dram.v
OTHERSOURCE = rvcorem.v memory.v mmu.v console.v disk.v microc.v loader.v debug.v read_file.v

# VCS
VCS       = vcs
VCSFLAGS  = -full64 -LDFLAGS -no-pie +define+SIM_MODE

VCSFLAGS2=${VCSFLAGS}
ifdef PROG
	VCSFLAGS2=${VCSFLAGS} +define+HEXFILE=\"${PROG}\"+
endif

# Verilator
VERILATOR  = verilator
#VERIFLAGS  = -DSIM_MODE #-DVERILATOR
#VERIFLAGS = -DSIM_MAIN // must be defined in defines.vh
VERIFLAGS += --public --top-module m_topsim --clk CLK
VERIFLAGS += --x-assign 0 --x-initial 0
VERIFLAGS += --no-threads -O2
#VERIFLAGS += --threads 3 -DVL_THREADED -O2
VERIFLAGS += -Wno-WIDTH -Wno-CASEINCOMPLETE -Wno-COMBDLY -Wno-LATCH
VERIFLAGS += --exe sim.cpp --cc

VERIFLAGS2=${VERIFLAGS}
ifdef PROG
	VERIFLAGS2=-DHEXFILE=\"${PROG}\" ${VERIFLAGS}
endif

.PHONY: all clean run vcs logclean diff gzip zdiff

all: vcs

clean:
	rm -f simple.vvp *.vcd *.out result.txt simv ucli.key vcs-result.txt log.txt diff.txt final_mem.txt log.txt.gz trace.txt simple.vvp
	rm -rf simv.daidir csrc
	rm -rf obj_dir

logclean:
	rm -f log_*.txt diff_*.txt

vcs:
	${VCS} ${VCSFLAGS2} ${TOPSOURCE} ${OTHERSOURCE}

veri:
	printf "\n\nfor make veri, the variable SIM_MODE must be enabled in define.vh\n\n\n"
	${VERILATOR} ${VERIFLAGS2} ${TOPSOURCE} ${OTHERSOURCE}
	make -j -C obj_dir -f Vm_topsim.mk Vm_topsim
	cp obj_dir/Vm_topsim simv

# download XilinxUnisimLibrary from github
VERIFLAGS_DIR = ../nexys4.srcs/sources_1/ip
VERIFLAGS_DIR_UNISIMS = ../XilinxUnisimLibrary/verilog/src
VERIFLAGS_SM = -y ${VERIFLAGS_DIR}/clk_wiz_0 -y ${VERIFLAGS_DIR}/clk_wiz_1 ${VERIFLAGS_DIR}/mig_7series_0/mig_7series_0_sim_netlist.v -y ${VERIFLAGS_DIR_UNISIMS}/unisims ${VERIFLAGS_DIR_UNISIMS}/glbl.v 
#${XILINX_VIVADO}/data/secureip/iserdese2/iserdese2_001.vp ${XILINX_VIVADO}/data/secureip/iserdese2/iserdese2_002.vp
icarus-sim-main:
	iverilog -o simple.vvp ${TOPSOURCE-SIM-MAIN} ${OTHERSOURCE} ${VERIFLAGS_SM} 

icarus:
	iverilog -o simple.vvp ${TOPSOURCE} ${OTHERSOURCE} -DICARUS
run-i:
	vvp simple.vvp
run:
	./simv

# run2: simv
# 	./simv
# #	simrv -m /home/pub/riscv/hexdata/rv32ima/bbl.bin -d /home/pub/riscv/hexdata/rv32ima/root.bin -u /home/pub/riscv/hexdata/rv32ima/ucprog.bin -c /home/pub/riscv/hexdata/rv32ima/devicetree.dtb -t 00M 10M -e 11M
# #	diff trace.txt log.txt > diff.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_00M_10M.txt log_00M_10M.txt > diff_00M_10M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_10M_20M.txt log_10M_20M.txt > diff_10M_20M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_20M_30M.txt log_20M_30M.txt > diff_20M_30M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_30M_40M.txt log_30M_40M.txt > diff_30M_40M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_40M_50M.txt log_40M_50M.txt > diff_40M_50M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_50M_60M.txt log_50M_60M.txt > diff_50M_60M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_60M_70M.txt log_60M_70M.txt > diff_60M_70M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_70M_80M.txt log_70M_80M.txt > diff_70M_80M.txt
# 	diff /home/miyazaki/riscv/trace/rv32imac/trace_80M_90M.txt log_80M_90M.txt > diff_80M_90M.txt

# run3:
# 	./simv
# 	diff /home/miyazaki/GitHub/MikuRV/MikuRV/app/test/trace.txt log.txt > diff.txt

# diff:
# 	diff log.txt /home/pub/riscv/data_vefify/trace0_126k.txt > diff.txt

# gzip:
# 	gzip log.txt

# zdiff:
# 	zdiff log.txt.gz /home/pub/riscv/data_vefify/trace60m_82m.txt.gz > diff.txt
