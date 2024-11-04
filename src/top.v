/* Modified by Laurentiu-Cristian Duca, 2021-12-20
 * - memory model similar to dram memory controller with DRAM_SIM
 * or simple memory model
 * - debug with RAM_DEBUG
 * - allow ICARUS simulation
 */
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** top module and simulation module v0.01                                                   ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/
`ifdef ICARUS
module m_topsim();
    reg CLK = 0;
    reg RST_X;

    initial forever #50 CLK = ~CLK;

    initial begin
        #50  RST_X = 0;
        #300 RST_X = 1;
    end

    initial begin
	$dumpfile("signals.vcd");
        $dumpvars(0, m_topsim);
    end
`else
module m_topsim(input wire CLK, input wire RST_X);
`endif

    wire w_halt;

    wire w_finish;

    wire [31:0] w_insn_data, w_insn_addr;
    wire [31:0] w_data_data, w_data_wdata, w_data_addr;
    wire        w_data_we;
    wire [2:0]  w_data_ctrl;

    wire [31:0] w_priv, w_satp, w_mstatus;
    wire [63:0] w_mtime, w_mtimecmp, w_wmtimecmp;
    wire        w_clint_we;
    wire [31:0] w_mip, w_wmip;
    wire        w_plic_we;
    wire        w_busy;
    wire [31:0] w_pagefault;
    wire [1:0]  w_tlb_req;
    wire        w_tlb_flush;
    wire        w_txd;
    wire        w_rxd;
    wire        w_init_done;
    wire        w_init_stage;

    wire        CORE_RST_X = RST_X & w_init_done;

`ifndef ARTYA7
    wire [15:0] ddr2_dq;
    wire [1:0]  ddr2_dqs_n;
    wire [1:0]  ddr2_dqs_p;
    wire [12:0] ddr2_addr;
    wire [2:0]  ddr2_ba;
    wire        ddr2_ras_n;
    wire        ddr2_cas_n;
    wire        ddr2_we_n;
    wire        ddr2_ck_p;
    wire        ddr2_ck_n;
    wire        ddr2_cke;
    wire        ddr2_cs_n;
    wire [1:0]  ddr2_dm;
    wire        ddr2_odt;
`else
    wire ref_clk;
    wire [15:0] ddr3_dq;
    wire [1:0]  ddr3_dqs_n;
    wire [1:0]  ddr3_dqs_p;
    wire [13:0] ddr3_addr;
    wire [2:0]  ddr3_ba;
    wire        ddr3_ras_n;
    wire        ddr3_cas_n;
    wire        ddr3_we_n;
    wire        ddr3_ck_p;
    wire        ddr3_ck_n;
    wire        ddr3_reset_n;
    wire        ddr3_cke;
    wire        ddr3_cs_n;
    wire [1:0]  ddr3_dm;
    wire        ddr3_odt;
`endif

    wire [7:0]  w_uart_data;
    wire        w_uart_we;

    wire [15:0] w_led;

    /**********************************************************************************************/

    reg       r_uart_busy  = 0;
    reg [3:0] r_uart_count = 0;
    reg [3:0] r_uart_cycle = 0;
    reg [7:0] r_uart_data  = 0;

`ifdef USE_UART
    always@(posedge CLK) begin
        if (w_init_done) begin
            if (!r_uart_busy && !w_txd) begin
                r_uart_busy  <= 1;
                r_uart_data  <= 0;
                r_uart_count <= 0;
                r_uart_cycle <= 1;
            end else if (r_uart_busy && (r_uart_count == 8) && w_txd) begin
                r_uart_count <= 0;
                r_uart_busy  <= 0;
                r_uart_cycle <= 0;
                $write("%c", r_uart_data);
    `ifndef VERILATOR
                $fflush();
    `endif
            end else if (r_uart_busy && (r_uart_cycle == 8)) begin
                r_uart_count <= r_uart_count + 1;
                r_uart_cycle <= 1;
            end else if (r_uart_busy && (r_uart_cycle == 4) && (r_uart_count > 0)) begin
                r_uart_cycle <= r_uart_cycle + 1;
                r_uart_data  <= {w_txd,r_uart_data[7:1]};
            end else if (r_uart_busy) begin
                r_uart_cycle <= r_uart_cycle + 1;
            end
        end
    end
`else
    always@(posedge CLK) begin
        if(w_uart_we) begin
            $write("%c", w_uart_data);
    `ifndef VERILATOR
            $fflush();
    `endif
        end
    end
