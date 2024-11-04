/**************************************************************************************************/
/**** Micro Controller for VirtIO ver.2019-11-17a                                              ****/
/**** MicroV (Mikuro Five)                                since 2018-08-07  ArchLab. TokyoTech ****/
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/
`define MC_IF  0     // Inst Fetch
`define MC_OF  1     // Operand Fetch
`define MC_EX  2     // Execution
`define MC_MA  3     // Memory Access

/**************************************************************************************************/
`define D_UC_LM_BITS    13 // 8KB
`define D_UC_LM_WIDTH   32
`define D_UC_LM_IFILE   "ucimage.hex"
`define D_UC_LM_SIZE    (1<<(`D_UC_LM_BITS)) // do not change

/**** m_RVuc : Risc-V Micro Controller for VirtIO                                              ****/
/**************************************************************************************************/
module m_RVuc(CLK, RST_X, w_stall, w_mic_addr, w_data, w_mic_wdata, w_mic_mmuwe, w_mic_ctrl, w_mic_req);
    input  wire         CLK, RST_X;
    input  wire         w_stall;
    output wire [31:0]  w_mic_addr;
    input  wire [31:0]  w_data;
    output wire [31:0]  w_mic_wdata;
    output wire         w_mic_mmuwe;
    output wire  [2:0]  w_mic_ctrl;
    output wire  [1:0]  w_mic_req;

    reg  [31:0] r_pc     = 0; // program counter (PC)
    reg   [1:0] r_state  = 0; // state, showing the executiong stage
    reg  [31:0] r_ir     = 0; // instruction (IR) to be fetched
    reg   [6:0] r_opcode = 0; // a field of IR
    reg   [2:0] r_funct3 = 0; // a field of IR
    reg   [6:0] r_funct7 = 0; // a field of IR
    reg   [4:0] r_rd     = 0; // a field of IR
    reg  [31:0] r_imm    = 0; // immediate 
    reg  [31:0] r_rrs1   = 0; // the first  operand
    reg  [31:0] r_rrs2   = 0; // the second operand
    reg  [31:0] r_rslt   = 0; // the execution result

    reg  [31:0] r_dram_data = 0;
    
    always @(posedge CLK) begin
        r_state <= (!RST_X) ? 0 : (w_stall) ? r_state : (r_state==`MC_MA) ? `MC_IF : r_state+1;
    end

    wire [31:0] w_mem_rdata;
    wire        w_we = (r_opcode==`OPCODE_STORE___ && r_state==`MC_EX);

    wire [31:0] w_reg_d  = (r_opcode==`OPCODE_LOAD____) ? w_mem_rdata : r_rslt;
    wire        w_reg_we = (r_opcode==`OPCODE_LOAD____) ? 1 :
                           (r_opcode==`OPCODE_LUI_____) ? 1 :
                           (r_opcode==`OPCODE_AUIPC___) ? 1 :
                           (r_opcode==`OPCODE_JAL_____) ? 1 :
                           (r_opcode==`OPCODE_JALR____) ? 1 :
                           (r_opcode==`OPCODE_OP______) ? 1 :
                           (r_opcode==`OPCODE_OP_IMM__) ? 1 : 0;

    assign w_mic_req = (r_state==`MC_IF)                            ? `ACCESS_CODE  :
                   (r_state==`MC_EX && w_we)                        ? `ACCESS_WRITE :
                   (r_state==`MC_EX && r_opcode==`OPCODE_LOAD____)  ? `ACCESS_READ  : 3;

    /******************************************** OF  *********************************************/
    wire [31:0] w_ir;                       /* 32-bit instruction from memory */
    wire  [6:0] w_op      = w_ir[ 6: 0];
    wire  [4:0] w_rd      = w_ir[11: 7];
    wire  [4:0] w_rs1     = w_ir[19:15];
    wire  [4:0] w_rs2     = w_ir[24:20];
    wire  [2:0] w_funct3  = w_ir[14:12];
    wire  [6:0] w_funct7  = w_ir[31:25];
    wire [11:0] w_funct12 = w_ir[31:20];
    wire [31:0] w_imm;
    wire [31:0] w_rrs1, w_rrs2;

    m_imm_gen imm_gen0(w_ir, w_imm);

    wire w_reg_w = (w_reg_we && r_state==`MC_IF && !w_stall); // regfile write_enable
    
    m_regfile regs(CLK, w_rs1, w_rs2, w_rrs1, w_rrs2, w_reg_w, r_rd, w_reg_d);

    reg  [31:0] r_mic_addr  = 0;
    always @(posedge CLK) begin
        if(r_state == `MC_OF) begin
            r_ir     <= w_ir;
            r_opcode <= w_op;
            r_rd     <= w_rd;
            r_funct3 <= w_funct3;
            r_funct7 <= w_funct7;
            r_imm    <= w_imm;
            r_rrs1   <= w_rrs1;
            r_rrs2   <= w_rrs2;
            r_mic_addr <= w_rrs1 + w_imm;
        end
    end

    /******************************************** EX  *********************************************/
    wire [31:0] w_alu_i_rslt; // integer ALU's result
    wire        w_alu_b_rslt; // branch resolution unit's result

    wire  [6:0] w_alu_fn7 = (r_opcode==`OPCODE_OP_IMM__) ? 
                            ((r_funct3==`FUNCT3_ADD___) ? 0 : r_funct7 & 7'h20) : r_funct7;

    wire [31:0] w_in2 = (r_opcode==`OPCODE_OP_IMM__) ? r_imm : r_rrs2;
    
    m_alu_i ALU_I (r_rrs1, w_in2, r_funct3, w_alu_fn7, w_alu_i_rslt);
    m_alu_b ALU_B (r_rrs1, w_in2, r_funct3, w_alu_b_rslt);

    //wire [31:0] w_jmp_pc   = (r_opcode==`OPCODE_JALR____) ? r_rrs1+r_imm : r_pc+r_imm;
    //wire        w_tkn = (r_opcode==`OPCODE_JAL_____ || r_opcode==`OPCODE_JALR____) ? 1 :
    //                    (r_opcode==`OPCODE_BRANCH__) ? w_alu_b_rslt : 0;

    reg  [31:0] r_jmp_pc    = 0;
    reg         r_tkn       = 0;

    always @(posedge CLK) begin
        if(r_state == `MC_EX) begin
           case(r_opcode)  
               `OPCODE_LUI_____ : r_rslt <= r_imm;
               `OPCODE_AUIPC___ : r_rslt <= r_pc + r_imm;
               `OPCODE_JAL_____ : r_rslt <= r_pc + 4;
               `OPCODE_JALR____ : r_rslt <= r_pc + 4;
               `OPCODE_OP______ : r_rslt <= w_alu_i_rslt;
               `OPCODE_OP_IMM__ : r_rslt <= w_alu_i_rslt;
               `OPCODE_BRANCH__ : r_rslt <= 0;
               `OPCODE_LOAD____ : r_rslt <= 0;
               `OPCODE_STORE___ : r_rslt <= 0;
               `OPCODE_MISC_MEM : r_rslt <= 0;
               default : begin
                   r_rslt <= 0;
                   $write("UNKNOWN OPCODE DETECT in Micro Controller!!\n");
                   $write("PC:%08x OPCODE=%7b, ir=%8x\n", r_pc, r_opcode, r_ir);
                   $write("Simulation Stopped...\n");
                   $finish();
               end
           endcase
            r_jmp_pc <= (r_opcode==`OPCODE_JALR____) ? r_rrs1+r_imm : r_pc+r_imm;
            r_tkn <= (r_opcode==`OPCODE_JAL_____ || r_opcode==`OPCODE_JALR____) ? 1 :
                    (r_opcode==`OPCODE_BRANCH__) ? w_alu_b_rslt : 0;
            //r_mic_addr  <= r_rrs1 + r_imm;
        end
    end

    /******************************************** MA  *********************************************/
    always@(posedge CLK) begin
        r_dram_data <= w_data;
    end

    assign  w_mic_addr  = r_mic_addr;//r_rrs1 + r_imm;
    assign  w_mic_wdata = r_rrs2;
    assign  w_mic_ctrl  = r_funct3;

    wire [31:0] w_lcm_data; // data from local memory
    
    wire [31:0] w_mic_insn_addr = r_pc;
    wire [31:0] w_mic_insn_data;
    assign  w_ir = w_mic_insn_data;

    reg  [2:0] r_ctrl  = 3;
    reg  [1:0] r_addr2 = 0;

    wire [31:0] w_wdata_t, w_odata1, w_odata2;


    always@(posedge CLK) begin
        r_addr2 <= w_mic_addr;
        r_ctrl  <= w_mic_ctrl;
    end

    // Select Output DATA
    assign w_wdata_t =  (w_mic_ctrl[1:0]==0) ? {4{w_mic_wdata[7:0]}} :
                        (w_mic_ctrl[1:0]==1) ? {2{w_mic_wdata[15:0]}} :
                        w_mic_wdata;

    assign w_mic_insn_data  = w_odata1;
    
    wire [31:0] w_odata2_t  = w_odata2;
    wire [31:0] w_odata2_t2 = w_odata2_t >> {r_addr2[1:0], 3'b0};

    wire [31:0] w_odata2_lb  = {{24{w_odata2_t2[7]}}, w_odata2_t2[7:0]};
    wire [31:0] w_odata2_lbu = {24'h0, w_odata2_t2[7:0]};
    wire [31:0] w_odata2_lh  = {{16{w_odata2_t2[15]}}, w_odata2_t2[15:0]};
    wire [31:0] w_odata2_lhu = {16'h0, w_odata2_t2[15:0]};
    
    assign w_lcm_data = (r_ctrl[1:0]==3'b000) ? w_odata2_lb :
                        (r_ctrl[1:0]==3'b100) ? w_odata2_lbu:
                        (r_ctrl[1:0]==3'b001) ? w_odata2_lh :
                        (r_ctrl[1:0]==3'b101) ? w_odata2_lhu: w_odata2_t2;

    // Check Write Enable
    wire  [3:0] w_we_sb = (4'b0001 << w_mic_addr[1:0]);
    wire  [3:0] w_we_sh = (4'b0011 << {w_mic_addr[1], 1'b0});
    wire  [3:0] w_we_sw = 4'b1111;
    wire  [3:0] w_mic_lcmwe =   (!(w_we && w_mic_addr[31:28]==0 && !w_stall))   ? 0 :
                                (w_mic_ctrl[1:0]==2)                            ? w_we_sw :
                                (w_mic_ctrl[1:0]==1)                            ? w_we_sh : w_we_sb;

    // BRAMs
    m_lm_mc lm_mc(CLK, w_mic_insn_addr[`D_UC_LM_BITS-1:2], w_odata1,
                    w_mic_lcmwe, w_mic_addr[`D_UC_LM_BITS-1:2], w_odata2, w_wdata_t);
    
    assign w_mic_mmuwe  = w_we && (w_mic_addr[31:28]!=0);
    assign w_mem_rdata  = (w_mic_addr[31:28]==0) ? w_lcm_data : r_dram_data;

    /**********************************************************************************************/
    always @(posedge CLK) begin /***** update program counter */
        r_pc <= (!RST_X) ? 0 : (r_state!=`MC_MA || w_stall) ? r_pc : (r_tkn) ? r_jmp_pc : r_pc+4;
    end
