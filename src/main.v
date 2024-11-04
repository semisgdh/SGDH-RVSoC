/* Modified by Laurentiu-Cristian Duca, 2021-12-20
 * - more usefull debug data on w_7seg_data
 * - SIM_MAIN flag for simulation in XSIM of DDR memory
 */
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** main module for Implemetaion v0.13                                                       ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/
module m_main(
`ifndef SIM_MAIN
	      input  wire        CLK,
              input  wire        w_rxd,
`endif
              output wire        w_txd,
`ifndef ARTYA7
              output wire [15:0] w_led,
              output reg   [7:0] r_sg,
              output reg   [7:0] r_an,
 	      	input wire w_btnu,
    		input wire w_btnd,
    		input wire w_btnl,
    		input wire w_btnr,
		input wire w_btnc,
    		input wire [15:0] w_sw,
`else
              output wire  [3:0] w_ledx,
              //output reg   [7:0] r_sg,
              //output reg   [7:0] r_an,
`endif
              output wire        w_led1_B,
              output wire        w_led1_G,
              output wire        w_led1_R,
`ifndef ARTYA7
              inout  wire [15:0] ddr2_dq,    ///// for DRAM
              inout  wire  [1:0] ddr2_dqs_n, //
              inout  wire  [1:0] ddr2_dqs_p, //
              output wire [12:0] ddr2_addr,  //
              output wire  [2:0] ddr2_ba,    //
              output wire        ddr2_ras_n, //
              output wire        ddr2_cas_n, //
              output wire        ddr2_we_n,  //
              output wire        ddr2_ck_p,  // 
              output wire        ddr2_ck_n,  //
              output wire        ddr2_cke,   //
              output wire        ddr2_cs_n,  //
              output wire  [1:0] ddr2_dm,    //
              output wire        ddr2_odt    //
`else
              inout  wire [15:0] ddr3_dq,    ///// for DRAM
              inout  wire  [1:0] ddr3_dqs_n, //
              inout  wire  [1:0] ddr3_dqs_p, //
              output wire [13:0] ddr3_addr,  //
              output wire  [2:0] ddr3_ba,    //
              output wire        ddr3_ras_n, //
              output wire        ddr3_cas_n, //
              output wire        ddr3_we_n,  //
              output wire  [0:0] ddr3_ck_p,  // 
              output wire  [0:0] ddr3_ck_n,  //
              output wire        ddr3_reset_n, //
              output wire  [0:0] ddr3_cke,   //
              output wire  [0:0] ddr3_cs_n,  //
              output wire  [1:0] ddr3_dm,    //
              output wire  [0:0] ddr3_odt    //
`endif
              );

// xsim requires declarations before using
wire CORE_CLK;
wire RST_X;

`ifdef ARTYA7
    wire w_btnu = 0;
    wire w_btnd = 0;
    wire w_btnl = 0;
    wire w_btnr = 0;
    wire w_btnc = 0;
    wire [15:0] w_sw = 0;
`endif

`ifndef SIM_MAIN
    wire RST_X_IN = 1;
`else
    reg CLK=0, RST_X_IN=0;
    // CLK period must be m_main.m_clkgen0.inst.mmcm_adv_inst.CLKIN1_PERIOD
    always #5000 CLK = ~CLK;
    initial begin
	//$dumpfile("signals.vcd");
	//$dumpvars(0, m_main);
        #20000 RST_X_IN = 1;
	#10000;
	$display("CLKIN1_PERIOD=%d", m_main.m_clkgen0.inst.mmcm_adv_inst.CLKIN1_PERIOD);
	#2000000000;
	$finish;
    end

