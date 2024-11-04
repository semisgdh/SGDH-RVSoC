/**************************************************************************************************/
/**** RVSoC  (Mini Kuroda/RISC-V)                      since 2018-08-07   ArchLab. TokyoTech   ****/
/**** config file v0.13                                                                        ****/
/**************************************************************************************************/
`ifndef __CONFIG_VH__
`define __CONFIG_VH__
/**************************************************************************************************/
`timescale 1ps/1ps

//`define ARTYA7
/**************************************************************************************************/
//`define VERILATOR
`define SIM_MODE
//`define SIM_MAIN // for xsim
`ifdef SIM_MAIN
`ifdef SIM_MODE
error
`endif
`endif

`ifdef SIM_MODE
`define DRAM_SIM
`define CACHE_DEBUG
`endif
//`define RAM_DEBUG

//`define SKIP_CACHE

`define LINUX
`define TIMEOUT 900000001
//`define DEBUG
//`define TRACE
//`define MIDDLE

`define HEX_DIR "./"
`ifdef LINUX
    `ifndef MIDDLE
        `define HEXFILE    "../binary/init_kernel.txt"
        `define IMAGE_FILE "../binary/init_disk.txt"
//        `define HEXFILE    "init_kernel.txt"
//        `define IMAGE_FILE "init_disk.txt"
    `else
        `define HEXFILE    "./init_mem.txt"
        `define REGFILE    "./init_reg.txt"
        `define IMAGE_FILE "./init_dsk.txt"
    `endif
`else
    `define HEXFILE "./test.mem"
`endif

// `define HEX_DIR ""
// `ifdef LINUX
//     `ifndef MIDDLE
//         `define HEXFILE    "/home/miyazaki/riscv/trace/rv32imac/init_mem.txt"
//         `define IMAGE_FILE "/home/miyazaki/riscv/trace/rv32imac/init_dsk.txt"
//     `else
//         `define HEXFILE    "./init_mem.txt"
//         `define REGFILE    "./init_reg.txt"
//         `define IMAGE_FILE "./init_dsk.txt"
//     `endif
// `else
//     `define HEXFILE "/home/miyazaki/GitHub/MikuRV/MikuRV/app/test/test.mem"
// `endif

/**************************************************************************************************/
`ifndef SIM_MODE
    `define REAL_MTIME
`endif

`ifdef REAL_MTIME
    `ifndef ARTYA7
        `define ENABLE_TIMER 64'd1600000000  // 80000000 * 20
    `else
        `define ENABLE_TIMER 64'd2000000000  // 80000000 * 25
    `endif
`else
    `define ENABLE_TIMER 64'd80000000
`endif

/**************************************************************************************************/
`define LATENCY 0
// //`define TIMEOUT 1000000
// //`define HEX_DIR "../app/hex/"
// //`define HEXFILE "template-asm2.hex"
// //`define INST_HEX "inst-template-asm2.hex"

`define CACHE_SIZE (128*1024)

`ifdef SIM_MAIN
// speed up a little bit the simulation
`define SERIAL_WCNT 2
`else
`define SERIAL_WCNT 13 // 13 for 104MHz, 8 for 64MHz, 9 for 72MHz
`endif
`define SKIP_CLK_WIZ_1

//`define STATE
//`define PC_TRACE
//`define MEM_DUMP

//`define VIRTIO_LOG "init_virtio.txt"
//`define CONSOLE_MEM "/home/pub/riscv/data_vefify/cons-test-initmem.txt"
/**************************************************************************************************/
//`define USE_UART
//`define SIM_MODE
/**************************************************************************************************/
//`ifdef LINUX
//    `undef HEX_DIR
//    `undef TIMEOUT
    //`define TIMEOUT 10000000 //500000 //(74000000)
    //`define TIMEOUT 70000000
//    `define TIMEOUT 80000000
    //`define HEX_DIR "/home/share/FPGA/riscv/data_vefify/"
//    `define HEX_DIR ""
    //`define MC_PROG "./microctrl.hex"
//    `ifdef MIDDLE
//        `define HEXFILE    "/home/pub/riscv/hexdata/rv32ima/60M/init_mem.txt"
//        `define REGFILE    "/home/pub/riscv/hexdata/rv32ima/60M/init_reg.txt"
//        `define IMAGE_FILE "/home/pub/riscv/hexdata/rv32ima/60M/init_dsk.txt"
        //`define HEXFILE    "./init_mem.txt"
        //`define REGFILE    "./init_reg.txt"
        //`define IMAGE_FILE "./init_dsk.txt"
//    `else
        //`define HEXFILE    "/home/pub/riscv/data_vefify/bbl_v05.hex"  //"/home/pub/riscv/data_vefify/initmem_nofloat_comp.txt"
        //`define IMAGE_FILE "/home/pub/riscv/data_vefify/root_v07.hex" //"/home/pub/riscv/data_vefify/initdsk_nofloat_comp.txt"