endmodule
/**************************************************************************************************/

/*** Local Memory for Micro Controller                                                          ***/
/**************************************************************************************************/
module m_lm_mc(CLK, w_addr1, r_odata1, w_we, w_addr2, r_odata2, w_idata);
    input  wire                         CLK;
    input  wire                   [3:0] w_we;
    input  wire [(`D_UC_LM_BITS-2)-1:0] w_addr1, w_addr2;
    input  wire    [`D_UC_LM_WIDTH-1:0] w_idata;
    output  reg    [`D_UC_LM_WIDTH-1:0] r_odata1, r_odata2;

    (* ram_style = "block" *) reg [`D_UC_LM_WIDTH-1:0] mem[0:(`D_UC_LM_SIZE/4)-1];
    initial begin
        $readmemh(`D_UC_LM_IFILE, mem);
        $write("Load a micro contoroller's program: %s\n", `D_UC_LM_IFILE);
    end

    always@(posedge CLK) begin
        r_odata1 <= mem[w_addr1];
    end
    always @(posedge CLK) begin
        if (w_we[0]) mem[w_addr2][ 7: 0] <= w_idata[ 7: 0];
        if (w_we[1]) mem[w_addr2][15: 8] <= w_idata[15: 8];
        if (w_we[2]) mem[w_addr2][23:16] <= w_idata[23:16];
        if (w_we[3]) mem[w_addr2][31:24] <= w_idata[31:24];
        r_odata2 <= mem[w_addr2];
    end
endmodule
/**************************************************************************************************/
