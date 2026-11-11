`timescale 1ns / 1ps
`default_nettype wire

/*
 sim_top.v - the Mac Plus machine (macplus of rtl/sv2v) on simple memory models, for verilator.

 ROM and RAM as the SRAM-like path of the NanoMac simulation: an access selected in busPhase 2
 is served in busPhase 6 (read data from the clock that ends phase 5, the write at the end of 6).
 The ROM file comes from +rom=FILE (128 KB, big endian words). The board top differs in the
 memories (SDRAM, SRAM), the clocks, the mcu link and the video output.

 The sector interface sdc_* goes to the harness (sim_macplus.cpp), which serves the disk images.
*/

module sim_top (
	input  wire        clk,
	input  wire        reset,
	input  wire [1:0]  ram_size,     // 0 128K, 1 512K, 2 1M, 3 4M
	input  wire        fastboot,
	input  wire        machine_se,   // the model: 0 Plus (and 128K / 512K), 1 SE
	input  wire [1:0]  rom_size,     // 0 64K (128K / 512K), 1 128K (Plus), 2 256K (SE)
	input  wire [1:0]  floppy_wprot,

	input  wire [5:0]  mouse,
	input  wire        kbd_strobe,
	input  wire [9:0]  kbd_data,

	output wire        pix,
	output wire        hs,
	output wire        vs,
	output wire [11:0] audio,
	output wire [4:0]  leds,
	output wire [2:0]  phase,
	output wire [23:1] cpu_addr,
	output wire        cpu_as_n,

	input  wire [31:0] sdc_image_size,
	input  wire [3:0]  sdc_image_mounted,
	output wire [31:0] sdc_lba,
	output wire [3:0]  sdc_rd,
	output wire [3:0]  sdc_wr,
	input  wire        sdc_done,
	input  wire        sdc_busy,
	output wire [7:0]  sdc_data_out,
	input  wire [7:0]  sdc_data_in,
	input  wire        sdc_data_en,
	input  wire [8:0]  sdc_addr,

	output wire        uart_txd
);

assign cpu_addr = mac.cpuAddr;
assign cpu_as_n = mac._cpuAS;

// ------------------------------------------------------------------ ROM up to 256 KB

reg [7:0] rom_b [0:262143];
integer fd, n;
reg [1023:0] rom_name;
initial begin
	for (n = 0; n < 262144; n = n + 1) rom_b[n] = 8'h00;
	if ($value$plusargs("rom=%s", rom_name)) begin
		fd = $fopen(rom_name, "rb");
		if (fd == 0) begin $display("sim_top: cannot open the ROM"); $finish; end
		n = $fread(rom_b, fd);
		$fclose(fd);
		$display("sim_top: ROM %0d bytes", n);
	end
end

wire        rom_oe_n;
wire [17:0] rom_addr;
wire [16:0] rom_word = rom_size == 2'd2 ? rom_addr[16:0] : rom_size == 2'd1 ? { 1'b0, rom_addr[15:0] } : { 2'b00, rom_addr[14:0] };
reg  [15:0] rom_data;

// ------------------------------------------------------------------ RAM 4 MB

reg  [7:0] ram_hi [0:2097151];
reg  [7:0] ram_lo [0:2097151];
wire [20:0] ram_addr;
wire [15:0] ram_din;
wire [1:0]  ram_ds;
wire        ram_we, ram_oe;
reg  [15:0] ram_do;
reg         ram_sel;

always @(posedge clk) begin
	if (phase == 3'd2) ram_sel <= ram_oe || ram_we;
	// the data are there from the clock that ends busPhase 5 on: stable in phases 6 and 7, as
	// the NanoMac harness gives them during phase 6
	if (phase == 3'd5) begin
		// the ROM file from offset 0 at any size, as the board has it (the 64K one: A16 / A17 dropped)
		if (!rom_oe_n) rom_data <= { rom_b[{ rom_word, 1'b0 }], rom_b[{ rom_word, 1'b1 }] };
		if (ram_sel && ram_oe) ram_do <= { ram_hi[ram_addr], ram_lo[ram_addr] };
	end
	if (phase == 3'd6 && ram_sel && ram_we) begin
		if (ram_ds[1]) ram_hi[ram_addr] <= ram_din[15:8];
		if (ram_ds[0]) ram_lo[ram_addr] <= ram_din[7:0];
	end
end

// ------------------------------------------------------------------ the machine

macplus mac (
	.CLKIN(clk),
	.RESET(reset),
	.pixelOut(pix),
	.vsync(vs),
	.hsync(hs),
	.audio(audio),
	.leds(leds),
	.ADC_BUS(),
	.MOUSE(mouse),
	.kbd_strobe(kbd_strobe),
	.kbd_data(kbd_data),
	.configROMSize(rom_size),
	.configFastboot(fastboot),
	.configRAMSize(ram_size),
	.configMachineType(machine_se),
	.configFloppyWProt(floppy_wprot),
	.configSCSIWProt(2'b00),
	.rtc_in(47'd0),   // no mac_clock: the PRAM defaults of rtc.v, the clock from 1904
	.rtc_out(),
	.sdc_image_size(sdc_image_size),
	.sdc_image_mounted(sdc_image_mounted),
	.sdc_lba(sdc_lba),
	.sdc_rd(sdc_rd),
	.sdc_wr(sdc_wr),
	.sdc_done(sdc_done),
	.sdc_busy(sdc_busy),
	.sdc_data_out(sdc_data_out),
	.sdc_data_in(sdc_data_in),
	.sdc_data_en(sdc_data_en),
	.sdc_addr(sdc_addr),
	.UART_TXD(uart_txd),
	.UART_RXD(1'b1),
	.UART_RTS(),
	.UART_CTS(1'b1),
	._romOE(rom_oe_n),
	.romAddr(rom_addr),
	.romData(rom_data),
	.busPhase(phase),
	.ram_addr(ram_addr),
	.sdram_din(ram_din),
	.sdram_ds(ram_ds),
	.sdram_we(ram_we),
	.sdram_oe(ram_oe),
	.sdram_do(ram_do)
);

endmodule
