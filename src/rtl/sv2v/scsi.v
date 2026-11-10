module scsi (
	clk,
	rst,
	sel,
	atn,
	bsy,
	msg,
	cd,
	io,
	req,
	ack,
	din,
	dout,
	img_mounted,
	img_blocks,
	wr_prot,
	io_lba,
	io_rd,
	io_wr,
	io_ack,
	sd_buff_addr,
	sd_buff_dout,
	sd_buff_din,
	sd_buff_wr
);
	input clk;
	input rst;
	input sel;
	input atn;
	output wire bsy;
	output wire msg;
	output wire cd;
	output wire io;
	output wire req;
	input ack;
	input [7:0] din;
	output wire [7:0] dout;
	input img_mounted;
	input [31:0] img_blocks;
	input wr_prot;
	output wire [31:0] io_lba;
	output reg io_rd;
	output reg io_wr;
	input io_ack;
	input [8:0] sd_buff_addr;
	input [7:0] sd_buff_dout;
	output wire [7:0] sd_buff_din;
	input sd_buff_wr;
	parameter [2:0] ID = 0;
	localparam PHASE_IDLE = 3'd0;
	localparam PHASE_CMD_IN = 3'd1;
	localparam PHASE_DATA_OUT = 3'd2;
	localparam PHASE_DATA_IN = 3'd3;
	localparam PHASE_STATUS_OUT = 3'd4;
	localparam PHASE_MESSAGE_OUT = 3'd5;
	reg [2:0] phase;
	reg sd_buff_sel;
	reg old_io_ack;
	always @(posedge clk) begin
		old_io_ack <= io_ack;
		if (phase == PHASE_IDLE)
			sd_buff_sel <= 0;
		else if (old_io_ack & ~io_ack)
			sd_buff_sel <= !sd_buff_sel;
	end
	reg buffer_wr;
	wire [7:0] buffer_dout;
	reg [31:0] data_cnt;
	scsi_dpram #(.ADDRWIDTH(10)) buffer(
		.clock(clk),
		.address_a({sd_buff_sel, sd_buff_addr}),
		.data_a(sd_buff_dout),
		.wren_a(sd_buff_wr),
		.q_a(sd_buff_din),
		.address_b(data_cnt[9:0]),
		.data_b(din),
		.wren_b(buffer_wr),
		.q_b(buffer_dout)
	);
	reg [7:0] status;
	assign msg = phase == PHASE_MESSAGE_OUT;
	assign cd = ((phase == PHASE_CMD_IN) || (phase == PHASE_STATUS_OUT)) || (phase == PHASE_MESSAGE_OUT);
	assign io = ((phase == PHASE_DATA_OUT) || (phase == PHASE_STATUS_OUT)) || (phase == PHASE_MESSAGE_OUT);
	wire io_busy = ((((phase == PHASE_DATA_OUT) && (io_rd | io_ack)) && (data_cnt[9] == sd_buff_sel)) || (((phase == PHASE_DATA_IN) && (io_wr | io_ack)) && (data_cnt[9] == sd_buff_sel))) || (((phase != PHASE_DATA_OUT) && (phase != PHASE_DATA_IN)) && ((io_rd | io_wr) | io_ack));
	assign req = ((phase != PHASE_IDLE) && !ack) && !io_busy;
	assign bsy = phase != PHASE_IDLE;
	reg [7:0] cmd [9:0];
	wire [7:0] op_code = cmd[0];
	wire cmd_inquiry = op_code == 8'h12;
	wire cmd_mode_sense = op_code == 8'h1a;
	wire cmd_read10 = op_code == 8'h28;
	wire cmd_read6 = op_code == 8'h08;
	wire cmd_read = cmd_read6 || cmd_read10;
	wire cmd_read_capacity = op_code == 8'h25;
	wire [7:0] inquiry_dout = (data_cnt == 32'd4 ? 8'd32 : (data_cnt == 32'd8 ? " " : (data_cnt == 32'd9 ? "S" : (data_cnt == 32'd10 ? "E" : (data_cnt == 32'd11 ? "A" : (data_cnt == 32'd12 ? "G" : (data_cnt == 32'd13 ? "A" : (data_cnt == 32'd14 ? "T" : (data_cnt == 32'd15 ? "E" : (data_cnt == 32'd16 ? " " : (data_cnt == 32'd17 ? " " : (data_cnt == 32'd18 ? " " : (data_cnt == 32'd19 ? " " : (data_cnt == 32'd20 ? " " : (data_cnt == 32'd21 ? " " : (data_cnt == 32'd22 ? " " : (data_cnt == 32'd23 ? " " : (data_cnt == 32'd24 ? " " : (data_cnt == 32'd25 ? " " : (data_cnt == 32'd26 ? "S" : (data_cnt == 32'd27 ? "T" : (data_cnt == 32'd28 ? "2" : (data_cnt == 32'd29 ? "2" : (data_cnt == 32'd30 ? "5" : (data_cnt == 32'd31 ? "N" : 8'h00)))))))))))))))))))))))));
	reg [31:0] capacity;
	wire [7:0] mode_sense_dout = (data_cnt == 32'd2 ? {wr_prot, 7'h00} : (data_cnt == 32'd3 ? 8'd8 : (data_cnt == 32'd5 ? capacity[23:16] : (data_cnt == 32'd6 ? capacity[15:8] : (data_cnt == 32'd7 ? capacity[7:0] : (data_cnt == 32'd10 ? 8'd2 : 8'h00))))));
	wire [7:0] read_capacity_dout = (data_cnt == 32'd0 ? capacity[31:24] : (data_cnt == 32'd1 ? capacity[23:16] : (data_cnt == 32'd2 ? capacity[15:8] : (data_cnt == 32'd3 ? capacity[7:0] : (data_cnt == 32'd6 ? 8'd2 : 8'h00)))));
	wire [7:0] cmd_dout = (cmd_read ? buffer_dout : (cmd_inquiry ? inquiry_dout : (cmd_read_capacity ? read_capacity_dout : (cmd_mode_sense ? mode_sense_dout : 8'h00))));
	assign dout = (phase == PHASE_STATUS_OUT ? status : (phase == PHASE_MESSAGE_OUT ? 8'h00 : (phase == PHASE_DATA_OUT ? cmd_dout : 8'h00)));
	reg mounted = 0;
	always @(posedge clk)
		if (img_mounted) begin
			if (|img_blocks) begin
				capacity <= img_blocks;
				$display("Image mounted on target %d, size: %d", ID, img_blocks);
				mounted <= 1;
			end
			else
				mounted <= 0;
		end
	reg [3:0] cmd_cnt;
	reg [31:0] lba;
	assign io_lba = lba;
	reg data_complete;
	reg [15:0] tlen;
	wire req_rd = (((phase == PHASE_DATA_OUT) && cmd_read) && ((data_cnt == 0) || ((data_cnt[8:0] == 9'd20) && (data_cnt[31:9] != ({7'd0, tlen} - 1'd1))))) && !data_complete;
	wire cmd_write10 = op_code == 8'h2a;
	wire cmd_write6 = op_code == 8'h0a;
	wire cmd_write = cmd_write6 || cmd_write10;
	wire req_wr = ((((phase == PHASE_DATA_IN) && (data_cnt[8:0] == 0)) && (data_cnt != 0)) || (phase == PHASE_STATUS_OUT)) && cmd_write;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg old_rd;
		reg old_wr;
		reg wr_pending;
		reg rd_pending;
		old_rd <= req_rd;
		old_wr <= req_wr;
		if (~old_rd & req_rd)
			rd_pending <= 1;
		if (~old_wr & req_wr)
			wr_pending <= 1;
		if (io_ack) begin
			io_rd <= 1'b0;
			io_wr <= 1'b0;
		end
		else begin
			if (rd_pending && !io_rd) begin
				$display("Target %d read %d", ID, lba);
				io_rd <= 1;
				rd_pending <= 0;
			end
			if (wr_pending && !io_wr) begin
				$display("Target %d write %d", ID, lba);
				io_wr <= 1;
				wr_pending <= 0;
			end
		end
	end
	reg stb_ack;
	reg stb_adv;
	always @(posedge clk) begin : sv2v_autoblock_2
		reg old_ack;
		old_ack <= ack;
		stb_ack <= ~old_ack & ack;
		stb_adv <= old_ack & ~ack;
	end
	always @(posedge clk) begin
		buffer_wr <= 1'b0;
		if (stb_ack) begin
			if (phase == PHASE_CMD_IN)
				cmd[cmd_cnt] <= din;
			if (phase == PHASE_DATA_IN)
				buffer_wr <= 1'b1;
		end
	end
	always @(posedge clk)
		if (phase == PHASE_IDLE)
			cmd_cnt <= 4'd0;
		else if ((stb_adv && (phase == PHASE_CMD_IN)) && (cmd_cnt != 15))
			cmd_cnt <= cmd_cnt + 4'd1;
	wire [31:0] data_len = (cmd_read_capacity ? 32'd8 : (cmd_read ? {7'd0, tlen, 9'd0} : (cmd_write ? {7'd0, tlen, 9'd0} : {16'd0, tlen})));
	always @(posedge clk)
		if ((((phase != PHASE_DATA_OUT) && (phase != PHASE_DATA_IN)) && (phase != PHASE_STATUS_OUT)) && (phase != PHASE_MESSAGE_OUT)) begin
			data_cnt <= 0;
			data_complete <= 0;
		end
		else if (stb_adv) begin
			if (!data_complete)
				data_cnt <= data_cnt + 1'd1;
			data_complete <= (data_len - 1'd1) == data_cnt;
		end
	reg status_sent;
	always @(posedge clk)
		if (phase != PHASE_STATUS_OUT)
			status_sent <= 0;
		else if (stb_adv)
			status_sent <= 1;
	reg message_sent;
	always @(posedge clk)
		if (phase != PHASE_MESSAGE_OUT)
			message_sent <= 0;
		else if (stb_adv)
			message_sent <= 1;
	wire [2:0] cmd_group = op_code[7:5];
	wire cmd10_cpl = ((cmd_group == 3'b010) || (cmd_group == 3'b001)) && (cmd_cnt == 10);
	wire cmd6_cpl = (cmd_group == 3'b000) && (cmd_cnt == 6);
	wire cmd_cpl = cmd6_cpl || cmd10_cpl;
	wire cmd_format = op_code == 8'h04;
	wire cmd_mode_select = op_code == 8'h15;
	wire cmd_test_unit_ready = op_code == 8'h00;
	wire cmd_read_buffer = op_code == 8'h3b;
	wire cmd_write_buffer = op_code == 8'h3c;
	wire cmd_verify6 = op_code == 8'h13;
	wire cmd_verify10 = op_code == 8'h2f;
	wire cmd_ok = ((((((((((cmd_read || cmd_write) || cmd_inquiry) || cmd_test_unit_ready) || cmd_read_capacity) || cmd_mode_select) || cmd_format) || cmd_mode_sense) || cmd_read_buffer) || cmd_write_buffer) || cmd_verify6) || cmd_verify10;
	wire [31:0] lba10 = {cmd[2], cmd[3], cmd[4], cmd[5]};
	wire [7:0] cmd1 = cmd[1];
	wire [20:0] lba6 = {cmd1[4:0], cmd[2], cmd[3]};
	wire [15:0] tlen10 = {cmd[7], cmd[8]};
	wire [8:0] tlen6 = (cmd[4] == 0 ? 9'd256 : {1'b0, cmd[4]});
	always @(posedge clk) begin
		if (old_io_ack & ~io_ack)
			lba <= lba + 1'd1;
		if (cmd_cpl && (phase == PHASE_CMD_IN)) begin
			lba <= (cmd6_cpl ? {11'd0, lba6} : lba10);
			tlen <= (cmd6_cpl ? {7'd0, tlen6} : tlen10);
		end
	end
	always @(posedge clk)
		if (rst)
			phase <= PHASE_IDLE;
		else if (phase == PHASE_IDLE) begin
			if ((sel && din[ID]) && mounted)
				phase <= PHASE_CMD_IN;
		end
		else if (phase == PHASE_CMD_IN) begin
			if (cmd_cpl) begin
				$display("New command on target %d: %02x %02x %02x %02x %02x %02x %02x %02x %02x %02x", ID, cmd[0], cmd[1], cmd[2], cmd[3], cmd[4], cmd[5], cmd[6], cmd[7], cmd[8], cmd[9]);
				if (cmd_ok) begin
					status <= 8'h00;
					if ((((cmd_read || cmd_inquiry) || cmd_read_capacity) || cmd_mode_sense) || cmd_read_buffer)
						phase <= PHASE_DATA_OUT;
					else if ((cmd_write || cmd_mode_select) || cmd_write_buffer)
						phase <= PHASE_DATA_IN;
					else
						phase <= PHASE_STATUS_OUT;
				end
				else begin
					status <= 8'h02;
					phase <= PHASE_STATUS_OUT;
				end
			end
		end
		else if (phase == PHASE_DATA_OUT) begin
			if (data_complete)
				phase <= PHASE_STATUS_OUT;
		end
		else if (phase == PHASE_DATA_IN) begin
			if (data_complete)
				phase <= PHASE_STATUS_OUT;
		end
		else if (phase == PHASE_STATUS_OUT) begin
			if (status_sent)
				phase <= PHASE_MESSAGE_OUT;
		end
		else if (phase == PHASE_MESSAGE_OUT) begin
			if (message_sent)
				phase <= PHASE_IDLE;
		end
		else
			phase <= PHASE_IDLE;
endmodule
