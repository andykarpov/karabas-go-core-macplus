`timescale 1ns / 1ps
`default_nettype wire

/*
 sim_board.v - the Mac Plus machine with the memory path of the board tops, for verilator:
 macplus on clk_sys, mac_sdram on clk_2x with a model of the MT48LC16M16A2 (commands at the rising
 edge of SDR_CLK = the falling edge of clk_2x, CL 2), mac_sram on clk_2x with a model of the SRAM
 (asynchronous, the ROM from +rom=FILE), and the write side of the frame buffer (mac_video; the
 harness reads the buffer back). The same ports as sim_top.v (sim_macplus.cpp -DSIM_BOARD): clk is
 clk_2x, clk_sys = clk_2x / 2 comes from the harness too, its rising edge in the same eval as one of
 clk (each side takes the values of the other from before the edge, as on the board). The disks go
 to the harness directly, as in sim_top.v.
*/

module sim_board (
	input  wire        clk,          // clk_2x
	input  wire        reset,
	input  wire [1:0]  ram_size,
	input  wire        fastboot,
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
	input  wire        clk_sys,
	output wire        ram_ready,

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

	output wire        uart_txd,

	// the frame buffer, read back by the harness
	input  wire [13:0] fb_addr,
	output wire [15:0] fb_word
);

assign cpu_addr = mac.cpuAddr;
assign cpu_as_n = mac._cpuAS;
assign fb_word = video.fb[fb_addr];

reg sys_t = 1'b0;
always @(posedge clk_sys) sys_t <= !sys_t;

// ------------------------------------------------------------------ SRAM model (2M x 16, asynchronous)

reg [7:0] sram_hi [0:131071];   // the ROM part is enough
reg [7:0] sram_lo [0:131071];
reg [7:0] rom_b [0:131071];
integer fd, n;
reg [1023:0] rom_name;
initial begin
	for (n = 0; n < 131072; n = n + 1) rom_b[n] = 8'h00;
	if ($value$plusargs("rom=%s", rom_name)) begin
		fd = $fopen(rom_name, "rb");
		if (fd == 0) begin $display("sim_board: cannot open the ROM"); $finish; end
		n = $fread(rom_b, fd);
		$fclose(fd);
		$display("sim_board: ROM %0d bytes", n);
	end
	for (n = 0; n < 65536; n = n + 1) begin
		sram_hi[n] = rom_b[2 * n];
		sram_lo[n] = rom_b[2 * n + 1];
	end
end

wire [20:0] MA;
wire [15:0] MD;
wire [1:0] MWR_N, MRD_N;
assign MD[15:8] = (!MRD_N[1] && MWR_N[1]) ? sram_hi[MA[16:0]] : 8'bz;
assign MD[7:0]  = (!MRD_N[0] && MWR_N[0]) ? sram_lo[MA[16:0]] : 8'bz;

wire rom_oe_n;
wire [17:0] rom_addr;
wire [15:0] rom_data;

