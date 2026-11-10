module uRom (
	clk,
	microAddr,
	microOutput
);
	input clk;
	localparam UADDR_WIDTH = 10;
	input [9:0] microAddr;
	localparam UROM_WIDTH = 17;
	output reg [16:0] microOutput;
	localparam UROM_DEPTH = 1024;
	reg [16:0] uRam [0:1023];
	initial $readmemb("rtl/fx68k/microrom.mem", uRam);
	always @(posedge clk) microOutput <= uRam[microAddr];
endmodule
