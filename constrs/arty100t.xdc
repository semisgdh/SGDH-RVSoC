###############################################################################################
## main.xdc for NEXYS A7   ArchLab TOKYO TECH
###############################################################################################

## 100MHz system clock
###############################################################################################
set_property -dict { PACKAGE_PIN E3  IOSTANDARD LVCMOS33} [get_ports { CLK }];
create_clock -add -name sys_clk -period 10.00 [get_ports {CLK}];

set_property -dict { PACKAGE_PIN C2  IOSTANDARD LVCMOS33 } [get_ports { RST_X }];

## UART (Serial Port)
###############################################################################################
set_property -dict { PACKAGE_PIN D10  IOSTANDARD LVCMOS33} [get_ports { w_txd }];
set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports { w_rxd }];
# set_property -dict { PACKAGE_PIN A9  IOSTANDARD LVCMOS33} [get_ports { w_txd }];
# set_property -dict { PACKAGE_PIN D10  IOSTANDARD LVCMOS33} [get_ports { w_rxd }];
###############################################################################################
create_generated_clock -name mig_in_clk [get_pins m_clkgen0/inst/mmcm_adv_inst/CLKOUT0]
set_clock_groups -asynchronous -group {mig_in_clk}

create_generated_clock -name core_clk [get_pins c/dram_con/cache_ctrl/dram_con_witout_cache/clkgen1/inst/mmcm_adv_inst/CLKOUT0]
set_clock_groups -asynchronous -group {core_clk}

## LEDs
###############################################################################################
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33} [get_ports { w_ledx[0] }];
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33} [get_ports { w_ledx[1] }];
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33} [get_ports { w_ledx[2] }];
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33} [get_ports { w_ledx[3] }];

## RGB LEDs
###############################################################################################
set_property -dict { PACKAGE_PIN E1 IOSTANDARD LVCMOS33 } [get_ports { w_led1_B }]; 
set_property -dict { PACKAGE_PIN F6 IOSTANDARD LVCMOS33 } [get_ports { w_led1_G }]; 
set_property -dict { PACKAGE_PIN G6 IOSTANDARD LVCMOS33 } [get_ports { w_led1_R }]; 

## TEST
set_property -dict { PACKAGE_PIN K5 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[0] }];
set_property -dict { PACKAGE_PIN L3 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[1] }]; 
set_property -dict { PACKAGE_PIN K3 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[2] }]; 
set_property -dict { PACKAGE_PIN L6 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[3] }]; 
set_property -dict { PACKAGE_PIN M3 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[4] }]; 
set_property -dict { PACKAGE_PIN M1 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[5] }]; 
set_property -dict { PACKAGE_PIN L4 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[6] }]; 
set_property -dict { PACKAGE_PIN M2 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[7] }]; 
set_property -dict { PACKAGE_PIN V4 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[8] }]; 
set_property -dict { PACKAGE_PIN T5 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[9] }]; 
set_property -dict { PACKAGE_PIN U4 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[10] }]; 
set_property -dict { PACKAGE_PIN V5 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[11] }]; 
set_property -dict { PACKAGE_PIN V1 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[12] }]; 
set_property -dict { PACKAGE_PIN T3 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[13] }]; 
set_property -dict { PACKAGE_PIN U3 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[14] }]; 
set_property -dict { PACKAGE_PIN R3 IOSTANDARD SSTL135 } [get_ports { ddr3_dq[15] }]; 

set_property -dict { PACKAGE_PIN L1 IOSTANDARD SSTL135 } [get_ports { ddr3_dm[0] }]; 
set_property -dict { PACKAGE_PIN U1 IOSTANDARD SSTL135 } [get_ports { ddr3_dm[1] }]; 

set_property -dict { PACKAGE_PIN N2 IOSTANDARD DIFF_SSTL135 } [get_ports { ddr3_dqs_p[0] }];
set_property -dict { PACKAGE_PIN N1 IOSTANDARD DIFF_SSTL135 } [get_ports { ddr3_dqs_n[0] }]; 
set_property -dict { PACKAGE_PIN U2 IOSTANDARD DIFF_SSTL135 } [get_ports { ddr3_dqs_p[1] }];
set_property -dict { PACKAGE_PIN V2 IOSTANDARD DIFF_SSTL135 } [get_ports { ddr3_dqs_n[1] }]; 

set_property -dict { PACKAGE_PIN T8 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[13] }];
set_property -dict { PACKAGE_PIN T6 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[12] }]; 
set_property -dict { PACKAGE_PIN U6 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[11] }]; 
set_property -dict { PACKAGE_PIN R6 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[10] }]; 
set_property -dict { PACKAGE_PIN V7 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[9] }]; 
set_property -dict { PACKAGE_PIN R8 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[8] }]; 
set_property -dict { PACKAGE_PIN U7 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[7] }]; 
set_property -dict { PACKAGE_PIN V6 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[6] }]; 
set_property -dict { PACKAGE_PIN R7 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[5] }]; 
set_property -dict { PACKAGE_PIN N6 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[4] }]; 
set_property -dict { PACKAGE_PIN T1 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[3] }]; 
set_property -dict { PACKAGE_PIN N4 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[2] }]; 
set_property -dict { PACKAGE_PIN M6 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[1] }]; 
set_property -dict { PACKAGE_PIN R2 IOSTANDARD SSTL135 } [get_ports { ddr3_addr[0] }]; 

set_property -dict { PACKAGE_PIN P2 IOSTANDARD SSTL135 } [get_ports { ddr3_ba[2] }]; 
set_property -dict { PACKAGE_PIN P4 IOSTANDARD SSTL135 } [get_ports { ddr3_ba[1] }]; 
set_property -dict { PACKAGE_PIN R1 IOSTANDARD SSTL135 } [get_ports { ddr3_ba[0] }]; 

set_property -dict { PACKAGE_PIN U9 IOSTANDARD DIFF_SSTL135 } [get_ports { ddr3_ck_p[0] }];
set_property -dict { PACKAGE_PIN V9 IOSTANDARD DIFF_SSTL135 } [get_ports { ddr3_ck_n[0] }];

set_property -dict { PACKAGE_PIN P3 IOSTANDARD SSTL135 } [get_ports { ddr3_ras_n }];
set_property -dict { PACKAGE_PIN M4 IOSTANDARD SSTL135 } [get_ports { ddr3_cas_n }]; 
set_property -dict { PACKAGE_PIN P5 IOSTANDARD SSTL135 } [get_ports { ddr3_we_n }];
set_property -dict { PACKAGE_PIN K6 IOSTANDARD SSTL135 } [get_ports { ddr3_reset_n }];
set_property -dict { PACKAGE_PIN N5 IOSTANDARD SSTL135 } [get_ports { ddr3_cke[0] }];
set_property -dict { PACKAGE_PIN R5 IOSTANDARD SSTL135 } [get_ports { ddr3_odt[0] }];
set_property -dict { PACKAGE_PIN U8 IOSTANDARD SSTL135 } [get_ports { ddr3_cs_n[0] }];

#set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports { sf }];


