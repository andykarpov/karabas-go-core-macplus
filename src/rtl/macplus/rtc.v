/* PRAM - RTC implementation for plus_too */

module rtc (
	input         clk,
	input         reset,

	// karabas: the clock and the PRAM are kept by the mcu (the clock chip of the board and
	// /config/macplus.eep), through mac_clock of the board top: rtc_in = { set, secs[31:0], ld_we,
	// ld_a[4:0], ld_d[7:0] } sets the seconds (Mac epoch) and loads PRAM bytes, rtc_out = { secs_wr,
	// secs[31:0], pram_we, pram_a[4:0], pram_d[7:0] } gives the seconds, a pulse after each write of
	// the Mac to them, and each PRAM byte the Mac writes (one clock each). Was a unix timestamp
	// taken once.
	input  [46:0] rtc_in,
	output [46:0] rtc_out,
	input         _cs,
	input         ck,
	input         dat_i,
	output reg    dat_o
);

reg   [2:0] bit_cnt;
reg         ck_d;
reg   [7:0] din;
reg   [7:0] cmd;
reg   [7:0] dout;
reg         cmd_mode;
reg         receiving;
reg  [31:0] secs;
reg  [31:0] secs2;
reg   [7:0] ram[20];
reg  [24:0] clocktoseconds;

initial begin
	ram[5'h00] = 8'hA8;
	ram[5'h01] = 8'h00;
	ram[5'h02] = 8'h00;
	ram[5'h03] = 8'h22;
	ram[5'h04] = 8'hCC;
	ram[5'h05] = 8'h0A;
	ram[5'h06] = 8'hCC;
	ram[5'h07] = 8'h0A;
	ram[5'h08] = 8'h00;
	ram[5'h09] = 8'h00;
	ram[5'h0A] = 8'h00;
	ram[5'h0B] = 8'h00;
	ram[5'h0C] = 8'h00;
	ram[5'h0D] = 8'h02;
	ram[5'h0E] = 8'h63;
	ram[5'h0F] = 8'h00;
	ram[5'h10] = 8'h03;
	ram[5'h11] = 8'h88;
	ram[5'h12] = 8'h00;
	ram[5'h13] = 8'h6C;
end

initial secs = 0;

// karabas: the ports of mac_clock (see the header)
wire        set_secs = rtc_in[46];
wire [31:0] set_value = rtc_in[45:14];
wire        ld_we = rtc_in[13];
wire  [4:0] ld_a = rtc_in[12:8];
wire  [7:0] ld_d = rtc_in[7:0];
reg         secs_wr = 1'b0;
reg         pram_we = 1'b0;
reg   [4:0] pram_a = 5'd0;
reg   [7:0] pram_d = 8'd0;
assign rtc_out = { secs_wr, secs, pram_we, pram_a, pram_d };

always @(posedge clk) begin
	if (reset) begin
		bit_cnt <= 0;
		receiving <= 1;
		cmd_mode <= 1;
		dat_o <= 1;
	//	sec_cnt <= 0;
	end 
	else begin

		// karabas: the seconds from mac_clock instead of a unix timestamp taken once
		secs_wr <= 1'b0;
		pram_we <= 1'b0;

		// we need to add one to the seconds
		clocktoseconds<= clocktoseconds + 1'd1;
		if (15_476_189==clocktoseconds) // karabas: the 15.476 MHz clock of the Karabas tops (650 / 42 MHz), was 15.6 MHz
		begin
			clocktoseconds<=0;
			secs<=secs+1;
		end

		if (_cs) begin
			bit_cnt <= 0;
			receiving <= 1;
			cmd_mode <= 1;
			dat_o <= 1;
		end
		else begin
			ck_d <= ck;

			// transmit at the falling edge
			if (ck_d & ~ck & !receiving)
				dat_o <= dout[7-bit_cnt];
			// receive at the rising edge of ck
			if (~ck_d & ck) begin
				bit_cnt <= bit_cnt + 1'd1;
				if (receiving)
					din <= {din[6:0], dat_i};

				if (bit_cnt == 7) begin
					if (receiving && cmd_mode) begin
						// command byte received
						cmd_mode <= 0;
						receiving <= ~din[6];
						cmd <= {din[6:0], dat_i};
						casez ({din[5:0], dat_i})
							7'b00?0001: dout <= secs[7:0];
							7'b00?0101: dout <= secs[15:8];
							7'b00?1001: dout <= secs[23:16];
							7'b00?1101: dout <= secs[31:24];
							7'b010??01: dout <= ram[{3'b100, din[2:1]}];
							7'b1????01: dout <= ram[din[4:1]];
							default: ;
						endcase
					end
					if (receiving && !cmd_mode) begin
						// data byte received
						casez (cmd[6:0])
							7'b0000001: secs[7:0] <= {din[6:0], dat_i};
							7'b0000101: secs[15:8] <= {din[6:0], dat_i};
							7'b0001001: secs[23:16] <= {din[6:0], dat_i};
							7'b0001101: secs[31:24] <= {din[6:0], dat_i};
							7'b010??01: ram[{3'b100, cmd[3:2]}] <= {din[6:0], dat_i};
							7'b1????01: ram[cmd[5:2]] <= {din[6:0], dat_i};
							default: ;
						endcase
						// karabas: tell mac_clock (the seconds: their 4 bytes come one by one)
						casez (cmd[6:0])
							7'b000??01: secs_wr <= 1'b1;
							7'b010??01: begin pram_we <= 1'b1; pram_a <= {3'b100, cmd[3:2]}; pram_d <= {din[6:0], dat_i}; end
							7'b1????01: begin pram_we <= 1'b1; pram_a <= {1'b0, cmd[5:2]}; pram_d <= {din[6:0], dat_i}; end
							default: ;
						endcase
					end
				end
			end
		end
	end
	// karabas: the PRAM bytes and the seconds of the mcu (mac_clock) come while the machine is still
	// in reset (the 68000 is held 100 ms after the top lets it go): taken also then
	if (ld_we)
		ram[ld_a] <= ld_d;
	if (set_secs) begin
		clocktoseconds <= 0;
		secs <= set_value;
	end
end

endmodule