`endif

    wire [2:0] w_init_state;
    wire w_pl_init_we;

    /**********************************************************************************************/
    m_mmu mmu(
        .CLK            (CLK),
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
        .mig_clk        (1'b0),
        .mig_rst_x      (1'b0),
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
	.ref_clk        (ref_clk),
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
        .o_clk          (),
        .o_rst_x        (),
        .w_uart_data    (w_uart_data),
        .w_uart_we      (w_uart_we),
        .w_led          (w_led),
        .w_init_stage   (w_init_stage),
        .w_checksum     (),
        .w_debug_btnd   (1'b0),
	.w_init_state   (w_init_state),
	.w_pl_init_we   (w_pl_init_we)
    );

    m_RVCoreM p(
        .CLK            (CLK),
        .RST_X          (CORE_RST_X),
        .w_stall        (1'b0),
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
        .w_core_pc      (),
        .w_core_ir      (),
        .w_core_odata   (),
        .w_init_stage   (w_init_stage)
    );

    /**********************************************************************************************/
    always@(posedge CLK) if (w_halt) begin $write("HALT detect! at PC:%x\n", p.pc); $finish(); end
    reg r_finish = 0;
    always@(posedge CLK) r_finish <= w_finish;
    always@(posedge CLK) if (r_finish & !r_uart_busy) begin
        $write("FINISH!\n");
`ifdef DEBUG
        if (p.mtime < 90000001) $fclose(fp);
`endif
        $finish();
    end

    // LOAD
    integer i,j;
    //integer k;
    reg  [7:0] mem_bbl [0:`BBL_SIZE-1];
    reg  [7:0] mem_mc[0:`MC_MEM_SIZE-1];
    reg  [7:0] mem_disk[0:`DISK_SIZE-1];
    initial begin
