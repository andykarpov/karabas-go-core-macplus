`timescale 1ns / 1ps
`default_nettype wire

/*
 Apple Macintosh Plus core for Karabas Mini rev.G (HDMI, PCM5102): the machine of NanoMac (macplus,
 through sv2v in rtl/sv2v) with the board glue of karabas-go-modules.

 Clocks: one PLL, VCO 650 MHz (50 * 13):
   clk_sys 15.476 MHz (/42): the machine (busPhase 0..7 per 8 clocks, the 68000 at 7.74 MHz; the
           Mac has 15.667 MHz, NanoMac on the Tang 15.6), the keyboard and mouse
   clk_2x  30.952 MHz (/21, twice clk_sys, rising edges together): the SDRAM, the SRAM, the MCU
           link, the file mounter, audio
   clk_65  65.0 MHz (/10): the video output (1024 x 768 at 60 Hz), the OSD, HDMI
   clk_ser 325 MHz (/2, 0 and 180 degrees): the HDMI serialiser; clk_8 8.125 MHz (/80): FT_CLK_OUT
 clk_sys and clk_2x are one clock domain for the timing (registers of either feed the other, the
 analysis takes the 32 ns between their edges); clk_65 is crossed with synchronisers, the frame
 buffer is a block RAM with two clocks.

 Memory: the RAM of the Mac (128 KB .. 4 MB) in the SDRAM (mac_sdram, one access per bus cycle), the
 ROMs (128 KB Plus, 256 KB SE, 64 KB 128K / 512K) in the SRAM (mac_sram), loaded by their FL items
 while the machine is held in reset.

 Video: the words the machine loads into its shifter go into a frame buffer (mac_video), out as
 1024 x 768, every pixel 2 x 2.

 Disks: the F items Floppy 1, Floppy 2 (sdc slots 0, 1: the internal and external drive) and SCSI
 6, SCSI 5 (slots 2, 3) through the file mounter of kg_mcu2 (link v2) and mac_sdc (its bytes into
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

module karabas_minig_top (
	input wire CLK_50MHZ,

	inout wire UART_RX,
	inout wire UART_TX,
	inout wire UART_CTS,

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

	input wire [7:0] VGA_R,
	input wire [7:0] VGA_G,
	input wire [7:0] VGA_B,
	input wire VGA_HS,
	input wire VGA_VS,

	output wire [3:0] TMDS_P,
	output wire [3:0] TMDS_N,

	output wire FT_SPI_CS_N,
	output wire FT_SPI_SCK,
	input wire FT_SPI_MISO,
	output wire FT_SPI_MOSI,
	input wire FT_INT_N,
	input wire FT_CLK,
	input wire FT_DE,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire DAC_BCK,
	output wire DAC_WS,
	output wire DAC_DAT,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [5:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire ESP32_SPI_CS_N,
	input wire ESP32_PCM_BCK,
	input wire ESP32_PCM_RLCK,
	input wire ESP32_PCM_DAT,

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
assign ESP32_SPI_CS_N = 1'b1;
assign UART_RX = 1'bz;
assign UART_TX = 1'bz;
assign UART_CTS = 1'bz;
assign MIDI_TX = 1'b1;

assign ADC_CLK = 1'b0;
assign ADC_BCK = 1'bz;
assign ADC_LRCK = 1'bz;

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

// the clock of the FT812: it must always have one (karabas-go-notes ft-clk-out-required)
ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));

// a register of clk_sys that toggles every clock: the clk_2x side finds the clk_sys edges by it
reg sys_t = 1'b0;
always @(posedge clk_sys) sys_t <= !sys_t;

// ------------------------------------------------------------------ MCU

// MCU_SCK on a global buffer (as tsconf and the menu: on local routing the flip-flops of the SPI
// receiver had several ns of clock skew); the FT812 and SD2 get the IBUFG output (a BUFG drives no pad)
wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));

// MCU link v2 (karabas-go-firmware docs/link_v2.md, kg_mcu2): INT on IO1
wire mcu_int;
assign MCU_IO[1] = mcu_int;
assign MCU_IO[0] = 1'bz;
assign MCU_IO[5:2] = 4'bzzzz;

wire [7:0] kb_status, kb_dat0, kb_dat1, kb_dat2, kb_dat3, kb_dat4, kb_dat5;
wire [15:0] joy_l16, joy_r16;
wire [7:0] ms_x, ms_y, ms_b8;
wire [2:0] ms_b = ms_b8[2:0];
wire ms_wr;
wire [1:0] ld_kind;
wire [7:0] ld_slot, ld_data;
wire [31:0] ld_addr;
wire ld_active, ld_wr;
wire mcu_busy;
wire dvi_only;
wire ft_cs_n, ft_mosi, ft_spi_on, sd2_cs_n, sd2_mosi;
wire [7:0] img_wp;
wire [7:0] rtc_a, rtc_di, rtc_do;
wire rtc_cs, rtc_wr_n;
wire [9*8-1:0] sw;
wire osd_wr, osd_en, osd_zoom;
wire [11:0] osd_waddr;
wire [7:0] osd_wdata;
wire [23:0] osd_fg, osd_bg;
wire [1:0] osd_alpha, osd_place;
wire [4:0] osd_px, osd_ph;
wire [3:0] osd_py;
wire [5:0] osd_pw;

// the disks (declared here, used below)
wire [7:0] sdc_img_mounted;
wire [63:0] sdc_img_size;
wire [31:0] mac_lba;
wire [3:0] mac_rd, mac_wr;
wire [7:0] mac_sdc_out;
wire sdc_busy, sdc_done, sdc_error, sdc_byte_in_strobe;
wire [8:0] sdc_byte_addr;
wire [7:0] sdc_byte_in_data;

kg_mcu2 #(
	.CAPS(16'h0004),     // write protected images (the RTC, the IMG bits come from ENABLE_*)
	.SW_N(9),
	.CS_FILTER(3),
	.ENABLE_OSD(1),
	.ENABLE_IMG(1),      // the floppies and the SCSI disks (slots 0..3)
	.IMG_OUT_LATENCY(4), // the buffers of the machine answer an address within two clocks of clk_sys
	.ENABLE_RTC(1),      // the clock and the PRAM of the Mac (mac_clock; rtc_mode 0, /config/macplus.eep)
	.ENABLE_FT(1),
	.ENABLE_SD2(1)
) mcu (
	.CLK(clk_2x), .N_RESET(~areset),
	.MCU_SCK(mcu_sck), .MCU_MOSI(MCU_MOSI), .MCU_MISO(MCU_MISO), .MCU_SS(MCU_CS_N), .MCU_INT(mcu_int),
	.MCU_SPI_FT_SS(MCU_IO[3]), .MCU_SPI_SD2_SS(MCU_IO[2]),

	.SW(sw), .SW_WR(), .SW_INDEX(), .SW_VALUE(), .HW_ID(), .DVI_ONLY(dvi_only), .CORE_BUILD(), .FW_BUILD(),
	.BUSY(mcu_busy), .BTNS(), .RELOAD_REQ(1'b0), .RELOAD_CORE(8'd0),

	.KBD({ kb_dat5, kb_dat4, kb_dat3, kb_dat2, kb_dat1, kb_dat0, kb_status }), .KBD_WR(),
	.PS2_CODE(), .PS2_KIND(), .PS2_WR(),
	.MS_X(ms_x), .MS_Y(ms_y), .MS_Z(), .MS_B(ms_b8), .MS_WR(ms_wr),
	.JOY_L(joy_l16), .JOY_R(joy_r16), .JOY_WR(), .PS2_CMD(16'h0000), .PS2_CMD_WR(1'b0),

	.LD_KIND(ld_kind), .LD_SLOT(ld_slot), .LD_SIZE(), .LD_START(), .LD_ACTIVE(ld_active), .LD_END(),
	.LD_ADDR(ld_addr), .LD_DATA(ld_data), .LD_WR(ld_wr), .LD_READY(1'b1),

	.OSD_WR(osd_wr), .OSD_WADDR(osd_waddr), .OSD_WDATA(osd_wdata), .OSD_EN(osd_en),
	.OSD_FG(osd_fg), .OSD_BG(osd_bg), .OSD_ALPHA(osd_alpha), .OSD_PX(osd_px), .OSD_PY(osd_py),
	.OSD_PW(osd_pw), .OSD_PH(osd_ph), .OSD_PLACE(osd_place), .OSD_ZOOM(osd_zoom),

	.SDC_IMG_MOUNTED(sdc_img_mounted), .SDC_IMG_SIZE(sdc_img_size),
	.SDC_RD({ 4'd0, mac_rd }), .SDC_WR({ 4'd0, mac_wr }), .SDC_SECTOR(mac_lba),
	.SDC_BUSY(sdc_busy), .SDC_DONE(sdc_done), .SDC_ERROR(sdc_error), .SDC_SLOT(),
	.SDC_BYTE_IN_STROBE(sdc_byte_in_strobe), .SDC_BYTE_ADDR(sdc_byte_addr),
	.SDC_BYTE_IN_DATA(sdc_byte_in_data), .SDC_BYTE_OUT_DATA(mac_sdc_out),
	.IMG_WP(img_wp), .IMG_PHYS_WR(), .IMG_PHYS(), .IMG_FLUSH(), .FDD_CHNG_WR(), .FDD_CHNG(),
	.FDD_CHNG_REQ(1'b0), .FDD_CHNG_DS(2'd0), .IMG_ACTIVE(),

	.PORT_OUT_DATA(), .PORT_OUT_WR(), .PORT_OUT_READY(4'd0), .PORT_IN_DATA(32'd0), .PORT_IN_WR(4'd0),
	.PORT_IN_FULL(), .PORT_CFG(128'd0), .PORT_STAT(), .PORT_STAT_WR(),

	.RTC_A(rtc_a), .RTC_DI(rtc_di), .RTC_DO(rtc_do), .RTC_CS(rtc_cs), .RTC_WR_N(rtc_wr_n),
	.MATRIX_CMD(24'd0), .MATRIX_CMD_WR(1'b0), .DEBUG_ADDR(16'd0), .DEBUG_DATA(16'd0),

	.FT_SPI_ON(ft_spi_on), .FT_VGA_ON(), .FT_RESET(), .FT_SCK(), .FT_MOSI(ft_mosi), .FT_MISO(FT_SPI_MISO),
	.FT_CS_N(ft_cs_n),
	.SD2_SCK(), .SD2_MOSI(sd2_mosi), .SD2_MISO(SD_DO), .SD2_CS_N(sd2_cs_n)
);

// the mouse of mac_hid takes a toggle per report
reg ms_upd = 1'b0;
always @(posedge clk_2x)
	if (ms_wr)
		ms_upd <= ~ms_upd;

// the ROM files of the FL items (LD kind 2)
wire file_active = ld_active && ld_kind == 2'd2;
wire file_wr = ld_wr && ld_kind == 2'd2;
wire [7:0] file_slot = ld_slot, file_data = ld_data;
wire [31:0] file_addr = ld_addr;

assign FT_SPI_CS_N = ft_spi_on ? ft_cs_n : 1'b1;
assign FT_SPI_SCK = ft_spi_on ? mcu_sck_ibufg : 1'b1;
assign FT_SPI_MOSI = ft_spi_on ? ft_mosi : 1'b1;
assign SD_CS_N = sd2_cs_n;
assign SD_DI = sd2_mosi;
assign SD_CLK = mcu_sck_ibufg;

// ------------------------------------------------------------------ soft switches

// the switches: the SW registers of kg_mcu2 (switch n = sw[n*8 +: 8])
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

// the file mounter of kg_mcu2 (kg_l2_img: the sd card interface of img_sdc), the nets above

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

// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board)
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
assign FLASH_CS_N = sdr_cs_n;
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

// the bitmap OSD of link v2 over the picture (1024 x 768: scale 3); its syncs and de go to HDMI
wire [23:0] osd_rgb;
wire osd_hs, osd_vs, osd_de;
kg_l2_osd_overlay osd (
	.wclk(clk_2x), .osd_wr(osd_wr), .osd_waddr(osd_waddr), .osd_wdata(osd_wdata), .osd_en(osd_en),
	.osd_fg(osd_fg), .osd_bg(osd_bg), .osd_alpha(osd_alpha), .osd_px(osd_px), .osd_py(osd_py),
	.osd_pw(osd_pw), .osd_ph(osd_ph), .osd_place(osd_place), .osd_zoom(osd_zoom),
	.clk(clk_65), .rgb_i(vid_rgb), .hs_i(vid_hs), .vs_i(vid_vs), .de_i(vid_de),
	.rgb_o(osd_rgb), .hs_o(osd_hs), .vs_o(osd_vs), .de_o(osd_de)
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
	.lrck(DAC_WS)
);

// into clk_65 for HDMI: taken when two samples agree (it changes once per line of the Mac)
reg [15:0] aud_s1 = 16'd0, aud_s2 = 16'd0, aud_65 = 16'd0;
always @(posedge clk_65) begin
	aud_s1 <= aud;
	aud_s2 <= aud_s1;
	if (aud_s1 == aud_s2)
		aud_65 <= aud_s2;
end

// the audio sample clock of hdmi_tx: 48 kHz of clk_65 (+ 48 per clock modulo 65000)
reg [16:0] aud_acc = 17'd0;
reg aud_stb = 1'b0;
reg [23:0] hdmi_smp = 24'd0;
always @(posedge clk_65) begin
	aud_stb <= 1'b0;
	if (aud_acc >= 17'd65000 - 17'd48) begin
		aud_acc <= aud_acc + 17'd48 - 17'd65000;
		aud_stb <= 1'b1;
		hdmi_smp <= { aud_65, 8'd0 };
	end
	else
		aud_acc <= aud_acc + 17'd48;
end

// ------------------------------------------------------------------ HDMI

wire dvi_only_65;
kg_sync #(.W(1), .STAGES(3)) sync_dvi (.clk(clk_65), .d(dvi_only), .q(dvi_only_65));

// the syncs and de of the overlay come with osd_rgb; 1024 x 768 at 60 Hz: negative syncs (VESA)
wire hdmi_hs = ~osd_hs, hdmi_vs = ~osd_vs, hdmi_de = osd_de;

hdmi_tx #(.SAMPLE_FREQ(48000)) hdmi (
	.clk(clk_65),
	.sclk(clk_ser),
	.sclk_n(clk_ser_n),
	.reset(areset),
	.rgb(osd_rgb),
	.vsync(hdmi_vs),
	.hsync(hdmi_hs),
	.de(hdmi_de),
	.audio_en(~dvi_only_65),
	.audio_l(hdmi_smp),
	.audio_r(hdmi_smp),
	.audio_clk(aud_stb),
	.tx_clk_n(TMDS_N[3]),
	.tx_clk_p(TMDS_P[3]),
	.tx_d_n(TMDS_N[2:0]),
	.tx_d_p(TMDS_P[2:0])
);

endmodule
