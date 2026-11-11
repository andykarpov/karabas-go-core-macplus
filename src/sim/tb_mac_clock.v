`timescale 1ns / 1ps

// tb_mac_clock.v (iverilog): mac_clock between a model of the RTC registers of kg_mcu (256 bytes,
// rtc_do a clock after rtc_a, writes logged) and a model of rtc.v (the strobes of rtc_in taken at
// the clk_sys edges, pulses on rtc_out). The reference calendar counts the days one by one from
// 1904-01-01 (a Friday), with the Gregorian leap rule.
//  1. the start: the 20 PRAM bytes (registers 0x10..0x23) reach rtc.v once each, then the seconds
//     (also into the real rtc.v, held in reset meanwhile, as the machine is)
//     of the date in the registers (+y/+mo/+d/+h/+mi/+s, +bin for binary registers);
//  2. a PRAM byte written by the Mac goes to its register;
//  3. the Mac sets its clock (4 byte writes, then the seconds): registers 0, 2, 4, 6..9 get the
//     date, for dates from 2000 (+cases random ones, up to the end of the Mac clock in 2040), nothing before.

module tb_mac_clock;

reg clk = 0;
always #16 clk = !clk;          // clk_2x
reg clk_sys = 0;
always @(posedge clk) clk_sys <= !clk_sys;
reg sys_t = 0;
always @(posedge clk_sys) sys_t <= !sys_t;

reg mcu_busy = 1;
wire [7:0] rtc_a, rtc_di;
reg [7:0] rtc_do = 0;
wire rtc_cs, rtc_wr_n;
wire [46:0] rtc_in;
reg [46:0] rtc_out = 0;
wire loaded;

mac_clock #(.QUIET_BITS(10), .RETRY_BITS(10)) dut (
	.clk(clk), .sys_t(sys_t), .mcu_busy(mcu_busy),
	.rtc_a(rtc_a), .rtc_di(rtc_di), .rtc_do(rtc_do), .rtc_cs(rtc_cs), .rtc_wr_n(rtc_wr_n),
	.rtc_in(rtc_in), .rtc_out(rtc_out), .loaded(loaded)
);

integer errors = 0;

// the real rtc.v (rtl/sv2v) on the same rtc_in, held in reset as the machine is while mac_clock
// loads it (the 68000 waits 100 ms after the top lets it go)
reg rtc_reset = 1;
wire [46:0] real_rtc_out;
rtc real_rtc (.clk(clk_sys), .reset(rtc_reset), .rtc_in(rtc_in), .rtc_out(real_rtc_out),
	._cs(1'b1), .ck(1'b0), .dat_i(1'b0), .dat_o());
reg [7:0] regs [0:255];
integer wr_count [0:255];
integer k;

always @(posedge clk) begin
	rtc_do <= regs[rtc_a];
	if (rtc_cs && !rtc_wr_n) begin
		regs[rtc_a] <= rtc_di;
		wr_count[rtc_a] = wr_count[rtc_a] + 1;
	end
end

// the rtc.v side
reg [7:0] pram [0:19];
integer ld_count [0:19];
integer set_count = 0;
reg [31:0] secs = 0;
always @(posedge clk_sys) begin
	if (rtc_in[46]) begin secs <= rtc_in[45:14]; set_count = set_count + 1; end
	if (rtc_in[13]) begin pram[rtc_in[12:8]] <= rtc_in[7:0]; ld_count[rtc_in[12:8]] = ld_count[rtc_in[12:8]] + 1; end
end

function leap(input integer y);
	leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;
endfunction

function integer mlen(input integer y, input integer m);
	mlen = (m == 2) ? (leap(y) ? 29 : 28) : (m == 4 || m == 6 || m == 9 || m == 11) ? 30 : 31;
endfunction

// days since 1904-01-01, one year and one month at a time
function integer ref_days(input integer y, input integer m, input integer d);
	integer yy, mm;
	begin
		ref_days = 0;
		for (yy = 1904; yy < y; yy = yy + 1) ref_days = ref_days + (leap(yy) ? 366 : 365);
		for (mm = 1; mm < m; mm = mm + 1) ref_days = ref_days + mlen(y, mm);
		ref_days = ref_days + d - 1;
	end
endfunction

function [7:0] enc(input integer v, input integer bin);
	enc = bin ? v : ((v / 10) << 4) | (v % 10);
endfunction

integer y, mo, d, h, mi, s, bin, cases, c, r, days, wday, late;
integer ey, emo, ed, eh, emi, es, ew;
reg [31:0] want;

task mac_write_pulse(input integer which); // 46: secs_wr, 13: pram_we
	begin
		@(posedge clk_sys) rtc_out[which] <= 1;
		@(posedge clk_sys) rtc_out[which] <= 0;
	end
endtask

task set_clock(input [31:0] value, input integer expect_write);
	integer n0, n9;
	begin
		n0 = wr_count[0]; n9 = wr_count[9];
		repeat (4) begin
			mac_write_pulse(46);
			repeat (40) @(posedge clk_sys);
		end
		@(posedge clk_sys) rtc_out[45:14] <= value;
		// the quiet time, then the conversion back to the idle state
		repeat (2000) @(posedge clk);
		while (dut.state != 4'd5 || dut.secs_dirty) @(posedge clk);
		repeat (20) @(posedge clk);
		// the expected date
		days = value / 86400; r = value % 86400;
		eh = r / 3600; emi = (r % 3600) / 60; es = r % 60;
		ew = (days + 5) % 7 + 1;
		ey = 1904;
		while (days >= (leap(ey) ? 366 : 365)) begin days = days - (leap(ey) ? 366 : 365); ey = ey + 1; end
		emo = 1;
		while (days >= mlen(ey, emo)) begin days = days - mlen(ey, emo); emo = emo + 1; end
		ed = days + 1;
		if (expect_write) begin
			if (wr_count[0] != n0 + 1 || wr_count[9] != n9 + 1) begin
				$display("ERROR: %08x: %0d / %0d writes of registers 0 / 9", value, wr_count[0] - n0, wr_count[9] - n9);
				errors = errors + 1;
			end
			if (regs[0] !== enc(es, bin) || regs[2] !== enc(emi, bin) || regs[4] !== enc(eh, bin) ||
			    regs[6] !== enc(ew, bin) || regs[7] !== enc(ed, bin) || regs[8] !== enc(emo, bin) ||
			    regs[9] !== enc(ey - 2000, bin)) begin
				$display("ERROR: %08x = %0d-%02d-%02d %02d:%02d:%02d wday %0d, registers 9 8 7 6 4 2 0: %02x %02x %02x %02x %02x %02x %02x",
					value, ey, emo, ed, eh, emi, es, ew, regs[9], regs[8], regs[7], regs[6], regs[4], regs[2], regs[0]);
				errors = errors + 1;
			end
		end
		else if (wr_count[0] != n0) begin
			$display("ERROR: %08x (year %0d) written", value, ey);
			errors = errors + 1;
		end
	end
endtask

initial begin
	if (!$value$plusargs("y=%d", y)) y = 2026;
	if (!$value$plusargs("mo=%d", mo)) mo = 11;
	if (!$value$plusargs("d=%d", d)) d = 11;
	if (!$value$plusargs("h=%d", h)) h = 4;
	if (!$value$plusargs("mi=%d", mi)) mi = 30;
	if (!$value$plusargs("s=%d", s)) s = 17;
	if (!$value$plusargs("bin=%d", bin)) bin = 0;
	if (!$value$plusargs("cases=%d", cases)) cases = 8;
	if (!$value$plusargs("late=%d", late)) late = 0;
	for (k = 0; k < 256; k = k + 1) begin regs[k] = 8'hEE; wr_count[k] = 0; end
	for (k = 0; k < 20; k = k + 1) begin regs[8'h10 + k] = k * 8'h1D + 8'h03; ld_count[k] = 0; end
	regs[8'h0B] = bin ? 8'h06 : 8'h02;
	// late: the time registers hold the bytes of the .eep (0) at first, the mcu sends the time
	// late clocks after the start (-1: never; the date is then 2000-01-01 00:00)
	if (late != 0) begin
		regs[0] = 0; regs[2] = 0; regs[4] = 0; regs[7] = 0; regs[8] = 0; regs[9] = 0;
	end
	else begin
		regs[0] = enc(s, bin); regs[2] = enc(mi, bin); regs[4] = enc(h, bin);
		regs[7] = enc(d, bin); regs[8] = enc(mo, bin); regs[9] = enc(y - 2000, bin);
	end
	if (late < 0) begin y = 2000; mo = 1; d = 1; h = 0; mi = 0; s = 0; end

	// 1. the start
	repeat (50) @(posedge clk);
	if (set_count != 0 || ld_count[0] != 0) begin $display("ERROR: rtc.v written while the mcu is busy"); errors = errors + 1; end
	mcu_busy <= 0;
	if (late > 0) begin
		repeat (late) @(posedge clk);
		if (loaded || set_count != 0) begin $display("ERROR: loaded before the time came"); errors = errors + 1; end
		regs[0] = enc(s, bin); regs[2] = enc(mi, bin); regs[4] = enc(h, bin);
		regs[7] = enc(d, bin); regs[8] = enc(mo, bin); regs[9] = enc(y - 2000, bin);
	end
	repeat (late < 0 ? 400000 : 200000) @(posedge clk);
	for (k = 0; k < 20; k = k + 1)
		if (ld_count[k] != 1 || pram[k] !== regs[8'h10 + k]) begin
			$display("ERROR: PRAM %0d: %0d loads, %02x, register %02x", k, ld_count[k], pram[k], regs[8'h10 + k]);
			errors = errors + 1;
		end
	want = ref_days(y, mo, d) * 86400 + h * 3600 + mi * 60 + s;
	if (set_count != 1 || secs !== want || !loaded) begin
		$display("ERROR: %0d-%02d-%02d %02d:%02d:%02d: %0d sets, seconds %0d, want %0d", y, mo, d, h, mi, s,
			set_count, secs, want);
		errors = errors + 1;
	end

	if (real_rtc.secs !== want) begin
		$display("ERROR: rtc.v in reset: seconds %0d, want %0d", real_rtc.secs, want);
		errors = errors + 1;
	end
	for (k = 0; k < 20; k = k + 1)
		if (real_rtc.ram[k] !== regs[8'h10 + k]) begin
			$display("ERROR: rtc.v in reset: PRAM %0d = %02x, register %02x", k, real_rtc.ram[k], regs[8'h10 + k]);
			errors = errors + 1;
		end
	rtc_reset <= 0;

	// 2. a PRAM byte of the Mac
	@(posedge clk_sys) rtc_out[12:0] <= { 5'd5, 8'h77 };
	mac_write_pulse(13);
	repeat (20) @(posedge clk);
	if (regs[8'h15] !== 8'h77 || wr_count[8'h15] != 1) begin
		$display("ERROR: PRAM write: register 15 = %02x, %0d writes", regs[8'h15], wr_count[8'h15]);
		errors = errors + 1;
	end

	// 3. the Mac sets its clock
	set_clock(ref_days(2031, 2, 28) * 86400 + 23 * 3600 + 59 * 60 + 58, 1);
	set_clock(ref_days(2024, 2, 29) * 86400 + 12 * 3600, 1);
	set_clock(ref_days(2000, 1, 1) * 86400, 1);
	set_clock(32'hFFFFFFFF, 1);   // the last second of the Mac: 2040-02-06 06:28:15
	set_clock(ref_days(1999, 12, 31) * 86400 + 86399, 0);
	for (c = 0; c < cases; c = c + 1)
		set_clock(ref_days(2000, 1, 1) * 86400 + $urandom_range(0, 32'hFFFFFFFF - 32'd35064 * 32'd86400), 1);
	if (set_count != 1) begin $display("ERROR: %0d sets of rtc.v", set_count); errors = errors + 1; end

	$display("tb_mac_clock: %0d errors", errors);
	$finish;
end

endmodule
