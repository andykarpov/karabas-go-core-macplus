`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_sram.v

 The SRAM of the board (two 2M x 8 chips = one 2M x 16, 10 ns, asynchronous) as the ROM of the Mac:
 the machine reads 16-bit words, the file loader of the mcu (the FL item of the ROM) writes bytes
 while the machine is held in reset. The even byte of a word is the high one (MD[15:8], MWR_N[1],
 MRD_N[1]), as the 68000 has it: a ROM file goes in byte by byte at its offsets.

 On clk_2x (30.95 MHz, 32.3 ns):
 - reads: MA takes raddr at every clock, rdata takes MD one clock later (32 ns for the pads and
   the 10 ns of the SRAM), so rdata follows raddr within two clocks of clk_2x (one machine clock).
   The machine takes ROM data at the end of busPhase 6 / 7, its address is stable from phase 2.
 - a write (we: one clock with waddr / wdata) turns /OE of both chips off (MRD_N = 11) and drives
   MD for three clocks, /WE of the lane low in the middle one; the reads pause meanwhile.
*/

module mac_sram (
	input  wire        clk,

	input  wire [20:0] raddr,      // word address
	output reg  [15:0] rdata = 16'hFFFF,

	input  wire        we,
	input  wire [21:0] waddr,      // byte address
	input  wire [7:0]  wdata,

	output reg  [20:0] MA = 21'd0,
	inout  wire [15:0] MD,
	output reg  [1:0]  MWR_N = 2'b11,
	output reg  [1:0]  MRD_N = 2'b00
);

reg wr_pend = 1'b0;
reg [21:0] wr_addr = 22'd0;
reg [7:0] wr_data = 8'd0;
reg md_oe = 1'b0;
reg [15:0] md_out = 16'd0;
reg [1:0] wst = 2'd0;   // 0 reading; 1, 2, 3 the write slot
reg rd_ok = 1'b0;       // MA held a read address during the last clock
reg lane = 1'b0;        // the lane of the write slot (a new we may change wr_addr meanwhile)

assign MD = md_oe ? md_out : 16'bz;

always @(posedge clk) begin
	if (we) begin
		wr_pend <= 1'b1;
		wr_addr <= waddr;
		wr_data <= wdata;
	end

	case (wst)
	2'd0:
		if (wr_pend && !we) begin
			MA <= wr_addr[21:1];
			lane <= wr_addr[0];
			md_out <= { wr_data, wr_data };
			md_oe <= 1'b1;
			MRD_N <= 2'b11;
			wr_pend <= 1'b0;
			rd_ok <= 1'b0;
			wst <= 2'd1;
		end
		else begin
			if (rd_ok) rdata <= MD;
			MA <= raddr;
			rd_ok <= 1'b1;
		end
	2'd1: begin
		MWR_N <= lane ? 2'b10 : 2'b01;   // odd: the low byte (lane 0)
		wst <= 2'd2;
	end
	2'd2: begin
		MWR_N <= 2'b11;
		wst <= 2'd3;
	end
	2'd3: begin
		md_oe <= 1'b0;
		MRD_N <= 2'b00;
		wst <= 2'd0;
	end
	endcase
end

endmodule
