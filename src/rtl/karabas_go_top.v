`timescale 1ns / 1ps
`default_nettype wire

/*
 Apple Macintosh Plus core for Karabas Go (VGA, PCM5102). Made by tools/mktops.py from
 karabas_minig_top.v (do not edit: change that one and run it): the same except the pins, the MCU
 link (MCU_SCK not on a clock pin) and the video: 24 bit RGB to the VGA DAC with its pixel clock on
 V_CLK (clk_65), the FT812 off that bus (FT_OE_N = 1). The floppy connector is not used (its
 outputs 0). The machine of NanoMac (macplus, through sv2v in rtl/sv2v) with the board glue of
 karabas-go-modules.

 Clocks: one PLL, VCO 650 MHz (50 * 13):
   clk_sys 15.476 MHz (/42): the machine (busPhase 0..7 per 8 clocks, the 68000 at 7.74 MHz; the
           Mac has 15.667 MHz, NanoMac on the Tang 15.6), the keyboard and mouse
   clk_2x  30.952 MHz (/21, twice clk_sys, rising edges together): the SDRAM, the SRAM, the MCU
           link, the file mounter, audio
   clk_65  65.0 MHz (/10): the video output (1024 x 768 at 60 Hz, VGA), the OSD
   (outputs 1..3, the HDMI serialiser and FT_CLK_OUT of Mini / Mini G, are not used here)
 clk_sys and clk_2x are one clock domain for the timing (registers of either feed the other, the
 analysis takes the 32 ns between their edges); clk_65 is crossed with synchronisers, the frame
 buffer is a block RAM with two clocks.

 Memory: the RAM of the Mac (128 KB .. 4 MB) in the SDRAM (mac_sdram, one access per bus cycle), the
 ROMs (128 KB Plus, 256 KB SE, 64 KB 128K / 512K) in the SRAM (mac_sram), loaded by their FL items
 while the machine is held in reset.

 Video: the words the machine loads into its shifter go into a frame buffer (mac_video), out as
 1024 x 768, every pixel 2 x 2.

 Disks: the F items Floppy 1, Floppy 2 (sdc slots 0, 1: the internal and external drive) and SCSI
 6, SCSI 5 (slots 2, 3) through img_sdc (the file mounter of the mcu) and mac_sdc (its bytes into
 the clock of the machine); an image mounted read only is a write protected disk (img_wp).

 Clock and PRAM: mac_clock between the RTC registers of the mcu (rtc_mode 0) and rtc.v: the time of
 the clock chip at the start, back to it when the Mac sets its clock; the 20 PRAM bytes in registers
 0x10..0x23, kept by the firmware in /config/macplus.eep (eeprom_bank 4, eeprom_init pram.bin).

 Soft switches (the "index" of core.json; 0..4 the file items Floppy 1 / 2, SCSI 6 / 5, ROM Plus):
   5 Memory (1 MB / 4 MB, Plus and SE)   6 Fastboot (Off / On, Plus ROM)   7 Reset
   8 Model (Plus / SE / 512Ke / 512K / 128K)
 ROM files (FL, autoloaded when present): ROM Plus slot 7 /macplus/plus.rom, ROM SE slot 6
 /macplus/se.rom, ROM 64K slot 5 /macplus/mac512.rom (the 128K and the 512K).
*/