//        `define HEXFILE    "/home/miyazaki/riscv/trace/rv32imac/init_mem.txt"
//        `define IMAGE_FILE "/home/miyazaki/riscv/trace/rv32imac/init_dsk.txt"
//    `endif
// `else
//     `ifndef HEXFILE
//         `ifdef TRACE2
//             `define HEXFILE "rvc.hex"
//         `else 
//             `ifdef CONSOLE_TEST
//                 `define HEXFILE "console.hex"
//             `else
//                 `define HEXFILE "template-c.hex"        /* default hex */
//             `endif
//         `endif
//     `endif
//`endif

/**************************************************************************************************/
/**** Simulation                                                                               ****/
/**************************************************************************************************/
`ifdef LINUX
`define D_START_PC      32'h80000000
`else
`define D_START_PC      0
`endif

/**** VirtIO                                                                                   ****/
/**************************************************************************************************/
`define VIRTIO_BASE_ADDR    32'h40000000
`define VIRTIO_BASE_TADDR    4'h4
`define VIRTIO_SIZE         32'h08000000

`define VRING_DESC_F_NEXT       1
`define VRING_DESC_F_WRITE      2
`define VRING_DESC_F_INDIRECT   4

// Console
`define CONSOLE_QUEUE_NUM_MAX   2
`define VIRTIO_CONSOLE_IRQ      1

// Block Device (DISK)
`define SECTOR_SIZE         512
`define DISK_BUF_SIZE       512*512
`ifdef LINUX
    `define DISK_SIZE           64*1024*1024
`else
    `define DISK_SIZE           32*1024
`endif
`define DISK_QUEUE_NUM_MAX  4
`define VIRTIO_DISK_IRQ     2
`define VIRTIO_BLK_T_IN     0
`define VIRTIO_BLK_T_OUT    1
`define VIRTIO_BLK_S_OK     0
`define VIRTIO_BLK_IOERR    1
`define VIRTIO_BLK_UNSUPP   2

/**** PLIC (Platform-Level Interrupt Controller)                                               ****/
/**************************************************************************************************/
`define PLIC_BASE_ADDR  32'h50000000
`define PLIC_BASE_TADDR  4'h5
`define PLIC_SIZE       32'h400000
`define PLIC_HART_BASE  32'h200000
`define PLIC_HART_SIZE  32'h1000

/**** CLINT (Core Local Interrupter)                                                           ****/
/**************************************************************************************************/
`define CLINT_BASE_ADDR 32'h60000000
`define CLINT_BASE_TADDR 4'h6
`define CLINT_SIZE      32'hc0000

/**** Micro Controller                                                                         ****/
/**************************************************************************************************/
`define MC_MEM_SIZE 8*1024    // 32KB
`define LINE_BUFFER_SIZE (8*100) // for debugging
`define D_INITD_ADDR    (32*1024*1024)

`ifndef SIM_MODE
	`define LAUR_MEM_RB // mem read-back after writing it with BBL
	`define LAUR_MEM_RB_ONLY_CHECK
`endif

`define BBL_SIZE (64*1024*1024)

`ifdef SIM_MAIN
`define BIN_BBL_SIZE   32 // Note!!
`define D_SIZE_DEVT 0
`define BIN_DISK_SIZE 0
`else
`define BIN_BBL_SIZE   (30*1024*1024) //(9*1024*1024 /*+ 4*1024*/) // Note!!
`define D_SIZE_DEVT (4*1024)
`define BIN_DISK_SIZE 0 //(16*1024*1024)
`endif
`define BIN_SIZE      (`BIN_BBL_SIZE + `D_SIZE_DEVT + `BIN_DISK_SIZE) 

/**************************************************************************************************/
/**** System Configuration                                                                     ****/
/**************************************************************************************************/
// RV32 (bit) Register size
`define XLEN 32

// 32bit Instruction Length
`define INST_LEN 32

// Floating Point Lengh (Not Supported)
//`define FLEN 64

// NOP Instruction
`define RV32_NOP 32'h00000013
// ILLEGAL
`define ILLEGAL_INST 32'h0

// MEMORY (Byte)
`define MEM_BASE_ADDR 32'h80000000
`define MEM_BASE_TADDR 4'h8
`ifdef LINUX
`define MEM_SIZE 1024*1024*128 // 128MB (DRAM_SIZE)
`define ARTY_MEM_SIZE 256*1024*1024 // 256MB (DRAM_SIZE)
`define APP_MODE 0
`else
`define MEM_SIZE 1024*32      // 32KB
`define ARTY_MEM_SIZE 64*1024 // 64KB
`define APP_MODE 1
`endif
`define MEMORY_DATA_WIDTH 1 // 1 Byte
`define I_CACHE_SIZE 4096 // 4KB
`define D_CACHE_SIZE 4096 // 4KB
`ifdef SIM_MODE
`define TLB_SIZE 4
`else
`define TLB_SIZE 32
`endif

// TOHOST_ADDR
`define TOHOST_ADDR 32'h40008000

