module rtc (
	clk,
	reset,
	timestamp,
	_cs,
	ck,
	dat_i,
	dat_o
);
	input clk;
	input reset;
	input [32:0] timestamp;
	input _cs;
	input ck;
	input dat_i;
	output reg dat_o;
	reg [2:0] bit_cnt;
	reg ck_d;
	reg [7:0] din;
	reg [7:0] cmd;
	reg [7:0] dout;
	reg cmd_mode;
	reg receiving;
	reg [31:0] secs;
	reg [31:0] secs2;
	reg [7:0] ram [0:19];
	reg [24:0] clocktoseconds;
	initial begin
		ram[5'h00] = 8'ha8;
		ram[5'h01] = 8'h00;
		ram[5'h02] = 8'h00;
		ram[5'h03] = 8'h22;
		ram[5'h04] = 8'hcc;
		ram[5'h05] = 8'h0a;
		ram[5'h06] = 8'hcc;
		ram[5'h07] = 8'h0a;
		ram[5'h08] = 8'h00;
		ram[5'h09] = 8'h00;
		ram[5'h0a] = 8'h00;
		ram[5'h0b] = 8'h00;
		ram[5'h0c] = 8'h00;
		ram[5'h0d] = 8'h02;
		ram[5'h0e] = 8'h63;
		ram[5'h0f] = 8'h00;
		ram[5'h10] = 8'h03;
		ram[5'h11] = 8'h88;
		ram[5'h12] = 8'h00;
		ram[5'h13] = 8'h6c;
	end
	initial secs = 0;
	always @(posedge clk)
		if (reset) begin
			bit_cnt <= 0;
			receiving <= 1;
			cmd_mode <= 1;
			dat_o <= 1;
		end
		else begin
			if (secs == 0)
				secs <= timestamp[31:0] + 2082844800;
			clocktoseconds <= clocktoseconds + 1'd1;
			if (15476189 == clocktoseconds) begin
				clocktoseconds <= 0;
				secs <= secs + 1;
			end
			if (_cs) begin
				bit_cnt <= 0;
				receiving <= 1;
				cmd_mode <= 1;
				dat_o <= 1;
			end
			else begin
				ck_d <= ck;
				if ((ck_d & ~ck) & !receiving)
					dat_o <= dout[7 - bit_cnt];
				if (~ck_d & ck) begin
					bit_cnt <= bit_cnt + 1'd1;
					if (receiving)
						din <= {din[6:0], dat_i};
					if (bit_cnt == 7) begin
						if (receiving && cmd_mode) begin
							cmd_mode <= 0;
							receiving <= ~din[6];
							cmd <= {din[6:0], dat_i};
							casez ({din[5:0], dat_i})
								7'b00z0001: dout <= secs[7:0];
								7'b00z0101: dout <= secs[15:8];
								7'b00z1001: dout <= secs[23:16];
								7'b00z1101: dout <= secs[31:24];
								7'b010zz01: dout <= ram[{3'b100, din[2:1]}];
								7'b1zzzz01: dout <= ram[din[4:1]];
								default:
									;
							endcase
						end
						if (receiving && !cmd_mode)
							casez (cmd[6:0])
								7'b0000001: secs[7:0] <= {din[6:0], dat_i};
								7'b0000101: secs[15:8] <= {din[6:0], dat_i};
								7'b0001001: secs[23:16] <= {din[6:0], dat_i};
								7'b0001101: secs[31:24] <= {din[6:0], dat_i};
								7'b010zz01: ram[{3'b100, cmd[3:2]}] <= {din[6:0], dat_i};
								7'b1zzzz01: ram[cmd[5:2]] <= {din[6:0], dat_i};
								default:
									;
							endcase
					end
				end
			end
		end
endmodule
