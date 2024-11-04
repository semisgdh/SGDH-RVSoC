// Author Laurentiu-Cristian Duca, 2021-12-20.
// MIT license.
// It reads the id in the file fid.txt and if it has changed will read
// the command from fcmd.txt in a fifo

`include "define.vh"

`define EOF -1
`define READ_WAIT_DELAY 50000

`ifdef laur0
module test_icarus();
reg r_consf_en;
reg clk=0;
wire we;
wire [7:0] key;
always begin
	#50; clk = 1;
	#50; clk = 0;
	if($time >= `READ_WAIT_DELAY) begin
	    $display("time to finish");
            $finish();
	end
end
initial begin
	$dumpfile("read_file.vcd");
	$dumpvars(0, test);
	r_consf_en = 1;
	#450;
	r_consf_en = 0;
	#400;
	r_consf_en = 1;
	#400;
	r_consf_en = 0;
end

read_file rf(clk, r_consf_en, we, 64'd100, 64'd100);

endmodule
`endif

module read_file (clk, r_consf_en, we, w_mtime, min_time);
input wire clk, r_consf_en;
input wire [63:0] w_mtime, min_time;
output reg we = 0;
reg [7:0] fifo [0:15];
//reg [7:0] fifo2 [0:15];

// The character received from $fgetc
integer c=0, oldc=1;
// The file handle for the input file
integer fid, fcmd;

integer n, i;
// Line buffer
reg [`LINE_BUFFER_SIZE-1:0] line;

reg boot_done=0;
reg [63:0] wait_delay=0;

always @(posedge clk) begin

    // wait for the user to login as root
    if((w_mtime >= min_time) && !boot_done) begin
	$display("file, w_mtime=%d consider boot_done", w_mtime);
    	boot_done <= 1;
    end
    if(wait_delay >= `READ_WAIT_DELAY)
	    wait_delay <= 0;
    else 
	    wait_delay <= wait_delay + 1;
end

always @(posedge clk) begin
    if(we == 1)
	    we = 0;
    if(boot_done && (r_consf_en == 0) && !wait_delay) begin
	    oldc = c;

	    fid = $fopen("fid.txt", "r");
	    if (fid == 0) begin
        	$display ("ERROR: fid.txt not opened");
	        $finish;
	    end

	    c = $fgetc(fid);
	    if((c != oldc) && (c != `EOF)) begin
    		$display("new command='%c'=%d", c, c);
		oldc = c;

	  	fcmd = $fopen("fcmd.txt", "r");
  		if (fcmd == 0) begin
    			$display ("ERROR: fcmd.txt not opened");
			$finish;
  		end

`ifdef laur0
		// fcmd should be ended with enter.
		key = $fgetc(fcmd);
		we = 0;
		// key != EOF && key != '#'
		while((key != 8'hff) && (key != 23)) begin
			$display("key='%c'=%x", key, key);
			@(posedge clk);
			wait(r_consf_en == 0);
			we = 1;
			@(posedge clk);
			we = 0;
			wait(r_consf_en == 1);
			key = $fgetc(fcmd);
		end
`endif
//`ifdef laur0
		we = 1;
		line = "";
		n = $fgets(line, fcmd);
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
		//fifo2 = fifo;
		//for(i = 0; i < n; i++)
                //        $display("fifo2[%d]=%x='%c'", i, fifo2[i], fifo2[i]);
//`endif
		$fclose(fcmd);
	    end

	    $fclose(fid);

	end
end

endmodule
