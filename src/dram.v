/**************************************************************************************************/
/**** RVSoc (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** ALU Module v0.01                                                                         ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/
/*** For Nexys A7 board ***************************************************************************/
module DRAM_con_witout_cache #(
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
     output wire [127:0]                 o_data,
     output wire                         o_busy,
     input  wire [3:0]                   i_mask);

    wire                        mig_ui_clk;
    wire                        mig_ui_rst_x;
    wire                        clk;
    wire                        rst_x;

    wire                        dram_init_calib_complete;
    wire                        dram_ren;
    wire                        dram_wen;
`ifndef ARTYA7
    wire [APP_ADDR_WIDTH-2 : 0] dram_addr;
`else
    wire [APP_ADDR_WIDTH-1 : 0] dram_addr;
`endif
    wire [APP_DATA_WIDTH-1 : 0] dram_din;
    wire [APP_DATA_WIDTH-1 : 0] dram_dout;
    wire                        dram_dout_valid;
    wire                        dram_ready;
    wire                        dram_wdf_ready;

    reg                         wen_afifo1;
    reg  [68:0]                 din_afifo1;
    wire                        ren_afifo1;
    wire [68:0]                 dout_afifo1;
    wire                        empty_afifo1;
    wire                        full_afifo1;
    wire                        dout_afifo1_wr_en;
    wire [31:0]                 dout_afifo1_addr;
    wire [31:0]                 dout_afifo1_data;

    wire                        wen_afifo2;
    wire [127:0]                din_afifo2;
    wire                        ren_afifo2;
    wire [127:0]                dout_afifo2;
    wire                        empty_afifo2;

    reg                         dram_init_calib_complete_sync1;
    reg                         dram_init_calib_complete_sync2;

    reg [1:0]                   state;

    wire [3:0]                  data_mask;

    localparam STATE_CALIB = 2'b00;
    localparam STATE_IDLE  = 2'b01;
    localparam STATE_WRITE = 2'b10;
    localparam STATE_READ  = 2'b11;

    wire locked;
    wire rst_x_async;
    reg  rst_x_sync1;
    reg  rst_x_sync2;

    clk_wiz_1 clkgen1 (
                       .clk_in1(mig_ui_clk),
                       .resetn(mig_ui_rst_x),
                       .clk_out1(clk),
                       .locked(locked));

    assign rst_x_async = mig_ui_rst_x & locked;
    assign rst_x = rst_x_sync2;

    always @(posedge clk or negedge rst_x_async) begin
        if (!rst_x_async) begin
            rst_x_sync1 <= 1'b0;
            rst_x_sync2 <= 1'b0;
        end else begin
            rst_x_sync1 <= 1'b1;
            rst_x_sync2 <= rst_x_sync1;
        end
    end

    assign o_clk = clk;
    assign o_rst_x = rst_x;

    // synchronize the calibration status signal: MIG -> MIPS core
    always @(posedge clk) begin
        if (!rst_x) begin
            dram_init_calib_complete_sync1 <= 1'b0;
            dram_init_calib_complete_sync2 <= 1'b0;
        end else begin
            dram_init_calib_complete_sync1 <= dram_init_calib_complete;
            dram_init_calib_complete_sync2 <= dram_init_calib_complete_sync1;
        end
    end
    assign o_init_calib_complete = dram_init_calib_complete_sync2;

    // MIPS core -> MIG
    assign ren_afifo1 = (dram_ren || dram_wen);
    AsyncFIFO #(
                .DATA_WIDTH(69),
                .ADDR_WIDTH(2))
    afifo1 (
            .wclk(clk),
            .rclk(mig_ui_clk),
            .i_wrst_x(rst_x),
            .i_rrst_x(mig_ui_rst_x),
            .i_wen(wen_afifo1),
            .i_data(din_afifo1),
            .i_ren(ren_afifo1),
            .o_data(dout_afifo1),
            .o_empty(empty_afifo1),
            .o_full(full_afifo1));

    // MIG -> MIPS core
    assign wen_afifo2 = dram_dout_valid;
    assign din_afifo2 = dram_dout;
    assign ren_afifo2 = !empty_afifo2;
    AsyncFIFO #(
                .DATA_WIDTH(128),
                .ADDR_WIDTH(2))
    afifo2 (
            .wclk(mig_ui_clk),
            .rclk(clk),
            .i_wrst_x(mig_ui_rst_x),
            .i_rrst_x(rst_x),
            .i_wen(wen_afifo2),
            .i_data(din_afifo2),
            .i_ren(ren_afifo2),
            .o_data(dout_afifo2),
            .o_empty(empty_afifo2),
            .o_full());

    assign {dout_afifo1_wr_en, dout_afifo1_addr, dout_afifo1_data, data_mask} = dout_afifo1;
    assign dram_ren = (!empty_afifo1 && !dout_afifo1_wr_en && dram_ready);
    assign dram_wen = (!empty_afifo1 && dout_afifo1_wr_en && dram_ready && dram_wdf_ready);
`ifndef ARTYA7
    assign dram_addr = dout_afifo1_addr[26:1];
    assign dram_din = {{(APP_DATA_WIDTH-32){1'b0}}, dout_afifo1_data};
`else
    assign dram_addr = {2'b0, dout_afifo1_addr[26:4], 3'b0};
    assign dram_din = {4{dout_afifo1_data}};

    wire  [3:0] mask_t = ~data_mask;
    wire [15:0] mask_t2 = mask_t << {dout_afifo1_addr[3:2], 2'b0};
`endif
    DRAMController #(
`ifndef ARTYA7
                     .DDR2_DQ_WIDTH(DDR2_DQ_WIDTH),
                     .DDR2_DQS_WIDTH(DDR2_DQS_WIDTH),
                     .DDR2_ADDR_WIDTH(DDR2_ADDR_WIDTH),
                     .DDR2_BA_WIDTH(DDR2_BA_WIDTH),
                     .DDR2_DM_WIDTH(DDR2_DM_WIDTH),
`else
                     .DDR3_DQ_WIDTH(DDR3_DQ_WIDTH),
                     .DDR3_DQS_WIDTH(DDR3_DQS_WIDTH),
                     .DDR3_ADDR_WIDTH(DDR3_ADDR_WIDTH),
                     .DDR3_BA_WIDTH(DDR3_BA_WIDTH),
                     .DDR3_DM_WIDTH(DDR3_DM_WIDTH),
`endif
                     .APP_ADDR_WIDTH(APP_ADDR_WIDTH),
                     .APP_CMD_WIDTH(APP_CMD_WIDTH),
                     .APP_DATA_WIDTH(APP_DATA_WIDTH),
                     .APP_MASK_WIDTH(APP_MASK_WIDTH))
    dc (
        // input clk, rst (active-low)
        .sys_clk(mig_clk),
        .sys_rst_x(mig_rst_x),
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
        .o_clk(mig_ui_clk),
        .o_rst_x(mig_ui_rst_x),
        // user interface ports
        .i_rd_en(dram_ren),
        .i_wr_en(dram_wen),
`ifndef ARTYA7
        .i_addr({1'b0, dram_addr}),
`else
        .i_addr(dram_addr),
`endif
        .i_data(dram_din),
        .o_init_calib_complete(dram_init_calib_complete),
        .o_data(dram_dout),
        .o_data_valid(dram_dout_valid),
        .o_ready(dram_ready),
        .o_wdf_ready(dram_wdf_ready),
`ifndef ARTYA7
        .i_mask(data_mask));
`else
        .i_mask(~mask_t2));
`endif

    // state machine
    always @(negedge clk) begin
        if (!rst_x) begin
            state <= STATE_CALIB;
            wen_afifo1 <= 0;
            din_afifo1 <= 0;
        end else begin
            wen_afifo1 <= 0;
            din_afifo1 <= 0;
            case (state)
                STATE_CALIB: begin
                    if (o_init_calib_complete) begin
                        state <= STATE_IDLE;
                    end
                end
                STATE_IDLE: begin
                    if (i_wr_en) begin
                        state <= STATE_WRITE;
                        wen_afifo1 <= 1;
                        din_afifo1 <= {1'b1, i_addr, i_data, i_mask};
                    end else if (i_rd_en) begin
                        state <= STATE_READ;
                        wen_afifo1 <= 1;
                        din_afifo1 <= {1'b0, i_addr, i_data, 4'h0};
                    end
                end
                STATE_WRITE: begin
                    if (!full_afifo1) begin
                        state <= STATE_IDLE;
                    end
                end
                STATE_READ: begin
                    if (!empty_afifo2) begin
                        state <= STATE_IDLE;
                    end
                end
            endcase
        end
    end

    assign o_data = dout_afifo2;
    assign o_busy = (state != STATE_IDLE);

endmodule

/**************************************************************************************************/
module DRAMController #(
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
                        parameter APP_DATA_WIDTH  = 128,
                        parameter APP_MASK_WIDTH  = 16)
    (
     // input clk, rst (active-low)
     input  wire                         sys_clk,
     input  wire                         sys_rst_x,
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
     input  wire [APP_ADDR_WIDTH-1 : 0]  i_addr,
     input  wire [APP_DATA_WIDTH-1 : 0]  i_data,
     output wire                         o_init_calib_complete,
     output wire [APP_DATA_WIDTH-1 : 0]  o_data,
     output wire                         o_data_valid,
     output wire                         o_ready,
     output wire                         o_wdf_ready,
`ifndef ARTYA7
     input  wire [3:0]                   i_mask);
`else
     input  wire [APP_MASK_WIDTH-1 : 0]  i_mask);
`endif

    localparam STATE_CALIB           = 3'b000;
    localparam STATE_IDLE            = 3'b001;
    localparam STATE_ISSUE_CMD_WDATA = 3'b010;
    localparam STATE_ISSUE_CMD       = 3'b011;
    localparam STATE_ISSUE_WDATA     = 3'b100;

    localparam CMD_READ  = 3'b001;
    localparam CMD_WRITE = 3'b000;

    wire                        init_calib_complete;
    wire [APP_DATA_WIDTH-1 : 0] app_rd_data;
    wire                        app_rd_data_valid;
    wire                        app_rdy;
    wire                        app_wdf_rdy;

    wire                        clk;
    wire                        rst;

    reg  [APP_ADDR_WIDTH-1 : 0] app_addr;
    reg  [APP_CMD_WIDTH-1 : 0]  app_cmd;
    reg                         app_en;
    reg  [APP_DATA_WIDTH-1 : 0] app_wdf_data;
    reg                         app_wdf_wren;

    reg  [2:0]                  state;

`ifndef ARTYA7
    reg  [3:0]                  data_mask = 0;
`else
    reg  [APP_MASK_WIDTH-1 : 0] data_mask = 0;
`endif

    assign o_clk = clk;
    assign o_rst_x = ~rst;

    assign o_init_calib_complete = init_calib_complete;

    assign o_data = app_rd_data;
    assign o_data_valid = app_rd_data_valid;

    assign o_ready = app_rdy;
    assign o_wdf_ready = app_wdf_rdy;

    mig_7series_0 mig
      (
       // memory interface ports
`ifndef ARTYA7
       .ddr2_addr           (ddr2_addr),
       .ddr2_ba             (ddr2_ba),
       .ddr2_cas_n          (ddr2_cas_n),
       .ddr2_ck_n           (ddr2_ck_n),
       .ddr2_ck_p           (ddr2_ck_p),
       .ddr2_cke            (ddr2_cke),
       .ddr2_ras_n          (ddr2_ras_n),
       .ddr2_we_n           (ddr2_we_n),
       .ddr2_dq             (ddr2_dq),
       .ddr2_dqs_n          (ddr2_dqs_n),
       .ddr2_dqs_p          (ddr2_dqs_p),
       .ddr2_cs_n           (ddr2_cs_n),
       .ddr2_dm             (ddr2_dm),
       .ddr2_odt            (ddr2_odt),
`else
       .ddr3_addr           (ddr3_addr),
       .ddr3_ba             (ddr3_ba),
       .ddr3_cas_n          (ddr3_cas_n),
       .ddr3_ck_n           (ddr3_ck_n),
       .ddr3_ck_p           (ddr3_ck_p),
       .ddr3_reset_n        (ddr3_reset_n),
       .ddr3_cke            (ddr3_cke),
       .ddr3_ras_n          (ddr3_ras_n),
       .ddr3_we_n           (ddr3_we_n),
       .ddr3_dq             (ddr3_dq),
       .ddr3_dqs_n          (ddr3_dqs_n),
       .ddr3_dqs_p          (ddr3_dqs_p),
       .ddr3_cs_n           (ddr3_cs_n),
       .ddr3_dm             (ddr3_dm),
       .ddr3_odt            (ddr3_odt),
`endif
       // calibration
       .init_calib_complete (init_calib_complete),
       // application interface ports
       .app_addr            (app_addr),
       .app_cmd             (app_cmd),
       .app_en              (app_en),
       .app_wdf_data        (app_wdf_data),
       .app_wdf_end         (app_wdf_wren), // to simplify the user logic, app_wdf_end and app_wdf_wren are tied together
       .app_wdf_wren        (app_wdf_wren), // to ensure that they are always driven together
       .app_rd_data         (app_rd_data),
       .app_rd_data_end     (),
       .app_rd_data_valid   (app_rd_data_valid),
       .app_rdy             (app_rdy),
       .app_wdf_rdy         (app_wdf_rdy),
       .app_sr_req          (1'b0),
       .app_ref_req         (1'b0),
       .app_zq_req          (1'b0),
       .app_sr_active       (),
       .app_ref_ack         (),
       .app_zq_ack          (),
       .ui_clk              (clk),
       .ui_clk_sync_rst     (rst),
       .app_wdf_mask        ({{(APP_MASK_WIDTH-4){1'b1}}, data_mask}),
       // system clock, reset ports
       .sys_clk_i           (sys_clk),
`ifndef ARTYA7
       .sys_rst             (sys_rst_x));
`else
       .sys_rst             (sys_rst_x),
       .clk_ref_i           (ref_clk));
`endif

    always @(posedge clk) begin
        if (rst) begin
            state <= STATE_CALIB;
            app_cmd <= 0;
            app_addr <= 0;
            app_en <= 0;
            app_wdf_data <= 0;
            app_wdf_wren <= 0;
            data_mask <= 0;
        end else begin
            case (state)
                STATE_CALIB: begin
                    if (init_calib_complete) begin
                        state <= STATE_IDLE;
                    end
                end
                STATE_IDLE: begin
                    if (i_wr_en) begin
                        app_cmd <= CMD_WRITE;
                        app_addr <= i_addr;
                        app_en <= 1;
                        app_wdf_data <= i_data;
                        app_wdf_wren <= 1;
                        state <= STATE_ISSUE_CMD_WDATA;
                        data_mask <= i_mask;
			`ifdef SIM_MAIN
			$display("STATE_IDLE app_cmd = CMD_WRITE, i_addr=%h i_data=%h i_mask=%h", i_addr, i_data, i_mask);
			`endif
                    end else if (i_rd_en) begin
                        app_wdf_wren <= 0;
                        app_cmd <= CMD_READ;
                        app_addr <= i_addr;
                        app_en <= 1;
                        state <= STATE_ISSUE_CMD;
                        data_mask <= 0;
			`ifdef SIM_MAIN
			$display("STATE_IDLE app_cmd = CMD_READ, i_addr=%h", i_addr);
			`endif
                    end
                end
                STATE_ISSUE_CMD_WDATA: begin
                    if (app_rdy && app_wdf_rdy) begin
                        if (i_wr_en) begin
                            app_cmd <= CMD_WRITE;
                            app_addr <= i_addr;
                            app_en <= 1;
                            app_wdf_data <= i_data;
                            app_wdf_wren <= 1;
                            state <= STATE_ISSUE_CMD_WDATA;
                            data_mask <= i_mask;
			    `ifdef SIM_MAIN
			    $display("STATE_ISSUE_CMD_WDATA app_cmd = CMD_WRITE, i_addr=%h i_data=%h i_mask=%h", i_addr, i_data, i_mask);
			    `endif
                        end else if (i_rd_en) begin
                            app_wdf_wren <= 0;
                            app_cmd <= CMD_READ;
                            app_addr <= i_addr;
                            app_en <= 1;
                            state <= STATE_ISSUE_CMD;
                            data_mask <= 0;
			    `ifdef SIM_MAIN
			    $display("STATE_ISSUE_CMD_WDATA app_cmd = CMD_READ, i_addr=%h", i_addr);
			    `endif
                        end else begin
                            app_en <= 0;
                            app_wdf_wren <= 0;
                            state <= STATE_IDLE;
			    `ifdef SIM_MAIN
			    if(app_rd_data_valid)
			    	$display("STATE_ISSUE_CMD_WDATA app_rd_data=%h", app_rd_data);
			    `endif
                        end
                    end else if (app_rdy) begin
                        app_en <= 0;
                        state <= STATE_ISSUE_WDATA;
                    end else if (app_wdf_rdy) begin
                        app_wdf_wren <= 0;
                        state <= STATE_ISSUE_CMD;
                    end
                end
                STATE_ISSUE_CMD: begin
                    if (app_rdy) begin
                        if (i_wr_en) begin
                            app_cmd <= CMD_WRITE;
                            app_addr <= i_addr;
                            app_en <= 1;
                            app_wdf_data <= i_data;
                            app_wdf_wren <= 1;
                            state <= STATE_ISSUE_CMD_WDATA;
                            data_mask <= i_mask;
			    `ifdef SIM_MAIN
			    $display("STATE_ISSUE_CMD app_cmd = CMD_WRITE, i_addr=%h i_data=%h i_mask=%h", i_addr, i_data, i_mask);
			    `endif
                        end else if (i_rd_en) begin
                            app_wdf_wren <= 0;
                            app_cmd <= CMD_READ;
                            app_addr <= i_addr;
                            app_en <= 1;
                            state <= STATE_ISSUE_CMD;
                            data_mask <= 0;
			    `ifdef SIM_MAIN
			    $display("STATE_ISSUE_CMD app_cmd = CMD_READ, i_addr=%h", i_addr);
			    `endif
                        end else begin
                            app_en <= 0;
                            app_wdf_wren <= 0;
                            state <= STATE_IDLE;
			    `ifdef SIM_MAIN
			    if(app_rd_data_valid)
                                $display("STATE_ISSUE_CMD app_rd_data=%h", app_rd_data);
			    `endif
                        end
                    end
                end
                STATE_ISSUE_WDATA: begin
                    if (app_wdf_rdy) begin
                        if (i_wr_en) begin
                            app_cmd <= CMD_WRITE;
                            app_addr <= i_addr;
                            app_en <= 1;
                            app_wdf_data <= i_data;
                            app_wdf_wren <= 1;
                            state <= STATE_ISSUE_CMD_WDATA;
                            data_mask <= i_mask;
			    `ifdef SIM_MAIN
			    $display("STATE_ISSUE_CMD_WDATA app_cmd = CMD_WRITE, i_addr=%h i_data=%h i_mask=%h", i_addr, i_data, i_mask);
			    `endif
                        end else if (i_rd_en) begin
                            app_wdf_wren <= 0;
                            app_cmd <= CMD_READ;
                            app_addr <= i_addr;
                            app_en <= 1;
                            state <= STATE_ISSUE_CMD;
                            data_mask <= 0;
			    `ifdef SIM_MAIN
			    $display("STATE_ISSUE_CMD_WDATA app_cmd = CMD_READ, i_addr=%h", i_addr);
			    `endif
                        end else begin
                            app_wdf_wren <= 0;
                            state <= STATE_IDLE;
			    `ifdef SIM_MAIN
			    if(app_rd_data_valid)
                                $display("STATE_ISSUE_WDATA app_rd_data=%h", app_rd_data);
			    `endif
                        end
                    end
                end
                default: begin
                    app_en <= 0;
                    app_wdf_wren <= 0;
                    state <= STATE_IDLE;
                end
            endcase
        end
    end

endmodule
/**************************************************************************************************/
