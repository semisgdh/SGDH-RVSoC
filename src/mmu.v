/* Modified by Laurentiu-Cristian Duca, 2021-12-20
 * - LAUR_MEM_RB memory read-back flag after BBL write
 * - SIM_MAIN flag for simulation in XSIM
 * - read_file module instantiation for interactive shell in SIM_MODE
 * - debug mc_mode code under the flag LAUR_SHOW_MC_MODE
 */
/**************************************************************************************************/
/**** RVSoC (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** Memory Controller v0.01                                                                  ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/
module m_mmu(
    input  wire         CLK, RST_X,
    input  wire [31:0]  w_insn_addr, w_data_addr,
    input  wire [31:0]  w_data_wdata,
    input  wire         w_data_we,
    input  wire  [2:0]  w_data_ctrl,
    output wire [31:0]  w_insn_data, w_data_data,
    output reg          r_finish,
    input  wire [31:0]  w_priv, w_satp, w_mstatus,
    input  wire [63:0]  w_mtime, w_mtimecmp,
    output wire [63:0]  w_wmtimecmp,
    output wire         w_clint_we,
    input  wire [31:0]  w_mip,
    output wire [31:0]  w_wmip,
    output wire         w_plic_we,
    output wire         w_proc_busy,
    output wire [31:0]  w_pagefault,
    input  wire  [1:0]  w_tlb_req,
    input  wire         w_tlb_flush,
    output wire         w_txd,
    input  wire         w_rxd,
    output wire         w_init_done,
    input  wire         mig_clk,
    input  wire         mig_rst_x,
`ifndef ARTYA7
    inout  wire [15:0]  ddr2_dq,
    inout  wire  [1:0]  ddr2_dqs_n,
    inout  wire  [1:0]  ddr2_dqs_p,
    output wire [12:0]  ddr2_addr,
    output wire  [2:0]  ddr2_ba,
    output wire         ddr2_ras_n,
    output wire         ddr2_cas_n,
    output wire         ddr2_we_n,
    output wire         ddr2_ck_p,
    output wire         ddr2_ck_n,
    output wire         ddr2_cke,
    output wire         ddr2_cs_n,
    output wire  [1:0]  ddr2_dm,
    output wire         ddr2_odt,
`else
    input  wire         ref_clk,
    inout  wire [15:0]  ddr3_dq,
    inout  wire  [1:0]  ddr3_dqs_n,
    inout  wire  [1:0]  ddr3_dqs_p,
    output wire [13:0]  ddr3_addr,
    output wire  [2:0]  ddr3_ba,
    output wire         ddr3_ras_n,
    output wire         ddr3_cas_n,
    output wire         ddr3_we_n,
    output wire         ddr3_ck_p,
    output wire         ddr3_ck_n,
    output wire         ddr3_reset_n,
    output wire         ddr3_cke,
    output wire         ddr3_cs_n,
    output wire  [1:0]  ddr3_dm,
    output wire         ddr3_odt,
`endif
    output wire         o_clk,
    output wire         o_rst_x,
    output wire  [7:0]  w_uart_data,
    output wire         w_uart_we,
    output wire [15:0]  w_led,
    input  wire         w_init_stage,
    output wire [31:0]  w_checksum,
`ifdef LAUR_MEM_RB
    output wire [31:0]  w_verify_checksum,
`endif
    input  wire         w_debug_btnd,
    output wire  [2:0]  w_init_state,
    output wire w_pl_init_we);
    initial r_finish = 0;

    /***** Address translation ********************************************************************/
    reg  [31:0] physical_addr       = 0;
    reg         page_walk_fail      = 0;

    // Page walk state
    reg  [2:0]  r_pw_state          = 0;

    // Page table entry
    reg  [31:0] L1_pte              = 0;
    reg  [31:0] L0_pte              = 0;

    /***** Other Registers ************************************************************************/
    // Device checker
    reg   [3:0] r_dev               = 0;
    reg   [3:0] r_virt              = 0;

    // TO HOST
    reg  [31:0] r_tohost            = 0;

    // PLIC
    reg  [31:0] plic_served_irq     = 0;
    reg  [31:0] plic_pending_irq    = 0;
    reg  [31:0] r_plic_odata        = 0;

    // CLINT
    reg  [31:0] r_clint_odata       = 0;

    /***** Micro Controller ***********************************************************************/
    reg   [1:0] r_mc_mode           = 0;
    reg  [31:0] r_mc_qnum           = 0;
    reg  [31:0] r_mc_qsel           = 0;

    reg  [31:0] r_mc_done           = 0;

    /***** Keyboard Input *************************************************************************/
    reg   [3:0] r_consf_head        = 0;  // Note!!
    reg   [3:0] r_consf_tail        = 0;  // Note!!
    reg   [4:0] r_consf_cnts        = 0;  // Note!!
    reg         r_consf_en          = 0;
    reg   [7:0] cons_fifo [0:15];
`ifdef SIM_MODE
    wire w_file_we;
    read_file rf(.clk(CLK), .r_consf_en(r_consf_en), .we(w_file_we), .w_mtime(w_mtime), .min_time(`ENABLE_TIMER + 64'd10000000));
`endif

`ifdef SIM_MODE
`define LAUR_EN_CONSOLE_INPUT
`ifdef LAUR_EN_CONSOLE_INPUT
    initial begin
        r_consf_en = 1;
        cons_fifo[0] = 8'h72;  // "r"
        cons_fifo[1] = 8'h6f;  // "o"
        cons_fifo[2] = 8'h6f;  // "o"
        cons_fifo[3] = 8'h74;  // "t"
        cons_fifo[4] = 8'hd;   // "(CR)"
        cons_fifo[5] = 8'hd;   // "(CR)"
`ifdef laur0
        cons_fifo[6] = 8'h74;  // "t"
        cons_fifo[7] = 8'h6f;  // "o"
        cons_fifo[8] = 8'h70;  // "p"
        cons_fifo[9] = 8'hd;   // "(CR)"
        r_consf_tail = 10;
        r_consf_cnts = 10;
`else
        r_consf_tail = 6;
        r_consf_cnts = 6;
