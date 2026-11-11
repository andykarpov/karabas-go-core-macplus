`timescale 1ns / 1ps

// tb_mac_sdc.v (iverilog): mac_sdc between the bytes of img_sdc (clk_2x) and the machine (clk_sys).
// Sectors with a byte every 3 clocks (a read) and every clock (the zero fill of a failed read): the
// machine side must see 512 strobes, one per clk_sys clock at most, addresses 0..511 in order, the
// right data, busy until the last byte has been out; and the mount pulses for one clk_sys clock.

module tb_mac_sdc;

reg clk = 0, clk_sys = 0;
always #8 clk = !clk;                     // clk_2x
// blocking: clk_sys rises in the same step as clk, before the registers of clk change (as on the board)
always @(posedge clk) clk_sys = !clk_sys;
reg sys_t = 0;
always @(posedge clk_sys) sys_t <= !sys_t;

reg [7:0] mounted = 0;
reg busy = 0, strobe = 0;
reg [8:0] addr = 0;
reg [7:0] data = 0;
wire [3:0] m_mounted;
wire m_busy, m_data_en;
wire [8:0] m_addr;
wire [7:0] m_data_in;

mac_sdc dut (
	.clk(clk), .sys_t(sys_t),
	.sdc_mounted(mounted), .sdc_busy(busy), .sdc_strobe(strobe), .sdc_addr(addr), .sdc_data(data),
	.m_mounted(m_mounted), .m_busy(m_busy), .m_data_en(m_data_en), .m_addr(m_addr), .m_data_in(m_data_in)
);

integer errors = 0, got = 0, mounts = 0;
reg [8:0] expect_addr = 0;
reg [7:0] seed = 0;
reg seen_busy = 0;

// the machine side
always @(posedge clk_sys) begin
	if (m_data_en) begin
		if (m_addr != expect_addr || m_data_in != (expect_addr[7:0] ^ seed)) begin
			if (errors < 10) $display("ERROR: byte %0d: addr %0d data %02x", expect_addr, m_addr, m_data_in);
			errors = errors + 1;
		end
		if (!m_busy) begin
			if (errors < 10) $display("ERROR: byte %0d without busy", expect_addr);
			errors = errors + 1;
		end
		expect_addr = expect_addr + 1;
		got = got + 1;
	end
	if (m_mounted != 0) mounts = mounts + 1;
end

task sector(input integer gap, input [7:0] s);
	integer i, k;
	begin
		seed = s;
		expect_addr = 0;
		got = 0;
		@(posedge clk) busy <= 1;
		repeat (5) @(posedge clk);
		for (i = 0; i < 512; i = i + 1) begin
			strobe <= 1; addr <= i; data <= i[7:0] ^ s;
			@(posedge clk) strobe <= 0;
			for (k = 1; k < gap; k = k + 1) @(posedge clk);
		end
		busy <= 0;
		// busy of the machine side falls only after the last byte
		while (m_busy) @(posedge clk_sys);
		if (got != 512) begin $display("ERROR: gap %0d: %0d bytes at the end of busy", gap, got); errors = errors + 1; end
		repeat (10) @(posedge clk_sys);
	end
endtask

initial begin
	repeat (10) @(posedge clk);
	sector(3, 8'h5A);
	sector(1, 8'hC3);
	sector(2, 8'h11);
	// a mount pulse of one clk_2x clock, at either phase of clk_sys
	@(posedge clk) mounted <= 8'h01; @(posedge clk) mounted <= 0;
	repeat (5) @(posedge clk_sys);
	@(posedge clk) mounted <= 8'h02; @(posedge clk) mounted <= 0;
	repeat (5) @(posedge clk_sys);
	if (mounts != 2) begin $display("ERROR: %0d mount clocks, expected 2", mounts); errors = errors + 1; end
	$display("tb_mac_sdc: %0d errors", errors);
	$finish;
end

endmodule
