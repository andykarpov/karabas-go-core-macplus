`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_hid.v

 The USB keyboard and mouse of the mcu link (kg_mcu: the keyboard report, mouse deltas) as the
 inputs of the Mac machine of NanoMac (macplus: kbd_strobe / kbd_data, MOUSE).

 Keyboard: the machine takes key events, as hid.v of NanoMac gives them from the FPGA companion:
 kbd_data = { the two keypad bits of the keymap, 1 = released, the Mac key code }, valid when
 kbd_strobe toggles. The input codes of the keymap (macplus_keymap.v of NanoMac) are the USB HID
 usage codes, the modifiers as 68..6F (bit n of the report's modifier byte = 68 + n). keyboard.v
 of the machine holds one key until the Mac asks for it, so the events are paced: one per 2^18
 clocks (17 ms at 15.476 MHz).

 The events come from a scan of the codes 04..6F, one per clock: a code is down when one of the six
 key bytes of the report (KB_DAT0..5, bit 7 = no key) has it, or its modifier bit is set; a change
 against the map of the keys sent (128 flip-flops) is sent as an event and taken into the map. A
 code that the keymap has not (7F) only goes into the map.

 Mouse: as hid.v: the deltas of each report are added to two counters; every 2^12 clocks a counter
 that is not 0 moves its 2-bit Gray code one step towards 0, as the light barriers of the mouse.
 MOUSE = { button (0 = pressed), X2, X1, Y2, Y1 } as hid.v has it.
*/

module mac_hid (
	input  wire       clk,
	input  wire       reset,

	input  wire [7:0] kb_status,
	input  wire [7:0] kb_dat0,
	input  wire [7:0] kb_dat1,
	input  wire [7:0] kb_dat2,
	input  wire [7:0] kb_dat3,
	input  wire [7:0] kb_dat4,
	input  wire [7:0] kb_dat5,

	input  wire [7:0] ms_x,
	input  wire [7:0] ms_y,
	input  wire [2:0] ms_b,
	input  wire       ms_upd,

	output reg        kbd_strobe = 1'b0,
	output wire [9:0] kbd_data,
	output wire [4:0] mouse
);

// ------------------------------------------------------------------ keyboard

reg [6:0] code = 7'd4;
reg [127:0] down = 128'd0;
reg [17:0] pace = 18'd0;
reg [7:0] ev = 8'h00;   // { released, code } of the last event

wire hit = (kb_dat0 == { 1'b0, code }) || (kb_dat1 == { 1'b0, code }) || (kb_dat2 == { 1'b0, code }) ||
           (kb_dat3 == { 1'b0, code }) || (kb_dat4 == { 1'b0, code }) || (kb_dat5 == { 1'b0, code });
wire mod = (code[6:3] == 4'b1101) && kb_status[code[2:0]];   // 68..6F
wire now = hit || mod;

wire [8:0] mac_code;
keymap keymap (
	.code(code),
	.mac(mac_code)
);

wire [8:0] ev_mac;
keymap keymap_ev (
	.code(ev[6:0]),
	.mac(ev_mac)
);
assign kbd_data = { ev_mac[8:7], ev[7], ev_mac[6:0] };

always @(posedge clk) begin
	if (reset) begin
		down <= 128'd0;
		pace <= 18'd0;
		code <= 7'd4;
	end
	else begin
		if (pace != 18'd0)
			pace <= pace + 18'd1;
		if (now != down[code]) begin
			if (mac_code[6:0] == 7'h7F)
				down[code] <= now;
			else if (pace == 18'd0) begin
				down[code] <= now;
				ev <= { !now, code };
				kbd_strobe <= !kbd_strobe;
				pace <= 18'd1;
			end
		end
		// stay on a changed code until its event is out
		if (now == down[code] || mac_code[6:0] == 7'h7F || pace == 18'd0)
			code <= (code == 7'h6F) ? 7'd4 : code + 7'd1;
	end
end

// ------------------------------------------------------------------ mouse

reg ms_upd_d = 1'b0;
reg [7:0] mx_cnt = 8'd0, my_cnt = 8'd0;
reg [1:0] mx = 2'b00, my = 2'b00;
reg mbtn = 1'b0;
reg [11:0] mdiv = 12'd0;

assign mouse = { !mbtn, mx, my };

always @(posedge clk) begin
	ms_upd_d <= ms_upd;
	mdiv <= mdiv + 12'd1;
	if (reset) begin
		mx_cnt <= 8'd0;
		my_cnt <= 8'd0;
		mbtn <= 1'b0;
	end
	else if (ms_upd != ms_upd_d) begin
		mbtn <= ms_b[0];
		mx_cnt <= mx_cnt + ms_x;
		my_cnt <= my_cnt + ms_y;
	end
	else if (mdiv == 12'd0) begin
		if (mx_cnt != 8'd0) begin
			if (mx_cnt[7]) begin
				mx_cnt <= mx_cnt + 8'd1;
				mx <= { ~mx[0], mx[1] };
			end
			else begin
				mx_cnt <= mx_cnt - 8'd1;
				mx <= { mx[0], ~mx[1] };
			end
		end
		if (my_cnt != 8'd0) begin
			if (my_cnt[7]) begin
				my_cnt <= my_cnt + 8'd1;
				my <= { my[0], ~my[1] };
			end
			else begin
				my_cnt <= my_cnt - 8'd1;
				my <= { ~my[0], my[1] };
			end
		end
	end
end

endmodule