`endif
	
    end
`endif
`endif

    /**********************************************************************************************/
    // dram data
    wire [31:0] w_dram_odata;

    wire        w_tlb_busy;
    wire        w_dram_busy;

    wire [31:0] w_mc_addr;
    wire [31:0] w_mc_wdata;
    wire        w_mc_we;
    wire  [2:0] w_mc_ctrl;
    wire  [1:0] w_mc_aces;

    wire [31:0] w_mem_wdata = (r_mc_mode!=0) ? w_mc_wdata  : w_data_wdata;
    wire        w_mem_we    = (r_mc_mode!=0) ? w_mc_we     : w_data_we;


    /***********************************        Page walk       ***********************************/
    wire        w_iscode        = (w_tlb_req == `ACCESS_CODE);
    wire        w_isread        = (w_tlb_req == `ACCESS_READ);
    wire        w_iswrite       = (w_tlb_req == `ACCESS_WRITE);
    wire [31:0] v_addr          = w_iscode ? w_insn_addr : w_data_addr;

    // Level 1
    wire [31:0] vpn1            = {22'b0, v_addr[31:22]};
    wire [31:0] L1_pte_addr     = {w_satp[19:0], 12'b0} + {vpn1, 2'b0};
    wire  [2:0] L1_xwr          = w_mstatus[19] ? (L1_pte[3:1] | L1_pte[5:3]) : L1_pte[3:1];
    wire [31:0] L1_paddr        = {L1_pte[29:10], 12'h0};
    wire [31:0] L1_p_addr       = {L1_paddr[31:22], v_addr[21:0]};
    wire        L1_write        = !L1_pte[6] || (!L1_pte[7] && w_iswrite);
    wire        L1_success      = !(L1_xwr ==2 || L1_xwr == 6 ||
                                    (w_priv == `PRIV_S && (L1_pte[4] && !w_mstatus[18])) ||
                                    (w_priv == `PRIV_U && !L1_pte[4]) ||
                                    (L1_xwr[w_tlb_req] == 0));

    // Level 0
    wire [31:0] vpn0            = {22'b0, v_addr[21:12]};
    wire [31:0] L0_pte_addr     = {L1_pte[29:10], 12'b0} + {vpn0, 2'b0};
    wire  [2:0] L0_xwr          = w_mstatus[19] ? (L0_pte[3:1] | L0_pte[5:3]) : L0_pte[3:1];
    wire [31:0] L0_paddr        = {L0_pte[29:10], 12'h0};
    wire [31:0] L0_p_addr       = {L0_paddr[31:12], v_addr[11:0]};
    wire        L0_write        = !L0_pte[6] || (!L0_pte[7] && w_iswrite);
    wire        L0_success      = !(L0_xwr ==2 || L0_xwr == 6 ||
                                    (w_priv == `PRIV_S && (L0_pte[4] && !w_mstatus[18])) ||
                                    (w_priv == `PRIV_U && !L0_pte[4]) ||
                                    (L0_xwr[w_tlb_req] == 0));

    // update pte
    wire [31:0] L1_pte_write    = L1_pte | `PTE_A_MASK | (w_iswrite ? `PTE_D_MASK : 0);
    wire [31:0] L0_pte_write    = L0_pte | `PTE_A_MASK | (w_iswrite ? `PTE_D_MASK : 0);
    wire        w_pte_we        = (r_pw_state==5) && (((L1_xwr != 0 && L1_success) && L1_write) ||
                                        ((L0_xwr != 0 && L0_success) && L0_write));
    wire [31:0] w_pte_waddr     = (L1_xwr != 0 && L1_success) ? L1_pte_addr : L0_pte_addr;
    wire [31:0] w_pte_wdata     = (L1_xwr != 0 && L1_success) ? L1_pte_write : L0_pte_write;

    assign w_pagefault          = !page_walk_fail ? ~32'h0 : (w_iscode) ? `CAUSE_FETCH_PAGE_FAULT :
                                    (w_isread) ? `CAUSE_LOAD_PAGE_FAULT : `CAUSE_STORE_PAGE_FAULT;

    reg  [31:0] r_tlb_addr = 0;
    reg   [2:0] r_tlb_use  = 0;
    wire [21:0] w_tlb_inst_r_addr, w_tlb_data_r_addr, w_tlb_data_w_addr;
    wire        w_tlb_inst_r_oe, w_tlb_data_r_oe, w_tlb_data_w_oe;
    wire        w_use_tlb = (r_mc_mode==0 && (w_iscode || w_isread || w_iswrite)
                                          && (!(w_priv == `PRIV_M || w_satp[31] == 0)));
    wire        w_tlb_hit = ((w_iscode && w_tlb_inst_r_oe) ||
                            (w_isread && w_tlb_data_r_oe)  ||
                            (w_iswrite && w_tlb_data_w_oe));

    // PAGE WALK state
    always@(posedge CLK) begin
        if(r_pw_state == 0) begin
            // PAGE WALK START
            if(!w_dram_busy && w_use_tlb) begin
                // tlb miss
                if(!w_tlb_hit) begin
                    r_pw_state <= 1;
                end
                else begin
                    r_pw_state <= 7;
                    case ({w_iscode, w_isread, w_iswrite})
                        3'b100 : r_tlb_addr <= {w_tlb_inst_r_addr[21:2], w_insn_addr[11:0]};
                        3'b010 : r_tlb_addr <= {w_tlb_data_r_addr[21:2], w_data_addr[11:0]};
                        3'b001 : r_tlb_addr <= {w_tlb_data_w_addr[21:2], w_data_addr[11:0]};
                        default: r_tlb_addr <= 0;
                    endcase
                    r_tlb_use <= {w_iscode, w_isread, w_iswrite};
                end
            end
        end
        // Level 1
        else if(r_pw_state == 1 && !w_dram_busy) begin
            L1_pte      <= w_dram_odata;
            r_pw_state  <= 2;
        end
        else if(r_pw_state == 2) begin
            r_pw_state  <= 3;
        end
        // Level 0
        else if(r_pw_state == 3 && !w_dram_busy) begin
            L0_pte      <= w_dram_odata;
            r_pw_state  <= 4;
        end
        // Success?
        else if(r_pw_state == 4) begin
            if(!L1_pte[0]) begin
                physical_addr   <= 0;
                page_walk_fail  <= 1;
            end
            else if(L1_xwr) begin
                physical_addr   <= (L1_success) ? L1_p_addr : 0;
                page_walk_fail  <= (L1_success) ? 0 : 1;
            end
            else if(!L0_pte[0]) begin
                physical_addr   <= 0;
                page_walk_fail  <= 1;
            end
            else if(L0_xwr) begin
                physical_addr   <= (L0_success) ? L0_p_addr : 0;
                page_walk_fail  <= (L0_success) ? 0 : 1;
            end
            r_pw_state  <= 5;
        end
        // Update pte
        else if(r_pw_state == 5) begin
            r_pw_state      <= 0;
            physical_addr   <= 0;
            page_walk_fail  <= 0;
        end
        else if(r_pw_state == 7) begin
            r_pw_state <= 0;
            r_tlb_use <= 0;
            //$write("hoge!, %x, %x\n", page_walk_fail, r_tlb_use);
        end
    end
    
    /***********************************           TLB          ***********************************/
    wire        w_tlb_inst_r_we   = (r_pw_state == 5 && !page_walk_fail && w_iscode);
    wire        w_tlb_data_r_we   = (r_pw_state == 5 && !page_walk_fail && w_isread);
    wire        w_tlb_data_w_we   = (r_pw_state == 5 && !page_walk_fail && w_iswrite);
    wire [21:0] w_tlb_wdata       = {physical_addr[31:12], 2'b0};

    m_tlb#(20, 22, `TLB_SIZE) TLB_inst_r (CLK, 1'b1, w_tlb_flush, w_tlb_inst_r_we,
                                            w_insn_addr[31:12], w_insn_addr[31:12], w_tlb_wdata,
                                            w_tlb_inst_r_addr, w_tlb_inst_r_oe);

    m_tlb#(20, 22, `TLB_SIZE) TLB_data_r (CLK, 1'b1, w_tlb_flush, w_tlb_data_r_we,
                                            w_data_addr[31:12], w_data_addr[31:12], w_tlb_wdata,
                                            w_tlb_data_r_addr, w_tlb_data_r_oe);

    m_tlb#(20, 22, `TLB_SIZE) TLB_data_w (CLK, 1'b1, w_tlb_flush, w_tlb_data_w_we,
                                            w_data_addr[31:12], w_data_addr[31:12], w_tlb_wdata,
                                            w_tlb_data_w_addr, w_tlb_data_w_oe);

    /***********************************          Memory        ***********************************/
    reg  [31:0] r_tlb_pte_addr = 0;
    reg         r_tlb_acs = 0;
    always@(*)begin
        case (r_pw_state)
            0:      begin r_tlb_pte_addr <= L1_pte_addr;    r_tlb_acs = 1; end
            2:      begin r_tlb_pte_addr <= L0_pte_addr;    r_tlb_acs = 1; end
            5:      begin r_tlb_pte_addr <= w_pte_waddr;    r_tlb_acs = 1; end
            default:begin r_tlb_pte_addr <= 0;              r_tlb_acs = 0; end
        endcase
    end

    //wire w_tlb_i_use = w_tlb_inst_r_oe && w_iscode;
    //wire w_tlb_r_use = w_tlb_data_r_oe && w_isread;
    //wire w_tlb_w_use = w_tlb_data_w_oe && w_iswrite;
    /*wire [31:0] w_tlb_data_addr = (w_tlb_w_use) ?   {w_tlb_data_w_addr[21:2], w_data_addr[11:0]} :
                                                    {w_tlb_data_r_addr[21:2], w_data_addr[11:0]};*/


    wire [31:0] w_insn_paddr =  (w_priv == `PRIV_M || w_satp[31] == 0) ? w_insn_addr :
                                r_tlb_addr;

    wire [31:0] w_mem_paddr  =  (r_mc_mode != 0)                        ? w_mc_addr     :
                                (w_priv == `PRIV_M || w_satp[31] == 0)  ? w_data_addr   : r_tlb_addr;
//                                (r_pw_state == 5)                       ? r_tlb_addr    :
//                                (r_tlb_acs)                             ? r_tlb_pte_addr:
//                                                                          w_data_addr;

    wire [2:0]  w_mem_ctrl   =  (r_mc_mode != 0)                        ? w_mc_ctrl         :
                                (w_priv == `PRIV_M || w_satp[31] == 0)  ? w_data_ctrl       :
                                (r_tlb_use[1:0]!=0)                     ? w_data_ctrl       :
                                (r_pw_state == 0)                       ? `FUNCT3_LW____    :
                                (r_pw_state == 2)                       ? `FUNCT3_LW____    :
                                (r_pw_state == 5)                       ? `FUNCT3_SW____    :
                                w_data_ctrl;

    wire  [3:0] w_dev       = w_mem_paddr[31:28];// & 32'hf0000000;
    wire  [3:0] w_virt      = w_mem_paddr[27:24];// & 32'h0f000000;
    wire [27:0] w_offset    = w_mem_paddr & 28'h7ffffff;

    //always@(posedge CLK) w_virt <= w_mem_paddr & 32'h0f000000;

    wire [31:0] w_dram_wdata    = (r_pw_state == 5) ? w_pte_wdata : w_mem_wdata;
    wire        w_dram_we       = (w_mem_we && !w_tlb_busy
                                    && (w_dev == `MEM_BASE_TADDR || w_dev == 0));

    wire [31:0] w_dram_addr =   (r_mc_mode!=0)              ? w_mc_addr         :
                                (w_iscode && !w_tlb_busy)   ? w_insn_paddr      :
                                (w_priv == `PRIV_M || w_satp[31] == 0) ? w_data_addr :
                                (r_tlb_acs && !w_tlb_hit)   ? r_tlb_pte_addr    : w_mem_paddr;

    wire [2:0]  w_dram_ctrl =   (r_mc_mode!=0)              ? (w_mem_ctrl)      :
                                (w_iscode && !w_tlb_busy)   ? `FUNCT3_LW____    : w_mem_ctrl;
    assign      w_insn_data =   w_dram_odata;

    wire        w_dram_aces = (w_dram_addr[31:28] == 8 || w_dram_addr[31:28] == 0 || w_dram_addr[31:28] == 9);

`ifdef LAUR_MEM_RB
    // xsim requires declaration before use
    reg r_set_dram_le=0;
`endif

    wire        w_dram_le   =
                    (w_dram_busy)  ? 0 :
`ifdef LAUR_MEM_RB
                    (r_set_dram_le) ? 1 :
`endif
                    (!w_dram_aces) ? 0 :
                    (r_mc_mode!=0) ? (w_mc_aces==`ACCESS_READ && w_mc_addr[31:28] != 0) :
                    (w_priv == `PRIV_M || w_satp[31] == 0) ? (w_iscode || w_isread) :
                    (r_tlb_use[2:1]!=0) ? 1 :
                    (w_tlb_busy && !w_tlb_hit && (r_pw_state == 0 || r_pw_state==2)) ? 1 : 0;


    /***********************************         Console        ***********************************/
    wire        w_cons_we   = (r_mc_mode != 0) ? (w_mem_we && w_mem_paddr[31:12] == 20'h4000a) :
                            (w_mem_we && !w_tlb_busy && w_dev == `VIRTIO_BASE_TADDR && w_virt == 0);
    wire [31:0] w_cons_data;
    wire [31:0] w_cons_addr = (r_mc_mode != 0) ? w_mem_paddr : {4'b0, w_offset};
    wire        w_cons_req;
    wire [31:0] w_cons_qnum;
    wire [31:0] w_cons_qsel;

    /***********************************           Disk         ***********************************/
    wire        w_disk_we   = (r_mc_mode != 0) ? (w_mem_we && w_mem_paddr[31:12] == 20'h4000b) :
                            (w_mem_we && !w_tlb_busy && w_dev == `VIRTIO_BASE_TADDR && w_virt != 0);
    wire [31:0] w_disk_data;
    wire [31:0] w_disk_addr = (r_mc_mode != 0) ? w_mem_paddr : {4'b0, w_offset};
    wire        w_disk_req;
    wire [31:0] w_disk_qnum;
    wire [31:0] w_disk_qsel;


    /***********************************           image        ***********************************/
//    wire        w_imag_we       = w_mem_we && r_mc_mode != 0 && w_dram_addr[31:28] == 4'h9;
    wire        w_imag_we       = w_mem_we && r_mc_mode != 0 && w_mem_paddr[31:28] == 4'h9;
    
    /***********************************          OUTPUT        ***********************************/
    reg  [31:0] r_data_data = 0;
    always@(*) begin
        case (r_dev)
            `CLINT_BASE_TADDR : r_data_data <= r_clint_odata;
            `PLIC_BASE_TADDR  : r_data_data <= r_plic_odata;
            `VIRTIO_BASE_TADDR: r_data_data <= (r_virt == 0) ? w_cons_data : w_disk_data;
            default           : r_data_data <= w_dram_odata;
        endcase
    end
    assign w_data_data = r_data_data;
    /*assign      w_data_data =   (r_dev == `CLINT_BASE_TADDR)    ? r_clint_odata     :
                                (r_dev == `PLIC_BASE_TADDR)     ? r_plic_odata      :
                                (r_dev == `VIRTIO_BASE_TADDR)   ?
                                    ((r_virt == 0) ? w_cons_data : w_disk_data) : w_dram_odata;*/

    /***********************************          VirtIO        ***********************************/
    wire        w_key_we;
    wire  [7:0] w_key_data;
    wire        w_key_req = r_consf_en && (w_mtime > `ENABLE_TIMER + 64'd1000000) && ((w_mtime & 64'h3ffff) == 0)
                            && r_mc_mode == 0 && w_init_stage;
    reg         r_key_we    = 0;
    reg   [7:0] r_key_data  = 0;
    always@(posedge CLK) begin
        r_key_we    <= w_key_we;
        r_key_data  <= w_key_data;
    end

`ifdef SIM_MODE
integer i;
`endif

    always@(posedge CLK) begin
        if(r_mc_done) begin
	    //$write("r_mc_done=%d\n", r_mc_done);
            r_mc_mode <= 0;
            r_mc_done <= 0;
            if(r_mc_mode==3) begin
//`ifdef SIM_MODE
//                r_consf_en <= 1;
//                r_consf_head <= (r_consf_head < 8) ? r_consf_head + 1 : r_consf_head;
//`else
                r_consf_en <= (r_consf_cnts<=1) ? 0 : 1;
                r_consf_head <= r_consf_head + 1;
                r_consf_cnts <= r_consf_cnts - 1;
//`endif
            end
        end
`ifdef SIM_MODE
	else if(w_file_we) begin
		$display("\nw_file_we\n");
		if(r_consf_cnts != 0)
			$display("warning: w_file_we and r_consf_cnts = %d with r_consf_en=%d", r_consf_cnts, r_consf_en);
		for(i = 0; i < rf.n; i++)
			cons_fifo[r_consf_tail+i] = rf.fifo[i];
		r_consf_tail <= r_consf_tail + rf.n;
		r_consf_cnts <= rf.n;
		r_consf_en <= 1;
	end
`else
        else if(r_key_we) begin
            if(r_consf_cnts < 16) begin
                cons_fifo[r_consf_tail] <= r_key_data;
                r_consf_tail            <= r_consf_tail + 1;
                r_consf_cnts            <= r_consf_cnts + 1;
                r_consf_en              <= 1;
            end
        end
`endif
        else begin
            case ({w_cons_req, w_disk_req, w_key_req})
                3'b100: begin
                    r_mc_mode <= 1;
                    r_mc_qnum <= w_cons_qnum;
                    r_mc_qsel <= w_cons_qsel;
                end
                3'b010: begin
                    r_mc_mode <= 2;
                    r_mc_qnum <= w_disk_qnum;
                    r_mc_qsel <= w_disk_qsel;
                end
                3'b001: begin
                    r_mc_mode <= 3;
                    r_mc_qnum <= w_cons_qnum;
                    r_mc_qsel <= 0;
                end
            endcase
        end
        /*else if(w_cons_req) begin
            r_mc_mode <= 1;
            r_mc_qnum <= w_cons_qnum;
            r_mc_qsel <= w_cons_qsel;
        end
        else if(w_disk_req) begin
            r_mc_mode <= 2;
            r_mc_qnum <= w_disk_qnum;
            r_mc_qsel <= w_disk_qsel;
        end
        else if(w_key_req) begin
            r_mc_mode <= 3;
            r_mc_qnum <= w_cons_qnum;
            r_mc_qsel <= 0;
        end*/
        if(r_tohost[31:16]==`CMD_POWER_OFF) begin
            r_mc_done <= 1;
        end

    end

//`define LAUR_SHOW_MC_MODE 1
`ifdef LAUR_SHOW_MC_MODE
    reg [1:0] old_r_mc_mode=1;
    reg [31:0] old_r_tohost=31'hffff;
    reg [2:0] three=7;
    reg old_r_mc_done=0;
    always @(posedge CLK) begin
         if((old_r_mc_mode != r_mc_mode) || (three != {w_cons_req, w_disk_req, w_key_req})
		 || (r_mc_done != old_r_mc_done))
	 begin
	     $write("r_mc_mode=%x r_tohost[31:16]=%x {w_cons_req, w_disk_req, w_key_req}=%x r_mc_done=%x\n", 
		     r_mc_mode, r_tohost[31:16], {w_cons_req, w_disk_req, w_key_req}, r_mc_done);
	     old_r_mc_mode <= r_mc_mode;
	     three <= {w_cons_req, w_disk_req, w_key_req};
	     old_r_mc_done <= r_mc_done;
	 end
    end
`endif

`define LAUR_WRITE_TIME
`ifdef LAUR_WRITE_TIME
    reg [31:0] old_w_mtime=0;
    always @(posedge CLK) begin
	    if(old_w_mtime != w_mtime) begin
		old_w_mtime = w_mtime;
		if(w_mtime % 32'd300000 == 32'd0) begin
			$write("w_mtime=%d ENABLE_TIMER=%d\n", w_mtime, `ENABLE_TIMER);
			if(w_mtime >= 32'd150000000)
				$finish();
		end
	    end
    end
`endif

    reg  [31:0] r_mc_arg = 0;
    always@(*) begin
        case (w_mem_paddr[31:12])
            20'h40009: begin
                case (w_mem_paddr[3:0])
                    4: r_mc_arg <= r_mc_qnum;
                    8: r_mc_arg <= r_mc_qsel;
                    default: r_mc_arg <= r_mc_mode;
                endcase
            end
            20'h4000a: r_mc_arg <= w_cons_data;
            20'h4000b: r_mc_arg <= w_disk_data;
            20'h4000c: r_mc_arg <= cons_fifo[r_consf_head];
            default:   r_mc_arg <= w_dram_odata;
        endcase
    end

    wire [31:0] w_mc_arg = r_mc_arg;
    /*wire [31:0] w_mc_arg =  (w_mem_paddr == `MODE_ADDR)        ? r_mc_mode                  :
                            (w_mem_paddr == `QNUM_ADDR)        ? r_mc_qnum                  :
                            (w_mem_paddr == `QSEL_ADDR)        ? r_mc_qsel                  :
                            (w_mem_paddr[31:12] == `CONQ_ADDR) ? w_cons_data                :
                            (w_mem_paddr[31:12] == `DISQ_ADDR) ? w_disk_data                : 
                            (w_mem_paddr == `KEYQ_ADDR)        ? cons_fifo[r_consf_head]    :
                            w_dram_odata;*/

    wire [31:0] w_cons_irq, w_disk_irq;
    wire        w_cons_irq_oe, w_disk_irq_oe;
    wire        w_isdisk        = w_virt != 0;
    wire [31:0] w_virt_irq      = (w_key_req) ? w_cons_irq : (w_isdisk) ? w_disk_irq : w_cons_irq;
    wire        w_virt_irq_oe   = w_cons_irq_oe | w_disk_irq_oe | w_key_req;

    m_RVuc mc(CLK, (r_mc_mode!=0), w_dram_busy, w_mc_addr, w_mc_arg, w_mc_wdata,
                w_mc_we, w_mc_ctrl, w_mc_aces);


    m_console   console(CLK, 1'b1, w_cons_we, w_cons_addr, w_mem_wdata, plic_pending_irq, w_cons_data,
                        w_cons_irq, w_cons_irq_oe, r_mc_mode, w_cons_req, w_cons_qnum, w_cons_qsel, w_key_req);
    
    m_disk      disk(CLK, 1'b1, w_disk_we, w_disk_addr, w_mem_wdata, plic_pending_irq, w_disk_data,
                        w_disk_irq, w_disk_irq_oe, r_mc_mode, w_disk_req, w_disk_qnum, w_disk_qsel);


    /***********************************           PLIC         ***********************************/
    wire [31:0] w_plic_pending_irq_nxt  =   w_virt_irq_oe ? w_virt_irq : plic_pending_irq;
    wire [31:0] w_plic_mask             =   w_plic_pending_irq_nxt & ~plic_served_irq;
    wire [31:0] w_plic_served_irq_nxt   =   (w_virt_irq_oe) ? plic_served_irq :
                                            (w_isread) ? plic_served_irq | w_plic_mask :
                                            plic_served_irq & ~(1 << (w_data_wdata-1));

    wire w_plic_aces = (w_dev == `PLIC_BASE_TADDR && !w_tlb_busy &&
            ((w_isread && w_plic_mask != 0) || (w_iswrite && w_offset == `PLIC_HART_BASE+4)));

    reg  [31:0] r_wmip = 0;
    reg         r_plic_we = 0;

    reg  [31:0] r_plic_pending_irq_t    = 0;
    reg  [31:0] r_plic_served_irq_t     = 0;

    reg         r_virt_irq_oe_t = 0;
    reg         r_plic_aces_t   = 0;

    wire [31:0] w_plic_mask_nxt = r_plic_pending_irq_t & ~r_plic_served_irq_t;

    always@(posedge CLK) begin
        if(!w_tlb_busy) begin
            //r_plic_we   <= (w_virt_irq_oe || w_plic_aces);
            r_virt_irq_oe_t         <= w_virt_irq_oe;
            r_plic_aces_t           <= w_plic_aces;
            r_plic_pending_irq_t    <= w_plic_pending_irq_nxt;
            r_plic_served_irq_t     <= w_plic_served_irq_nxt;
        end
    end

    assign w_plic_we    = (r_virt_irq_oe_t || r_plic_aces_t);//r_plic_we;
    assign w_wmip       = (w_plic_mask_nxt) ? w_mip | (`MIP_MEIP | `MIP_SEIP) :
                            w_mip & ~(`MIP_MEIP | `MIP_SEIP);

//    assign w_plic_we = (w_virt_irq_oe || w_plic_aces);
//    assign w_wmip    = (w_plic_mask_nxt) ? w_mip | (`MIP_MEIP | `MIP_SEIP) :
                        //w_mip & ~(`MIP_MEIP | `MIP_SEIP);

    /***********************************          CLINT         ***********************************/
    assign w_wmtimecmp  = (r_dev == `CLINT_BASE_TADDR && w_offset==28'h4000 && w_data_we != 0) ?
                                {w_mtimecmp[63:32], w_data_wdata} :
                          (r_dev == `CLINT_BASE_TADDR && w_offset==28'h4004 && w_data_we != 0) ?
                                {w_data_wdata, w_mtimecmp[31:0]} : 0;
    assign w_clint_we   = (r_dev == `CLINT_BASE_TADDR && w_data_we != 0);

    /***********************************           BUSY         ***********************************/
    assign w_tlb_busy = 
                    !(w_use_tlb)                            ? 0 :
                    (r_pw_state == 7)                       ? 0 : 1;
/*                    (r_pw_state != 0)                       ? 1 :
                    ((w_iscode && w_tlb_inst_r_oe) ||
                    (w_isread && w_tlb_data_r_oe)  ||
                    (w_iswrite && w_tlb_data_w_oe))         ? 0 : 1;*/
    
    /*wire w_mc_busy =    (r_mc_done)                                                 ? 0 :
                        (r_mc_mode != 0 || w_cons_req || w_key_req || w_disk_req)   ? 1 : 0;*/
    wire w_mc_busy =    (r_mc_mode != 0) ? 1 : 0;


    wire w_tx_ready;
    assign w_proc_busy = w_tlb_busy || w_mc_busy || w_dram_busy || !w_tx_ready;
    /**********************************************************************************************/
    // PLIC, CLINT ACCESS
    reg         r_uart_we = 0;
    reg   [7:0] r_uart_data = 0;
`ifdef LAUR_MEM_RB
    // xsim requires declaration before use
    reg r_rb_uart_we=0;
    reg [7:0] r_rb_uart_data;
`endif
    always@(posedge CLK) begin
        r_dev   <= w_dev;
        r_virt  <= w_virt;

        /*********************************         TOHOST         *********************************/
        // OUTPUT CHAR
        if(r_tohost[31:16]==`CMD_PRINT_CHAR) begin
            r_uart_we   <= 1;
            r_uart_data <= r_tohost[7:0];
`ifdef LAUR_MEM_RB
	end else if(r_rb_uart_we) begin
		r_uart_we <= 1;
		r_uart_data <= r_rb_uart_data;
`endif
    	end else begin 
            r_uart_we   <= 0;
            r_uart_data <= 0;
        end
        // Finish Simulation
        if(r_tohost[31:16]==`CMD_POWER_OFF) begin
            if(r_mc_mode==0) r_finish = 1;
            else begin
                r_tohost <= 0;
            end
        end
        else begin
            r_tohost <= (w_mem_paddr==`TOHOST_ADDR && w_mem_we) ? w_mem_wdata   :
                        (r_tohost[31:16]==`CMD_PRINT_CHAR)      ? 0             : r_tohost;
        end

        /**********************************         PLIC         **********************************/
        if(w_plic_aces) begin
            r_plic_odata    <= (w_plic_mask!=0) ? w_plic_mask : 0;
            plic_served_irq <= w_plic_served_irq_nxt;
        end

        if(w_virt_irq_oe) begin
            plic_pending_irq    <= w_virt_irq;
        end

        /*********************************          CLINT         *********************************/
        r_clint_odata <=    (w_offset==28'hbff8) ? w_mtime[31:0] :
                            (w_offset==28'hbffc) ? w_mtime[63:32] :
                            (w_offset==28'h4000) ? w_mtimecmp[31:0] :
                            (w_offset==28'h4004) ? w_mtimecmp[63:32] : 0;
    end
    /**********************************************************************************************/

    wire w_cons_txd;
    UartTx UartTx0(CLK, RST_X, r_uart_data, r_uart_we, w_cons_txd, w_tx_ready);

    assign w_uart_data = r_uart_data;
    assign w_uart_we   = r_uart_we;

    wire [31:0]  w_pl_init_addr;
    wire [31:0]  w_pl_init_data;
    //wire         w_pl_init_we;
    wire         w_pl_init_done;
    PLOADER ploader(CLK, RST_X, w_rxd, w_pl_init_addr, w_pl_init_data, w_pl_init_we,
                    w_pl_init_done, w_key_we, w_key_data);

    /**********************************************************************************************/
`ifdef SIM_MODE
    reg  [2:0] r_init_state = 5;
`else
    reg  [2:0] r_init_state = 0;
`endif
    reg  [31:0]  r_initaddr  = 0;
    reg  [31:0]  r_checksum = 0;
    always@(posedge CLK) begin
//`ifdef LAUR_MEM_RB
//	r_checksum <= (!RST_X)                      ? 0                             :
//		      (!w_init_done & w_pl_init_we & 
//		      ((r_init_state == 2) && (r_initaddr  < `BIN_BBL_SIZE)))
//		      				    ? r_checksum + w_pl_init_data   :
//		      r_checksum;
//`else
	r_checksum <= (!RST_X)                      ? 0                             :
                      (!w_init_done & w_pl_init_we) ? r_checksum + w_pl_init_data   :
		      r_checksum;
//`endif
    end

    assign w_checksum = r_checksum;

    /**********************************************************************************************/

    wire w_debug_txd;
    wire w_rec_done;
    m_debug_key debug_KEY(CLK, RST_X, w_debug_btnd, w_debug_txd, w_key_we, w_key_data, w_mtime[31:0], w_rec_done);

    assign w_txd = (w_rec_done) ? w_debug_txd : w_cons_txd;

/**************************************************************************************************/
    reg          r_bbl_done   = 0;
    reg          r_disk_done  = 0;
    reg          r_dtree_done = 0;
`ifdef LAUR_MEM_RB
    reg  [31:0]  r_initaddr6  = 0;
`endif
    reg  [31:0]  r_initaddr2 = `BBL_SIZE ; /* initial addres for Disk Drive */
    reg  [31:0]  r_initaddr3 = `D_INITD_ADDR ; /* initial address of Device Tree */

    // Zero init
    wire w_zero_we;
    reg  r_zero_we=0;
    reg  r_zero_done        = 0;
    reg  [31:0]  r_zeroaddr = 0;

`ifdef LAUR_MEM_RB
    // xsim requires declaration before use
    reg r_mem_rb_done=0;
`endif
`ifndef SIM_MODE
    always@(posedge CLK) begin
        r_init_state <= (!RST_X) ? 0 :
                      (r_init_state == 0)                ? 1 :
                      (r_init_state == 1 & r_zero_done)  ? 2 :
		      (r_init_state == 2 & r_bbl_done)   ? 3 :
                      (r_init_state == 3 & r_dtree_done) ? 4 :  
`ifdef LAUR_MEM_RB
		      (r_init_state == 4 & r_disk_done)  ? 6 :
		      (r_init_state == 6 & r_mem_rb_done)  ? 5 :
`else 
                      (r_init_state == 4 & r_disk_done)  ? 5 :
`endif
                      r_init_state;
    end
`endif

    //assign w_init_start = (r_initaddr != 0);
    assign w_init_state = r_init_state;

    assign w_init_done = (r_init_state == 5);
        
    always@(posedge CLK) begin	
	if(r_init_state < 1)
		$display("r_init_state=%d", r_init_state);
        if(w_pl_init_we & (r_init_state == 2)) begin     r_initaddr      <= r_initaddr + 4; end
        if(r_initaddr  >= `BIN_BBL_SIZE)            r_bbl_done      <= 1;
        if(w_pl_init_we & (r_init_state == 3))      r_initaddr3     <= r_initaddr3 + 4;
        if(r_initaddr3 >= (`D_INITD_ADDR + `D_SIZE_DEVT))  r_dtree_done    <= 1;
        if(w_pl_init_we & (r_init_state == 4))      r_initaddr2     <= r_initaddr2 + 4;
        if(r_initaddr2 >= `BBL_SIZE + `BIN_DISK_SIZE)      r_disk_done     <= 1;
    end

`ifdef LAUR_MEM_RB
`ifdef LAUR_MEM_RB_ONLY_CHECK
        reg [31:0] r_rb_delay=0;
`endif
	reg [7:0] r_rb_state=0, r_rb_cnt=0;
	reg [31:0] r_rb_data=0, r_verify_checksum=0;
	assign w_verify_checksum = r_verify_checksum;
	wire w_checksum_match = (r_verify_checksum == r_checksum);
    	always@(posedge CLK) begin
		if(r_init_state != 6) begin
			r_rb_state <= 0;
			r_set_dram_le <= 0;
		end else begin
			if(r_rb_state == 0) begin // idle
				if(!r_mem_rb_done)
					r_rb_state <= 1;
			end else if(r_rb_state == 1) begin
				// memory is 0 between (`D_INITD_ADDR + `D_SIZE_DEVT) and `BBL_SIZE
				if(r_initaddr6 < (`BBL_SIZE + `BIN_DISK_SIZE)) begin
					if(!w_dram_busy) begin
						r_set_dram_le <= 1;
						r_rb_state <= 7;
					end
				end else begin
					r_mem_rb_done <= 1;
					r_rb_state <= 0;
				end
			end else if(r_rb_state == 7) begin // we have sent command
				if(w_dram_busy) begin
					r_set_dram_le <= 0;
					r_rb_state <= 2;
				end
			end else if(r_rb_state == 2) begin // wait ram data
				r_set_dram_le <= 0;
				if(!w_dram_busy) begin
					// we have w_dram_odata
					r_verify_checksum <= r_verify_checksum + w_dram_odata;
					r_rb_data <= w_dram_odata;
`ifdef LAUR_MEM_RB_ONLY_CHECK
					$display("mem[%x]: %x='%c%c%c%c'", r_initaddr6, w_dram_odata, 
						 w_dram_odata >> 24, (w_dram_odata >> 16) & 8'hff, 
						(w_dram_odata >> 8) & 8'hff, w_dram_odata & 8'hff);
					r_rb_state <= 20;
					r_rb_delay <= 0;
`else
					r_rb_state <= 3;
`endif
					r_rb_cnt <= 0;
				end
`ifdef LAUR_MEM_RB_ONLY_CHECK
			end else if(r_rb_state == 20) begin
                                if(r_rb_delay < 1) 
                                        r_rb_delay <= r_rb_delay + 1;
                                else begin
                                        r_rb_state <= 0;
                                        r_initaddr6 <= r_initaddr6 + 4;
                                        r_rb_delay <= 0;
                                end	
`endif
			end else if(r_rb_state == 3) begin // send 32 bit data
				if(w_tx_ready)
				       if(r_rb_cnt < 4) begin
						r_rb_cnt <= r_rb_cnt + 1;
						r_rb_uart_data <= r_rb_data[7:0];
						r_rb_data <= {8'h0, r_rb_data[31:8]};
						r_rb_state <= 4;
					end else begin
						r_rb_uart_we <= 0;
						r_initaddr6 <= r_initaddr6 + 4;
						r_rb_state <= 0;
					end
			end else if(r_rb_state == 4) begin // send 1 byte
				r_rb_uart_we <= 1;
				if(!w_tx_ready)
					r_rb_state <= 5;
			end else if(r_rb_state == 5) begin // done sending 1 byte
				r_rb_state <= 3;
				r_rb_uart_we <= 0;
			end
		end
    	end
`endif

    // Zero init
    wire calib_done;
    always@(posedge CLK) begin
`ifdef SIM_MAIN
	r_zero_we <= 0;
	r_zero_done <= 1;
`else
`ifndef ARTYA7
        if(!w_dram_busy & !r_zero_done) r_zero_we <= 1;
`else
        if(!w_dram_busy & !r_zero_done & calib_done) r_zero_we <= 1;
`endif
        if(r_zero_we) begin
            r_zero_we    <= 0;
            r_zeroaddr <= r_zeroaddr + 4;
        end
        if(r_zeroaddr >= `MEM_SIZE) r_zero_done <= 1;
`endif
    end

`ifdef SIM_MODE
    assign w_zero_we = 0;
`else
`ifdef SIM_MAIN
    assign w_zero_we = 0;
`else
    assign w_zero_we = r_zero_we;
`endif
`endif
    /**********************************************************************************************/
    wire [31:0] w_dram_addr_t   = ((w_dram_addr[31:28]==9) ?
                                    (w_dram_addr & 32'h3ffffff) + `BBL_SIZE :
                                    w_dram_addr & 32'h3ffffff);
    wire [31:0]  w_dram_addr_t2 =
                    (r_init_state == 1) ? r_zeroaddr     : 
                    (r_init_state == 2) ? r_initaddr     :
`ifdef LAUR_MEM_RB
		    (r_init_state == 6) ? r_initaddr6    :
`endif
                    (r_init_state == 3) ? r_initaddr3    : 
                    (r_init_state == 4) ? r_initaddr2    : w_dram_addr_t;
    
    wire [31:0]  w_dram_wdata_t   =   (r_init_state == 1) ? 32'b0 :
                                    (r_init_state == 5) ? w_dram_wdata : w_pl_init_data;
    wire         w_dram_we_t      =   (w_pte_we || w_dram_we || w_imag_we) && !w_dram_busy;
    wire [2:0]   w_dram_ctrl_t  = (!w_init_done) ? `FUNCT3_SW____ : w_dram_ctrl;
/**************************************************************************************************/

`ifdef LAUR_MEM_RB
wire w_wr_en = 
                               (r_init_state == 6) ? 0 :
				w_zero_we || w_pl_init_we || w_dram_we_t;
`else
wire w_wr_en =                  w_zero_we || w_pl_init_we || w_dram_we_t;
`endif


`ifdef SIM_MODE
    m_dram_sim#(`MEM_SIZE) idbmem(CLK, w_dram_addr_t2, w_dram_odata, w_dram_we_t, w_dram_le,
                                    w_dram_wdata_t, w_dram_ctrl_t, w_dram_busy, w_mtime[31:0]);
`else
    DRAM_conRV dram_con (
                                // user interface ports
                               .i_rd_en(w_dram_le),
                               .i_wr_en(w_wr_en),
                               .i_addr(w_dram_addr_t2),
                               .i_data(w_dram_wdata_t),
                               .o_data(w_dram_odata),
                               .o_busy(w_dram_busy),
                               .i_ctrl(w_dram_ctrl_t),
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
                               // other
                               .o_init_calib_complete(calib_done)
                               );
`endif

// first 4 leds are set in main.v
`ifdef LAUR_MEM_RB
    assign w_led = ({r_rb_state[2:0], w_checksum_match} << 12) | (r_mem_rb_done << 11) | (r_init_state << 8)
                    | ({w_pl_init_done, r_disk_done, r_bbl_done, r_zero_done} << 4) | r_init_state;
`else
    assign w_led = (w_proc_busy << 12) | (r_mc_mode << 8)
                    | ({w_pl_init_done, r_disk_done, r_bbl_done, r_zero_done} << 4) | r_init_state;
`endif
    
endmodule
/**************************************************************************************************/
/*** Simple Direct Mapped Cache for TLB                                                         ***/
/**************************************************************************************************/
module m_tlb#(parameter ADDR_WIDTH = 20, D_WIDTH = 20, ENTRY = 4)
            (CLK, RST_X, w_flush, w_we, w_waddr, w_raddr, w_idata, w_odata, w_oe);
    input  wire                     CLK, RST_X;
    input  wire                     w_flush, w_we;
    input  wire [ADDR_WIDTH-1:0]    w_waddr, w_raddr;
    input  wire    [D_WIDTH-1:0]    w_idata;
    output wire    [D_WIDTH-1:0]    w_odata;
    output wire                     w_oe;             //output enable

    reg                               [ENTRY-1:0]   r_valid = 0;
    reg  [(ADDR_WIDTH-$clog2(ENTRY)+D_WIDTH)-1:0]   mem [0:ENTRY-1];
    integer i;
    initial for(i=0; i<ENTRY; i=i+1) mem[i] = 0;

    // READ
    wire              [$clog2(ENTRY)-1:0]   w_ridx;
    wire [(ADDR_WIDTH-$clog2(ENTRY))-1:0]   w_rtag;
    assign {w_rtag, w_ridx} = w_raddr;

    wire w_tagmatch = (mem[w_ridx][(ADDR_WIDTH-$clog2(ENTRY)+D_WIDTH)-1:D_WIDTH] == w_rtag);

    assign w_odata  = mem[w_ridx][D_WIDTH-1:0];
    assign w_oe     = (w_tagmatch && r_valid[w_ridx]);

    // WRITE
    wire              [$clog2(ENTRY)-1:0]   w_widx;
    wire [(ADDR_WIDTH-$clog2(ENTRY))-1:0]   w_wtag;
    assign {w_wtag, w_widx} = w_waddr;

    always  @(posedge  CLK)  begin
        // FLUSH
        if (!RST_X || w_flush) begin
            r_valid <= 0;
        end
        if (w_we) begin
            mem[w_widx] <= {w_wtag, w_idata};
            r_valid[w_widx] <= 1;
        end
    end
endmodule // m_tlb

/**************************************************************************************************/
