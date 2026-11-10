module rxuart (
	i_clk,
	i_en,
	i_reset,
	i_setup,
	i_uart_rx,
	o_wr,
	o_data,
	o_break,
	o_parity_err,
	o_frame_err,
	o_ck_uart
);
	input i_clk;
	input i_en;
	input i_reset;
	input [30:0] i_setup;
	input i_uart_rx;
	output reg o_wr;
	output reg [7:0] o_data;
	output reg o_break;
	output reg o_parity_err;
	output reg o_frame_err;
	output wire o_ck_uart;
	parameter [30:0] INITIAL_SETUP = 31'd868;
	wire [27:0] clocks_per_baud;
	wire [27:0] break_condition;
	wire [27:0] half_baud;
	wire [1:0] data_bits;
	wire use_parity;
	wire parity_even;
	wire dblstop;
	wire fixd_parity;
	reg [29:0] r_setup;
	reg [3:0] state;
	assign clocks_per_baud = {4'h0, r_setup[23:0]};
	assign data_bits = r_setup[29:28];
	assign dblstop = r_setup[27];
	assign use_parity = r_setup[26];
	assign fixd_parity = r_setup[25];
	assign parity_even = r_setup[24];
	assign break_condition = {r_setup[23:0], 4'h0};
	assign half_baud = {5'h00, r_setup[23:1]} - 28'h0000001;
	reg [27:0] baud_counter;
	reg zero_baud_counter;
	reg q_uart;
	reg qq_uart;
	reg ck_uart;
	initial q_uart = 1'b0;
	initial qq_uart = 1'b0;
	initial ck_uart = 1'b0;
	always @(posedge i_clk)
		if (i_en) begin
			q_uart <= i_uart_rx;
			qq_uart <= q_uart;
			ck_uart <= qq_uart;
		end
	assign o_ck_uart = ck_uart;
	reg [27:0] chg_counter;
	initial chg_counter = 28'h0000000;
	always @(posedge i_clk)
		if (i_en) begin
			if (i_reset)
				chg_counter <= 28'h0000000;
			else if (qq_uart != ck_uart)
				chg_counter <= 28'h0000000;
			else if (chg_counter < break_condition)
				chg_counter <= chg_counter + 1;
		end
	initial o_break = 1'b0;
	always @(posedge i_clk)
		if (i_en)
			o_break <= ((chg_counter >= break_condition) && ~ck_uart ? 1'b1 : 1'b0);
	reg line_synch;
	initial line_synch = 1'b0;
	always @(posedge i_clk)
		if (i_en)
			line_synch <= (chg_counter >= break_condition) && ck_uart;
	reg half_baud_time;
	initial half_baud_time = 0;
	always @(posedge i_clk)
		if (i_en)
			half_baud_time <= ~ck_uart && (chg_counter >= half_baud);
	initial r_setup = INITIAL_SETUP[29:0];
	always @(posedge i_clk)
		if (i_en) begin
			if (state >= 4'he)
				r_setup <= i_setup[29:0];
		end
	initial state = 4'he;
	always @(posedge i_clk)
		if (i_en) begin
			if (i_reset)
				state <= 4'he;
			else if (state == 4'he) begin
				if (line_synch)
					state <= 4'hf;
				else
					state <= 4'he;
			end
			else if (o_break)
				state <= 4'hd;
			else if (state == 4'hd) begin
				if (ck_uart)
					state <= 4'hf;
				else
					state <= 4'hd;
			end
			else if (state == 4'hf) begin
				if (~ck_uart && half_baud_time)
					case (data_bits)
						2'b00: state <= 4'h0;
						2'b01: state <= 4'h1;
						2'b10: state <= 4'h2;
						2'b11: state <= 4'h3;
					endcase
				else
					state <= 4'hf;
			end
			else if (zero_baud_counter) begin
				if (state < 4'h7)
					state <= state + 1;
				else if (state == 4'h7)
					state <= (use_parity ? 4'h8 : 4'h9);
				else if (state == 4'h8)
					state <= 4'h9;
				else if (state == 4'h9) begin
					if (~ck_uart)
						state <= 4'he;
					else if (dblstop)
						state <= 4'ha;
					else
						state <= 4'hf;
				end
				else if (~ck_uart)
					state <= 4'he;
				else
					state <= 4'hf;
			end
		end
	reg [7:0] data_reg;
	always @(posedge i_clk)
		if (i_en) begin
			if (zero_baud_counter && (state != 4'h8))
				data_reg <= {ck_uart, data_reg[7:1]};
		end
	reg calc_parity;
	always @(posedge i_clk)
		if (i_en) begin
			if (state == 4'hf)
				calc_parity <= 0;
			else if (zero_baud_counter)
				calc_parity <= calc_parity ^ ck_uart;
		end
	initial o_parity_err = 1'b0;
	always @(posedge i_clk)
		if (i_en) begin
			if (zero_baud_counter && (state == 4'h8)) begin
				if (fixd_parity)
					o_parity_err <= ck_uart ^ parity_even;
				else if (parity_even)
					o_parity_err <= calc_parity != ck_uart;
				else
					o_parity_err <= calc_parity == ck_uart;
			end
			else if (state >= 4'hd)
				o_parity_err <= 1'b0;
		end
	initial o_frame_err = 1'b0;
	always @(posedge i_clk)
		if (i_en) begin
			if (zero_baud_counter && ((state == 4'h9) || (state == 4'ha)))
				o_frame_err <= o_frame_err || ~ck_uart;
			else if (zero_baud_counter || (state >= 4'hd))
				o_frame_err <= 1'b0;
		end
	initial o_data = 8'h00;
	reg pre_wr;
	initial pre_wr = 1'b0;
	always @(posedge i_clk)
		if (i_en) begin
			if (i_reset) begin
				pre_wr <= 1'b0;
				o_data <= 8'h00;
			end
			else if (zero_baud_counter && (state == 4'h9)) begin
				pre_wr <= 1'b1;
				case (data_bits)
					2'b00: o_data <= data_reg;
					2'b01: o_data <= {1'b0, data_reg[7:1]};
					2'b10: o_data <= {2'b00, data_reg[7:2]};
					2'b11: o_data <= {3'b000, data_reg[7:3]};
				endcase
			end
			else if (zero_baud_counter || (state == 4'hf))
				pre_wr <= 1'b0;
		end
	initial o_wr = 1'b0;
	always @(posedge i_clk)
		if (i_en) begin
			if (zero_baud_counter || (state == 4'hf))
				o_wr <= pre_wr && !i_reset;
			else
				o_wr <= 1'b0;
		end
	always @(posedge i_clk)
		if (i_en) begin
			if (i_reset)
				baud_counter <= clocks_per_baud - 28'h0000001;
			else if (zero_baud_counter)
				baud_counter <= clocks_per_baud - 28'h0000001;
			else
				case (state)
					4'he: baud_counter <= clocks_per_baud - 28'h0000001;
					4'hd: baud_counter <= clocks_per_baud - 28'h0000001;
					4'hf: baud_counter <= clocks_per_baud - 28'h0000001;
					default: baud_counter <= baud_counter - 28'h0000001;
				endcase
		end
	initial zero_baud_counter = 1'b0;
	always @(posedge i_clk)
		if (i_en) begin
			if (state == 4'hf)
				zero_baud_counter <= 1'b0;
			else
				zero_baud_counter <= baud_counter == 28'h0000001;
		end
endmodule