// command for application mode using tohost
`define CMD_PRINT_CHAR 1
`define CMD_POWER_OFF  2

// I-Cache TEST
// Note: This cache support only 4-byte instructions
//`define ICACHE_ENABLE

`endif
/**************************************************************************************************/
/**************************************************************************************************/
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** System defines v0.01                                                                     ****/
/**************************************************************************************************/
`ifndef __SYS_DEFINE_VH__
`define __SYS_DEFINE_VH__
/**************************************************************************************************/
/**** Multi Cycle Stage                                                                        ****/
/**************************************************************************************************/
`define S_INI 0     // Init
`define S_IF  1     // Inst Fetch
`define S_CVT 2     // Convert
`define S_ID  3     // Inst Decode
`define S_OF  4     // Operand Fetch
`define S_EX1 5     // Execution 1
`define S_LD  6     // Load DATA
`define S_EX2 7     // Execution 2
`define S_SD  8     // Store DATA
`define S_WB  9     // Write Back
`define S_COM 10    // Complete Insn
`define S_FIN 11    // Finish

/**************************************************************************************************/
/**** TLB                                                                                      ****/
/**************************************************************************************************/
`define PTE_V_MASK  32'h1
`define PTE_R_MASK  32'h2
`define PTE_W_MASK  32'h4
`define PTE_X_MASK  32'h8
`define PTE_U_MASK  32'h10
`define PTE_A_MASK  32'h40
`define PTE_D_MASK  32'h80

`define ACCESS_READ     0
`define ACCESS_WRITE    1
`define ACCESS_CODE     2

`define LEVELS      2
`define PTE_SIZE    4
`define PAGE_SIZE   (1 << 12)

/**************************************************************************************************/
/**** exception & interrupt                                                                    ****/
/**************************************************************************************************/
`define CAUSE_INTERRUPT 32'h80000000

// EXEPTION CODE
`define CAUSE_MISALIGNED_FETCH      32'h0
`define CAUSE_FAULT_FETCH           32'h1
`define CAUSE_ILLEGAL_INSTRUCTION   32'h2
`define CAUSE_BREAKPOINT            32'h3
`define CAUSE_MISALIGNED_LOAD       32'h4
`define CAUSE_FAULT_LOAD            32'h5
`define CAUSE_MISALIGNED_STORE      32'h6
`define CAUSE_FAULT_STORE           32'h7
`define CAUSE_USER_ECALL            32'h8
`define CAUSE_SUPERVISOR_ECALL      32'h9
`define CAUSE_HYPERVISOR_ECALL      32'ha
`define CAUSE_MACHINE_ECALL         32'hb
`define CAUSE_FETCH_PAGE_FAULT      32'hc
`define CAUSE_LOAD_PAGE_FAULT       32'hd
`define CAUSE_STORE_PAGE_FAULT      32'hf




/**************************************************************************************************/
/**** CSR Addr                                                                                 ****/
/**************************************************************************************************/
// User-Mode
`define CSR_USTATUS     12'h000
`define CSR_FFLAGS      12'h001
`define CSR_FRM         12'h002
`define CSR_FCSR        12'h003
`define CSR_UIE         12'h004
`define CSR_UTVEC       12'h005
`define CSR_USCRATCH    12'h040
`define CSR_UEPC        12'h041
`define CSR_UCAUSE      12'h042
`define CSR_UTVAL       12'h043
`define CSR_UIP         12'h044
`define CSR_CYCLE       12'hc00
`define CSR_TIME        12'hc01
`define CSR_INSTRET     12'hc02

// Superviser-Mode
`define CSR_SSTATUS     12'h100
`define CSR_SEDELEG     12'h102
`define CSR_SIDELEG     12'h103
`define CSR_SIE         12'h104
`define CSR_STVEC       12'h105
`define CSR_SCOUNTEREN  12'h106
`define CSR_SSCRATCH    12'h140
`define CSR_SEPC        12'h141
`define CSR_SCAUSE      12'h142
`define CSR_STVAL       12'h143
`define CSR_SIP         12'h144
`define CSR_SATP        12'h180