`ifndef ARTYA7
	// this is seen by xsim after adding ddr2_model.v and ddr2_model_parameters.v 
	// from nexys4.srcs/sources_1/ip/mig_7series_0/mig_7series_0/example_design/sim
	ddr2_model u_comp_ddr2
            (
             .ck      (ddr2_ck_p),
             .ck_n    (ddr2_ck_n),
             .cke     (ddr2_cke),
             .cs_n    (ddr2_cs_n),
             .ras_n   (ddr2_ras_n),
             .cas_n   (ddr2_cas_n),
             .we_n    (ddr2_we_n),
             .dm_rdqs (ddr2_dm),
             .ba      (ddr2_ba),
             .addr    (ddr2_addr),
             .dq      (ddr2_dq),
             .dqs     (ddr2_dqs_p),
             .dqs_n   (ddr2_dqs_n),
             .rdqs_n  (),
             .odt     (ddr2_odt)
             );
`else
	// this is seen in xsim after adding ddr3_model.sv and ddr3_model_parameters.v
	// from arty35t.srcs/sources_1/ip/mig_7series_0/mig_7series_0/example_design/sim
	ddr3_model u_comp_ddr3
            (
             .rst_n   (ddr3_reset_n),
             .ck      (ddr3_ck_p),
             .ck_n    (ddr3_ck_n),
             .cke     (ddr3_cke),
             .cs_n    (ddr3_cs_n),
             .ras_n   (ddr3_ras_n),
             .cas_n   (ddr3_cas_n),
             .we_n    (ddr3_we_n),
             .dm_tdqs (ddr3_dm),
             .ba      (ddr3_ba),
             .addr    (ddr3_addr),
             .dq      (ddr3_dq),
             .dqs     (ddr3_dqs_p),
             .dqs_n   (ddr3_dqs_n),
             .tdqs_n  (),
             .odt     (ddr3_odt)
             );