module karabas_go_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,
	inout wire ESP_RESET_N,
	inout wire ESP_BOOT_N,

	output wire [20:0] MA,
	inout wire [15:0] MD,
	output wire [1:0] MWR_N,
	output wire [1:0] MRD_N,

	output wire [1:0] SDR_BA,
	output wire [12:0] SDR_A,
	output wire SDR_CLK,
	output wire [1:0] SDR_DQM,
	output wire SDR_WE_N,
	output wire SDR_CAS_N,
	output wire SDR_RAS_N,
	inout wire [15:0] SDR_DQ,

	output wire SD_CS_N,
	output wire SD_CLK,
	output wire SD_DI,
	input wire SD_DO,
	input wire SD_DET_N,

	output wire [7:0] VGA_R,
	output wire [7:0] VGA_G,
	output wire [7:0] VGA_B,
	output wire VGA_HS,
	output wire VGA_VS,
	output wire V_CLK,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	output wire FT_OE_N,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	input wire FDC_INDEX,
	output wire [1:0] FDC_DRIVE,
	output wire FDC_MOTOR,
	output wire FDC_DIR,
	output wire FDC_STEP,
	output wire FDC_WDATA,
	output wire FDC_WGATE,
	input wire FDC_TR00,
	input wire FDC_WPRT,
	input wire FDC_RDATA,
	output wire FDC_SIDE_N,

	output wire TAPE_OUT,
	input wire TAPE_IN,
	output wire BEEPER,

	output wire DAC_LRCK,
	output wire DAC_DAT,
	output wire DAC_BCK,
	output wire DAC_MUTE,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	input wire MCU_SPI_FT_CS_N,
	input wire MCU_SPI_SD2_CS_N,
	inout wire [1:0] MCU_SPI_IO, // [0] burst ready (firmware IO1, GPIO2), [1] burst cs_n (IO0, GPIO14)

	output wire MIDI_TX,
	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);

// ------------------------------------------------------------------ unused

assign WA = 3'b000;
assign WCS_N = 2'b11;
assign WRD_N = 1'b1;
assign WWR_N = 1'b1;
assign WRESET_N = 1'b1;
assign WD = 16'bz;

assign TAPE_OUT = 1'b0;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;
assign MIDI_TX = 1'b1;
assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign MIDI_CLK = 1'b0;      // the SAM2695 synth: held in reset, the Mac has no use for it
assign MIDI_RESET_N = 1'b0;

assign FT_OE_N = 1'b1;     // the FT812 does not drive the video DAC
assign BEEPER = 1'b0;
assign DAC_MUTE = 1'b1;    // soft mute of the PCM5102: 1 = sound on

// the floppy connector is not used: its outputs 0 (the board inverts them: high = active)
assign FDC_DRIVE = 2'b00;
assign FDC_MOTOR = 1'b0;
assign FDC_DIR = 1'b0;
assign FDC_STEP = 1'b0;
assign FDC_WDATA = 1'b0;
assign FDC_WGATE = 1'b0;
assign FDC_SIDE_N = 1'b0;

assign FLASH_DI = 1'b1;
assign FLASH_SCK = 1'b0;
assign FLASH_WP_N = 1'b1;
assign FLASH_HOLD_N = 1'b1;

// ------------------------------------------------------------------ clocks