mac_sram sram (
	.clk(clk),
	.raddr({ 5'd0, rom_addr[15:0] }),
	.rdata(rom_data),
	.we(1'b0),
	.waddr(22'd0),
	.wdata(8'd0),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);

// ------------------------------------------------------------------ SDRAM model (bank 0, 4096 x 512)

wire [12:0] SDR_A;
wire [1:0] SDR_BA, SDR_DQM;
wire [15:0] SDR_DQ;
wire sdr_cs_n, sdr_ras_n, sdr_cas_n, sdr_we_n;
reg [15:0] sdr_mem [0:2097151];
reg [11:0] sdr_row = 12'd0;
reg [20:0] rd_a1 = 21'd0, rd_a2 = 21'd0;
reg rd_p1 = 1'b0, rd_p2 = 1'b0, dq_drive = 1'b0;
reg [15:0] dq_val = 16'd0;
assign SDR_DQ = dq_drive ? dq_val : 16'bz;

always @(negedge clk) begin
	// CL 2: the data of a READ at edge n are on DQ from edge n + 2 until edge n + 3
	dq_drive <= rd_p2;
	dq_val <= sdr_mem[rd_a2];
	rd_p2 <= rd_p1;
	rd_a2 <= rd_a1;
	rd_p1 <= 1'b0;
	if (!sdr_cs_n) begin
		case ({ sdr_ras_n, sdr_cas_n, sdr_we_n })
		3'b011: sdr_row <= SDR_A[11:0];                       // ACTIVE
		3'b101: begin rd_p1 <= 1'b1; rd_a1 <= { sdr_row, SDR_A[8:0] }; end   // READ
		3'b100: begin                                         // WRITE
			if (!SDR_DQM[1]) sdr_mem[{ sdr_row, SDR_A[8:0] }][15:8] <= SDR_DQ[15:8];
			if (!SDR_DQM[0]) sdr_mem[{ sdr_row, SDR_A[8:0] }][7:0] <= SDR_DQ[7:0];
		end
		default: ;
		endcase
	end
end

// ------------------------------------------------------------------ the machine

wire [20:0] ram_addr;
wire [15:0] ram_din, ram_dout;
wire [1:0] ram_ds;
wire ram_we, ram_oe;
wire vid_load;

reg [7:0] rst_cnt = 8'd0;
always @(posedge clk) if (rst_cnt != 8'hFF) rst_cnt <= rst_cnt + 8'd1;

mac_sdram sdram (
	.clk(clk),
	.reset_n(rst_cnt == 8'hFF),
	.ready(ram_ready),
	.sys_t(sys_t),
	.phase(phase),
	.addr(ram_addr),
	.din(ram_din),
	.dout(ram_dout),
	.ds(ram_ds),
	.oe(ram_oe),
	.we(ram_we),
	.SDR_A(SDR_A),
	.SDR_BA(SDR_BA),
	.SDR_DQ(SDR_DQ),
	.SDR_DQM(SDR_DQM),
	.SDR_CS_N(sdr_cs_n),
	.SDR_RAS_N(sdr_ras_n),
	.SDR_CAS_N(sdr_cas_n),
	.SDR_WE_N(sdr_we_n)
);

macplus mac (
	.CLKIN(clk_sys),
	.RESET(reset || !ram_ready),
	.pixelOut(pix),
	.vidLoad(vid_load),
	.vsync(vs),
	.hsync(hs),
	.audio(audio),
	.leds(leds),
	.ADC_BUS(),
	.MOUSE(mouse),
	.kbd_strobe(kbd_strobe),
	.kbd_data(kbd_data),
	.configROMSize(1'b1),
	.configFastboot(fastboot),
	.configRAMSize(ram_size),
	.configMachineType(1'b0),
	.configFloppyWProt(floppy_wprot),
	.configSCSIWProt(2'b00),
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
	.sdram_do(ram_dout)
);

// a reference RAM as sim_top.v has it: every read of the SDRAM path is checked against it
reg [15:0] ref_ram [0:2097151];
reg ref_sel = 1'b0, ref_rd = 1'b0;
reg [20:0] ref_a = 21'd0;
integer mism = 0;
always @(posedge clk_sys) begin
	if (phase == 3'd2) begin ref_sel <= ram_oe || ram_we; ref_rd <= ram_oe && !ram_we; ref_a <= ram_addr; end
	if (phase == 3'd6 && ref_sel && ram_we) begin
		if (ram_ds[1]) ref_ram[ram_addr][15:8] <= ram_din[15:8];
		if (ram_ds[0]) ref_ram[ram_addr][7:0] <= ram_din[7:0];
	end
	if (phase == 3'd7 && ref_sel && ref_rd && ram_dout != ref_ram[ref_a] && mism < 20) begin
		mism = mism + 1;
		$display("sim_board: read %06x: sdram %04x, reference %04x (addr now %06x)", ref_a, ram_dout, ref_ram[ref_a], ram_addr);
	end
end

// the frame buffer (its read side runs on a clock the harness does not make)
mac_video video (
	.clk_sys(clk_sys),
	.vid_load(vid_load),
	.phase(phase),
	.vid_word(ram_dout),
	.vsync_n(vs),
	.clk_65(1'b0),
	.blank(1'b0),
	.rgb(),
	.hs(),
	.vs(),
	.de()
);

endmodule
