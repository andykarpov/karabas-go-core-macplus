module floppy_track_buffer (
	clk,
	rst,
	eject,
	activity,
	drive,
	side,
	track,
	spt,
	ready,
	addr,
	data,
	dirty,
	writeDataDecoded,
	writeAddr,
	writeSector,
	writeStrobe,
	sd_img_size,
	sd_img_mounted,
	inserted,
	sides,
	sd_lba,
	sd_rd,
	sd_wr,
	sd_busy,
	sd_done,
	sd_addr,
	sd_data_en,
	sd_data_in,
	sd_data_out
);
	input clk;
	input rst;
	input [1:0] eject;
	input activity;
	input drive;
	input side;
	input [6:0] track;
	output wire [3:0] spt;
	output wire ready;
	input [13:0] addr;
	output wire [7:0] data;
	output wire dirty;
	input [7:0] writeDataDecoded;
	input [8:0] writeAddr;
	input [3:0] writeSector;
	input writeStrobe;
	input [31:0] sd_img_size;
	input [1:0] sd_img_mounted;
	output wire [1:0] inserted;
	output wire [1:0] sides;
	output reg [10:0] sd_lba;
	output reg [1:0] sd_rd;
	output reg [1:0] sd_wr;
	input sd_busy;
	input sd_done;
	input [8:0] sd_addr;
	input sd_data_en;
	input [7:0] sd_data_in;
	output wire [7:0] sd_data_out;
	reg [1:0] ejected = 2'b00;
	reg [63:0] size = 64'h0000000000000000;
	assign inserted = {!ejected[1] && (size[0+:32] != 32'd0), !ejected[0] && (size[32+:32] != 32'd0)};
	assign sides = {size[0+:32] > 32'd409600, size[32+:32] > 32'd409600};
	always @(posedge clk) begin
		if (sd_img_mounted[0]) begin
			size[32+:32] <= sd_img_size;
			ejected[0] <= 1'b0;
		end
		if (sd_img_mounted[1]) begin
			size[0+:32] <= sd_img_size;
			ejected[1] <= 1'b0;
		end
		if (eject[0])
			ejected[0] <= 1'b1;
		if (eject[1])
			ejected[1] <= 1'b1;
	end
	wire [6:0] iotrack;
	assign spt = (iotrack[6:4] == 3'd0 ? 4'd12 : (iotrack[6:4] == 3'd1 ? 4'd11 : (iotrack[6:4] == 3'd2 ? 4'd10 : (iotrack[6:4] == 3'd3 ? 4'd9 : 4'd8))));
	wire [9:0] track_times_12 = {iotrack, 3'b000} + {1'b0, iotrack, 2'b00};
	wire [9:0] track_times_11 = ({iotrack, 3'b000} + {2'b00, iotrack, 1'b0}) + {3'b000, iotrack};
	wire [9:0] track_times_10 = {iotrack, 3'b000} + {2'b00, iotrack, 1'b0};
	wire [9:0] track_times_9 = {iotrack, 3'b000} + {3'b000, iotrack};
	wire [9:0] track_times_8 = {iotrack, 3'b000};
	wire [6:0] trackm1 = iotrack - 7'd1;
	wire [9:0] soff = (iotrack == 0 ? 10'd0 : (trackm1[6:4] == 3'd0 ? track_times_12 : (trackm1[6:4] == 3'd1 ? track_times_11 + 10'd16 : (trackm1[6:4] == 3'd2 ? track_times_10 + (10'd32 + 10'd16) : (trackm1[6:4] == 3'd3 ? (track_times_9 + (10'd48 + 10'd32)) + 10'd16 : (track_times_8 + (10'd64 + 10'd48)) + (10'd32 + 10'd16))))));
	reg [7:0] track_in_buffer;
	reg [7:0] track_buffer [0:12287];
	reg [23:0] track_buffer_dirty;
	reg [4:0] track_loader_sector;
	reg [7:0] track_loader_state;
	reg [7:0] track_in_progress;
	reg [3:0] track_spt;
	reg track_force_write_back;
	assign dirty = track_buffer_dirty != 24'h000000;
	wire [6:0] track_in_buffer_track = track_in_buffer[6:0];
	wire track_in_buffer_drive = track_in_buffer[7];
	wire iowriting = ((((track_loader_state == 0) && !ready) && track_buffer_dirty) || (track_loader_state == 5)) || (track_loader_state == 6);
	assign iotrack = (iowriting ? track_in_buffer_track : track);
	wire [4:0] track_sector_to_write = (track_buffer_dirty[0] ? 5'd0 : (track_buffer_dirty[1] ? 5'd1 : (track_buffer_dirty[2] ? 5'd2 : (track_buffer_dirty[3] ? 5'd3 : (track_buffer_dirty[4] ? 5'd4 : (track_buffer_dirty[5] ? 5'd5 : (track_buffer_dirty[6] ? 5'd6 : (track_buffer_dirty[7] ? 5'd7 : (track_buffer_dirty[8] ? 5'd8 : (track_buffer_dirty[9] ? 5'd9 : (track_buffer_dirty[10] ? 5'd10 : (track_buffer_dirty[11] ? 5'd11 : (track_buffer_dirty[12] ? 5'd12 : (track_buffer_dirty[13] ? 5'd13 : (track_buffer_dirty[14] ? 5'd14 : (track_buffer_dirty[15] ? 5'd15 : (track_buffer_dirty[16] ? 5'd16 : (track_buffer_dirty[17] ? 5'd17 : (track_buffer_dirty[18] ? 5'd18 : (track_buffer_dirty[19] ? 5'd19 : (track_buffer_dirty[20] ? 5'd20 : (track_buffer_dirty[21] ? 5'd21 : (track_buffer_dirty[22] ? 5'd22 : (track_buffer_dirty[23] ? 5'd23 : 5'd31))))))))))))))))))))))));
	wire [7:0] track_requested = (ejected[drive] ? 8'hff : {drive, track});
	assign ready = (track_in_buffer == track_requested) && !track_force_write_back;
	wire [14:0] rd_addr = {1'b0, addr} + (side ? {spt, 9'd0} : 14'd0);
	reg [7:0] tb_q;
	reg tb_rd_ready;
	reg [7:0] data_hold;
	reg [7:0] sd_data_out_hold;
	wire [14:0] tb_raddr = (ready ? rd_addr : {1'b0, track_sector_to_write, sd_addr});
	always @(posedge clk) begin
		tb_q <= track_buffer[tb_raddr[13:0]];
		tb_rd_ready <= ready;
		data_hold <= data;
		sd_data_out_hold <= sd_data_out;
	end
	assign data = (tb_rd_ready ? tb_q : data_hold);
	assign sd_data_out = (tb_rd_ready ? sd_data_out_hold : tb_q);
	reg writeStrobeD;
	wire [4:0] wr_sector = {1'b0, writeSector} + (side ? {1'b0, spt} : 5'd0);
	wire tb_wr_iwm = ((!rst && (track_loader_state == 8'd0)) && ready) && (writeStrobe ^ writeStrobeD);
	wire tb_wr_sd = (!rst && (track_loader_state == 8'd2)) && sd_data_en;
	wire [13:0] tb_waddr = (tb_wr_iwm ? {wr_sector, writeAddr} : {track_loader_sector, sd_addr});
	wire [7:0] tb_wdata = (tb_wr_iwm ? writeDataDecoded : sd_data_in);
	always @(posedge clk)
		if (tb_wr_iwm || tb_wr_sd)
			track_buffer[tb_waddr] <= tb_wdata;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg activityD;
		if (rst) begin
			track_in_buffer <= 8'hff;
			track_loader_state <= 8'd0;
			sd_rd <= 2'b00;
			sd_wr <= 2'b00;
			track_force_write_back <= 1'b0;
			track_buffer_dirty <= 24'h000000;
		end
		else begin
			writeStrobeD <= writeStrobe;
			activityD <= activity;
			if ((!activity && activityD) && track_buffer_dirty)
				track_force_write_back <= 1'b1;
			case (track_loader_state)
				0:
					if ((!ready && !sd_busy) && (size[(1 - drive) * 32+:32] != 32'd0)) begin
						if (track_buffer_dirty) begin
							sd_lba <= (sides[track_in_buffer_drive] ? {soff, 1'b0} : {1'b0, soff}) + {6'd0, track_sector_to_write};
							sd_wr <= (track_in_buffer_drive ? 2'b10 : 2'b01);
							track_loader_state <= 8'd5;
						end
						else if (inserted[drive] && (track_requested != 8'hff)) begin
							$display("floppy_track_buffer.v: track requested: %0d", track_requested);
							track_in_buffer <= 8'hff;
							track_in_progress <= track_requested;
							track_spt <= spt;
							track_loader_sector <= 5'd0;
							sd_lba <= (sides[drive] ? {soff, 1'b0} : {1'b0, soff});
							sd_rd <= (drive ? 2'b10 : 2'b01);
							track_buffer_dirty <= 24'h000000;
							track_loader_state <= 8'd1;
							track_force_write_back <= 1'b0;
						end
					end
					else if (ready) begin
						if (writeStrobe ^ writeStrobeD)
							track_buffer_dirty[wr_sector] <= 1'b1;
					end
				1:
					if (sd_busy) begin
						sd_rd <= 2'b00;
						track_loader_state <= 8'd2;
					end
				2:
					if (sd_data_en) begin
						if (sd_addr == 9'd511)
							track_loader_state <= 8'd3;
					end
				3:
					if (!sd_busy)
						track_loader_state <= 8'd4;
				4:
					if (track_loader_sector >= ((2 * track_spt) - 1)) begin
						track_in_buffer <= track_in_progress;
						track_loader_state <= 8'd0;
					end
					else if (track_in_progress != track_requested)
						track_loader_state <= 8'd0;
					else begin
						track_loader_sector <= track_loader_sector + 5'd1;
						sd_lba <= sd_lba + 11'd1;
						sd_rd <= (track_in_progress[7] ? 2'b10 : 2'b01);
						track_loader_state <= 8'd1;
					end
				5:
					if (sd_busy) begin
						sd_wr <= 2'b00;
						track_loader_state <= 8'd6;
					end
				6:
					if (!sd_busy) begin
						track_buffer_dirty[track_sector_to_write] <= 1'b0;
						track_loader_state <= 8'd0;
					end
			endcase
			if (sd_img_mounted[track_in_buffer_drive] && (track_in_buffer != 8'hff)) begin
				track_in_buffer <= 8'hff;
				track_buffer_dirty <= 24'h000000;
				track_force_write_back <= 1'b0;
			end
			if ((sd_img_mounted[track_in_progress[7]] && (track_loader_state >= 8'd1)) && (track_loader_state <= 8'd4)) begin
				track_in_progress <= 8'hfe;
				if (track_loader_state == 8'd4)
					track_in_buffer <= 8'hff;
			end
		end
	end
endmodule