`endif	

    // we simulate memory file sending to rvsoc
    wire        w_rxd, w_tx_ready;
    reg [7:0] r_uart_data;
    reg r_uart_we;
    UartTx UartTx1(.CLK(CORE_CLK), .RST_X(RST_X), .DATA(r_uart_data), .WE(r_uart_we), .TXD(w_rxd), .READY(w_tx_ready));

    reg [7:0] fifo [0:1000];
    // The file handle for the input file
    integer f;
    integer i;
    // Line buffer
    reg [`LINE_BUFFER_SIZE-1:0] line;
    reg file_was_read=0;
    reg [31:0] mem_cnt=0, n=0;
    reg [2:0] byte_sent=0;

    always @(posedge CORE_CLK) begin
    	if(!file_was_read) begin
		file_was_read = 1;
		f = $fopen("/home/laur/lucru/cn/riscv/rvsoc-site-japan/rvsoc_src_ver053/src/mem.txt", "r");
            	if (f == 0) begin
                	$display ("ERROR: mem.txt not opened");
                	$finish;
            	end
		$display("mem.txt file was opened");
		line = "";
                n = $fgets(line, f);
                $display("fgets n=%d line='%s'", n, line);
                for(i = (`LINE_BUFFER_SIZE/8)-n+1; i < (`LINE_BUFFER_SIZE/8)+1; i=i+1) begin
                        if(line[(`LINE_BUFFER_SIZE - i*8)+:8]) begin
                                $display("line[%d:%d]=%x='%c'", `LINE_BUFFER_SIZE - i*8 + 7, `LINE_BUFFER_SIZE - i*8,
                                        line[(`LINE_BUFFER_SIZE - i*8)+:8], line[(`LINE_BUFFER_SIZE - i*8)+:8]);
                                fifo[i - ((`LINE_BUFFER_SIZE/8)-n+1)] = line[(`LINE_BUFFER_SIZE - i*8)+:8];
                        end else
                                $display("empty line");
                end
                for(i = 0; i < n; i=i+1)
                        $display("fifo[%d]=%x='%c'", i, fifo[i], fifo[i]);
		$fclose(f);
	end else if(RST_X && (mem_cnt < n) && (c.r_init_state == 2)) begin
		if(w_tx_ready) begin
			if(!c.w_dram_busy && !byte_sent) begin
				$display("mem_cnt=%d. sending %x='%c'", mem_cnt, fifo[mem_cnt], fifo[mem_cnt]);
				mem_cnt <= mem_cnt + 1;
				r_uart_data <= fifo[mem_cnt];
				r_uart_we <= 1;
				byte_sent <= 1;
			end
		end else if(byte_sent) begin // waiting for w_tx_ready
			//$display("r_uart_we <= 0");
			r_uart_we <= 0;
			byte_sent <= 0;
		end
	end
    end
`endif // SIM_MAIN

`ifdef ARTYA7
    wire [15:0] w_led;
    assign w_ledx = w_led[3:0];//w_insn_data[3:0];

    reg [7:0] r_sg;
    reg [7:0] r_an;
`endif

    wire [15:0] w_led_t; // temporal w_led


    reg [31:0] r_cnt=0;
    reg        r_time_led=0;
    always@(posedge CORE_CLK) r_cnt <= (r_cnt>=(64*1000000/2-1)) ? 0 : r_cnt+1;
    always@(posedge CORE_CLK) r_time_led <= (r_cnt==0) ? !r_time_led : r_time_led;

    /*******************************************************************************/
    reg         r_stop = 0;
    reg  [63:0] r_core_cnt = 0;

    // Connection Core <--> mem_ctrl
    wire [31:0] w_insn_data, w_insn_addr;
    wire [31:0] w_data_data, w_data_wdata, w_data_addr;
    wire        w_data_we;
    wire  [2:0] w_data_ctrl;

    wire [31:0] w_priv, w_satp, w_mstatus;
    wire [63:0] w_mtime, w_mtimecmp, w_wmtimecmp;
    wire        w_clint_we;
    wire [31:0] w_mip, w_wmip;
    wire        w_plic_we;
    wire        w_busy;
    wire [31:0] w_pagefault;
    wire  [1:0] w_tlb_req;
    wire        w_tlb_flush;
    wire        w_init_done;
    wire        w_init_stage;

    reg         r_load = 0;
    wire [2:0] w_init_state;
    assign w_led[0] = r_time_led & r_load; // loading initmem.bin
`ifdef LAUR_MEM_RB
    wire [31:0] w_verify_checksum;
    wire [31:0] w_checksum;
    assign w_led[1] = w_init_done && (w_verify_checksum == w_checksum);
`else
    assign w_led[1] = w_init_done;
`endif
    assign w_led[2] = (w_init_state >= 2); // memory is 0
    assign w_led[3] = 1;
    assign w_led[15:4] = w_led_t[15:4];

    // Clock
    wire w_locked;
`ifndef ARTYA7
    wire mig_clk, RST_X2;
    clk_wiz_0 m_clkgen0 (.clk_in1(CLK), .resetn(RST_X_IN), .clk_out1(mig_clk), .locked(w_locked));
`else
    wire mig_clk, RST_X2, ref_clk;
    clk_wiz_0 m_clkgen0 (.clk_in1(CLK), .resetn(RST_X_IN), .clk_out1(mig_clk), .clk_out2(ref_clk), .locked(w_locked));
`endif

    // Reset
    wire RST        = ~w_locked;
    assign RST_X      = ~RST & RST_X2;
    wire CORE_RST_X = RST_X & w_init_done;

    // Uart
    wire  [7:0] w_uart_data;
    wire        w_uart_we;

    // 7seg
    wire [31:0] w_core_odata;
    wire [31:0] w_core_pc, w_core_ir;
`ifdef LAUR_MEM_RB
    wire [31:0] w_7seg_data = (w_btnu) ? w_verify_checksum : (w_btnd) ? w_checksum : (w_btnc) ? w_insn_addr :
	        (w_btnl) ? w_insn_data  : (w_btnr) ? w_core_ir : w_core_pc;
`else
    wire [31:0] w_7seg_data = (w_btnu) ? r_core_cnt[41:10] : (w_btnd) ? w_insn_addr :
		(w_btnl) ? w_insn_data  : (w_btnr) ? w_core_ir : w_core_pc;
`endif
    //wire w_init_start;
    wire w_pl_init_we;
    always@(posedge CORE_CLK) begin
        //if(r_load==0 && w_init_start && !w_init_done) r_load <= 1;
	if(r_load==0 && ((w_init_state >= 2) && w_pl_init_we) && !w_init_done) r_load <= 1;
        else if(w_init_done) r_load <= 0;
    end

    wire  [7:0] w_sg;
    wire  [7:0] w_an;
    m_7segcon m_7segcon(CORE_CLK, CORE_RST_X, r_load, w_7seg_data, w_sg, w_an);
    always @(posedge CORE_CLK) begin
        r_sg <= w_sg;
        r_an <= w_an;
    end

    wire w_finish;
    wire w_halt;

    // stop and count
    always@(posedge CORE_CLK) begin
`ifdef LAUR_MEM_RB
        if(w_halt | w_finish) r_stop <= 1;
	if(w_init_done && !r_stop) r_core_cnt <= r_core_cnt + 1;
`else
	if(w_btnc | w_halt | w_finish) r_stop <= 1;
	if(w_init_done && !r_stop && w_led_t[9:8] == 0) r_core_cnt <= r_core_cnt + 1;
`endif
    end

    m_mmu c(
        .CLK            (CORE_CLK),
        .RST_X          (RST_X),
        .w_insn_addr    (w_insn_addr),
        .w_data_addr    (w_data_addr),
        .w_data_wdata   (w_data_wdata),
        .w_data_we      (w_data_we),
        .w_data_ctrl    (w_data_ctrl),
        .w_insn_data    (w_insn_data),
        .w_data_data    (w_data_data),
        .r_finish       (w_finish),
        .w_priv         (w_priv),
        .w_satp         (w_satp),
        .w_mstatus      (w_mstatus),
        .w_mtime        (w_mtime),
        .w_mtimecmp     (w_mtimecmp),
        .w_wmtimecmp    (w_wmtimecmp),
        .w_clint_we     (w_clint_we),
        .w_mip          (w_mip),
        .w_wmip         (w_wmip),
        .w_plic_we      (w_plic_we),
        .w_proc_busy    (w_busy),
        .w_pagefault    (w_pagefault),
        .w_tlb_req      (w_tlb_req),
        .w_tlb_flush    (w_tlb_flush),
        .w_txd          (w_txd),
        .w_rxd          (w_rxd),
        .w_init_done    (w_init_done),
        // input clk, rst (active-low)
        .mig_clk        (mig_clk),
        .mig_rst_x      (w_locked),
`ifdef ARTYA7
        .ref_clk        (ref_clk),
`endif
        // memory interface ports
`ifndef ARTYA7
        .ddr2_dq        (ddr2_dq),
        .ddr2_dqs_n     (ddr2_dqs_n),
        .ddr2_dqs_p     (ddr2_dqs_p),
        .ddr2_addr      (ddr2_addr),
        .ddr2_ba        (ddr2_ba),
        .ddr2_ras_n     (ddr2_ras_n),
        .ddr2_cas_n     (ddr2_cas_n),
        .ddr2_we_n      (ddr2_we_n),
        .ddr2_ck_p      (ddr2_ck_p),
        .ddr2_ck_n      (ddr2_ck_n),
        .ddr2_cke       (ddr2_cke),
        .ddr2_cs_n      (ddr2_cs_n),
        .ddr2_dm        (ddr2_dm),
        .ddr2_odt       (ddr2_odt),
`else
        .ddr3_dq        (ddr3_dq),
        .ddr3_dqs_n     (ddr3_dqs_n),
        .ddr3_dqs_p     (ddr3_dqs_p),
        .ddr3_addr      (ddr3_addr),
        .ddr3_ba        (ddr3_ba),
        .ddr3_ras_n     (ddr3_ras_n),
        .ddr3_cas_n     (ddr3_cas_n),
        .ddr3_we_n      (ddr3_we_n),
        .ddr3_ck_p      (ddr3_ck_p),
        .ddr3_ck_n      (ddr3_ck_n),
        .ddr3_reset_n   (ddr3_reset_n),
        .ddr3_cke       (ddr3_cke),
        .ddr3_cs_n      (ddr3_cs_n),
        .ddr3_dm        (ddr3_dm),
        .ddr3_odt       (ddr3_odt),
`endif
        // output clk, rst (active-low)
        .o_clk          (CORE_CLK),
        .o_rst_x        (RST_X2),
        .w_uart_data    (w_uart_data),
        .w_uart_we      (w_uart_we),
        .w_led          (w_led_t),
        .w_init_stage   (w_init_stage),
`ifdef LAUR_MEM_RB
    .w_checksum     (w_checksum),
	.w_verify_checksum (w_verify_checksum),
`endif
        .w_debug_btnd   (w_sw[1]), //(w_btnd),
        .w_init_state   (w_init_state),
	.w_pl_init_we   (w_pl_init_we));

    m_RVCoreM p(
        .CLK            (CORE_CLK),
        .RST_X          (CORE_RST_X),
        .w_stall        (r_stop), // does nothing
        .r_halt         (w_halt),
        .w_insn_addr    (w_insn_addr),
        .w_data_addr    (w_data_addr),
        .w_insn_data    (w_insn_data),
        .w_data_data    (w_data_data),
        .w_data_wdata   (w_data_wdata),
        .w_data_we      (w_data_we),
        .w_data_ctrl    (w_data_ctrl),
        .w_priv         (w_priv),
        .w_satp         (w_satp),
        .w_mstatus      (w_mstatus),
        .w_mtime        (w_mtime),
        .w_mtimecmp     (w_mtimecmp),
        .w_wmtimecmp    (w_wmtimecmp),
        .w_clint_we     (w_clint_we),
        .w_mip          (w_mip),
        .w_wmip         (w_wmip),
        .w_plic_we      (w_plic_we),
        .w_busy         (w_busy),
        .w_pagefault    (w_pagefault),
        .w_tlb_req      (w_tlb_req),
        .w_tlb_flush    (w_tlb_flush),
        .w_core_pc      (w_core_pc),
        .w_core_ir      (w_core_ir),
        .w_core_odata   (w_core_odata),
        .w_init_stage   (w_init_stage)
    );


/*********** Chika Chika **************************/
    reg  r_led1_B=0,r_led1_G=0,r_led1_R=0;

    reg  [12:0] r_cnt_B=0, r_cnt_G=64, r_cnt_R=512;
    reg  [11:0] r_ctrl_cnt = 0;
    reg   [3:0] r_blite_cnt = 0;
    always@(posedge CLK) begin
        r_ctrl_cnt <= r_ctrl_cnt + 1;
        r_blite_cnt <= r_blite_cnt + 1;
        if(r_ctrl_cnt == 0) begin
            r_cnt_B <= r_cnt_B + 2;
            r_cnt_G <= r_cnt_G + 3;
            r_cnt_R <= r_cnt_R + 5;
        end
        r_led1_B <= r_cnt_B[12] ? (r_cnt_B[11:0] < r_ctrl_cnt) : (r_cnt_B[11:0] >= r_ctrl_cnt);
        r_led1_G <= r_cnt_G[12] ? (r_cnt_G[11:0] < r_ctrl_cnt) : (r_cnt_G[11:0] >= r_ctrl_cnt);
        r_led1_R <= r_cnt_R[12] ? (r_cnt_R[11:0] < r_ctrl_cnt) : (r_cnt_R[11:0] >= r_ctrl_cnt);
    end
    wire [2:0] t_led = {r_led1_B, r_led1_G, r_led1_R};
    // User blue, SuperVisor Green or Yellow, Machine, Error -> Red
    assign {w_led1_B,w_led1_G,w_led1_R} =   (w_sw[0]) ? 0 :
                                            (w_led_t[3:0] == 4'b0001) ? {r_led1_B, r_led1_G, r_led1_R} :
                                            (!w_init_done) ? 0 :
                                            (r_blite_cnt != 0) ? 0 :
                                            (w_priv == `PRIV_U) ? 3'b001 :
                                            (w_priv == `PRIV_S) ? 3'b010 :
                                            (w_priv == `PRIV_M) ? 3'b100 : 0;
endmodule

/**************************************************************************************************/
module m_7segled (w_in, r_led);
    input  wire [3:0] w_in;
    output reg  [7:0] r_led;
    always @(*) begin
        case (w_in)
        4'h0  : r_led <= 8'b01111110;
        4'h1  : r_led <= 8'b00110000;
        4'h2  : r_led <= 8'b01101101;
        4'h3  : r_led <= 8'b01111001;
        4'h4  : r_led <= 8'b00110011;
        4'h5  : r_led <= 8'b01011011;
        4'h6  : r_led <= 8'b01011111;
        4'h7  : r_led <= 8'b01110000;
        4'h8  : r_led <= 8'b01111111;
        4'h9  : r_led <= 8'b01111011;
        4'ha  : r_led <= 8'b01110111;
        4'hb  : r_led <= 8'b00011111;
        4'hc  : r_led <= 8'b01001110;
        4'hd  : r_led <= 8'b00111101;
        4'he  : r_led <= 8'b01001111;
        4'hf  : r_led <= 8'b01000111;
        default:r_led <= 8'b00000000;
        endcase
    end
endmodule

`define DELAY7SEG  16000 // 200000 for 100MHz, 100000 for 50MHz -> 16000 for 8MHz
/**************************************************************************************************/
module m_7segcon(w_clk, w_rst_x, w_load, w_din, r_sg, r_an);
    input  wire w_clk, w_rst_x, w_load;
    input  wire [31:0] w_din;
    output reg [7:0] r_sg;  // cathode segments
    output reg [7:0] r_an;  // common anode

    reg [31:0] r_val   = 0;
    reg [31:0] r_cnt   = 0;
    reg  [3:0] r_in    = 0;
    reg  [2:0] r_digit = 0;
    always@(posedge w_clk) r_val <= w_din;

    // For RVSoc_1
    `define r_7seg_A 8'b01110111
    `define r_7seg_r 8'b00000101
    `define r_7seg_c 8'b00001101
    `define r_7seg_h 8'b00010111
    `define r_7seg_P 8'b01100111
    `define r_7seg_o 8'b00011101

    // For Loading
    `define r_7seg_L 8'b00001110
    `define r_7seg_a 8'b01111101
    `define r_7seg_d 8'b00111101
    `define r_7seg_i 8'b00010000
    `define r_7seg_n 8'b00010101
    `define r_7seg_g 8'b11111011

    reg  [7:0] r_init   = 8'b00000000;
    reg  [7:0] r_load   = 8'b00000000;

    reg  [7:0] r_load_mem [0:15];
    integer i;
    initial begin
        r_load_mem[0] = 0;
        r_load_mem[1] = 0;
        r_load_mem[2] = 0;
        r_load_mem[3] = 0;
        r_load_mem[4] = 0;
        r_load_mem[5] = 0;
        r_load_mem[6] = 0;
        r_load_mem[7] = `r_7seg_L;
        r_load_mem[8] = `r_7seg_o;
        r_load_mem[9] = `r_7seg_a;
        r_load_mem[10] = `r_7seg_d;
        r_load_mem[11] = `r_7seg_i;
        r_load_mem[12] = `r_7seg_n;
        r_load_mem[13] = `r_7seg_g;
        r_load_mem[14] = 8'b10000000;
        r_load_mem[15] = 8'b10000000;
    end

//    reg[104:0] r_load_tmp = {49'b0, `r_7seg_L, `r_7seg_o, `r_7seg_a, `r_7seg_d, `r_7seg_i, `r_7seg_n, `r_7seg_g, 14'b0};
    reg [24:0] r_load_cnt = 0;
    reg  [3:0] r_lcnt = 0;
    always@(posedge w_clk) begin
        if(w_load) r_load_cnt <= r_load_cnt + 1;
        if(w_load && (r_load_cnt == 0)) r_lcnt <= r_lcnt + 1;//r_load_tmp <= r_load_tmp << 7;
    end

    always@(posedge w_clk) begin
        r_cnt <= (r_cnt>=(`DELAY7SEG-1)) ? 0 : r_cnt + 1;
        if(r_cnt==0) begin
        r_digit <= r_digit+ 1;
        if      (r_digit==0) begin r_an <= 8'b11111110; r_in <= r_val[3:0]  ; r_init = `r_7seg_c; r_load = r_load_mem[r_lcnt+7]; end
        else if (r_digit==1) begin r_an <= 8'b11111101; r_in <= r_val[7:4]  ; r_init = `r_7seg_o; r_load = r_load_mem[r_lcnt+6]; end
        else if (r_digit==2) begin r_an <= 8'b11111011; r_in <= r_val[11:8] ; r_init = `r_7seg_r; r_load = r_load_mem[r_lcnt+5]; end
        else if (r_digit==3) begin r_an <= 8'b11110111; r_in <= r_val[15:12]; r_init = `r_7seg_P; r_load = r_load_mem[r_lcnt+4]; end
        else if (r_digit==4) begin r_an <= 8'b11101111; r_in <= r_val[19:16]; r_init = `r_7seg_h; r_load = r_load_mem[r_lcnt+3]; end
        else if (r_digit==5) begin r_an <= 8'b11011111; r_in <= r_val[23:20]; r_init = `r_7seg_c; r_load = r_load_mem[r_lcnt+2]; end
        else if (r_digit==6) begin r_an <= 8'b10111111; r_in <= r_val[27:24]; r_init = `r_7seg_r; r_load = r_load_mem[r_lcnt+1]; end
        else                 begin r_an <= 8'b01111111; r_in <= r_val[31:28]; r_init = `r_7seg_A; r_load = r_load_mem[r_lcnt];   end
        end
    end
    wire [7:0] w_segments;
    m_7segled m_7segled (r_in, w_segments);
    always@(posedge w_clk) r_sg <= (w_load) ? ~r_load : (w_rst_x) ? ~w_segments : ~r_init;
endmodule
/**************************************************************************************************/

// A E F J L P U H Y O 

// A r c h P r o c
