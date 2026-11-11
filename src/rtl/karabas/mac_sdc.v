`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_sdc.v

 The sector interface of img_sdc (on clk_2x) to the one of the machine (sdc_* of macplus, on
 clk_sys = clk_2x / 2 of the same PLL). The outputs to the machine are clk_2x registers that change
 only at the clk_2x edges that are clk_sys edges (sys_edge: sys_t, a clk_sys register that toggles
 every clock, equals its clk_2x copy), so the machine sees each value for whole clocks of its own:

 - the read bytes: img_sdc gives a byte every 3 clocks of clk_2x (and every clock when it fills a
   failed read with zeros), the machine takes one per clock of its own. They go through a FIFO
   (512 x 18, one RAMB16, a whole sector) and come out one per clk_sys clock as m_data_en with
   m_addr / m_data_in;
 - m_busy is the busy of img_sdc or any byte still in the FIFO: the floppy and the SCSI targets
   take the end of busy as the end of the sector (they need all of its bytes before it);
 - m_mounted: the mount pulses of img_sdc (one clock of clk_2x), held for one clk_sys clock;
 - writes: img_sdc reads the bytes of the sector with sdc_byte_addr and takes sdc_byte_out_data
   OUT_LATENCY (4) clocks of clk_2x later; m_addr is that address while no read byte is out, the
   machine's buffer answers within one clk_sys clock (+ a clock until the next clk_sys edge).
*/

module mac_sdc (
	input  wire        clk,          // clk_2x
	input  wire        sys_t,

	// img_sdc
	input  wire [7:0]  sdc_mounted,
	input  wire        sdc_busy,
	input  wire        sdc_strobe,
	input  wire [8:0]  sdc_addr,
	input  wire [7:0]  sdc_data,

	// the machine
	output reg  [3:0]  m_mounted = 4'd0,
	output reg         m_busy = 1'b0,
	output reg         m_data_en = 1'b0,
	output wire [8:0]  m_addr,
	output reg  [7:0]  m_data_in = 8'd0
);

reg sys_t_d = 1'b0;
always @(posedge clk) sys_t_d <= sys_t;
wire sys_edge = (sys_t == sys_t_d);

// ------------------------------------------------------------------ FIFO of the read bytes

reg [16:0] fifo [0:511];
reg [8:0] wp = 9'd0, rp = 9'd0;
reg [9:0] count = 10'd0;
reg [16:0] q = 17'd0;
reg q_valid = 1'b0;    // q holds the entry at rp (one clock after rp moved)
reg [8:0] out_addr = 9'd0;
reg strobe_d = 1'b0;   // count takes a byte a clock after its write: q has it when a pop can take it

wire pop = sys_edge && q_valid && count != 10'd0;

always @(posedge clk) begin
	if (sdc_strobe)
		fifo[wp] <= { sdc_addr, sdc_data };
	q <= fifo[rp];
end

always @(posedge clk) begin
	if (sdc_strobe) wp <= wp + 9'd1;
	strobe_d <= sdc_strobe;
	q_valid <= !pop;
	if (pop) rp <= rp + 9'd1;
	count <= count + (strobe_d ? 10'd1 : 10'd0) - (pop ? 10'd1 : 10'd0);

	if (sys_edge) begin
		m_data_en <= pop;
		if (pop) begin
			out_addr <= q[16:8];
			m_data_in <= q[7:0];
		end
		m_busy <= sdc_busy || strobe_d || count != 10'd0;
	end
end

assign m_addr = m_data_en ? out_addr : sdc_addr;

// ------------------------------------------------------------------ mount pulses

reg [3:0] mount_pend = 4'd0;
always @(posedge clk) begin
	if (sys_edge) begin
		m_mounted <= mount_pend | sdc_mounted[3:0];
		mount_pend <= 4'd0;
	end
	else
		mount_pend <= mount_pend | sdc_mounted[3:0];
end

endmodule
