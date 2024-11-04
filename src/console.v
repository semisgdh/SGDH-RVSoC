/**************************************************************************************************/
/**** RVSoc (Mini Kuroda/RISC-V)                       since 2018-08-07   ArchLab. TokyoTech   ****/
/**** The Console Module v0.01                                                                 ****/
/**************************************************************************************************/
`default_nettype none
/**************************************************************************************************/
`include "define.vh"

/**************************************************************************************************/
module m_console(CLK, RST_X, w_we, w_addr_t, w_idata, w_iirq, w_odata,
                w_oirq, w_oeirq, w_mode, w_req, w_qnum, w_qsel, w_keyreq);
    input  wire         CLK, RST_X;
    input  wire         w_we;
    input  wire [31:0]  w_addr_t, w_idata, w_iirq;
    output wire [31:0]  w_odata, w_oirq;
    output wire         w_oeirq;
    input  wire  [1:0]  w_mode;   // 0:CPU, 1:CONS-w_req, 2: DISK_REQ
    output wire         w_req;    // Micro-Ctrl Request
    output wire [31:0]  w_qnum, w_qsel;
    input  wire         w_keyreq;

    wire [7:0] w_addr = w_addr_t[7:0]; // Note, use just lower8-bit, not verified
               
    reg  [31:0] MagicValue              = 32'h74726976;
    reg  [31:0] Version                 = 32'h2;
    reg  [31:0] DeviceID                = 32'h3;
    reg  [31:0] VendorID                = 32'hffff;
    reg  [31:0] DeviceFeatures          = 32'h1;
    reg  [31:0] QueueNumMax             = `CONSOLE_QUEUE_NUM_MAX;
    reg  [31:0] ConfigGeneration        = 0;

    reg   [7:0] Config [0:255];
    reg  [31:0] DeviceFeaturesSel       = 0;
    reg  [31:0] DriverFeatures          = 0;
    reg  [31:0] DriverFeaturesSel       = 0;
    reg  [31:0] InterruptStatus         = 0;
    reg  [31:0] InterruptAcknowledge    = 0;
    reg  [31:0] Status                  = 1;
    reg  [31:0] QueueSel                = 0; /* Note */
    reg  [31:0] QueueNum                = 0;

    reg  [31:0] Queue[0:(`CONSOLE_QUEUE_NUM_MAX * 9) -1];
    integer i;
    initial begin 
        for(i=0;i<`CONSOLE_QUEUE_NUM_MAX * 9;i=i+1) Queue[i] = 0;
    end
    
    reg  [31:0] r_rdata = 0;

    assign w_odata = r_rdata;
    assign w_oeirq = (w_mode==0) && w_we && (w_addr==32'h64);

    // Console IRQ
    wire [31:0] w_irqmask = 1 << (`VIRTIO_CONSOLE_IRQ-1);
    wire [31:0] w_oirq1   = w_iirq |  w_irqmask;
    wire [31:0] w_oirq2   = w_iirq & ~w_irqmask;
    assign      w_oirq    = (w_keyreq) ? w_oirq1 : (w_addr==32'h64) ? w_oirq2 : w_oirq1;

    assign w_req  = (w_mode==0 && w_we && w_addr == 32'h50 && w_idata == 1);
    assign w_qnum = (w_keyreq) ? QueueNum : w_idata;
    assign w_qsel = w_idata;

    always@(posedge CLK) begin
        // Micro-Ctrl Access
        if(w_mode==1 || w_mode==3) begin
            // READ
            r_rdata <= Queue[w_addr[$clog2(`CONSOLE_QUEUE_NUM_MAX*9)+1:2]];
            if(w_we) begin
                Queue[w_addr[$clog2(`CONSOLE_QUEUE_NUM_MAX*9)+1:2]] <= w_idata;
            end
        end
        
        // CPU Access
        else if(w_mode==0) begin
            // READ
            case (w_addr)
                32'h0   : r_rdata <= MagicValue;
                32'h4   : r_rdata <= Version;
                32'h8   : r_rdata <= DeviceID;
                32'hc   : r_rdata <= VendorID;
                32'h10  : r_rdata <= DeviceFeatures;
                32'h34  : r_rdata <= QueueNumMax;
                32'h44  : r_rdata <= Queue[QueueSel*9];               // Ready
                32'h60  : r_rdata <= InterruptStatus;
                32'h70  : r_rdata <= Status;
                32'hfc  : r_rdata <= ConfigGeneration;
                default : r_rdata <= 0;
            endcase

            // WRITE
            if(w_we) begin
                case (w_addr)
                    32'h14  : DeviceFeaturesSel         <= w_idata;
                    32'h20  : DriverFeatures            <= w_idata;
                    32'h24  : DriverFeaturesSel         <= w_idata;
                    32'h30  : QueueSel                  <= w_idata;
                    32'h38  : QueueNum                  <= w_idata;
                    32'h44  : Queue[QueueSel*9]         <= w_idata;  // Ready
                    32'h50  : begin
                        Queue[QueueSel*9+1] <= w_idata;              // Notify
                        InterruptStatus <= InterruptStatus | 1;
                    end
                    32'h64  : begin
                        InterruptAcknowledge <= w_idata;
                        InterruptStatus <= InterruptStatus & ~w_idata;
                    end
                    32'h70  : Status                    <= w_idata;
                    32'h80  : Queue[QueueSel*9+2]       <= w_idata;  // DescLow
                    32'h90  : Queue[QueueSel*9+4]       <= w_idata;  // AvailLow
                    32'ha0  : Queue[QueueSel*9+6]       <= w_idata;  // UsedLow
                endcase
            end
        end
        if(w_keyreq) begin
            InterruptStatus <= InterruptStatus | 1;
        end
    end
endmodule // Condole
/**************************************************************************************************/
