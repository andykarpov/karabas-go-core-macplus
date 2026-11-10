module keyboard (
	clk,
	en,
	reset,
	kbd_strobe,
	kbd_data,
	data_out,
	strobe_out,
	data_in,
	strobe_in
);
	input clk;
	input en;
	input reset;
	input kbd_strobe;
	input [9:0] kbd_data;
	input [7:0] data_out;
	input strobe_out;
	output wire [7:0] data_in;
	output wire strobe_in;
	reg [9:0] keymac;
	reg key_pending;
	reg [19:0] pacetimer;
	reg inquiry_active;
	reg got_key;
	wire tick_short;
	wire tick_long;
	wire pop_key;
	reg cmd_inquiry;
	reg cmd_instant;
	reg cmd_model;
	reg cmd_test;
	always @(posedge clk or posedge reset)
		if (reset) begin
			cmd_inquiry <= 0;
			cmd_instant <= 0;
			cmd_model <= 0;
			cmd_test <= 0;
		end
		else if (en) begin
			if (strobe_out) begin
				cmd_inquiry <= 0;
				cmd_instant <= 0;
				cmd_model <= 0;
				cmd_test <= 0;
				case (data_out)
					8'h10: cmd_inquiry <= 1;
					8'h14: cmd_instant <= 1;
					8'h16: cmd_model <= 1;
					8'h36: cmd_test <= 1;
				endcase
			end
		end
	always @(posedge clk or posedge reset)
		if (reset)
			pacetimer <= 0;
		else if (en) begin
			if (strobe_out)
				pacetimer <= 0;
			else if (!tick_long)
				pacetimer <= pacetimer + 1'd1;
		end
	assign tick_long = pacetimer == 20'hfffff;
	assign tick_short = pacetimer == 20'h00fff;
	always @(posedge clk or posedge reset)
		if (reset)
			inquiry_active <= 0;
		else if (en) begin
			if (strobe_out | strobe_in)
				inquiry_active <= 0;
			else if (tick_short)
				inquiry_active <= cmd_inquiry;
		end
	assign pop_key = ((cmd_instant & tick_short) | (inquiry_active & tick_long)) | (inquiry_active & key_pending);
	assign strobe_in = ((cmd_model | cmd_test) & tick_short) | pop_key;
	reg keypad_byte2;
	reg keypad_byte3;
	always @(posedge clk or posedge reset)
		if (reset) begin
			key_pending <= 0;
			keypad_byte2 <= 0;
			keypad_byte3 <= 0;
		end
		else if (en) begin
			if (cmd_model | cmd_test)
				key_pending <= 0;
			else if (pop_key) begin
				if ((key_pending & keymac[9]) && !keypad_byte3)
					keypad_byte3 <= 1;
				else if ((key_pending & keymac[8]) & !keypad_byte2)
					keypad_byte2 <= 1;
				else begin
					key_pending <= 0;
					keypad_byte2 <= 0;
					keypad_byte3 <= 0;
				end
			end
			else if (!key_pending & got_key)
				key_pending <= 1;
		end
	reg caps = 1'b0;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg strobe;
		if (en) begin
			got_key <= 1'b0;
			if (kbd_strobe != strobe) begin
				if (kbd_data != 10'h0f3) begin
					if (kbd_data == 10'h073) begin
						keymac <= {kbd_data[9:8], caps, kbd_data[6:0]};
						caps <= !caps;
					end
					else
						keymac <= kbd_data;
					got_key <= 1'b1;
				end
			end
			strobe <= kbd_strobe;
		end
	end
	assign data_in = (cmd_test ? 8'h7d : (cmd_model ? 8'h0b : (key_pending ? (keymac[9] & !keypad_byte3 ? {keymac[7], 7'h71} : (keymac[8] & !keypad_byte2 ? 8'h79 : keymac[7:0])) : 8'h7b)));
endmodule