`ifndef VERILATOR
    #1
`endif
`ifdef LINUX
        /*$write("Load micro-ctrl program: %s\n", `MC_PROG);
        $readmemh(`MC_PROG, mem_mc);
        j=0;

        for(i=0;i<`MC_MEM_SIZE;i=i+4) begin
            mmu.mc.LCMEM.mem1.mem[j]=mem_mc[i];
            mmu.mc.LCMEM.mem2.mem[j]=mem_mc[i+1];
            mmu.mc.LCMEM.mem3.mem[j]=mem_mc[i+2];
            mmu.mc.LCMEM.mem4.mem[j]=mem_mc[i+3];
            j=j+1;
        end*/
        $write("Load image file: %s\n", `IMAGE_FILE);
        $readmemh(`IMAGE_FILE, mem_disk);
        //j=`BBL_SIZE/4;
        j=`BBL_SIZE;

        /*for(i=0;i<`DISK_SIZE;i=i+4) begin
            mmu.idbmem.idbmem.mem1.mem[j]=mem_disk[i];
            mmu.idbmem.idbmem.mem2.mem[j]=mem_disk[i+1];
            mmu.idbmem.idbmem.mem3.mem[j]=mem_disk[i+2];
            mmu.idbmem.idbmem.mem4.mem[j]=mem_disk[i+3];
            j=j+1;
        end*/
        for(i=0;i<`DISK_SIZE;i=i+1) begin
`ifdef SKIP_CACHE
	    mmu.idbmem.idbmem.mem[j]=mem_disk[i];
`else
	    mmu.idbmem.cache_ctrl.idbmem.mem[j]=mem_disk[i];
`endif
            j=j+1;
        end
`endif
        $write("Running %s\n", {`HEX_DIR,`HEXFILE});
        $readmemh({`HEX_DIR,`HEXFILE}, mem_bbl);
        j=0;

        /*for(i=0;i<`BBL_SIZE;i=i+4) begin
            mmu.idbmem.idbmem.mem1.mem[j]=mem_bbl[i];
            mmu.idbmem.idbmem.mem2.mem[j]=mem_bbl[i+1];
            mmu.idbmem.idbmem.mem3.mem[j]=mem_bbl[i+2];
            mmu.idbmem.idbmem.mem4.mem[j]=mem_bbl[i+3];
            j=j+1;
        end*/
        for(i=0;i<`BBL_SIZE;i=i+1) begin
`ifdef SKIP_CACHE
            mmu.idbmem.idbmem.mem[j]=mem_bbl[i];
`else
	    mmu.idbmem.cache_ctrl.idbmem.mem[j]=mem_bbl[i];
`endif
            j=j+1;
        end
        $write("-------------------------------------------------------------------\n");
    end

/**********************************************************************************************/

`ifdef RAM_DEBUG
reg [31:0] o_pc=-1, o_ir=-1, bbl_cnt=0;
always @(posedge CLK)
begin
	if(	(p.r_cpc[31:30] == 3) && (((mmu.idbmem.r_ctrl==1) && (mmu.idbmem.r_mask==8)) || 
			(mmu.idbmem.r_ctrl==3 && (mmu.idbmem.r_mask!=15)))
	       		&&
		((o_pc != p.r_cpc) || (o_ir != p.r_ir)) && (bbl_cnt < 20)) begin
		o_pc <= p.r_cpc;
		o_ir <= p.r_ir;
		bbl_cnt <= bbl_cnt + 1;
		$write("%08d pc=%08x ir=%08x r_addr=%08x %19x odata=%x ctrl=%x mask=%x\n",
                	p.mtime[31:0], p.r_cpc, p.r_ir,
	                mmu.idbmem.r_addr, 
			mmu.idbmem.w_odata_aux, mmu.idbmem.w_odata, 
			mmu.idbmem.r_ctrl, mmu.idbmem.r_mask);
	end
end
`endif

//`define DEBUG_MEMMOVE
`ifdef DEBUG_MEMMOVE
//`define ADDR_MEMMOVE_START 32'h80002942
`define ADDR_MEMMOVE_START 32'hc02b3330
//`define ADDR_WORD_COPY 32'h8000296a
`define ADDR_WORD_COPY 32'hc02b334e
//`define ADDR_MEMMOVE_STOP 32'h800029e2
`define ADDR_MEMMOVE_STOP 32'hc02b339c
//`define TEXT_ADDR 32'h8000bd84
`define TEXT_ADDR 32'hc0c000d0
`define STRLEN_TEXT 170

//`define ADDR_MEMMOVE_START 32'h80002934
//`define ADDR_WORD_COPY 32'h8000295c
//`define ADDR_MEMMOVE_STOP 32'h800029d4
//`define TEXT_ADDR 32'h8000bdf8
//`define STRLEN_TEXT 53
reg [31:0] old_pc=0, t3;
reg [7:0] a0,a1,a2,a3;
always @(posedge CLK)
begin
    if((p.r_cpc >= `ADDR_MEMMOVE_START) && (p.r_cpc <= `ADDR_MEMMOVE_STOP) && 
	    ((old_pc != p.r_cpc) || (p.regs.mem[28] != t3))) begin
        old_pc <= p.r_cpc;
	t3 <= p.regs.mem[28];
        $write("%08d %08x %08x mem addr: %08x %08x %16x %1x %8x\n", 
		p.mtime[31:0], p.r_cpc, p.r_ir, 
		mmu.idbmem.idbmem.w_addr, mmu.idbmem.r_addr,
		mmu.idbmem.r_odata, mmu.idbmem.r_addr[3:0], mmu.idbmem.w_odata_t);
        // REGSTATE
        for(i=0;i<32;i=i+1)
	    if((p.regs.mem[i] != 32'd0) || (i == 7))
	    if((i >= 5) && (i <= 7))
		$write("t%1d=%x ", i-5, p.regs.mem[i]);
	    else if((i >= 28)) begin
  	        if((i == 28) && (p.r_cpc >= `ADDR_WORD_COPY)) begin // 32'h20 = ' '
		    $write("t3=%c%c%c%c=%x ", 
			    (p.regs.mem[i] >> 24) >= 32'h20 ? (p.regs.mem[i] >> 24) : 32'h20, 
			    ((p.regs.mem[i] >> 16) & 8'hff) >= 32'h20 ? ((p.regs.mem[i] >> 16) & 8'hff) : 32'h20, 
			    ((p.regs.mem[i] >> 8) & 8'hff) >= 32'h20 ? ((p.regs.mem[i] >> 8) & 8'hff) : 32'h20,
			    (p.regs.mem[i] & 8'hff) >= 32'h20 ? (p.regs.mem[i] & 8'hff) : 32'h20, 
			    p.regs.mem[i]);
		end else
		    $write("t%1d=%x ", i-28+3, p.regs.mem[i]);
            end
	    else if((i >= 10) && (i <= 17))
                $write("a%1d=%x ", i-10, p.regs.mem[i]);
	    else
		$write("R[%2d]=%x ", i, p.regs.mem[i]);
        $write("\n");
	$write("mem[%x]: ", `TEXT_ADDR);
        for(i=(`TEXT_ADDR & 32'h3ffffff);i<((`TEXT_ADDR+`STRLEN_TEXT)&32'h3ffffff);i=i+1)
            $write("%c", mmu.idbmem.idbmem.mem[i]);//, mmu.idbmem.idbmem.mem[i]);
        $write("\n");
    end
end
`endif //DEBUG_MEMMOVE
/**********************************************************************************************/

`ifdef DEBUG
    `ifndef TRACE
    integer fp;
    initial begin
        fp=$fopen("log.txt","w");
        if(fp == 0)begin
            $display("File Open Error!!!!!");
            $finish();
        end
    end
    `else
        `ifdef LINUX
    integer fp;
    initial begin
        fp=$fopen("log_00M_10M.txt","w");
        if(fp == 0)begin
            $display("File Open Error!!!!!");
            $finish();
        end
    end

    always@(posedge CLK) begin
        if(p.state == `S_INI && !p.w_busy) begin
            if(p.mtime == 10000001) begin
                $fclose(fp);
                fp=$fopen("log_10M_20M.txt","w");
            end
            else if (p.mtime == 20000001) begin
                $fclose(fp);
                fp=$fopen("log_20M_30M.txt","w");
            end
            else if (p.mtime == 30000001) begin
                $fclose(fp);
                fp=$fopen("log_30M_40M.txt","w");
            end
            else if (p.mtime == 40000001) begin
                $fclose(fp);
                fp=$fopen("log_40M_50M.txt","w");
            end
            else if (p.mtime == 50000001) begin
                $fclose(fp);
                fp=$fopen("log_50M_60M.txt","w");
            end
            else if (p.mtime == 60000001) begin
                $fclose(fp);
                fp=$fopen("log_60M_70M.txt","w");
            end
            else if (p.mtime == 70000001) begin
                $fclose(fp);
                fp=$fopen("log_70M_80M.txt","w");
            end
            else if (p.mtime == 80000001) begin
                $fclose(fp);
                fp=$fopen("log_80M_90M.txt","w");
            end
            else if (p.mtime == 90000001) begin
                $fclose(fp);
            end

            if(fp == 0)begin
                $display("File Open Error!!!!!");
                $finish();
            end
        end
    end
        `else
    integer fp;
    initial begin
        fp=$fopen("log.txt","w");
        if(fp == 0)begin
            $display("File Open Error!!!!!");
            $finish();
        end
    end
        `endif
    `endif
`endif

    reg [31:0] r_cnt = 0;
    always@(posedge CLK) begin
        r_cnt <= r_cnt + 1;
        if(p.mtime > `TIMEOUT) begin
            $write("Simulation Time out...\n");
`ifdef MEM_DUMP
            $fclose(fp);
            fp=$fopen("final_mem.txt","w");
            if(fp == 0)begin
                $display("File Open Error!!!!! in final_mem!");
                $finish();
            end
            j=0;
            for(i=0;i<`BBL_SIZE;i=i+4) begin
                $fwrite(fp,"%x\n",mmu.idbmem.mem1.mem[j]);
                $fwrite(fp,"%x\n",mmu.idbmem.mem2.mem[j]);
                $fwrite(fp,"%x\n",mmu.idbmem.mem3.mem[j]);
                $fwrite(fp,"%x\n",mmu.idbmem.mem4.mem[j]);
                j=j+1;
            end
            $fclose(fp);
`endif
            $finish();
        end

`ifdef DEBUG
        // EXEC STATE
        if(p.state == `S_FIN && !p.w_busy) begin
            if(p.mtime % 1000000 == 0) begin
                $write("MTIME=%09d %d\n", p.mtime[31:0], p.mtimecmp);
    `ifndef VERILATOR
                $fflush();
    `endif
            end
`ifdef TRACE
            $fwrite(fp, "%08d %08x %08x\n", p.mtime[31:0], p.r_cpc, p.r_ir);
            // REGSTATE
            for(i=0;i<4;i=i+1) begin
                for(j=0;j<8;j=j+1) begin
                    $fwrite(fp, "%08x",p.regs.mem[i*8+j]);
                    if(j==7)    $fwrite(fp, "\n");
                    else        $fwrite(fp, " ");
                end
            end
`ifdef LINUX
            // CSR STATE
    `ifndef VERILATOR
            #1
    `endif
            $fwrite(fp, "%08x %08x %08x %08x %08x %08x %08x %08x \n", p.mstatus, p.mtvec, p.mscratch, p.mepc, p.mcause, p.mtval, p.mhartid, p.misa);
            $fwrite(fp, "%08x %08x %08x %08x %08x %08x %08x %08x \n", p.mie, p.mip, p.medeleg, p.mideleg, p.mcounteren, p.stvec, p.sscratch, p.sepc);
            $fwrite(fp, "%08x %08x %08x %08x %08x %08x %08x %08x \n", p.scause, p.stval, p.satp, p.scounteren, p.load_res, p.pending_exception, p.pending_tval, {30'h0,p.priv});
            
            //TLB
            for(i=0;i<4;i=i+1) begin
                $fwrite(fp, "%08x %08x ", (mmu.TLB_inst_r.r_valid[i]) ? {mmu.TLB_inst_r.mem[i][39:22], i[1:0], 12'b0} : 32'hffffffff, (mmu.TLB_inst_r.r_valid[i]) ? {mmu.TLB_inst_r.mem[i][21:0], 10'b0} : 32'hffffffff);
            end
            $fwrite(fp,"\n");
            for(i=0;i<4;i=i+1) begin
                $fwrite(fp, "%08x %08x ", (mmu.TLB_data_r.r_valid[i]) ? {mmu.TLB_data_r.mem[i][39:22], i[1:0], 12'b0} : 32'hffffffff, (mmu.TLB_data_r.r_valid[i]) ? {mmu.TLB_data_r.mem[i][21:0], 10'b0} : 32'hffffffff);
            end
            $fwrite(fp,"\n");
            for(i=0;i<4;i=i+1) begin
                $fwrite(fp, "%08x %08x ", (mmu.TLB_data_w.r_valid[i]) ? {mmu.TLB_data_w.mem[i][39:22], i[1:0], 12'b0} : 32'hffffffff, (mmu.TLB_data_w.r_valid[i]) ? {mmu.TLB_data_w.mem[i][21:0], 10'b0} : 32'hffffffff);
            end
            $fwrite(fp,"\n");
`endif
`endif
`ifdef PC_TRACE
            if(p.mtime % 1000 == 0) begin
                $fwrite(fp, "%08d %08x\n", (p.mtime[31:0]/1000), p.r_cpc);
    `ifndef VERILATOR
                $fflush(fp);
    `endif
            end
`endif

        end
`endif
    end
`ifdef MIDDLE
    initial begin
        #300
        `include `REGFILE
    end
`endif

`ifdef STATE
    always@(posedge CLK) begin
        case(p.state)
            `S_INI: $write("state: S_INI");
            `S_IF : $write("state: S_IF ");
            `S_CVT: $write("state: S_CVT");
            `S_ID : $write("state: S_ID ");
            `S_OF : $write("state: S_OF ");
            `S_EX1: $write("state: S_EX1");
            `S_LD : $write("state: S_LD ");
            `S_EX2: $write("state: S_EX2");
            `S_SD : $write("state: S_SD ");
            `S_WB : $write("state: S_WB ");
            `S_COM: $write("state: S_COM");
            `S_FIN: $write("state: S_FIN");
            default: $write("state: UNKNOWN");
        endcase
        if(p.r_com[2]) $write("  exception");
        if(p.r_com[1]) $write("  pagefault");
        if(p.r_com[0]) $write("  ecall");
        $write("\n");
        if(p.state == `S_FIN && !p.w_busy) begin
            $write("%08d %08x %08x\n", p.mtime[31:0], p.r_cpc, p.r_ir);
            $write("--------------------------\n");
        end
    end
`endif

    /**********************************************************************************************/

    wire init_txd, tx_ready;

    reg [7:0]   uartdata = 0;
    reg         uartwe   = 0;
    reg [16:0]  imemaddr = 0;

    always@(posedge CLK) begin
        if(r_cnt > 10 && tx_ready && !uartwe) begin
            uartdata <= mem_bbl[imemaddr];
            imemaddr <= imemaddr + 1;
            uartwe   <= 1;
        end else begin
            uartwe   <= 0;
            uartdata <= 0;
        end
    end

    UartTx UartTx_init(CLK, RST_X, uartdata, uartwe, init_txd, tx_ready);

    assign w_rxd = init_txd;

endmodule

/**************************************************************************************************/
/**** Byte unit BRAM Main Memory module with LATENCY for simulation (1-port)                   ****/
/**************************************************************************************************/
`ifdef DRAM_SIM
module m_bu_mem #(parameter MEM_SIZE = `MEM_SIZE)
            (CLK, w_addr, w_odata, w_we, w_le, w_wdata, w_ctrl, w_stall, w_mask);
    input  wire             CLK;
    input  wire [31:0] w_addr;
    output wire [127:0] w_odata;
    input  wire w_we, w_le;
    input  wire [31:0] w_wdata;
    input  wire [2:0] w_ctrl;
    output wire w_stall;
    // active 0 mask
    input wire [3:0] w_mask;

    reg   [7:0] mem [0:MEM_SIZE-1];

    reg [7:0] state=0;
    reg r_stall=0;
    assign w_stall = r_stall;
    reg [31:0] r_addr;
    reg [31:0] r_wdata;
    reg [127:0] r_odata=0, r_odata_aux=0;
    reg [3:0] r_mask;
    assign w_odata=r_odata;
    reg [7:0] r_cnt;
    `ifdef RAM_DEBUG
    reg r_was_read=0, r_was_write=0;
    reg r_last_addr=1;
    reg [31:0] rd_cnt=20;
    `endif
    always @(posedge CLK) begin
	case(state)
	8'd0: begin // idle
		if(w_le) begin
                        state <= 10;
                        r_stall <= 1;
                        r_addr <= w_addr;
			r_odata_aux <= 
			   {mem[w_addr+15], mem[w_addr+14], mem[w_addr+13], mem[w_addr+12],
                            mem[w_addr+11], mem[w_addr+10], mem[w_addr+9],  mem[w_addr+8],
                            mem[w_addr+7],  mem[w_addr+6],  mem[w_addr+5],  mem[w_addr+4],
                            mem[w_addr+3],  mem[w_addr+2],  mem[w_addr+1],  mem[w_addr+0]};
                end else if(w_we) begin
                        state <= 20;
                        r_stall <= 1;
                        r_addr <= w_addr;
                        r_wdata <= w_wdata;
			r_mask <= w_mask;
                end
	end
	8'd10: begin
		r_odata <= r_odata_aux;
		`ifdef RAM_DEBUG
		r_was_read <= 1;
                `endif
		r_cnt <= 0;
		state <= 100;
	end
	8'd20: begin
		if(!r_mask[0]) begin
			mem[r_addr] <= r_wdata;
		end
		if(!r_mask[1]) begin
			mem[r_addr+1] <= r_wdata >> 8;
		end
		if(!r_mask[2]) begin
                        mem[r_addr+2] <= r_wdata >> 16;
		end
		if(!r_mask[3]) begin
                        mem[r_addr+3] <= r_wdata >> 24;
		end
		`ifdef RAM_DEBUG
		r_was_write <= 1;
		`endif
		r_cnt <= 0;
		state <= 100;
	end
	8'd100: begin
		if(r_cnt <= `LATENCY)
			r_cnt <= r_cnt + 1;
		else begin
			`ifdef RAM_DEBUG
			rd_cnt <= rd_cnt + 1;
			if(rd_cnt < 20) begin
				if(r_was_read && (r_last_addr != r_addr))
					$display("RAM read: mem[%x] is %x", r_addr, r_odata);
				if(r_was_write && (r_last_addr != r_addr))
					$display("RAM write: mem[%x] <= %x", r_addr, {mem[r_addr+3], mem[r_addr+2], mem[r_addr+1], mem[r_addr]});
			end
			`endif
			state <= 110;
		end
	end
	8'd110: begin
		`ifdef RAM_DEBUG
		r_was_read <= 0;
		r_was_write <= 0;
		r_last_addr <= r_addr;
		`endif
		state <= 0;
		r_stall <= 0;
	end
	endcase
    end

endmodule
/**************************************************************************************************/
/**** BRAM Wrapper for simulation (1-port)                                                     ****/
/**************************************************************************************************/
// template from memory.v
module m_dram_sim#(parameter MEM_SIZE = `MEM_SIZE)(
     input wire                         o_clk,
     input  wire [31:0]                  i_addr,
     output wire [31:0]                  o_data,
     input  wire                         i_wr_en,
     input  wire                         i_rd_en,
     input  wire [31:0]                  i_data,
     input  wire [2:0]                   i_ctrl,
     output wire                         o_busy,
     input wire [31:0]                   w_mtime);

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

    // 16+3 bytes shifted with r_addr[3:0]*8 bits
    wire[151:0] w_odata_aux = {r_dram_odata2, r_dram_odata1} >> {r_addr[3:0], 3'b0};
    wire[31:0] w_odata = w_odata_aux[31:0];
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
    `ifdef RAM_DEBUG
    reg r_was_read=0, r_was_write=0;
    reg [31:0] rd_cnt=20;
    `endif
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
			`ifdef RAM_DEBUG
			r_was_read <= 1;
			`endif
                end else if(i_wr_en && !w_busy) begin
			state <= 20;
                        r_stall <= 1;
			r_addr <= i_addr;
                        r_maddr <= {i_addr[31:2], 2'b0};
                        r_wdata_ui <= (i_ctrl[1:0] == 0) ? {24'h0, i_data[7:0]} :
                                   (i_ctrl[1:0] == 1) ? {16'h0, i_data[15:0]} : i_data;
                        r_ctrl <= i_ctrl;
			`ifdef RAM_DEBUG
			r_was_write <= 1;
			`endif
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
		`ifdef RAM_DEBUG
		r_was_read <= 0;
		r_was_write <= 1;
`ifdef SKIP_CACHE
		if(r_was_read && (w_odata != {idbmem.mem[r_addr+3], idbmem.mem[r_addr+2], idbmem.mem[r_addr+1], idbmem.mem[r_addr]}))
			$display("MEM BUG: r_addr=%x w_odata=%x != %x", r_addr, w_odata, {idbmem.mem[r_addr+3], idbmem.mem[r_addr+2], idbmem.mem[r_addr+1], idbmem.mem[r_addr]});
`else
`endif
		`endif
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
    m_bu_mem#(MEM_SIZE) idbmem(.CLK(o_clk), .w_addr(r_maddr), .w_odata(w_dram_odata),
                               .w_we(r_we), .w_le(r_rd), .w_wdata(r_wdata), .w_ctrl(r_ctrl), .w_stall(w_busy), .w_mask(~r_mask));
`else
    cache_ctrl#(MEM_SIZE) cache_ctrl(.o_clk(o_clk), .i_rd_en(r_rd), .i_wr_en(r_we), .i_addr(r_maddr), .i_data(r_wdata), 
				     .o_data(w_dram_odata), .o_busy(w_busy), .i_mask(r_mask), .w_mtime(w_mtime));
`endif // SKIP_CACHE
endmodule
/**************************************************************************************************/

/**** Memory Controller with Cache                                                             ****/

/**************************************************************************************************/

module cache_ctrl#(parameter MEM_SIZE = `MEM_SIZE)(
     // on FPGA, o_clk is output
     input wire                         o_clk,
     // user interface ports
     input  wire                         i_rd_en,
     input  wire                         i_wr_en,
     input  wire [31:0]                  i_addr,
     input  wire [31:0]                  i_data,
     output wire[127:0]                  o_data,
     output wire                         o_busy,
     input  wire [3:0]                   i_mask,
     input wire [31:0]                   w_mtime);

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
`ifdef CACHE_DEBUG
    // evaluation
    reg  hit_rate_shown=0;
    reg         e_test=1;
    reg  [31:0] e_data;
    reg  [63:0] e_cnt = 0;
    reg  [63:0] e_hit = 0;
`endif
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
`ifdef CACHE_DEBUG
	    e_test <= c_oe;
            e_data <= c_odata;
`endif
        end
        else if(r_cache_state == 2'b11 || (r_cache_state == 2'b01 && c_oe)
                || (r_cache_state == 2'b10 && !w_dram_stall)) begin
            r_cache_state <= 2'b00;
            r_o_data <= (r_cache_state == 2'b01) ? c_odata : w_dram_odata;
`ifdef CACHE_DEBUG
	    if(r_cache_state == 2'b01 && c_oe) begin
                e_hit <= e_hit + 1;
            end
	    // CACHE DATA CHECK
            if(r_cache_state!=2'b11 && e_test) begin
                if(e_data != w_dram_odata) begin
                    $write("%d: CACHE DATA WRONG!!, ADDR:%x DATA%x %x\n",
                            w_mtime, r_addr, w_dram_odata, e_data);
                    $finish();
                end
            end
`endif
        end
        else if(i_wr_en) begin
            r_cache_state <= 2'b11;
            r_addr <= i_addr;
        end
        else if(i_rd_en) begin
            r_cache_state <= 2'b01;
            r_addr <= i_addr;
`ifdef CACHE_DEBUG
	    e_cnt           <= e_cnt + 1;
`endif
        end
`ifdef CACHE_DEBUG
`ifdef laur0
	if((w_mtime == 500000) && (!hit_rate_shown)) begin
	    hit_rate_shown = 1;
            $write("Cache hit rate: cnt = %d, hit = %d\n", e_cnt, e_hit);
            $write("\thit rate = %f\n", 1.0*e_hit/e_cnt);
        end
`endif
`endif
    end

    m_dram_cache#(28,128,`CACHE_SIZE/16) cache(o_clk, 1'b1, 1'b0, c_clr, c_we,
                                c_addr[31:4], c_idata, c_odata, c_oe);

    assign w_dram_le = (r_cache_state == 2'b01 && !c_oe);
    assign o_busy = w_dram_stall || r_cache_state != 0;

    assign o_data = r_o_data;

    m_bu_mem#(MEM_SIZE) idbmem(.CLK(o_clk), .w_addr(w_dram_addr), .w_odata(w_dram_odata),
                               .w_we(i_wr_en), .w_le(w_dram_le), .w_wdata(i_data), .w_ctrl(r_ctrl), .w_stall(w_dram_stall), .w_mask(~i_mask));
endmodule
`else
// simplest memory model
/**************************************************************************************************/
/**** Byte unit BRAM Main Memory module with LATENCY for simulation (1-port)                   ****/
/**************************************************************************************************/
module m_bu_mem #(parameter MEM_SIZE = `MEM_SIZE)
            (CLK, w_addr, w_odata, w_we, w_le, w_wdata, w_ctrl, w_stall);
    input  wire             CLK;
    input  wire [`XLEN-1:0] w_addr;
    output wire [`XLEN-1:0] w_odata;
    input  wire             w_we, w_le;
    input  wire [`XLEN-1:0] w_wdata;
    input  wire       [2:0] w_ctrl;
    output wire             w_stall;

    reg   [2:0] r_ctrl  = 0;
    reg  [31:0] r_addr  = 0;
    reg  [31:0] r_cnt   = 0;

    reg   [7:0] mem [0:MEM_SIZE-1];
    reg [`XLEN-1:0] r_odata = 0;

    assign w_odata = (r_ctrl[1:0]==0) ? ((r_ctrl[2]) ? {24'h0, r_odata[7:0]} :
                                         {{24{r_odata[7]}}, r_odata[7:0]}) :
                     (r_ctrl[1:0]==1) ? ((r_ctrl[2]) ? {16'h0, r_odata[15:0]} :
                                         {{16{r_odata[15]}}, r_odata[15:0]}) :
                     r_odata;

    reg r_stall=0;
    assign w_stall = r_stall;
    reg [`XLEN-1:0] r_maddr;
    // Select Write DATA
    wire [7:0] w_data3, w_data2, w_data1, w_data0;
    reg [31:0] r_wdata=0;
    assign {w_data3, w_data2, w_data1, w_data0} = r_wdata;
    reg [7:0] state = 0;
    always@(posedge CLK) begin
        case(state)
        8'd0: // idle
                if(w_le) begin
                        state <= 1;
                        r_stall <= 1;
                        r_maddr <= w_addr;
			r_ctrl <= w_ctrl;
                end else if(w_we) begin
                        state <= 2;
                        r_stall <= 1;
                        r_maddr <= w_addr;
                        r_wdata <= (w_ctrl[1:0] == 0) ? {24'h0, w_wdata[7:0]} :
                                   (w_ctrl[1:0] == 1) ? {16'h0, w_wdata[15:0]} : w_wdata;
                        r_ctrl <= w_ctrl;
                end
        8'd1: begin // mem read
		r_odata <= {mem[r_maddr+3], mem[r_maddr+2], mem[r_maddr+1], mem[r_maddr+0]};
		state <= 10;
		r_cnt <= 0;
	end 
	8'd10: begin
		if(r_cnt <= `LATENCY)
			r_cnt <= r_cnt + 1;
		else 
			state <= 11;
	end 
	8'd11: begin
                state <= 0;
                r_stall <= 0;
        end 
	8'd2: begin // mem write
                //r_odata <= {mem[r_maddr+3], mem[r_maddr+2], mem[r_maddr+1], mem[r_maddr+0]};
		//r_odata <= r_wdata;
		if(r_ctrl[1:0]==0) begin // SB
                                mem[r_maddr] <= w_data0;
                end else if(r_ctrl[1:0]==1) begin // SH
                                mem[r_maddr] <= w_data0;
                                mem[r_maddr+1] <= w_data1;
                end else if(r_ctrl[1:0]==2) begin // SW
                                mem[r_maddr  ] <= w_data0;
                                mem[r_maddr+1] <= w_data1;
                                mem[r_maddr+2] <= w_data2;
                                mem[r_maddr+3] <= w_data3;
                end
		r_cnt <= 0;
		state <= 10;
	end
        endcase
    end
endmodule
/**************************************************************************************************/
/**** BRAM Wrapper for simulation (1-port)                                                     ****/
/**************************************************************************************************/
module m_dram_sim#(parameter MEM_SIZE = `MEM_SIZE)
            (CLK, w_addr, w_odata, w_we, w_le, w_wdata, w_ctrl, w_stall, w_mtime);
    input  wire             CLK;
    input  wire [`XLEN-1:0] w_addr;
    output wire [`XLEN-1:0] w_odata;
    input  wire             w_we, w_le;
    input  wire [`XLEN-1:0] w_wdata;
    input  wire       [2:0] w_ctrl;
    output wire             w_stall;
    input  wire      [31:0] w_mtime;

    m_bu_mem#(MEM_SIZE) idbmem(CLK, w_addr, w_odata,
                                w_we, w_le, w_wdata, w_ctrl, w_stall);

endmodule
`endif // DRAM_SIM
