`timescale 1ns / 1ps

// tb_floppy_swap.v (iverilog): floppy_track_buffer (rtl/sv2v) with a model of the sd interface,
// one image per mount (the bytes of image i, sector lba, offset b are img_byte(i, lba, b)):
//  1. image 1 in drive 0, track 0 loaded: the buffer reads image 1;
//  2. a byte written by the IWM into sector 0, then image 2 mounted (an OSD swap without an
//     eject): the buffer reloads track 0 from image 2 and nothing is written into image 2;
//  3. a byte written into sector 1, the activity stops: the sector goes to image 2 (write-back);
//  4. track 1 requested, image 3 mounted while its sectors come: the buffer ends with image 3.

module tb_floppy_swap;

reg clk = 0;
always #32 clk = !clk;

reg rst = 1;
reg [1:0] eject = 0;
reg activity = 1, drive = 0, side = 0;
reg [6:0] track = 0;
reg [13:0] addr = 0;
reg [7:0] wdata = 0;
reg [8:0] waddr = 0;
reg [3:0] wsector = 0;
reg wstrobe = 0;
reg [31:0] img_size = 0;
reg [1:0] img_mounted = 0;
reg sd_busy = 0, sd_data_en = 0;
reg [8:0] sd_addr = 0;
reg [7:0] sd_data_in = 0;

wire [3:0] spt;
wire ready, dirty;
wire [7:0] data, sd_data_out;
wire [1:0] inserted, sides, sd_rd, sd_wr;
wire [10:0] sd_lba;

floppy_track_buffer dut (
	.clk(clk), .rst(rst), .eject(eject), .activity(activity), .drive(drive), .side(side),
	.track(track), .spt(spt), .ready(ready), .addr(addr), .data(data), .dirty(dirty),
	.writeDataDecoded(wdata), .writeAddr(waddr), .writeSector(wsector), .writeStrobe(wstrobe),
	.sd_img_size(img_size), .sd_img_mounted(img_mounted), .inserted(inserted), .sides(sides),
	.sd_lba(sd_lba), .sd_rd(sd_rd), .sd_wr(sd_wr), .sd_busy(sd_busy), .sd_done(1'b0),
	.sd_addr(sd_addr), .sd_data_en(sd_data_en), .sd_data_in(sd_data_in), .sd_data_out(sd_data_out)
);

function [7:0] img_byte(input integer i, input integer lba, input integer b);
	img_byte = (i * 8'h47) ^ (lba * 8'h1D) ^ b[7:0] ^ (b >> 8);
endfunction

integer errors = 0, cur_img = 0, sectors_read = 0, i, n;
integer wr_img [0:15];
integer wr_lba [0:15];
reg [7:0] wr_b0 [0:15];
integer writes = 0;

// the sd interface: a request (sd_rd / sd_wr held until busy), busy, the bytes, end of busy
always @(posedge clk) begin : sd_model
	integer lba, b;
	if (sd_rd != 0 || sd_wr != 0) begin
		lba = sd_lba;
		repeat (3) @(posedge clk);
		sd_busy <= 1;
		@(posedge clk);
		if (sd_wr != 0) begin
			// the write: each address held, the byte taken 3 clocks later
			wr_img[writes] = cur_img; wr_lba[writes] = lba;
			for (b = 0; b < 512; b = b + 1) begin
				sd_addr <= b;
				repeat (3) @(posedge clk);
				if (b == 0) wr_b0[writes] = sd_data_out;
			end
			writes = writes + 1;
		end
		else begin
			for (b = 0; b < 512; b = b + 1) begin
				repeat (2) @(posedge clk);
				sd_addr <= b; sd_data_in <= img_byte(cur_img, lba, b); sd_data_en <= 1;
				@(posedge clk);
				sd_data_en <= 0;
			end
			sectors_read = sectors_read + 1;
		end
		repeat (2) @(posedge clk);
		sd_busy <= 0;
		@(posedge clk);
	end
end

task mount(input integer img);
	begin
		@(negedge clk) begin cur_img = img; img_size <= 819200; img_mounted <= 2'b01; end
		@(negedge clk) img_mounted <= 2'b00;
	end
endtask

task wait_ready;
	begin
		n = 0;
		while (!ready && n < 400000) begin @(posedge clk); n = n + 1; end
		if (!ready) begin $display("ERROR: no ready"); errors = errors + 1; end
	end
endtask

// a byte of the buffer, side 0: sector k (lba of the track + k), offset b
task check(input integer img, input integer lba0, input integer k, input integer b, input [8*24-1:0] what);
	begin
		@(negedge clk) addr <= k * 512 + b;
		repeat (3) @(negedge clk);
		if (data !== img_byte(img, lba0 + k, b)) begin
			$display("ERROR: %0s: sector %0d byte %0d is %02x, image %0d has %02x", what, k, b, data,
				img, img_byte(img, lba0 + k, b));
			errors = errors + 1;
		end
	end
endtask

task iwm_write(input integer k, input [7:0] d);
	begin
		@(negedge clk) begin wsector <= k; waddr <= 0; wdata <= d; end
		@(negedge clk) wstrobe <= !wstrobe;
		repeat (2) @(negedge clk);
	end
endtask

initial begin
	repeat (4) @(negedge clk);
	rst <= 0;

	// 1. image 1, track 0 (both sides: lba 0..23)
	mount(1);
	wait_ready;
	check(1, 0, 0, 0, "image 1");
	check(1, 0, 11, 300, "image 1");

	// 2. a dirty sector 0, then image 2 in the same drive
	iwm_write(0, 8'hA5);
	if (!dirty) begin $display("ERROR: not dirty after a write"); errors = errors + 1; end
	mount(2);
	repeat (4) @(posedge clk);
	if (ready) begin $display("ERROR: still ready after a new image"); errors = errors + 1; end
	wait_ready;
	check(2, 0, 0, 0, "swap");
	check(2, 0, 5, 17, "swap");
	if (writes != 0) begin $display("ERROR: %0d sector(s) written after the swap (image %0d lba %0d)",
		writes, wr_img[0], wr_lba[0]); errors = errors + 1; end

	// 3. the write-back still works: sector 1 of image 2
	iwm_write(1, 8'h3C);
	@(negedge clk) activity <= 0;
	n = 0;
	while (writes == 0 && n < 100000) begin @(posedge clk); n = n + 1; end
	if (writes != 1 || wr_img[0] != 2 || wr_lba[0] != 1 || wr_b0[0] != 8'h3C) begin
		$display("ERROR: write-back: %0d writes, image %0d lba %0d byte %02x", writes, wr_img[0],
			wr_lba[0], wr_b0[0]);
		errors = errors + 1;
	end
	wait_ready;
	@(negedge clk) activity <= 1;

	// 4. track 1 (lba 24..47), image 3 mounted after 3 of its sectors
	i = sectors_read;
	@(negedge clk) track <= 1;
	while (sectors_read < i + 3) @(posedge clk);
	mount(3);
	wait_ready;
	check(3, 24, 0, 0, "swap while loading");
	check(3, 24, 2, 9, "swap while loading");
	check(3, 24, 11, 511, "swap while loading");

	$display("tb_floppy_swap: %0d errors", errors);
	$finish;
end

initial begin
	#200000000;
	$display("ERROR: timeout");
	$display("tb_floppy_swap: %0d errors", errors + 1);
	$finish;
end

endmodule
