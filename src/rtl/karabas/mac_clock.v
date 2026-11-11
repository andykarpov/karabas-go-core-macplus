`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_clock.v

 The clock and the PRAM of the Mac (rtc.v in the machine) on the RTC registers of kg_mcu
 (kg_mcu_rtc, MC146818A layout, rtc_mode 0 of core.json: the mcu keeps the time registers in step
 with the clock chip of the board, and registers 0x0E..0xFF in /config/macplus.eep, eeprom_bank of
 core.json; its first content is the eeprom_init pram.bin).

 - The PRAM: its 20 bytes are registers 0x10..0x23 (rtc.v ram[i] = register 0x10 + i). They are
   loaded into rtc.v once the mcu has set the registers (mcu_busy low), while the machine is still
   in reset (the top holds it while mcu_busy and the 68000 reset lasts 100 ms more); a byte the
   Mac writes goes to its register (kg_mcu sends it to the mcu, which saves the .eep).
 - The time: seconds since 1904-01-01 (the clock of the Mac, local time) from registers 0 (s),
   2 (min), 4 (hour, 24 h), 7 (date), 8 (month), 9 (year, 2000 + 0..99), BCD or binary (bit 2 of
   register B), into rtc.v once with the PRAM; rtc.v counts on from there. When the Mac sets its
   clock (the Control Panel: four byte writes), the seconds are taken 4 ms after the last of
   them, turned into a date and written to registers 0, 2, 4, 6 (day of the week, Sunday 1),
   7, 8, 9: the mcu sets the clock chip. A date before 2000 is not written (the registers have
   two digits of the year; the seconds of the Mac end in 2040).
 Both conversions are loops of subtractions / additions (up to ~75000 clocks, 2.5 ms): no
 multiplier or divider.

 Clocks: clk is clk_2x of the top, sys_t the toggle of clk_sys = clk_2x / 2 (rising edges together),
 as in mac_sdc: rtc_in changes only at the clk_2x edges that are clk_sys edges, and rtc_out (a
 clk_sys register) is taken only at them, so each strobe is seen once.
*/

module mac_clock #(
	parameter QUIET_BITS = 17   // 2^17 clocks of clk_2x = 4.2 ms after the last write of the seconds
) (
	input  wire        clk,        // clk_2x
	input  wire        sys_t,
	input  wire        mcu_busy,   // kg_mcu BUSY: the registers are set by the mcu until it drops

	// the RTC port of kg_mcu (rtc_do a clock after rtc_a, a write = one clock of rtc_cs, !rtc_wr_n)
	output reg  [7:0]  rtc_a = 8'd0,
	output reg  [7:0]  rtc_di = 8'd0,
	input  wire [7:0]  rtc_do,
	output reg         rtc_cs = 1'b0,
	output reg         rtc_wr_n = 1'b1,

	// rtc.v: rtc_in = { set, secs[31:0], ld_we, ld_a[4:0], ld_d[7:0] },
	//        rtc_out = { secs_wr, secs[31:0], pram_we, pram_a[4:0], pram_d[7:0] }
	output wire [46:0] rtc_in,
	input  wire [46:0] rtc_out,

	output reg         loaded = 1'b0   // the PRAM and the time are in rtc.v
);

localparam [7:0] PRAM_BASE = 8'h10;

reg sys_t_d = 1'b0;
always @(posedge clk) sys_t_d <= sys_t;
wire sys_edge = (sys_t == sys_t_d);

// ------------------------------------------------------------------ to and from rtc.v

reg o_set = 1'b0, o_ld = 1'b0;
reg [31:0] o_secs = 32'd0;
reg [4:0] o_a = 5'd0;
reg [7:0] o_d = 8'd0;
reg set_pend = 1'b0, ld_pend = 1'b0;
assign rtc_in = { o_set, o_secs, o_ld, o_a, o_d };

reg m_secs_wr = 1'b0, m_pram_we = 1'b0;
reg [31:0] m_secs = 32'd0;
reg [4:0] m_pram_a = 5'd0;
reg [7:0] m_pram_d = 8'd0;

// ------------------------------------------------------------------ the conversions

function [6:0] from_bcd(input [7:0] v, input bin);
	from_bcd = bin ? v[6:0] : { 3'd0, v[7:4] } * 7'd10 + { 3'd0, v[3:0] };
endfunction

wire [7:0] tens_of;   // of cv, 0..99
reg  [6:0] cv;
wire [14:0] cv205 = cv * 8'd205;
assign tens_of = { 4'd0, cv205[14:11] };
function [7:0] to_reg(input [6:0] v, input [3:0] tens, input bin);
	to_reg = bin ? { 1'b0, v } : { tens, v[3:0] - { tens[2:0], 1'b0 } - { tens[0], 3'b000 } };
endfunction

// days before month m (1..12) of a common year
function [8:0] cum_days(input [3:0] m);
	case (m)
	4'd1: cum_days = 9'd0;   4'd2: cum_days = 9'd31;  4'd3: cum_days = 9'd59;
	4'd4: cum_days = 9'd90;  4'd5: cum_days = 9'd120; 4'd6: cum_days = 9'd151;
	4'd7: cum_days = 9'd181; 4'd8: cum_days = 9'd212; 4'd9: cum_days = 9'd243;
	4'd10: cum_days = 9'd273; 4'd11: cum_days = 9'd304; default: cum_days = 9'd334;
	endcase
endfunction

function [4:0] month_len(input [3:0] m, input leap);
	case (m)
	4'd2: month_len = leap ? 5'd29 : 5'd28;
	4'd4, 4'd6, 4'd9, 4'd11: month_len = 5'd30;
	default: month_len = 5'd31;
	endcase
endfunction

reg bin_mode = 1'b0;
reg [6:0] t_s = 7'd0, t_min = 7'd0, t_h = 7'd0, t_d = 7'd1, t_mo = 7'd1, t_y = 7'd0;
reg [2:0] t_wd = 3'd1;
reg [16:0] days = 17'd0;
reg [16:0] n = 17'd0;
reg [31:0] acc = 32'd0, r = 32'd0;
reg [7:0] yrs = 8'd0;   // years since 1904

// days since 1904-01-01 of t_y / t_mo / t_d: 1904..1999 = 96 * 365 + 24 leap days
wire [16:0] y365 = { 10'd0, t_y } * 17'd365;
wire [16:0] date_days = 17'd35064 + y365 + { 10'd0, (t_y + 7'd3) >> 2 } + { 8'd0, cum_days(t_mo[3:0]) }
	+ ((t_y[1:0] == 2'd0 && t_mo > 7'd2) ? 17'd1 : 17'd0) + { 10'd0, t_d } - 17'd1;

// ------------------------------------------------------------------ the state machine

localparam S_BOOT = 4'd0, S_PRAM = 4'd1, S_TIME = 4'd2, S_DAYS = 4'd3, S_SET = 4'd4, S_IDLE = 4'd5,
	S_QUIET = 4'd6, S_DIV = 4'd7, S_YEAR = 4'd8, S_MONTH = 4'd9, S_WDAY = 4'd10, S_WRITE = 4'd11;

reg [3:0] state = S_BOOT;
reg [3:0] step = 4'd0;
reg [1:0] rd = 2'd0;        // a read: the address out, the data two clocks later
reg [7:0] i = 8'd0;
reg [QUIET_BITS-1:0] quiet = 0;
reg [1:0] dstep = 2'd0;     // S_DIV: days, hours, minutes
reg p_pend = 1'b0;          // a PRAM byte of the Mac to write
reg [4:0] p_a = 5'd0;
reg [7:0] p_d = 8'd0;
reg secs_dirty = 1'b0;
wire [3:0] wd5 = { 1'b0, n[2:0] } + 4'd5;   // S_WDAY: n = days % 7 there

wire port_free = state != S_PRAM && state != S_TIME && state != S_WRITE;

always @(posedge clk) begin
	rtc_cs <= 1'b0;
	rtc_wr_n <= 1'b1;

	// rtc.v side, at the clk_sys edges only
	if (sys_edge) begin
		o_set <= set_pend;
		o_ld <= ld_pend;
		set_pend <= 1'b0;
		ld_pend <= 1'b0;
		m_secs_wr <= rtc_out[46];
		m_secs <= rtc_out[45:14];
		m_pram_we <= rtc_out[13];
		m_pram_a <= rtc_out[12:8];
		m_pram_d <= rtc_out[7:0];
	end

	// a PRAM byte of the Mac (taken once: m_pram_we is a copy made at a clk_sys edge)
	if (sys_edge && m_pram_we) begin
		p_pend <= 1'b1;
		p_a <= m_pram_a;
		p_d <= m_pram_d;
	end
	else if (p_pend && port_free && !mcu_busy) begin
		rtc_a <= PRAM_BASE + { 3'd0, p_a };
		rtc_di <= p_d;
		rtc_cs <= 1'b1;
		rtc_wr_n <= 1'b0;
		p_pend <= 1'b0;
	end

	// a write of the Mac to its seconds: wait for the last of its bytes
	if (sys_edge && m_secs_wr) begin
		secs_dirty <= 1'b1;
		quiet <= {QUIET_BITS{1'b1}};
	end
	else if (quiet != 0)
		quiet <= quiet - 1'b1;

	case (state)
	S_BOOT:
		if (!mcu_busy) begin
			i <= 8'd0;
			rd <= 2'd0;
			state <= S_PRAM;
		end

	// the 20 PRAM bytes into rtc.v
	S_PRAM:
		if (rd == 2'd0) begin
			if (!ld_pend && !o_ld) begin
				rtc_a <= PRAM_BASE + i;
				rd <= 2'd1;
			end
		end
		else if (rd == 2'd1)
			rd <= 2'd2;
		else begin
			o_a <= i[4:0];
			o_d <= rtc_do;
			ld_pend <= 1'b1;
			rd <= 2'd0;
			if (i == 8'd19) begin
				step <= 4'd0;
				state <= S_TIME;
			end
			i <= i + 8'd1;
		end

	// register B, then the time registers
	S_TIME:
		if (rd == 2'd0) begin
			case (step)
			4'd0: rtc_a <= 8'h0B;
			4'd1: rtc_a <= 8'h00;
			4'd2: rtc_a <= 8'h02;
			4'd3: rtc_a <= 8'h04;
			4'd4: rtc_a <= 8'h07;
			4'd5: rtc_a <= 8'h08;
			default: rtc_a <= 8'h09;
			endcase
			rd <= 2'd1;
		end
		else if (rd == 2'd1)
			rd <= 2'd2;
		else begin
			case (step)
			4'd0: bin_mode <= rtc_do[2];
			4'd1: t_s <= from_bcd(rtc_do & 8'h7F, bin_mode);
			4'd2: t_min <= from_bcd(rtc_do & 8'h7F, bin_mode);
			4'd3: t_h <= from_bcd(rtc_do & 8'h3F, bin_mode);
			4'd4: t_d <= from_bcd(rtc_do & 8'h3F, bin_mode);
			4'd5: t_mo <= from_bcd(rtc_do & 8'h1F, bin_mode);
			default: t_y <= from_bcd(rtc_do, bin_mode);
			endcase
			rd <= 2'd0;
			step <= step + 4'd1;
			if (step == 4'd6) state <= S_DAYS;
		end

	// seconds = days * 86400 + h * 3600 + min * 60 + s, by additions
	S_DAYS: begin
		if (t_y > 7'd99 || t_mo == 7'd0 || t_mo > 7'd12 || t_d == 7'd0 || t_d > 7'd31) begin
			// no valid date (a board without a clock chip): 2000-01-01 00:00
			t_y <= 7'd0; t_mo <= 7'd1; t_d <= 7'd1; t_h <= 7'd0; t_min <= 7'd0; t_s <= 7'd0;
		end
		else begin
			n <= date_days;
			acc <= { 25'd0, t_s };
			step <= 4'd0;
			state <= S_SET;
		end
	end

	S_SET:
		case (step)
		4'd0: if (n != 17'd0) begin acc <= acc + 32'd86400; n <= n - 17'd1; end
		      else begin n <= { 10'd0, t_h }; step <= 4'd1; end
		4'd1: if (n != 17'd0) begin acc <= acc + 32'd3600; n <= n - 17'd1; end
		      else begin n <= { 10'd0, t_min }; step <= 4'd2; end
		4'd2: if (n != 17'd0) begin acc <= acc + 32'd60; n <= n - 17'd1; end
		      else step <= 4'd3;
		default:
			if (!set_pend && !o_set) begin
				o_secs <= acc;
				set_pend <= 1'b1;
				loaded <= 1'b1;
				secs_dirty <= 1'b0;
				state <= S_IDLE;
			end
		endcase

	S_IDLE:
		if (secs_dirty && quiet == 0 && !(sys_edge && m_secs_wr)) begin
			secs_dirty <= 1'b0;
			r <= m_secs;
			days <= 17'd0;
			dstep <= 2'd0;
			state <= S_DIV;
		end

	// the seconds into days, hours, minutes, seconds
	S_DIV:
		case (dstep)
		2'd0: if (r >= 32'd86400) begin r <= r - 32'd86400; days <= days + 17'd1; end
		      else begin dstep <= 2'd1; t_h <= 7'd0; end
		2'd1: if (r >= 32'd3600) begin r <= r - 32'd3600; t_h <= t_h + 7'd1; end
		      else begin dstep <= 2'd2; t_min <= 7'd0; end
		default:
			if (r >= 32'd60) begin r <= r - 32'd60; t_min <= t_min + 7'd1; end
			else begin
				t_s <= r[6:0];
				n <= days;
				yrs <= 8'd0;
				state <= S_YEAR;
			end
		endcase

	// the year (1904..2099: every fourth a leap year), then the month
	S_YEAR:
		if (n >= ((yrs[1:0] == 2'd0) ? 17'd366 : 17'd365)) begin
			n <= n - ((yrs[1:0] == 2'd0) ? 17'd366 : 17'd365);
			yrs <= yrs + 8'd1;
		end
		else begin
			t_mo <= 7'd1;
			state <= S_MONTH;
		end

	S_MONTH:
		if (n >= { 12'd0, month_len(t_mo[3:0], yrs[1:0] == 2'd0) }) begin
			n <= n - { 12'd0, month_len(t_mo[3:0], yrs[1:0] == 2'd0) };
			t_mo <= t_mo + 7'd1;
		end
		else begin
			t_d <= n[6:0] + 7'd1;
			n <= days;
			state <= S_WDAY;
		end

	// the day of the week: 1904-01-01 was a Friday (6, Sunday = 1)
	S_WDAY:
		if (n >= 17'd7)
			n <= n - 17'd7;
		else begin
			t_wd <= (wd5 >= 4'd7) ? wd5[2:0] - 3'd6 : wd5[2:0] + 3'd1;
			if (yrs >= 8'd96 && yrs <= 8'd195) begin
				t_y <= yrs[6:0] - 7'd96;
				step <= 4'd0;
				state <= S_WRITE;
			end
			else
				state <= S_IDLE;
		end

	// the registers to the mcu, one per two clocks (the BCD of each through cv)
	S_WRITE:
		if (rd == 2'd0) begin
			case (step)
			4'd0: cv <= t_s;
			4'd1: cv <= t_min;
			4'd2: cv <= t_h;
			4'd3: cv <= { 4'd0, t_wd };
			4'd4: cv <= t_d;
			4'd5: cv <= t_mo;
			default: cv <= t_y;
			endcase
			rd <= 2'd1;
		end
		else begin
			if (!mcu_busy) begin
				case (step)
				4'd0: rtc_a <= 8'h00;
				4'd1: rtc_a <= 8'h02;
				4'd2: rtc_a <= 8'h04;
				4'd3: rtc_a <= 8'h06;
				4'd4: rtc_a <= 8'h07;
				4'd5: rtc_a <= 8'h08;
				default: rtc_a <= 8'h09;
				endcase
				rtc_di <= to_reg(cv, tens_of[3:0], bin_mode);
				rtc_cs <= 1'b1;
				rtc_wr_n <= 1'b0;
			end
			rd <= 2'd0;
			step <= step + 4'd1;
			if (step == 4'd6) state <= S_IDLE;
		end

	default: state <= S_BOOT;
	endcase
end

endmodule