wire clk_65, clk_ser, clk_ser_n, clk_8, clk_2x, clk_sys;
wire locked;
wire [5:0] pll_clk;
kg_pll #(
	.CLKIN_PERIOD(20.0),
	.DIVCLK_DIVIDE(1),
	.CLKFBOUT_MULT(13),
	.CLKOUT0_DIVIDE(10),
	.CLKOUT1_DIVIDE(2),
	.CLKOUT2_DIVIDE(2), .CLKOUT2_PHASE(180.0),
	.CLKOUT3_DIVIDE(80),
	.CLKOUT4_DIVIDE(21),
	.CLKOUT5_DIVIDE(42),
	.BUFG_MASK(6'b111111)
) pll (
	.clk_in(CLK_50MHZ),
	.rst(1'b0),
	.clk_out(pll_clk),
	.locked(locked)
);
assign clk_65 = pll_clk[0];
assign clk_ser = pll_clk[1];
assign clk_ser_n = pll_clk[2];
assign clk_8 = pll_clk[3];
assign clk_2x = pll_clk[4];
assign clk_sys = pll_clk[5];
wire areset = ~locked;

// the pixel clock of the VGA DAC
ODDR2 oddr_v_clk (.Q(V_CLK), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// a register of clk_sys that toggles every clock: the clk_2x side finds the clk_sys edges by it
reg sys_t = 1'b0;
always @(posedge clk_sys) sys_t <= !sys_t;

// ------------------------------------------------------------------ MCU

// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;

wire mcu_burst_ready;
assign MCU_SPI_IO[0] = mcu_burst_ready;
assign MCU_SPI_IO[1] = 1'bz;

wire [7:0] kb_status, kb_dat0, kb_dat1, kb_dat2, kb_dat3, kb_dat4, kb_dat5;
wire [7:0] uart_rx_data, uart_rx_idx, uart_tx_data;
wire uart_tx_wr;
wire [12:0] joy_l, joy_r;
wire [7:0] ms_x, ms_y;
wire [3:0] ms_z;
wire [2:0] ms_b;
wire ms_upd;
wire rom_active, rom_wr;
wire [31:0] rom_addr;
wire [7:0] rom_data;
wire file_active, file_wr;
wire [7:0] file_slot, file_data;
wire [31:0] file_addr;
wire [15:0] softsw_command, osd_command;
wire mcu_busy;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [7:0] img_mounted, img_data, img_result, img_wp;
wire [63:0] img_size;
wire img_data_wr, img_result_wr, img_q_wr, img_q_ack;
wire [8:0] img_data_addr;
wire [15:0] img_sum;
wire [23:0] img_q_di;
wire [7:0] rtc_a, rtc_di, rtc_do;
wire rtc_cs, rtc_wr_n;

kg_mcu #(
	.BURST_MAX_MHZ(0),   // MCU_SCK is not on a clock pin: bursts at the link clock
	.CS_FILTER(3),
	.ENABLE_RTC(1),      // the clock and the PRAM of the Mac (mac_clock; rtc_mode 0, /config/macplus.eep)
	.ENABLE_UART(0),
	.ENABLE_MATRIX(0),
	.ENABLE_DEBUG(0),
	.ENABLE_IMG(1),      // the floppies and the SCSI disks (slots 0..3)
	.ENABLE_IMG_WP(1),   // read only images: write protected disks
	.ENABLE_MIDI(0),
	.ENABLE_FILE(1),     // the ROM (FL 7)
	.FILE_CMDS(0),
	.FILE_WR_EACH(1),
	.FILE_TO_ROM(0),
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_2x),
	.N_RESET(~areset),

	.MCU_MOSI(MCU_MOSI),
	.MCU_MISO(MCU_MISO),
	.MCU_SCK(mcu_sck),
	.MCU_SS(MCU_CS_N),
	.MCU_SPI_FT_SS(MCU_SPI_FT_CS_N),
	.MCU_SPI_SD2_SS(MCU_SPI_SD2_CS_N),
	.MCU_BURST_CS_N(MCU_SPI_IO[1]),
	.MCU_BURST_READY(mcu_burst_ready),

	.KB_STATUS(kb_status),
	.KB_DAT0(kb_dat0),
	.KB_DAT1(kb_dat1),
	.KB_DAT2(kb_dat2),
	.KB_DAT3(kb_dat3),
	.KB_DAT4(kb_dat4),
	.KB_DAT5(kb_dat5),
	.KB_SCANCODE(),
	.KB_SCANCODE_UPD(),
	.JOY_L(joy_l),
	.JOY_R(joy_r),
	.MS_X(ms_x),
	.MS_Y(ms_y),
	.MS_Z(ms_z),
	.MS_B(ms_b),
	.MS_UPD(ms_upd),

	.ROMLOADER_ACTIVE(rom_active),
	.ROMLOAD_ADDR(rom_addr),
	.ROMLOAD_DATA(rom_data),
	.ROMLOAD_WR(rom_wr),

	.FILELOAD_ACTIVE(file_active),
	.FILELOAD_ADDR(file_addr),
	.FILELOAD_DATA(file_data),
	.FILELOAD_WR(file_wr),
	.FILELOAD_SLOT(file_slot),

	.SOFTSW_COMMAND(softsw_command),
	.OSD_COMMAND(osd_command),
	.BUSY(mcu_busy),

	.FT_SPI_ON(ft_spi_on),
	.FT_CS_N(ft_cs_n),
	.FT_MOSI(ft_mosi),
	.FT_MISO(FT_SPI_MISO),
	.FT_SCK(),
	.SD2_CS_N(sd2_cs_n),
	.SD2_MOSI(sd2_mosi),
	.SD2_MISO(SD_DO),
	.SD2_SCK(),

	.DVI_ONLY(dvi_only),

	.MIDI_DATA(),
	.MIDI_WR(),
	.MIDI_LOST(),

	// not used by this core (yet)
	.PS2_COMMAND(16'h0000),
	.PS2_COMMAND_WR(1'b0),
	.RTC_A(rtc_a),
	.RTC_DI(rtc_di),
	.RTC_DO(rtc_do),
	.RTC_CS(rtc_cs),
	.RTC_WR_N(rtc_wr_n),
	.UART_RX_DATA(uart_rx_data),
	.UART_RX_IDX(uart_rx_idx),
	.UART_TX_DATA(uart_tx_data),
	.UART_TX_WR(uart_tx_wr),
	.UART_TX_MODE(1'b0),
	.UART_DLM(8'h00),
	.UART_DLL(8'h00),
	.UART_DLM_WR(1'b0),
	.UART_DLL_WR(1'b0),
	.MATRIX_CMD(24'h000000),
	.MATRIX_CMD_WR(1'b0),
	.DEBUG_ADDR(16'h0000),
	.DEBUG_DATA(16'h0000),
	.IMG_MOUNTED(img_mounted),
	.IMG_SIZE(img_size),
	.IMG_WP(img_wp),
	.IMG_DATA_WR(img_data_wr),
	.IMG_DATA_ADDR(img_data_addr),
	.IMG_DATA(img_data),
	.IMG_RESULT_WR(img_result_wr),
	.IMG_RESULT(img_result),
	.IMG_SUM(img_sum),
	.IMG_Q_WR(img_q_wr),
	.IMG_Q_DI(img_q_di),
	.IMG_Q_ACK(img_q_ack),
	.ESP_UART_RX_DATA(8'h00),
	.ESP_UART_RX_WR(1'b0),
	.FLASHBOOT_START(1'b0),
	.FLASHBOOT_COREID(5'd0)
);

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches

wire [9*8-1:0] sw;
kg_soft_switches #(.N(9)) soft_switches (
	.clk(clk_2x),
	.command(softsw_command),
	.regs(sw),
	.upd()
);
wire sw_mem_4m = sw[5*8];     // Memory: 0 1 MB, 1 4 MB
wire sw_fastboot = sw[6*8];   // Fastboot: 0 off, 1 on
wire sw_reset = sw[7*8];
wire [2:0] sw_model = sw[8*8 +: 3];   // Model: 0 Plus, 1 SE, 2 512Ke, 3 512K, 4 128K

// the model: the SE has its own ROM (256 KB) and ADB; the 512K and 128K the 64K ROM; the 512Ke is a
// Plus ROM with 512 KB; the Memory item sizes the Plus and the SE
wire model_se = sw_model == 3'd1;
wire model_64k = sw_model == 3'd3 || sw_model == 3'd4;
wire [1:0] cfg_rom_size = model_se ? 2'd2 : model_64k ? 2'd0 : 2'd1;
wire [1:0] cfg_ram_size = sw_model == 3'd4 ? 2'b00 : (sw_model == 3'd2 || sw_model == 3'd3) ? 2'b01 :
	sw_mem_4m ? 2'b11 : 2'b10;

// ------------------------------------------------------------------ ROM in the SRAM

// the ROM files of the FL items, each in its part of the SRAM (mac_rom_map); the model picks one (the
// machine is reset when it changes)
wire rom_file_wr;
wire [21:0] rom_file_addr;
wire [20:0] rom_raddr;
wire rom_oe_n;
wire [17:0] mac_rom_addr;
wire [15:0] mac_rom_data;

mac_rom_map rom_map (
	.rom_size(cfg_rom_size),
	.rom_addr(mac_rom_addr),
	.raddr(rom_raddr),
	.file_slot(file_slot),
	.file_addr(file_addr),
	.file_wr(file_wr),
	.we(rom_file_wr),
	.waddr(rom_file_addr)
);

mac_sram sram (
	.clk(clk_2x),
	.raddr(rom_raddr),
	.rdata(mac_rom_data),
	.we(rom_file_wr),
	.waddr(rom_file_addr),
	.wdata(file_data),
	.MA(MA),
	.MD(MD),
	.MWR_N(MWR_N),
	.MRD_N(MRD_N)
);

// ------------------------------------------------------------------ reset

// the SDRAM gets 200 us after the PLL locks before its initialisation
reg [12:0] sdr_wait = 13'd0;
always @(posedge clk_2x)
	if (areset)
		sdr_wait <= 13'd0;
	else if (sdr_wait != 13'h1FFF)
		sdr_wait <= sdr_wait + 13'd1;
wire sdr_reset_n = sdr_wait == 13'h1FFF;
wire ram_ready;

// a change of the memory size or of the model is a reset (the ROM sizes the RAM at its start)
reg [3:0] mem_d = 4'd0;
reg [7:0] mem_rst = 8'hFF;
always @(posedge clk_2x) begin
	mem_d <= { sw_model, sw_mem_4m };
	if ({ sw_model, sw_mem_4m } != mem_d || areset)
		mem_rst <= 8'hFF;
	else if (mem_rst != 8'd0)
		mem_rst <= mem_rst - 8'd1;
end

wire rom_loading = file_active && (file_slot == 8'd7 || file_slot == 8'd6 || file_slot == 8'd5);
wire clock_loaded;   // mac_clock (clk_2x; it only rises, once)
reg mac_reset = 1'b1;
always @(posedge clk_sys)
	mac_reset <= areset || !ram_ready || mem_rst != 8'd0 || sw_reset || mcu_busy || rom_loading || !clock_loaded;

// ------------------------------------------------------------------ disks

wire [7:0] sdc_img_mounted;
wire [63:0] sdc_img_size;
wire [31:0] mac_lba;
wire [3:0] mac_rd, mac_wr;
wire [7:0] mac_sdc_out;
wire sdc_busy, sdc_done, sdc_error, sdc_byte_in_strobe;
wire [8:0] sdc_byte_addr;
wire [7:0] sdc_byte_in_data;

// OUT_LATENCY 4: the buffers of the machine answer an address within two clocks of clk_sys
img_sdc #(.OUT_LATENCY(4)) img_sdc (
	.clk(clk_2x),
	.reset(areset),

	.img_mounted(img_mounted),
	.img_size(img_size),
	.img_data_wr(img_data_wr),
	.img_data_addr(img_data_addr),
	.img_data(img_data),
	.img_result_wr(img_result_wr),
	.img_result(img_result),
	.img_sum(img_sum),
	.img_q_wr(img_q_wr),
	.img_q_di(img_q_di),
	.img_q_ack(img_q_ack),

	.sdc_img_mounted(sdc_img_mounted),
	.sdc_img_size(sdc_img_size),
	.sdc_rd({ 4'd0, mac_rd }),
	.sdc_wr({ 4'd0, mac_wr }),
	.sdc_sector(mac_lba),
	.sdc_busy(sdc_busy),
	.sdc_done(sdc_done),
	.sdc_error(sdc_error),
	.sdc_slot(),
	.sdc_byte_in_strobe(sdc_byte_in_strobe),
	.sdc_byte_addr(sdc_byte_addr),
	.sdc_byte_in_data(sdc_byte_in_data),
	.sdc_byte_out_data(mac_sdc_out),

	.active()
);

wire [3:0] m_mounted;
wire m_busy, m_data_en;
wire [8:0] m_addr;
wire [7:0] m_data_in;
mac_sdc sdc (
	.clk(clk_2x),
	.sys_t(sys_t),
	.sdc_mounted(sdc_img_mounted),
	.sdc_busy(sdc_busy),
	.sdc_strobe(sdc_byte_in_strobe),
	.sdc_addr(sdc_byte_addr),
	.sdc_data(sdc_byte_in_data),
	.m_mounted(m_mounted),
	.m_busy(m_busy),
	.m_data_en(m_data_en),
	.m_addr(m_addr),
	.m_data_in(m_data_in)
);

// ------------------------------------------------------------------ clock, PRAM

wire [46:0] mac_rtc_in, mac_rtc_out;
mac_clock clock (
	.clk(clk_2x),
	.sys_t(sys_t),
	.mcu_busy(mcu_busy),
	.rtc_a(rtc_a),
	.rtc_di(rtc_di),
	.rtc_do(rtc_do),
	.rtc_cs(rtc_cs),
	.rtc_wr_n(rtc_wr_n),
	.rtc_in(mac_rtc_in),
	.rtc_out(mac_rtc_out),
	.loaded(clock_loaded)   // the Mac reads its clock at the start: held in reset until it is set
);

// ------------------------------------------------------------------ keyboard, mouse

wire kbd_strobe;
wire [9:0] kbd_data;
wire [4:0] mouse;
mac_hid hid (
	.clk(clk_sys),
	.reset(areset),
	.kb_status(kb_status),
	.kb_dat0(kb_dat0),
	.kb_dat1(kb_dat1),
	.kb_dat2(kb_dat2),
	.kb_dat3(kb_dat3),
	.kb_dat4(kb_dat4),
	.kb_dat5(kb_dat5),
	.ms_x(ms_x),
	.ms_y(ms_y),
	.ms_b(ms_b),
	.ms_upd(ms_upd),
	.kbd_strobe(kbd_strobe),
	.kbd_data(kbd_data),
	.mouse(mouse)
);

// ------------------------------------------------------------------ the machine

wire pix, mac_hs, mac_vs, vid_load;
wire [11:0] mac_audio;
wire [2:0] phase;
wire [20:0] ram_addr;
wire [15:0] ram_din, ram_dout;
wire [1:0] ram_ds;
wire ram_we, ram_oe;

macplus mac (
	.CLKIN(clk_sys),
	.RESET(mac_reset),
	.pixelOut(pix),
	.vidLoad(vid_load),
	.vsync(mac_vs),
	.hsync(mac_hs),
	.audio(mac_audio),
	.leds(),
	.ADC_BUS(),
	.MOUSE({ 1'b1, mouse }),
	.kbd_strobe(kbd_strobe),
	.kbd_data(kbd_data),
	.configROMSize(cfg_rom_size),
	.configFastboot(sw_fastboot),
	.configRAMSize(cfg_ram_size),
	.configMachineType(model_se),
	.configFloppyWProt(img_wp[1:0]),
	.configSCSIWProt(img_wp[3:2]),
	.rtc_in(mac_rtc_in),
	.rtc_out(mac_rtc_out),
	.sdc_image_size(sdc_img_size[31:0]),
	.sdc_image_mounted(m_mounted),
	.sdc_lba(mac_lba),
	.sdc_rd(mac_rd),
	.sdc_wr(mac_wr),
	.sdc_done(1'b0),
	.sdc_busy(m_busy),
	.sdc_data_out(mac_sdc_out),
	.sdc_data_in(m_data_in),
	.sdc_data_en(m_data_en),
	.sdc_addr(m_addr),
	.UART_TXD(),
	.UART_RXD(1'b1),
	.UART_RTS(),
	.UART_CTS(1'b1),
	._romOE(rom_oe_n),
	.romAddr(mac_rom_addr),
	.romData(mac_rom_data),
	.busPhase(phase),
	.ram_addr(ram_addr),
	.sdram_din(ram_din),
	.sdram_ds(ram_ds),
	.sdram_we(ram_we),
	.sdram_oe(ram_oe),
	.sdram_do(ram_dout)
);

// ------------------------------------------------------------------ RAM in the SDRAM

// the SDRAM /CS is hard wired on Go: sdr_cs_n is not used
wire sdr_cs_n;
mac_sdram sdram (
	.clk(clk_2x),
	.reset_n(sdr_reset_n),
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
	.SDR_RAS_N(SDR_RAS_N),
	.SDR_CAS_N(SDR_CAS_N),
	.SDR_WE_N(SDR_WE_N)
);
assign FLASH_CS_N = 1'b1;   // the flash chip; the SDRAM /CS is hard wired on Go
ODDR2 oddr_sdr_clk (.Q(SDR_CLK), .C0(clk_2x), .C1(~clk_2x), .CE(1'b1), .D0(1'b0), .D1(1'b1), .R(1'b0), .S(1'b0));

// ------------------------------------------------------------------ video

wire blank_65;
kg_sync #(.W(1), .STAGES(3)) sync_blank (.clk(clk_65), .d(mac_reset), .q(blank_65));

wire [23:0] vid_rgb;
wire vid_hs, vid_vs, vid_de;
mac_video video (
	.clk_sys(clk_sys),
	.vid_load(vid_load),
	.phase(phase),
	.vid_word(ram_dout),
	.vsync_n(mac_vs),
	.clk_65(clk_65),
	.blank(blank_65),
	.rgb(vid_rgb),
	.hs(vid_hs),
	.vs(vid_vs),
	.de(vid_de)
);

// osd_command into clk_65: taken when two samples agree (it holds for many clocks)
reg [15:0] osd_s1 = 16'd0, osd_s2 = 16'd0, osd_cmd = 16'd0;
always @(posedge clk_65) begin
	osd_s1 <= osd_command;
	osd_s2 <= osd_s1;
	if (osd_s1 == osd_s2)
		osd_cmd <= osd_s2;
end

// as core-bk: 1024 x 768, the counters start at the leading edge of the syncs
wire [23:0] osd_rgb;
kg_osd_overlay #(.H_OFFSET(276), .V_OFFSET(105), .H_DIV4_WIDTH(1400), .V_DIV4_HEIGHT(900)) osd (
	.clk(clk_65),
	.rgb_i(vid_rgb),
	.rgb_o(osd_rgb),
	.hsync_i(vid_hs),
	.vsync_i(vid_vs),
	.v_offset(11'd0),
	.h_offset(11'd0),
	.osd_command(osd_cmd)
);

// ------------------------------------------------------------------ audio

// the 8-bit sound of the Mac with its volume and filter: 12 bits, signed. Without sound the machine
// holds its output at +127 (dataController: "when disabled, drive output high"), a large DC level
// that steps at every reset: a DC blocker takes it out (the average as a leaky integrator, 2^18
// clocks of clk_2x: a high pass at 19 Hz), the difference saturated to 16 bits.
wire signed [15:0] aud_in = { mac_audio, 4'd0 };
reg signed [33:0] dc_acc = 34'sd0;
wire signed [15:0] dc = dc_acc[33:18];
wire signed [16:0] aud_d = { aud_in[15], aud_in } - { dc[15], dc };
wire [15:0] aud = (aud_d[16] != aud_d[15]) ? { aud_d[16], { 15{ !aud_d[16] } } } : aud_d[15:0];
always @(posedge clk_2x)
	dc_acc <= dc_acc + { { 18{ aud_in[15] } }, aud_in } - { { 18{ dc[15] } }, dc };

kg_pcm5102 #(.DIV_BITS(2)) dac (  // bck 3.87 MHz, 121 kHz
	.clk(clk_2x),
	.reset(areset),
	.left(aud),
	.right(aud),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_LRCK)
);

// ------------------------------------------------------------------ VGA

// osd_rgb is one clock behind the syncs of the overlay's input: the syncs go with it
reg vga_hs = 1'b1, vga_vs = 1'b1;
always @(posedge clk_65) begin
	vga_hs <= ~vid_hs;   // 1024 x 768 at 60 Hz: negative syncs (VESA)
	vga_vs <= ~vid_vs;
end
assign VGA_R = osd_rgb[23:16];
assign VGA_G = osd_rgb[15:8];
assign VGA_B = osd_rgb[7:0];
assign VGA_HS = vga_hs;
assign VGA_VS = vga_vs;

endmodule