// Machine-Mode
`define CSR_MVENDORID   12'hf11
`define CSR_MARCHID     12'hf12
`define CSR_MIMPID      12'hf13
`define CSR_MHARTID     12'hf14
`define CSR_MSTATUS     12'h300
`define CSR_MISA        12'h301
`define CSR_MEDELEG     12'h302
`define CSR_MIDELEG     12'h303
`define CSR_MIE         12'h304
`define CSR_MTVEC       12'h305
`define CSR_MCOUNTEREN  12'h306
`define CSR_MSCRATCH    12'h340
`define CSR_MEPC        12'h341
`define CSR_MCAUSE      12'h342
`define CSR_MTVAL       12'h343
`define CSR_MIP         12'h344
`define CSR_MCYCLE      12'hb00
`define CSR_MINSTRET    12'hb02
`define CSR_MCYCLEH     12'hb80
`define CSR_MINSTRETH   12'hb82
`define CSR_CYCLEH      12'hc80
`define CSR_TIMEH       12'hc81
`define CSR_INSTRETH    12'hc82

/**************************************************************************************************/
/**** CSR Mask                                                                                 ****/
/**************************************************************************************************/
// PRIV MODE
`define PRIV_U 0
`define PRIV_S 1
`define PRIV_H 2
`define PRIV_M 3

// CSR Masks
`define COUNTEREN_MASK  32'h5   // ((1 << 0) | (1 << 2))

`define MSTATUS_UIE     32'h1       // (1 << 0)
`define MSTATUS_SIE     32'h2       // (1 << 1)
`define MSTATUS_HIE     32'h4       // (1 << 2)
`define MSTATUS_MIE     32'h8       // (1 << 3)
`define MSTATUS_UPIE    32'h10      // (1 << 4)
`define MSTATUS_SPIE    32'h20      // (1 << 5)
`define MSTATUS_HPIE    32'h40      // (1 << 6)
`define MSTATUS_MPIE    32'h80      // (1 << 7)
`define MSTATUS_SPP     32'h100     // (1 << 8)
`define MSTATUS_HPP     32'h600     // (3 << 9)
`define MSTATUS_MPP     32'h1800    // (3 << 11)
`define MSTATUS_FS      32'h6000    // (3 << 13)
`define MSTATUS_XS      32'h18000   // (3 << 15)
`define MSTATUS_MPRV    32'h20000   // (1 << 17)
`define MSTATUS_SUM     32'h40000   // (1 << 18)
`define MSTATUS_MXR     32'h80000   // (1 << 19)

`define MSTATUS_SPIE_SHIFT  5
`define MSTATUS_MPIE_SHIFT  7
`define MSTATUS_SPP_SHIFT   8
`define MSTATUS_MPP_SHIFT   11
`define MSTATUS_FS_SHIFT    13

`define MSTATUS_MASK    32'h000e79bb
`define SSTATUS_MASK0   32'h000de133
`define SSTATUS_MASK    `SSTATUS_MASK0

`define MIP_USIP        32'h1   // (1 << 0)
`define MIP_SSIP        32'h2   // (1 << 1)
`define MIP_HSIP        32'h4   // (1 << 2)
`define MIP_MSIP        32'h8   // (1 << 3)
`define MIP_UTIP        32'h10   // (1 << 4)
`define MIP_STIP        32'h20  // (1 << 5)
`define MIP_HTIP        32'h40  // (1 << 6)
`define MIP_MTIP        32'h80  // (1 << 7)
`define MIP_UEIP        32'h100  // (1 << 8)
`define MIP_SEIP        32'h200 // (1 << 9)
`define MIP_HEIP        32'h400 // (1 << 10)
`define MIP_MEIP        32'h800 // (1 << 11)


// Write CSR
`define WCSR_MASK1  32'hffff    // ((1 << (CAUSE_STORE_PAGE_FAULT + 1)) - 1;)
`define WCSR_MASK2  (`MIP_SSIP | `MIP_STIP | `MIP_SEIP)
`define WCSR_MASK3  (`MIP_MSIP | `MIP_MTIP | `MIP_SSIP | `MIP_STIP | `MIP_SEIP)
`define WCSR_MASK4  (`MIP_SSIP | `MIP_STIP)

`define MASK_STATUS (`MSTATUS_MASK & ~`MSTATUS_FS)

/**************************************************************************************************/
/**** VirtIO                                                                                   ****/
/**************************************************************************************************/
// Console
`define CONSOLE_MAGIC_VALUE         32'h74726976
`define CONSOLE_VERSION             2
`define CONSOLE_DEVICE_ID           3
`define CONSOLE_VENDOR_ID           32'hffff
`define CONSOLE_DEVICE_FEATURES     1
`define CONSOLE_CONFIG_GENERATION   0

// Disk
`define DISK_MAGIC_VALUE            32'h74726976
`define DISK_VERSION                2
`define DISK_DEVICE_ID              2
`define DISK_VENDOR_ID              32'hffff
`define DISK_DEVICE_FEATURES        1
`define DISK_CONFIG_GENERATION      0

