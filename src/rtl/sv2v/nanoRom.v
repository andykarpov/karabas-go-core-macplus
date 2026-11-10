module nanoRom (
	clk,
	nanoAddr,
	nanoOutput
);
	input clk;
	localparam NADDR_WIDTH = 9;
	input [8:0] nanoAddr;
	localparam NANO_WIDTH = 68;
	output reg [67:0] nanoOutput;
	localparam NANO_DEPTH = 336;
	reg [67:0] nRam [0:335];
	initial $readmemb("rtl/fx68k/nanorom.mem", nRam);
	always @(posedge clk) nanoOutput <= nRam[nanoAddr];
endmodule
