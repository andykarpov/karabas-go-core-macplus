`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_video.v

 The screen of the Mac (512 x 342, 1 bit) through a frame buffer in block RAM, out as 1024 x 768 at
 60 Hz (VESA, 65 MHz), every pixel 2 x 2: 1024 x 684 in the middle, 42 black lines above and below.

 Write side (clk_sys, the machine): the words of video RAM as the machine loads them into its
 shifter (vid_load at the end of busPhase 7, 16 pixels, bit 15 left, 1 = black): 32 per line,
 342 lines, only inside the visible screen. The n-th word after the start of the vertical sync of
 the machine goes to word n of the buffer (10944 words of 16 bits).

 Read side (clk_65): the VESA timing (1344 x 806: 1024 + 24 + 136 + 160, 768 + 3 + 6 + 29, negative
 syncs), a buffer word read one clock ahead of the pixel pipeline. The machine (59.4 Hz) and the output
 (60.0 Hz) are not locked: the buffer is written while it is read, a frame shows a seam once a
 second or two, invisible on a still screen.

 hs / vs / de are positive here (the top inverts the syncs for HDMI / VGA), rgb is white or black.
*/

module mac_video (
	input  wire        clk_sys,
	input  wire        vid_load,
	input  wire [2:0]  phase,
	input  wire [15:0] vid_word,
	input  wire        vsync_n,    // the vsync of the machine (low in the sync)

	input  wire        clk_65,
	input  wire        blank,      // black screen (the machine in reset)
	output reg  [23:0] rgb = 24'd0,
	output reg         hs = 1'b0,
	output reg         vs = 1'b0,
	output reg         de = 1'b0
);

// ------------------------------------------------------------------ write

reg [15:0] fb [0:10943];
reg [13:0] wa = 14'd0;
reg vs_d = 1'b1;

always @(posedge clk_sys) begin
	vs_d <= vsync_n;
	if (vs_d && !vsync_n)
		wa <= 14'd0;
	else if (vid_load && phase == 3'd7) begin
		if (wa < 14'd10944)
			fb[wa] <= vid_word;
		wa <= wa + 14'd1;
	end
end

// ------------------------------------------------------------------ read: 1024 x 768 at 60 Hz

localparam H_TOTAL = 11'd1344, H_SYNC0 = 11'd1048, H_SYNC1 = 11'd1184;
localparam V_TOTAL = 10'd806,  V_SYNC0 = 10'd771,  V_SYNC1 = 10'd777;
localparam V_TOP = 10'd42;   // the first line of the Mac screen

reg [10:0] hc = 11'd0;
reg [9:0] vc = 10'd0;

always @(posedge clk_65) begin
	if (hc == H_TOTAL - 11'd1) begin
		hc <= 11'd0;
		vc <= (vc == V_TOTAL - 10'd1) ? 10'd0 : vc + 10'd1;
	end
	else
		hc <= hc + 11'd1;
end

// whether this output line shows the Mac screen
wire in_y = (vc >= V_TOP) && (vc < V_TOP + 10'd684);

// the word of the next pixel (hc + 1, x / 32): it is in word when that pixel is in stage 1; at the
// end of a line the next pixel is on the next line
wire [10:0] hx = hc + 11'd1;
wire last_h = (hc == H_TOTAL - 11'd1);
wire [9:0] vn = !last_h ? vc : (vc == V_TOTAL - 10'd1) ? 10'd0 : vc + 10'd1;
wire [9:0] myn = vn - V_TOP;
reg [13:0] ra = 14'd0;
reg [15:0] word = 16'd0;
always @(posedge clk_65) begin
	ra <= { myn[9:1], 5'd0 } + { 9'd0, (last_h ? 5'd0 : hx[9:5]) };
	word <= fb[ra];
end

// the pixel pipeline: the edge at hc = x - 1 sets ra, at x word gets the word of x and stage 1 the
// bit of x, at x + 1 rgb has pixel x (with de / hs / vs of x)
reg [3:0] bit1 = 4'd0;
reg act1 = 1'b0;
reg de1 = 1'b0, hs1 = 1'b0, vs1 = 1'b0;
always @(posedge clk_65) begin
	// stage 1: the bit of the pixel at hc (the word comes at stage 2)
	bit1 <= 4'd15 - hc[4:1];
	act1 <= in_y && hc < 11'd1024 && !blank;
	de1 <= (hc < 11'd1024) && (vc < 10'd768);
	hs1 <= (hc >= H_SYNC0) && (hc < H_SYNC1);
	vs1 <= (vc >= V_SYNC0) && (vc < V_SYNC1);
	// stage 2
	rgb <= (act1 && !word[bit1]) ? 24'hFFFFFF : 24'h000000;
	de <= de1;
	hs <= hs1;
	vs <= vs1;
end

endmodule