/**************************************************************************************************/
/**** Micro Controller                                                                         ****/
/**************************************************************************************************/
`define MODE_ADDR 32'h40009000
`define QNUM_ADDR 32'h40009004
`define QSEL_ADDR 32'h40009008
`define CONQ_ADDR 20'h4000a
`define DISQ_ADDR 20'h4000b
`define KEYQ_ADDR 32'h4000c000
`endif
/**************************************************************************************************/

/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** opecode defines v0.01                                                                    ****/
/**************************************************************************************************/
`ifndef __OPCODES_VH__
`define __OPCODES_VH__
/**************************************************************************************************/
/**** OPCODE                                                                                   ****/
/**************************************************************************************************/

`define OPCODE_OP______ 7'h33
`define OPCODE_OP_FP___ 7'h53
`define OPCODE_AMO_____ 7'h2F
`define OPCODE_OP_IMM__ 7'h13
`define OPCODE_LOAD____ 7'h03
`define OPCODE_LOAD_FP_ 7'h07
`define OPCODE_JALR____ 7'h67
`define OPCODE_STORE___ 7'h23
`define OPCODE_STORE_FP 7'h27
`define OPCODE_BRANCH__ 7'h63
`define OPCODE_LUI_____ 7'h37
`define OPCODE_AUIPC___ 7'h17
`define OPCODE_JAL_____ 7'h6F
`define OPCODE_JALR____ 7'h67
`define OPCODE_MADD____ 7'h43
`define OPCODE_MSUB____ 7'h47
`define OPCODE_NMADD___ 7'h4F
`define OPCODE_NMSUB___ 7'h4B
`define OPCODE_MISC_MEM 7'h0F
`define OPCODE_SYSTEM__ 7'h73

//special
`define OPCODE_HALT____ 7'h7F

/**************************************************************************************************/
/**** FUNCT                                                                                    ****/
/**************************************************************************************************/

// OP_I
`define FUNCT3_ADD___ 3'h0
`define FUNCT3_SLL___ 3'h1
`define FUNCT3_SLT___ 3'h2
`define FUNCT3_SLTU__ 3'h3
`define FUNCT3_XOR___ 3'h4
`define FUNCT3_SRL___ 3'h5
`define FUNCT3_OR____ 3'h6
`define FUNCT3_AND___ 3'h7

// OP_M
`define FUNCT3_MUL___ 3'h0
`define FUNCT3_MULH__ 3'h1
`define FUNCT3_MULHSU 3'h2
`define FUNCT3_MULHU_ 3'h3
`define FUNCT3_DIV___ 3'h4
`define FUNCT3_DIVU__ 3'h5
`define FUNCT3_REM___ 3'h6
`define FUNCT3_REMU__ 3'h7

// STORE
`define FUNCT3_SB____ 3'h0
`define FUNCT3_SH____ 3'h1
`define FUNCT3_SW____ 3'h2
`define FUNCT3_SD____ 3'h3
`define FUNCT3_FSW___ 3'h2
`define FUNCT3_FSD___ 3'h3

// LOAD
`define FUNCT3_LB____ 3'h0
`define FUNCT3_LH____ 3'h1
`define FUNCT3_LW____ 3'h2
`define FUNCT3_LD____ 3'h3
`define FUNCT3_LBU___ 3'h4
`define FUNCT3_LHU___ 3'h5
`define FUNCT3_LWU___ 3'h6
`define FUNCT3_FLW___ 3'h2
`define FUNCT3_FLD___ 3'h3

// BRANCH
`define FUNCT3_BEQ___ 3'h0
`define FUNCT3_BNE___ 3'h1
`define FUNCT3_BLT___ 3'h4
`define FUNCT3_BGE___ 3'h5
`define FUNCT3_BLTU__ 3'h6
`define FUNCT3_BGEU__ 3'h7

// MISC_MEM
`define FUNCT3_FENCE_ 3'h0
`define FUNCT3_FENCEI 3'h1

// SYSTEM
`define FUNCT3_PRIV__ 3'h0
`define FUNCT3_CSRRW_ 3'h1
`define FUNCT3_CSRRS_ 3'h2
`define FUNCT3_CSRRC_ 3'h3
`define FUNCT3_CSRRWI 3'h5
`define FUNCT3_CSRRSI 3'h6
`define FUNCT3_CSRRCI 3'h7

`define FUNCT12_ECALL_ 12'h000
`define FUNCT12_EBREAK 12'h001
`define FUNCT12_ERET__ 12'h100
`define FUNCT12_MRET__ 12'h302
`define FUNCT12_SRET__ 12'h102
`define FUNCT12_URET__ 12'h002
`define FUNCT12_WFI___ 12'h105
`define FUNCT7_SFENCE_VMA 5'h09

