module videoTimer (
	clk,
	clk8_en_n,
	clk8_en_p,
	videoCycle,
	vid_alt,
	videoAddr,
	hsync,
	vsync,
	_hblank,
	_vblank,
	loadPixels,
	refresh
);
	input clk;
	input clk8_en_n;
	input clk8_en_p;
	input videoCycle;
	input vid_alt;
	output wire [20:0] videoAddr;
	output reg hsync;
	output reg vsync;
	output wire _hblank;
	output wire _vblank;
	output wire loadPixels;
	output wire refresh;
	localparam kTotalWidth = 704;
	localparam kVisibleWidth = 512;
	localparam kHsyncStart = 526;
	localparam kHsyncEnd = 529;
	localparam kTotalHeight = 370;
	localparam kVisibleHeight = 342;
	localparam kVsyncStart = 342;
	localparam kVsyncEnd = 346;
	reg [9:0] xpos;
	reg [8:0] ypos;
	wire endline = xpos == 703;
	assign refresh = xpos[9:3] == 7'h54;
	always @(posedge clk)
		if (clk8_en_n || clk8_en_p) begin
			if (endline)
				xpos <= 0;
			else if ((xpos == 0) && !videoCycle)
				xpos <= 0;
			else
				xpos <= xpos + 1'b1;
			if (endline) begin
				if (ypos == 369)
					ypos <= 0;
				else
					ypos <= ypos + 1'b1;
			end
			hsync <= ~((xpos >= kHsyncStart) && (xpos <= kHsyncEnd));
			vsync <= ~((ypos >= kVsyncStart) && (ypos <= kVsyncEnd));
		end
	assign _hblank = ~(xpos >= kVisibleWidth);
	assign _vblank = ~(ypos >= kVisibleHeight);
	assign videoAddr = (21'h1fd380 - (vid_alt ? 16'h0000 : 16'h4000)) + {ypos[8:0], xpos[8:4]};
	assign loadPixels = (_vblank && (xpos < kVisibleWidth)) && (videoCycle & !xpos[3]);
endmodule
