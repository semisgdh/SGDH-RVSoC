/* Modified by Laurentiu-Cristian Duca, 2021-12-20
 * - implemented a new controller with unaligned ld/sw
 */
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** Memory Module v0.02                                                                      ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**** DRAM Main Memory module for implementation                                               ****/
/**************************************************************************************************/
`ifndef SIM_MODE
/**** DRAM Controller without Cache                                                            ****/
/**************************************************************************************************/
module DRAM_conRV#(
`ifndef ARTYA7
              parameter DDR2_DQ_WIDTH   = 16,
              parameter DDR2_DQS_WIDTH  = 2,
              parameter DDR2_ADDR_WIDTH = 13,
              parameter DDR2_BA_WIDTH   = 3,
              parameter DDR2_DM_WIDTH   = 2,
              parameter APP_ADDR_WIDTH  = 27,
`else
              parameter DDR3_DQ_WIDTH   = 16,
              parameter DDR3_DQS_WIDTH  = 2,
              parameter DDR3_ADDR_WIDTH = 14,
              parameter DDR3_BA_WIDTH   = 3,
              parameter DDR3_DM_WIDTH   = 2,
              parameter APP_ADDR_WIDTH  = 28,
`endif
              parameter APP_CMD_WIDTH   = 3,
              parameter APP_DATA_WIDTH  = 128,  // Note
              parameter APP_MASK_WIDTH  = 16)
    (
     // input clk, rst (active-low)
     input  wire                         mig_clk,
     input  wire                         mig_rst_x,
`ifdef ARTYA7
     input  wire                         ref_clk,
`endif
     // memory interface ports
`ifndef ARTYA7
     inout  wire [DDR2_DQ_WIDTH-1 : 0]   ddr2_dq,
     inout  wire [DDR2_DQS_WIDTH-1 : 0]  ddr2_dqs_n,
     inout  wire [DDR2_DQS_WIDTH-1 : 0]  ddr2_dqs_p,
     output wire [DDR2_ADDR_WIDTH-1 : 0] ddr2_addr,
     output wire [DDR2_BA_WIDTH-1 : 0]   ddr2_ba,
     output wire                         ddr2_ras_n,
     output wire                         ddr2_cas_n,
     output wire                         ddr2_we_n,
     output wire [0:0]                   ddr2_ck_p,
     output wire [0:0]                   ddr2_ck_n,
     output wire [0:0]                   ddr2_cke,
     output wire [0:0]                   ddr2_cs_n,
     output wire [DDR2_DM_WIDTH-1 : 0]   ddr2_dm,
     output wire [0:0]                   ddr2_odt,
`else
     inout  wire [DDR3_DQ_WIDTH-1 : 0]   ddr3_dq,
     inout  wire [DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_n,
     inout  wire [DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_p,
     output wire [DDR3_ADDR_WIDTH-1 : 0] ddr3_addr,
     output wire [DDR3_BA_WIDTH-1 : 0]   ddr3_ba,
     output wire                         ddr3_ras_n,
     output wire                         ddr3_cas_n,
     output wire                         ddr3_we_n,
     output wire [0:0]                   ddr3_ck_p,
     output wire [0:0]                   ddr3_ck_n,
     output wire                         ddr3_reset_n,
     output wire [0:0]                   ddr3_cke,
     output wire [0:0]                   ddr3_cs_n,
     output wire [DDR3_DM_WIDTH-1 : 0]   ddr3_dm,
     output wire [0:0]                   ddr3_odt,
`endif

     // output clk, rst (active-low)
     output wire                         o_clk,
     output wire                         o_rst_x,
     // user interface ports
     input  wire                         i_rd_en,
     input  wire                         i_wr_en,
     input  wire [31:0]                  i_addr,
     input  wire [31:0]                  i_data,
     output wire                         o_init_calib_complete,
     output wire [31:0]                  o_data,
     output wire                         o_busy,
     input  wire [2:0]                   i_ctrl);

    reg         r_we    = 0;
    reg         r_rd    = 0;
    wire 	w_busy;
    wire[127:0] w_dram_odata;
    reg [3:0] r_mask = 0;
    reg   [2:0] r_ctrl  = 0;
    reg [31:0] r_odata = 0;
    reg [127:0] r_dram_odata1 = 0;
    reg [23:0] r_dram_odata2 = 0;
    reg [31:0] r_maddr, r_addr;

    // 16+3 bytes shifted with 0 or 15 bytes.
    wire[31:0] w_odata = {r_dram_odata2, r_dram_odata1} >> {r_addr[3:0], 3'b0};
    assign o_data = (r_ctrl[1:0]==0) ? ((r_ctrl[2]) ? {24'h0, w_odata[7:0]} :
                                         {{24{w_odata[7]}}, w_odata[7:0]}) :
                     (r_ctrl[1:0]==1) ? ((r_ctrl[2]) ? {16'h0, w_odata[15:0]} :
                                         {{16{w_odata[15]}}, w_odata[15:0]}) :
                     w_odata;
    reg [31:0] r_wdata=0, r_wdata_ui=0;

    reg r_stall = 0;
    assign o_busy = (r_stall | w_busy);
    reg [7:0] state = 0, state_next = 0;
    reg [31:0] r_cnt = 0;
    always@(posedge o_clk) begin
        case(state)
        8'd0: // idle
                if(i_rd_en && !w_busy) begin
                        state <= 10;
			state_next <= 30;
			r_rd <= 1;
                        r_stall <= 1;
                        r_addr <= i_addr;
			r_maddr <= {i_addr[31:4], 4'b0};
                        r_ctrl <= i_ctrl;
                end else if(i_wr_en && !w_busy) begin
			state <= 20;
                        r_stall <= 1;
			r_addr <= i_addr;
                        r_maddr <= {i_addr[31:2], 2'b0};
                        r_wdata_ui <= (i_ctrl[1:0] == 0) ? {24'h0, i_data[7:0]} :
                                   (i_ctrl[1:0] == 1) ? {16'h0, i_data[15:0]} : i_data;
                        r_ctrl <= i_ctrl;
                end
	8'd10: begin //mem read
		if(w_busy) begin
			r_rd <= 0;
                	state <= 11;
		end 
	end
	8'd11: begin
                if(!w_busy) begin
                        r_dram_odata1 <= w_dram_odata;
                        if(r_addr[3:0] <= 12) // one read is enough
                                state <= 100;
                        else begin
                                state <= 12;
                                r_rd <= 1;
                                //r_maddr <= {r_addr[31:4]+28'b1, 4'b0};
                                r_maddr <= r_maddr + 16;
                        end
                end
        end
	8'd12: begin 
		// idem state 10
		if(w_busy) begin
                        r_rd <= 0;
                        state <= 13;
                end
	end
	8'd13: begin
		// similar state 11
		if(!w_busy) begin
                        //r_dram_odata2 <= w_dram_odata[23:0];
			r_dram_odata2 <= w_dram_odata;
                        state <= 100;
                end
	end
	8'd100: begin 
		state <= 0;
		r_stall <= 0;
	end
	8'd20: begin // mem_write
                if(r_ctrl[1:0]==0) begin // SB
			if(r_addr[1:0] == 0) begin
                        	r_mask <= 4'b0001;
				r_wdata <= r_wdata_ui;
			end else if(r_addr[1:0] == 1) begin
				r_mask <= 4'b0010;
				r_wdata <= r_wdata_ui << 8;
			end else if(r_addr[1:0] == 2) begin
                                r_mask <= 4'b0100;
				r_wdata <= r_wdata_ui << 16;
			end else if(r_addr[1:0] == 3) begin
                                r_mask <= 4'b1000;
				r_wdata <= r_wdata_ui << 24;
			end
			r_we <= 1;
			state <= 21;
			state_next <= 100;
                end else if(r_ctrl[1:0]==1) begin // SH
			if(r_addr[1:0] == 0) begin
				r_mask <= 4'b0011;
				r_wdata <= r_wdata_ui;
				r_we <= 1;
				state <= 21;
				state_next <= 100;
			end else if (r_addr[1:0] == 1) begin
				r_mask <= 4'b0110;
				r_wdata <= r_wdata_ui << 8;
				r_we <= 1;
				state <= 21;
				state_next <= 100;
			end else if (r_addr[1:0] == 2) begin
                                r_mask <= 4'b1100;
                                r_we <= 1;
                                r_wdata <= r_wdata_ui << 16;
                                state <= 21;
                                state_next <= 100;
			end else if (r_addr[1:0] == 3) begin
				// write in two cycles.
                                r_mask <= 4'b1000;
                                r_wdata <= r_wdata_ui << 24;
                                r_we <= 1;
                                state <= 21;
                                state_next <= 31;
			end
                end else if(r_ctrl[1:0]==2) begin // SW
			if(r_addr[1:0] == 0) begin
				r_mask <= 4'b1111;
				r_wdata <= r_wdata_ui;
				r_we <= 1;
                                state <= 21;
                                state_next <= 100;
			end else if(r_addr[1:0] == 1) begin
				// write in two cycles.
				r_mask <= 4'b1110;
				r_wdata <= r_wdata_ui << 8;
				r_we <= 1;
				state <= 21;
				state_next <= 40;
			end else if(r_addr[1:0] == 2) begin
				// write in two cycles.
				r_mask <= 4'b1100;
                                r_wdata <= r_wdata_ui << 16;
                                r_we <= 1;
                                state <= 21;
                                state_next <= 41;
			end else if(r_addr[1:0] == 3) begin
				// write in two cycles.
				r_mask <= 4'b1000;
                                r_wdata <= r_wdata_ui << 24;
                                r_we <= 1;
                                state <= 21;
                                state_next <= 42;
			end
                end
                state <= 21;
		r_we <= 1;
	end
	8'd21: begin
		if(w_busy) begin
			r_we <= 0;
			state <= 22;
		end 
	end
	8'd22: begin
		if(!w_busy) begin
			state <= state_next;
		end
	end
        8'd31: begin
                // SH with (r_addr[1:0] == 3) second write
                r_mask <= 4'b0001;
		r_maddr <= r_maddr + 4;
		r_wdata <= r_wdata_ui >> 8;
                r_we <= 1;
                state <= 21;
                state_next <= 100;
        end
	8'd40: begin
		// SW with (r_addr[1:0] == 1) second write
		r_mask <= 4'b0001;
		r_maddr <= r_maddr + 4;
		r_wdata <= r_wdata_ui >> 24;
		r_we <= 1;
                state <= 21;
                state_next <= 100;
	end
	8'd41: begin
		// SW with (r_addr[1:0] == 2) second write
		r_mask <= 4'b0011;
		r_maddr <= r_maddr + 4;
                r_wdata <= r_wdata_ui >> 16;
                r_we <= 1;
                state <= 21;
                state_next <= 100;
	end
        8'd42: begin
                // SW with (r_addr[1:0] == 3) second write
		r_mask <= 4'b0111;
		r_maddr <= r_maddr + 4;
                r_wdata <= r_wdata_ui >> 8;
                r_we <= 1;
                state <= 21;
                state_next <= 100;
	end
	endcase
    end
   
`ifdef SKIP_CACHE 
    DRAM_con_witout_cache dram_con_witout_cache (
               // input clk, rst (active-low)
               .mig_clk(mig_clk),
               .mig_rst_x(mig_rst_x),
`ifdef ARTYA7
               .ref_clk(ref_clk),
`endif
               // memory interface ports
`ifndef ARTYA7
               .ddr2_dq(ddr2_dq),
               .ddr2_dqs_n(ddr2_dqs_n),
               .ddr2_dqs_p(ddr2_dqs_p),
               .ddr2_addr(ddr2_addr),
               .ddr2_ba(ddr2_ba),
               .ddr2_ras_n(ddr2_ras_n),
               .ddr2_cas_n(ddr2_cas_n),
               .ddr2_we_n(ddr2_we_n),
               .ddr2_ck_p(ddr2_ck_p),
               .ddr2_ck_n(ddr2_ck_n),
               .ddr2_cke(ddr2_cke),
               .ddr2_cs_n(ddr2_cs_n),
               .ddr2_dm(ddr2_dm),
               .ddr2_odt(ddr2_odt),
`else
               .ddr3_dq(ddr3_dq),
               .ddr3_dqs_n(ddr3_dqs_n),
               .ddr3_dqs_p(ddr3_dqs_p),
               .ddr3_addr(ddr3_addr),
               .ddr3_ba(ddr3_ba),
               .ddr3_ras_n(ddr3_ras_n),
               .ddr3_cas_n(ddr3_cas_n),
               .ddr3_we_n(ddr3_we_n),
               .ddr3_ck_p(ddr3_ck_p),
               .ddr3_ck_n(ddr3_ck_n),
               .ddr3_reset_n(ddr3_reset_n),
               .ddr3_cke(ddr3_cke),
               .ddr3_cs_n(ddr3_cs_n),
               .ddr3_dm(ddr3_dm),
               .ddr3_odt(ddr3_odt),
`endif
               // output clk, rst (active-low)
               .o_clk(o_clk),
               .o_rst_x(o_rst_x),
               // user interface ports
               .i_rd_en(r_rd),
               .i_wr_en(r_we),
	       .o_init_calib_complete(o_init_calib_complete),
	       .i_addr(r_maddr),
               .i_data(r_wdata),               .o_data(w_dram_odata),
               .o_busy(w_busy),
               .i_mask(~r_mask));
`else // SKIP_CACHE
    cache_ctrl cache_ctrl (
               // input clk, rst (active-low)
               .mig_clk(mig_clk),
               .mig_rst_x(mig_rst_x),
`ifdef ARTYA7
               .ref_clk(ref_clk),
`endif
               // memory interface ports
`ifndef ARTYA7
               .ddr2_dq(ddr2_dq),
               .ddr2_dqs_n(ddr2_dqs_n),
               .ddr2_dqs_p(ddr2_dqs_p),
               .ddr2_addr(ddr2_addr),
               .ddr2_ba(ddr2_ba),
               .ddr2_ras_n(ddr2_ras_n),
               .ddr2_cas_n(ddr2_cas_n),
               .ddr2_we_n(ddr2_we_n),
               .ddr2_ck_p(ddr2_ck_p),
               .ddr2_ck_n(ddr2_ck_n),
               .ddr2_cke(ddr2_cke),
               .ddr2_cs_n(ddr2_cs_n),
               .ddr2_dm(ddr2_dm),
               .ddr2_odt(ddr2_odt),
`else
               .ddr3_dq(ddr3_dq),
               .ddr3_dqs_n(ddr3_dqs_n),
               .ddr3_dqs_p(ddr3_dqs_p),
               .ddr3_addr(ddr3_addr),
               .ddr3_ba(ddr3_ba),
               .ddr3_ras_n(ddr3_ras_n),
               .ddr3_cas_n(ddr3_cas_n),
               .ddr3_we_n(ddr3_we_n),
               .ddr3_ck_p(ddr3_ck_p),
               .ddr3_ck_n(ddr3_ck_n),
               .ddr3_reset_n(ddr3_reset_n),
               .ddr3_cke(ddr3_cke),
               .ddr3_cs_n(ddr3_cs_n),
               .ddr3_dm(ddr3_dm),
               .ddr3_odt(ddr3_odt),
`endif
               // output clk, rst (active-low)
               .o_clk(o_clk),
               .o_rst_x(o_rst_x),
               // user interface ports
               .i_rd_en(r_rd),
               .i_wr_en(r_we),
               .i_addr(r_maddr),
               .i_data(r_wdata),
               .o_init_calib_complete(o_init_calib_complete),
               .o_data(w_dram_odata),
               .o_busy(w_busy),
               .i_mask(r_mask)
               );    
`endif //SKIP_CACHE
endmodule
/**************************************************************************************************/

/**** Memory Controller with Cache                                                             ****/

/**************************************************************************************************/

module cache_ctrl#(
`ifndef ARTYA7
              parameter DDR2_DQ_WIDTH   = 16,
              parameter DDR2_DQS_WIDTH  = 2,
              parameter DDR2_ADDR_WIDTH = 13,
              parameter DDR2_BA_WIDTH   = 3,
              parameter DDR2_DM_WIDTH   = 2,
              parameter APP_ADDR_WIDTH  = 27,
`else
              parameter DDR3_DQ_WIDTH   = 16,
              parameter DDR3_DQS_WIDTH  = 2,
              parameter DDR3_ADDR_WIDTH = 14,
              parameter DDR3_BA_WIDTH   = 3,
              parameter DDR3_DM_WIDTH   = 2,
              parameter APP_ADDR_WIDTH  = 28,
`endif
              parameter APP_CMD_WIDTH   = 3,
              parameter APP_DATA_WIDTH  = 128,  // Note
              parameter APP_MASK_WIDTH  = 16)
     (
     // input clk, rst (active-low)
     input  wire                         mig_clk,
     input  wire                         mig_rst_x,
`ifdef ARTYA7
     input  wire                         ref_clk,
`endif
     // memory interface ports
`ifndef ARTYA7
     inout  wire [DDR2_DQ_WIDTH-1 : 0]   ddr2_dq,
     inout  wire [DDR2_DQS_WIDTH-1 : 0]  ddr2_dqs_n,
     inout  wire [DDR2_DQS_WIDTH-1 : 0]  ddr2_dqs_p,
     output wire [DDR2_ADDR_WIDTH-1 : 0] ddr2_addr,
     output wire [DDR2_BA_WIDTH-1 : 0]   ddr2_ba,
     output wire                         ddr2_ras_n,
     output wire                         ddr2_cas_n,
     output wire                         ddr2_we_n,
     output wire [0:0]                   ddr2_ck_p,
     output wire [0:0]                   ddr2_ck_n,
     output wire [0:0]                   ddr2_cke,
     output wire [0:0]                   ddr2_cs_n,
     output wire [DDR2_DM_WIDTH-1 : 0]   ddr2_dm,
     output wire [0:0]                   ddr2_odt,
`else
     inout  wire [DDR3_DQ_WIDTH-1 : 0]   ddr3_dq,
     inout  wire [DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_n,
     inout  wire [DDR3_DQS_WIDTH-1 : 0]  ddr3_dqs_p,
     output wire [DDR3_ADDR_WIDTH-1 : 0] ddr3_addr,
     output wire [DDR3_BA_WIDTH-1 : 0]   ddr3_ba,
     output wire                         ddr3_ras_n,
     output wire                         ddr3_cas_n,
     output wire                         ddr3_we_n,
     output wire [0:0]                   ddr3_ck_p,
     output wire [0:0]                   ddr3_ck_n,
     output wire                         ddr3_reset_n,
     output wire [0:0]                   ddr3_cke,
     output wire [0:0]                   ddr3_cs_n,
     output wire [DDR3_DM_WIDTH-1 : 0]   ddr3_dm,
     output wire [0:0]                   ddr3_odt,
`endif

     // on FPGA, o_clk is output
     output wire                         o_clk,
     output wire 			 o_rst_x,
     // user interface ports
     input  wire                         i_rd_en,
     input  wire                         i_wr_en,
     input  wire [31:0]                  i_addr,
     input  wire [31:0]                  i_data,
     output wire                         o_init_calib_complete,
     output wire[127:0]                  o_data,
     output wire                         o_busy,
     input  wire [3:0]                   i_mask);

    /***** store output data to registers in posedge clock cycle *****/
    reg   [1:0] r_cache_state = 0;

    reg  [31:0] r_addr = 0;
    reg   [2:0] r_ctrl = 0;
    reg [127:0] r_o_data = 0;

    // DRAM
    wire        w_dram_stall;
    wire        w_dram_le;
    wire [31:0] w_dram_addr = (i_wr_en) ? i_addr : r_addr;
    wire[127:0] w_dram_odata;

    // Cache
    wire        c_oe;
    wire        c_clr   = (r_cache_state == 2'b11 && c_oe);
    wire        c_we    = (r_cache_state == 2'b10 && !w_dram_stall);
    wire [31:0] c_addr  = (r_cache_state == 2'b00) ? i_addr : r_addr;
    wire[127:0] c_idata = w_dram_odata;
    wire[127:0] c_odata;
    /*
    cache states:
        2'b00=idle,
        (2'b01=read && c_oe)=read made in c_odata,
        2'b10=cache read miss;
        2'b11=write

    */
    always@(posedge o_clk) begin
        if(r_cache_state == 2'b01 && !c_oe) begin
            r_cache_state <= 2'b10;
        end
        else if(r_cache_state == 2'b11 || (r_cache_state == 2'b01 && c_oe)
                || (r_cache_state == 2'b10 && !w_dram_stall)) begin
            r_cache_state <= 2'b00;
            r_o_data <= (r_cache_state == 2'b01) ? c_odata : w_dram_odata;
        end
        else if(i_wr_en) begin
            r_cache_state <= 2'b11;
            r_addr <= i_addr;
        end
        else if(i_rd_en) begin
            r_cache_state <= 2'b01;
            r_addr <= i_addr;
        end
    end

    m_dram_cache#(28,128,`CACHE_SIZE/16) cache(o_clk, 1'b1, 1'b0, c_clr, c_we,
                                c_addr[31:4], c_idata, c_odata, c_oe);

    assign w_dram_le = (r_cache_state == 2'b01 && !c_oe);
    assign o_busy = w_dram_stall || r_cache_state != 0;

    assign o_data = r_o_data;

    DRAM_con_witout_cache dram_con_witout_cache (
               // input clk, rst (active-low)
               .mig_clk(mig_clk),
               .mig_rst_x(mig_rst_x),
`ifdef ARTYA7
               .ref_clk(ref_clk),
`endif
               // memory interface ports
`ifndef ARTYA7
               .ddr2_dq(ddr2_dq),
               .ddr2_dqs_n(ddr2_dqs_n),
               .ddr2_dqs_p(ddr2_dqs_p),
               .ddr2_addr(ddr2_addr),
               .ddr2_ba(ddr2_ba),
               .ddr2_ras_n(ddr2_ras_n),
               .ddr2_cas_n(ddr2_cas_n),
               .ddr2_we_n(ddr2_we_n),
               .ddr2_ck_p(ddr2_ck_p),
               .ddr2_ck_n(ddr2_ck_n),
               .ddr2_cke(ddr2_cke),
               .ddr2_cs_n(ddr2_cs_n),
               .ddr2_dm(ddr2_dm),
               .ddr2_odt(ddr2_odt),
`else
               .ddr3_dq(ddr3_dq),
               .ddr3_dqs_n(ddr3_dqs_n),
               .ddr3_dqs_p(ddr3_dqs_p),
               .ddr3_addr(ddr3_addr),
               .ddr3_ba(ddr3_ba),
               .ddr3_ras_n(ddr3_ras_n),
               .ddr3_cas_n(ddr3_cas_n),
               .ddr3_we_n(ddr3_we_n),
               .ddr3_ck_p(ddr3_ck_p),
               .ddr3_ck_n(ddr3_ck_n),
               .ddr3_reset_n(ddr3_reset_n),
               .ddr3_cke(ddr3_cke),
               .ddr3_cs_n(ddr3_cs_n),
               .ddr3_dm(ddr3_dm),
               .ddr3_odt(ddr3_odt),
`endif
               // output clk, rst (active-low)
               .o_clk(o_clk),
               .o_rst_x(o_rst_x),
               // user interface ports
               .i_rd_en(w_dram_le),
               .i_wr_en(i_wr_en),
               .o_init_calib_complete(o_init_calib_complete),
               .i_addr(w_dram_addr),
               .i_data(i_data),
               .o_data(w_dram_odata),
               .o_busy(w_dram_stall),
               .i_mask(~i_mask));
endmodule
`endif // SIM_MODE

/**************************************************************************************************/

/*** Single-port RAM with synchronous read                                                      ***/
module m_bram#(parameter WIDTH=32, ENTRY=256)(CLK, w_we, w_addr, w_idata, r_odata);
  input  wire                     CLK, w_we;
  input  wire [$clog2(ENTRY)-1:0] w_addr;
  input  wire         [WIDTH-1:0] w_idata;
  output reg          [WIDTH-1:0] r_odata;

  reg          [WIDTH-1:0]  mem [0:ENTRY-1];

  integer i;
  initial for (i=0;i<ENTRY;i=i+1) mem[i]=0;

  always  @(posedge  CLK)  begin
    if (w_we) mem[w_addr] <= w_idata;
    r_odata <= mem[w_addr];
  end
endmodule
/**************************************************************************************************/

/*** Dual-port RAM with synchronous read                                                        ***/
module m_bram2#(parameter WIDTH=32, ENTRY=256)
                (CLK, w_we, w_raddr, w_waddr, w_idata, w_odata1, w_odata2);
    input  wire                     CLK, w_we;
    input  wire [$clog2(ENTRY)-1:0] w_raddr, w_waddr;
    input  wire         [WIDTH-1:0] w_idata;
    output wire         [WIDTH-1:0] w_odata1, w_odata2;

    reg  [$clog2(ENTRY)-1:0] r_addr, r_addr2;

    reg          [WIDTH-1:0] mem [0:ENTRY-1];

    always  @(posedge  CLK)  begin
        if (w_we) mem[w_waddr] <= w_idata;
        r_addr2 <= w_waddr;
        r_addr <= w_raddr;
    end
    assign w_odata1 = mem[r_addr];
    assign w_odata2 = mem[r_addr2];
endmodule
/**************************************************************************************************/
/*** Single-port RAM with synchronous read with colum access                                    ***/
module m_col_bram#(parameter WIDTH=32, ENTRY=256)(CLK, w_we, w_addr, w_idata, w_odata);
    input  wire                     CLK;
    input  wire               [3:0] w_we;
    input  wire [$clog2(ENTRY)-1:0] w_addr;
    input  wire         [WIDTH-1:0] w_idata;
    output wire         [WIDTH-1:0] w_odata;

    //initial $readmemh(`MEMFILE, mem);

    (* ram_style = "block" *) reg [WIDTH-1:0] mem[0:ENTRY-1];
    reg [$clog2(ENTRY)-1:0] addr=0;
    always @(posedge CLK) begin
        if (w_we[0]) mem[w_addr][ 7: 0] <= w_idata[ 7: 0];
        if (w_we[1]) mem[w_addr][15: 8] <= w_idata[15: 8];
        if (w_we[2]) mem[w_addr][23:16] <= w_idata[23:16];
        if (w_we[3]) mem[w_addr][31:24] <= w_idata[31:24];
        addr <= w_addr;
    end
    assign w_odata = mem[addr];
endmodule
/**************************************************************************************************/
`ifndef SIM_MODE
module AsyncFIFO #(
			       parameter DATA_WIDTH  = 512,
			       parameter ADDR_WIDTH  = 8) // FIFO_DEPTH = 2^ADDR_WIDTH
    (
     input  wire                    wclk,
	 input  wire                    rclk,
     input  wire                    i_wrst_x,
     input  wire                    i_rrst_x,
	 input  wire                    i_wen,
	 input  wire [DATA_WIDTH-1 : 0] i_data,
     input  wire                    i_ren,
	 output wire [DATA_WIDTH-1 : 0] o_data,
	 output wire                    o_empty,
	 output wire                    o_full);

    reg  [DATA_WIDTH-1 : 0] afifo[(2**ADDR_WIDTH)-1 : 0];
    reg  [ADDR_WIDTH : 0]   waddr;
    reg  [ADDR_WIDTH : 0]   raddr;

    reg  [ADDR_WIDTH : 0]   raddr_gray1;
    reg  [ADDR_WIDTH : 0]   raddr_gray2;

    reg  [ADDR_WIDTH : 0]   waddr_gray1;
    reg  [ADDR_WIDTH : 0]   waddr_gray2;

    wire [DATA_WIDTH-1 : 0] data;

    wire [ADDR_WIDTH : 0]   raddr_gray;
    wire [ADDR_WIDTH : 0]   waddr_gray;

    wire [ADDR_WIDTH : 0]   raddr2;
    wire [ADDR_WIDTH : 0]   waddr2;

    genvar genvar_i;

    // output signals
    assign o_data  = data;
    assign o_empty = (raddr == waddr2);
    assign o_full  = (waddr[ADDR_WIDTH] != raddr2[ADDR_WIDTH]) &&
                     (waddr[ADDR_WIDTH-1 : 0] == raddr2[ADDR_WIDTH-1 : 0]);

    // binary code to gray code
    assign raddr_gray = raddr[ADDR_WIDTH : 0] ^ {1'b0, raddr[ADDR_WIDTH : 1]};
    assign waddr_gray = waddr[ADDR_WIDTH : 0] ^ {1'b0, waddr[ADDR_WIDTH : 1]};

    // gray code to binary code
    generate
	    for (genvar_i = 0; genvar_i <= ADDR_WIDTH; genvar_i = genvar_i + 1) begin
		    assign raddr2[genvar_i] = ^raddr_gray2[ADDR_WIDTH : genvar_i];
		    assign waddr2[genvar_i] = ^waddr_gray2[ADDR_WIDTH : genvar_i];
	    end
    endgenerate

    // double flopping read address before using it in write clock domain
    always @(posedge wclk) begin
	    if (!i_wrst_x) begin
		    raddr_gray1 <= 0;
		    raddr_gray2 <= 0;
	    end else begin
		    raddr_gray1 <= raddr_gray;
		    raddr_gray2 <= raddr_gray1;
	    end
    end

    // double flopping write address before using it in read clock domain
    always @(posedge rclk) begin
	    if (!i_rrst_x) begin
		    waddr_gray1 <= 0;
		    waddr_gray2 <= 0;
	    end else begin
		    waddr_gray1 <= waddr_gray;
		    waddr_gray2 <= waddr_gray1;
	    end
    end

    // read
    assign data = afifo[raddr[ADDR_WIDTH-1 : 0]];
    always @(posedge rclk) begin
	    if (!i_rrst_x) begin
		    raddr <= 0;
	    end else if (i_ren) begin
		    raddr <= raddr + 1;
	    end
    end

    // write
    always @(posedge wclk) begin
	    if (!i_wrst_x) begin
		    waddr <= 0;
	    end else if (i_wen) begin
		    afifo[waddr[ADDR_WIDTH-1 : 0]] <= i_data;
		    waddr <= waddr + 1;
	    end
    end

endmodule
`endif
/**************************************************************************************************/
/*** Simple Direct Mapped Cache Sync CLK for DRAM                                               ***/
/**************************************************************************************************/
module m_dram_cache#(parameter ADDR_WIDTH = 30, D_WIDTH = 32, ENTRY = 1024)
    (CLK, RST_X, w_flush, w_clr, w_we, w_addr, w_idata, w_odata, w_oe);
    input  wire                     CLK, RST_X;
    input  wire                     w_flush, w_we, w_clr;
    input  wire [ADDR_WIDTH-1:0]    w_addr;
    input  wire    [D_WIDTH-1:0]    w_idata;
    output wire    [D_WIDTH-1:0]    w_odata;
    output wire                     w_oe;             //output enable

    // index and tag
    reg  [$clog2(ENTRY)-1:0]                r_idx = 0;
    reg  [(ADDR_WIDTH - $clog2(ENTRY))-1:0] r_tag = 0;

    // index and tag
    wire                [$clog2(ENTRY)-1:0] w_idx;
    wire [(ADDR_WIDTH - $clog2(ENTRY))-1:0] w_tag;
    assign {w_tag, w_idx} = w_addr;

    wire                                            w_mwe = w_clr | w_we | !RST_X | w_flush;
    wire                      [$clog2(ENTRY)-1:0]   w_maddr = w_idx;
    wire [ADDR_WIDTH - $clog2(ENTRY) + D_WIDTH:0]   w_mwdata = w_we ? {1'b1, w_tag, w_idata} : 0;
    wire [ADDR_WIDTH - $clog2(ENTRY) + D_WIDTH:0]   w_modata;

    wire                                            w_mvalid;
    wire                     [$clog2(ENTRY)-1:0]    w_midx;
    wire      [(ADDR_WIDTH - $clog2(ENTRY))-1:0]    w_mtag;
    wire                           [D_WIDTH-1:0]    w_mdata;
    assign {w_mvalid, w_mtag, w_mdata} = w_modata;


    m_bram#((ADDR_WIDTH - $clog2(ENTRY) + D_WIDTH)+1, ENTRY)
        mem(CLK, w_mwe, w_maddr, w_mwdata, w_modata);

    assign w_odata  = w_mdata;
    assign w_oe     = (w_mvalid && w_mtag == r_tag);

    always  @(posedge  CLK)  begin
        r_tag <= w_tag;
        r_idx <= w_idx;
    end
endmodule // DMC
/**************************************************************************************************/