// AMO
`define FUNCT5_AMO_LR__ 5'h02
`define FUNCT5_AMO_SC__ 5'h03
`define FUNCT5_AMO_SWAP 5'h01
`define FUNCT5_AMO_ADD_ 5'h00
`define FUNCT5_AMO_AND_ 5'h0c
`define FUNCT5_AMO_OR__ 5'h08
`define FUNCT5_AMO_XOR_ 5'h04
`define FUNCT5_AMO_MIN_ 5'h10
`define FUNCT5_AMO_MINU 5'h18
`define FUNCT5_AMO_MAX_ 5'h14
`define FUNCT5_AMO_MAXU 5'h1c

`define AMO_FAILURE_CODE 1
`define AMO_SUCCESS_CODE 0

`endif
/**************************************************************************************************/
/**************************************************************************************************/
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** System defines v0.01                                                                     ****/
/**************************************************************************************************/
`ifndef __SYS_DEFINE_VH__
`define __SYS_DEFINE_VH__
/**************************************************************************************************/
/**** Multi Cycle Stage                                                                        ****/
/**************************************************************************************************/
`define S_INI 0     // Init
`define S_IF  1     // Inst Fetch
`define S_CVT 2     // Convert
`define S_ID  3     // Inst Decode
`define S_OF  4     // Operand Fetch
`define S_EX1 5     // Execution 1
`define S_LD  6     // Load DATA
`define S_EX2 7     // Execution 2
`define S_SD  8     // Store DATA
`define S_WB  9     // Write Back
`define S_COM 10    // Complete Insn
`define S_FIN 11    // Finish

/**************************************************************************************************/
/**** TLB                                                                                      ****/
/**************************************************************************************************/
`define PTE_V_MASK  32'h1
`define PTE_R_MASK  32'h2
`define PTE_W_MASK  32'h4
`define PTE_X_MASK  32'h8
`define PTE_U_MASK  32'h10
`define PTE_A_MASK  32'h40
`define PTE_D_MASK  32'h80

`define ACCESS_READ     0
`define ACCESS_WRITE    1
`define ACCESS_CODE     2

`define LEVELS      2
`define PTE_SIZE    4
`define PAGE_SIZE   (1 << 12)

/**************************************************************************************************/
/**** exception & interrupt                                                                    ****/
/**************************************************************************************************/
`define CAUSE_INTERRUPT 32'h80000000

// EXEPTION CODE
`define CAUSE_MISALIGNED_FETCH      32'h0
`define CAUSE_FAULT_FETCH           32'h1
`define CAUSE_ILLEGAL_INSTRUCTION   32'h2
`define CAUSE_BREAKPOINT            32'h3
`define CAUSE_MISALIGNED_LOAD       32'h4
`define CAUSE_FAULT_LOAD            32'h5
`define CAUSE_MISALIGNED_STORE      32'h6
`define CAUSE_FAULT_STORE           32'h7
`define CAUSE_USER_ECALL            32'h8
`define CAUSE_SUPERVISOR_ECALL      32'h9
`define CAUSE_HYPERVISOR_ECALL      32'ha
`define CAUSE_MACHINE_ECALL         32'hb
`define CAUSE_FETCH_PAGE_FAULT      32'hc
`define CAUSE_LOAD_PAGE_FAULT       32'hd
`define CAUSE_STORE_PAGE_FAULT      32'hf




/**************************************************************************************************/
/**** CSR Addr                                                                                 ****/
/**************************************************************************************************/
// User-Mode
`define CSR_USTATUS     12'h000
`define CSR_FFLAGS      12'h001
`define CSR_FRM         12'h002
`define CSR_FCSR        12'h003
`define CSR_UIE         12'h004
`define CSR_UTVEC       12'h005
`define CSR_USCRATCH    12'h040
`define CSR_UEPC        12'h041
`define CSR_UCAUSE      12'h042
`define CSR_UTVAL       12'h043
`define CSR_UIP         12'h044
`define CSR_CYCLE       12'hc00
`define CSR_TIME        12'hc01
`define CSR_INSTRET     12'hc02

// Superviser-Mode
`define CSR_SSTATUS     12'h100
`define CSR_SEDELEG     12'h102
`define CSR_SIDELEG     12'h103
`define CSR_SIE         12'h104
`define CSR_STVEC       12'h105
`define CSR_SCOUNTEREN  12'h106
`define CSR_SSCRATCH    12'h140
`define CSR_SEPC        12'h141
`define CSR_SCAUSE      12'h142
`define CSR_STVAL       12'h143
`define CSR_SIP         12'h144
`define CSR_SATP        12'h180

// Machine-Mode
`define CSR_MVENDORID   12'hf11
`define CSR_MARCHID     12'hf12
`define CSR_MIMPID      12'hf13
`define CSR_MHARTID     12'hf14
`define CSR_MSTATUS     12'h300
`define CSR_MISA        12'h301
`define CSR_MEDELEG     12'h302
`define CSR_MIDELEG     12'h303
`define CSR_MIE         12'h304
`define CSR_MTVEC       12'h305
`define CSR_MCOUNTEREN  12'h306
`define CSR_MSCRATCH    12'h340
`define CSR_MEPC        12'h341
`define CSR_MCAUSE      12'h342
`define CSR_MTVAL       12'h343
`define CSR_MIP         12'h344
`define CSR_MCYCLE      12'hb00
`define CSR_MINSTRET    12'hb02
`define CSR_MCYCLEH     12'hb80
`define CSR_MINSTRETH   12'hb82
`define CSR_CYCLEH      12'hc80
`define CSR_TIMEH       12'hc81
`define CSR_INSTRETH    12'hc82

