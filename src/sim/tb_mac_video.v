`timescale 1ns / 1ps

// tb_mac_video.v (iverilog): the read side of mac_video. The frame buffer is filled with a pattern
// (written through its port, as the machine does), then one output frame is checked pixel by
// pixel: inside de, x = 0..1023 and y = 0..767 counted from de and vs, a pixel is white unless
// 42 <= y < 726 and bit 15 - (x / 2) % 16 of word ((y - 42) / 2) * 32 + x / 32 is set; the number
// of lines and pixels per line, and the sync lengths (136 clocks, 6 lines).

module tb_mac_video;

reg clk_sys = 0, clk_65 = 0;
always #32 clk_sys = !clk_sys;
always #7.692 clk_65 = !clk_65;

reg vid_load = 0, vsync_n = 1;
reg [2:0] phase = 0;
reg [15:0] vid_word = 0;
wire [23:0] rgb;
wire hs, vs, de;

mac_video dut (
	.clk_sys(clk_sys), .vid_load(vid_load), .phase(phase), .vid_word(vid_word), .vsync_n(vsync_n),
	.clk_65(clk_65), .blank(1'b0), .rgb(rgb), .hs(hs), .vs(vs), .de(de)
);

function [15:0] pat(input integer a);
	pat = (a * 16'h9E37) ^ (a >> 3) ^ 16'h5AA5;
endfunction

integer errors = 0, i, x = 0, y = -1, frames = 0, hs_len = 0, vs_lines = 0, lines = 0;
reg de_d = 0, vs_d = 0, hs_d = 0;
reg expect_w;
integer w;

always @(posedge clk_65) begin
	if (vs && !vs_d) begin
		if (frames > 0 && lines != 768) begin $display("ERROR: %0d lines", lines); errors = errors + 1; end
		frames = frames + 1;
		y = -1;
		lines = 0;
	end
	if (hs) hs_len = hs_len + 1;
	if (!hs && hs_d) begin
		if (hs_len != 136) begin $display("ERROR: hsync %0d clocks", hs_len); errors = errors + 1; end
		hs_len = 0;
		if (vs) vs_lines = vs_lines + 1;
	end
	if (de && !de_d) begin y = y + 1; x = 0; lines = lines + 1; end
	if (de && frames > 0 && y >= 0) begin
		if (y >= 42 && y < 726) begin
			w = pat(((y - 42) / 2) * 32 + x / 32);
			expect_w = !w[15 - (x / 2) % 16];
		end
		else
			expect_w = 0;
		if ((rgb == 24'hFFFFFF) != expect_w) begin
			if (errors < 10) $display("ERROR: pixel %0d,%0d is %06x", x, y, rgb);
			errors = errors + 1;
		end
	end
	if (de) x = x + 1;
	if (!de && de_d && frames > 0 && x != 1024) begin $display("ERROR: line %0d has %0d pixels", y, x); errors = errors + 1; end
	de_d = de; vs_d = vs; hs_d = hs;
end

initial begin
	// a vsync of the machine, then the 10944 words of a screen, one per bus cycle
	@(posedge clk_sys) vsync_n <= 0;
	@(posedge clk_sys) vsync_n <= 1;
	for (i = 0; i < 10944; i = i + 1) begin
		@(posedge clk_sys) begin vid_load <= 1; phase <= 7; vid_word <= pat(i); end
		@(posedge clk_sys) begin vid_load <= 0; phase <= 0; end
	end
	// one whole output frame after the fill
	while (frames < 2) @(posedge clk_65);
	if (vs_lines != 6) begin $display("ERROR: %0d vsync lines in one sync", vs_lines); errors = errors + 1; end
	$display("tb_mac_video: %0d errors", errors);
	$finish;
end

endmodule