/**************************************************************************************************/
/**** CSR Mask                                                                                 ****/
/**************************************************************************************************/
// PRIV MODE
`define PRIV_U 0
`define PRIV_S 1
`define PRIV_H 2
`define PRIV_M 3

// CSR Masks
`define COUNTEREN_MASK  32'h5   // ((1 << 0) | (1 << 2))

`define MSTATUS_UIE     32'h1       // (1 << 0)
`define MSTATUS_SIE     32'h2       // (1 << 1)
`define MSTATUS_HIE     32'h4       // (1 << 2)
`define MSTATUS_MIE     32'h8       // (1 << 3)
`define MSTATUS_UPIE    32'h10      // (1 << 4)
`define MSTATUS_SPIE    32'h20      // (1 << 5)
`define MSTATUS_HPIE    32'h40      // (1 << 6)
`define MSTATUS_MPIE    32'h80      // (1 << 7)
`define MSTATUS_SPP     32'h100     // (1 << 8)
`define MSTATUS_HPP     32'h600     // (3 << 9)
`define MSTATUS_MPP     32'h1800    // (3 << 11)
`define MSTATUS_FS      32'h6000    // (3 << 13)
`define MSTATUS_XS      32'h18000   // (3 << 15)
`define MSTATUS_MPRV    32'h20000   // (1 << 17)
`define MSTATUS_SUM     32'h40000   // (1 << 18)
`define MSTATUS_MXR     32'h80000   // (1 << 19)

`define MSTATUS_SPIE_SHIFT  5
`define MSTATUS_MPIE_SHIFT  7
`define MSTATUS_SPP_SHIFT   8
`define MSTATUS_MPP_SHIFT   11
`define MSTATUS_FS_SHIFT    13

`define MSTATUS_MASK    32'h000e79bb
`define SSTATUS_MASK0   32'h000de133
`define SSTATUS_MASK    `SSTATUS_MASK0

`define MIP_USIP        32'h1   // (1 << 0)
`define MIP_SSIP        32'h2   // (1 << 1)
`define MIP_HSIP        32'h4   // (1 << 2)
`define MIP_MSIP        32'h8   // (1 << 3)
`define MIP_UTIP        32'h10   // (1 << 4)
`define MIP_STIP        32'h20  // (1 << 5)
`define MIP_HTIP        32'h40  // (1 << 6)
`define MIP_MTIP        32'h80  // (1 << 7)
`define MIP_UEIP        32'h100  // (1 << 8)
`define MIP_SEIP        32'h200 // (1 << 9)
`define MIP_HEIP        32'h400 // (1 << 10)
`define MIP_MEIP        32'h800 // (1 << 11)


// Write CSR
`define WCSR_MASK1  32'hffff    // ((1 << (CAUSE_STORE_PAGE_FAULT + 1)) - 1;)
`define WCSR_MASK2  (`MIP_SSIP | `MIP_STIP | `MIP_SEIP)
`define WCSR_MASK3  (`MIP_MSIP | `MIP_MTIP | `MIP_SSIP | `MIP_STIP | `MIP_SEIP)
`define WCSR_MASK4  (`MIP_SSIP | `MIP_STIP)

`define MASK_STATUS (`MSTATUS_MASK & ~`MSTATUS_FS)

/**************************************************************************************************/
/**** VirtIO                                                                                   ****/
/**************************************************************************************************/
// Console
`define CONSOLE_MAGIC_VALUE         32'h74726976
`define CONSOLE_VERSION             2
`define CONSOLE_DEVICE_ID           3
`define CONSOLE_VENDOR_ID           32'hffff
`define CONSOLE_DEVICE_FEATURES     1
`define CONSOLE_CONFIG_GENERATION   0

// Disk
`define DISK_MAGIC_VALUE            32'h74726976
`define DISK_VERSION                2
`define DISK_DEVICE_ID              2
`define DISK_VENDOR_ID              32'hffff
`define DISK_DEVICE_FEATURES        1
`define DISK_CONFIG_GENERATION      0

/**************************************************************************************************/
/**** Micro Controller                                                                         ****/
/**************************************************************************************************/
`define MODE_ADDR 32'h40009000
`define QNUM_ADDR 32'h40009004
`define QSEL_ADDR 32'h40009008
`define CONQ_ADDR 20'h4000a
`define DISQ_ADDR 20'h4000b
`define KEYQ_ADDR 32'h4000c000
`endif
/**************************************************************************************************/

/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** opecode defines v0.01                                                                    ****/
/**************************************************************************************************/
`ifndef __OPCODES_VH__
`define __OPCODES_VH__
/**************************************************************************************************/
/**** OPCODE                                                                                   ****/
/**************************************************************************************************/

`define OPCODE_OP______ 7'h33
`define OPCODE_OP_FP___ 7'h53
`define OPCODE_AMO_____ 7'h2F
`define OPCODE_OP_IMM__ 7'h13
`define OPCODE_LOAD____ 7'h03
`define OPCODE_LOAD_FP_ 7'h07
`define OPCODE_JALR____ 7'h67
`define OPCODE_STORE___ 7'h23
`define OPCODE_STORE_FP 7'h27
`define OPCODE_BRANCH__ 7'h63
`define OPCODE_LUI_____ 7'h37
`define OPCODE_AUIPC___ 7'h17
`define OPCODE_JAL_____ 7'h6F
`define OPCODE_JALR____ 7'h67
`define OPCODE_MADD____ 7'h43
`define OPCODE_MSUB____ 7'h47
`define OPCODE_NMADD___ 7'h4F
`define OPCODE_NMSUB___ 7'h4B
`define OPCODE_MISC_MEM 7'h0F
`define OPCODE_SYSTEM__ 7'h73

//special
`define OPCODE_HALT____ 7'h7F

/**************************************************************************************************/
/**** FUNCT                                                                                    ****/
/**************************************************************************************************/

// OP_I
`define FUNCT3_ADD___ 3'h0
`define FUNCT3_SLL___ 3'h1
`define FUNCT3_SLT___ 3'h2
`define FUNCT3_SLTU__ 3'h3
`define FUNCT3_XOR___ 3'h4
`define FUNCT3_SRL___ 3'h5
`define FUNCT3_OR____ 3'h6
`define FUNCT3_AND___ 3'h7

// OP_M
`define FUNCT3_MUL___ 3'h0
`define FUNCT3_MULH__ 3'h1
`define FUNCT3_MULHSU 3'h2
`define FUNCT3_MULHU_ 3'h3
`define FUNCT3_DIV___ 3'h4
`define FUNCT3_DIVU__ 3'h5
`define FUNCT3_REM___ 3'h6
`define FUNCT3_REMU__ 3'h7

// STORE
`define FUNCT3_SB____ 3'h0
`define FUNCT3_SH____ 3'h1
`define FUNCT3_SW____ 3'h2
`define FUNCT3_SD____ 3'h3
`define FUNCT3_FSW___ 3'h2
`define FUNCT3_FSD___ 3'h3

// LOAD
`define FUNCT3_LB____ 3'h0
`define FUNCT3_LH____ 3'h1
`define FUNCT3_LW____ 3'h2
`define FUNCT3_LD____ 3'h3
`define FUNCT3_LBU___ 3'h4
`define FUNCT3_LHU___ 3'h5
`define FUNCT3_LWU___ 3'h6
`define FUNCT3_FLW___ 3'h2
`define FUNCT3_FLD___ 3'h3

// BRANCH
`define FUNCT3_BEQ___ 3'h0
`define FUNCT3_BNE___ 3'h1
`define FUNCT3_BLT___ 3'h4
`define FUNCT3_BGE___ 3'h5
`define FUNCT3_BLTU__ 3'h6
`define FUNCT3_BGEU__ 3'h7

// MISC_MEM
`define FUNCT3_FENCE_ 3'h0
`define FUNCT3_FENCEI 3'h1

// SYSTEM
`define FUNCT3_PRIV__ 3'h0
`define FUNCT3_CSRRW_ 3'h1
`define FUNCT3_CSRRS_ 3'h2
`define FUNCT3_CSRRC_ 3'h3
`define FUNCT3_CSRRWI 3'h5
`define FUNCT3_CSRRSI 3'h6
`define FUNCT3_CSRRCI 3'h7

`define FUNCT12_ECALL_ 12'h000
`define FUNCT12_EBREAK 12'h001
`define FUNCT12_ERET__ 12'h100
`define FUNCT12_MRET__ 12'h302
`define FUNCT12_SRET__ 12'h102
`define FUNCT12_URET__ 12'h002
`define FUNCT12_WFI___ 12'h105
`define FUNCT7_SFENCE_VMA 5'h09

// AMO
`define FUNCT5_AMO_LR__ 5'h02
`define FUNCT5_AMO_SC__ 5'h03
`define FUNCT5_AMO_SWAP 5'h01
`define FUNCT5_AMO_ADD_ 5'h00
`define FUNCT5_AMO_AND_ 5'h0c
`define FUNCT5_AMO_OR__ 5'h08
`define FUNCT5_AMO_XOR_ 5'h04
`define FUNCT5_AMO_MIN_ 5'h10
`define FUNCT5_AMO_MINU 5'h18
`define FUNCT5_AMO_MAX_ 5'h14
`define FUNCT5_AMO_MAXU 5'h1c

`define AMO_FAILURE_CODE 1
`define AMO_SUCCESS_CODE 0

`endif
/**************************************************************************************************/
