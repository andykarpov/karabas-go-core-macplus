#!/usr/bin/env python3
"""Makes rtl/karabas_mini_top.v and rtl/karabas_go_top.v from rtl/karabas_minig_top.v.

The three tops share everything but the board: change the Mini G top, then run this (every
replacement must match once, else it stops). The ports of Mini and Go are those of core-atarist.

Mini (before rev.G): MCU_SCK not on a clock pin (no BUFG, bursts at the link clock), 4 MCU_IO,
  sigma-delta audio on AUDIO_L / AUDIO_R instead of the PCM5102, FT_RESET, the ESP pins.
Go: VGA 8:8:8 with V_CLK (clk_65) instead of HDMI, the FT812 off the video bus (FT_OE_N = 1), the MCU
  link on MCU_SPI_*, DAC_LRCK / DAC_MUTE, the floppy connector unused (its outputs 0), the SDRAM
  /CS hard wired (FLASH_CS_N = 1: the flash chip).
Both: the SAM2695 synth held in reset (MIDI_RESET_N = 0, no MIDI_CLK): the Mac has no use for it.
"""
import os
import re
import sys

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "rtl")


def sub(s, old, new, what):
    if s.count(old) != 1:
        sys.exit("mktops.py: %s: %d matches of %r" % (what, s.count(old), old[:70]))
    return s.replace(old, new)


def ports(s, body, what):
    a = s.index("module karabas_minig_top (")
    b = s.index("\n);\n", a) + 4
    return s[:a] + body + s[b:]


COMMON_PORTS_HEAD = """	input wire CLK_50MHZ,

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
"""

FLASH_PORTS = """	output wire FLASH_CS_N,
	input wire FLASH_DO,
	output wire FLASH_DI,
	output wire FLASH_SCK,
	output wire FLASH_WP_N,
	output wire FLASH_HOLD_N
);
"""

MINI_PORTS = "module karabas_mini_top (\n" + COMMON_PORTS_HEAD + """
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
	input wire FT_AUDIO,
	input wire FT_DISP,
	output wire FT_RESET,
	output wire FT_CLK_OUT,

	output wire [2:0] WA,
	output wire [1:0] WCS_N,
	output wire WRD_N,
	output wire WWR_N,
	output wire WRESET_N,
	inout wire [15:0] WD,

	output wire TAPE_OUT,
	input wire TAPE_IN,

	output wire AUDIO_L,
	output wire AUDIO_R,

	output wire ADC_CLK,
	inout wire ADC_BCK,
	inout wire ADC_LRCK,
	input wire ADC_DOUT,

	input wire MCU_CS_N,
	input wire MCU_SCK,
	inout wire MCU_MOSI,
	output wire MCU_MISO,
	inout wire [3:0] MCU_IO, // [0] burst cs_n, [1] burst ready, [2] sd2 cs_n, [3] ft cs_n

	output wire MIDI_TX,

	output wire MIDI_CLK,
	output wire MIDI_RESET_N,

""" + FLASH_PORTS

GO_PORTS = "module karabas_go_top (\n" + COMMON_PORTS_HEAD + """
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

""" + FLASH_PORTS

MCU_SCK_G = """// MCU_SCK on a global buffer (as tsconf and the menu: on local routing the flip-flops of the SPI
// receiver had several ns of clock skew); the FT812 and SD2 get the IBUFG output (a BUFG drives no pad)
wire mcu_sck_ibufg, mcu_sck;
IBUFG ibufg_mcu_sck (.I(MCU_SCK), .O(mcu_sck_ibufg));
BUFG bufg_mcu_sck (.I(mcu_sck_ibufg), .O(mcu_sck));
"""
MCU_SCK_OLD = """// MCU_SCK is not on a clock pin before rev.G (CLOCK_DEDICATED_ROUTE = FALSE in the ucf)
wire mcu_sck = MCU_SCK, mcu_sck_ibufg = MCU_SCK;
"""

UNUSED_SYNTH = """assign ESP_RESET_N = 1'bz;
assign ESP_BOOT_N = 1'bz;
assign MIDI_CLK = 1'b0;      // the SAM2695 synth: held in reset, the Mac has no use for it
assign MIDI_RESET_N = 1'b0;
"""

PCM = """kg_pcm5102 #(.DIV_BITS(2)) dac (  // bck 3.87 MHz, 121 kHz
	.clk(clk_2x),
	.reset(areset),
	.left(aud),
	.right(aud),
	.din(DAC_DAT),
	.bck(DAC_BCK),
	.lrck(DAC_WS)
);
"""


def common(s):
    s = sub(s, "assign ESP32_SPI_CS_N = 1'b1;\n", "", "ESP32_SPI_CS_N")
    s = sub(s, "assign MIDI_TX = 1'b1;\n", "assign MIDI_TX = 1'b1;\n" + UNUSED_SYNTH, "unused")
    s = sub(s, MCU_SCK_G, MCU_SCK_OLD, "MCU_SCK")
    s = sub(s, "	.BURST_MAX_MHZ(32),  // Rev.G has MCU_SCK on a global clock pin\n",
            "	.BURST_MAX_MHZ(0),   // MCU_SCK is not on a clock pin: bursts at the link clock\n", "burst")
    return s


def mini(s):
    s = sub(s, " Apple Macintosh Plus core for Karabas Mini rev.G (HDMI, PCM5102): the machine of NanoMac (macplus,\n"
               " through sv2v in rtl/sv2v) with the board glue of karabas-go-modules.\n",
            " Apple Macintosh Plus core for Karabas Mini before rev.G (HDMI, sigma-delta audio). Made by\n"
            " tools/mktops.py from karabas_minig_top.v (do not edit: change that one and run it): the same\n"
            " except the pins, the MCU link (MCU_SCK not on a clock pin) and the audio (AUDIO_L / AUDIO_R).\n"
            " The machine of NanoMac (macplus, through sv2v in rtl/sv2v) with the board glue of\n"
            " karabas-go-modules.\n", "header")
    s = ports(s, MINI_PORTS, "ports")
    s = common(s)
    s = sub(s, "assign MIDI_RESET_N = 1'b0;\n", "assign MIDI_RESET_N = 1'b0;\nassign FT_RESET = 1'b1;\n", "FT_RESET")
    s = sub(s, "assign MCU_IO[5:2] = 4'bzzzz;\n", "assign MCU_IO[3:2] = 2'bzz;\n", "MCU_IO")
    s = sub(s, PCM, "// no I2S DAC on this board: sigma-delta outputs into an RC filter, offset binary input\n"
               "kg_sigma_delta_dac dac_l (.clk(clk_2x), .reset(areset), .din({ ~aud[15], aud[14:0] }), .dout(AUDIO_L));\n"
               "kg_sigma_delta_dac dac_r (.clk(clk_2x), .reset(areset), .din({ ~aud[15], aud[14:0] }), .dout(AUDIO_R));\n",
            "audio")
    return s


def go(s):
    s = sub(s, " Apple Macintosh Plus core for Karabas Mini rev.G (HDMI, PCM5102): the machine of NanoMac (macplus,\n"
               " through sv2v in rtl/sv2v) with the board glue of karabas-go-modules.\n",
            " Apple Macintosh Plus core for Karabas Go (VGA, PCM5102). Made by tools/mktops.py from\n"
            " karabas_minig_top.v (do not edit: change that one and run it): the same except the pins, the MCU\n"
            " link (MCU_SCK not on a clock pin) and the video: 24 bit RGB to the VGA DAC with its pixel clock on\n"
            " V_CLK (clk_65), the FT812 off that bus (FT_OE_N = 1). The floppy connector is not used (its\n"
            " outputs 0). The machine of NanoMac (macplus, through sv2v in rtl/sv2v) with the board glue of\n"
            " karabas-go-modules.\n", "header")
    s = ports(s, GO_PORTS, "ports")
    s = common(s)
    s = sub(s, "assign ADC_CLK = 1'b0;\nassign ADC_BCK = 1'bz;\nassign ADC_LRCK = 1'bz;\n",
            "assign FT_OE_N = 1'b1;     // the FT812 does not drive the video DAC\n"
            "assign BEEPER = 1'b0;\n"
            "assign DAC_MUTE = 1'b1;    // soft mute of the PCM5102: 1 = sound on\n\n"
            "// the floppy connector is not used: its outputs 0 (the board inverts them: high = active)\n"
            "assign FDC_DRIVE = 2'b00;\nassign FDC_MOTOR = 1'b0;\nassign FDC_DIR = 1'b0;\nassign FDC_STEP = 1'b0;\n"
            "assign FDC_WDATA = 1'b0;\nassign FDC_WGATE = 1'b0;\nassign FDC_SIDE_N = 1'b0;\n", "unused Go")
    s = sub(s, "// the clock of the FT812: it must always have one (karabas-go-notes ft-clk-out-required)\n"
               "ODDR2 oddr_ft_clk (.Q(FT_CLK_OUT), .C0(clk_8), .C1(~clk_8), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
            "// the pixel clock of the VGA DAC\n"
            "ODDR2 oddr_v_clk (.Q(V_CLK), .C0(clk_65), .C1(~clk_65), .CE(1'b1), .D0(1'b1), .D1(1'b0), .R(1'b0), .S(1'b0));\n",
            "V_CLK")
    s = sub(s, "assign MCU_IO[1] = mcu_burst_ready;\nassign MCU_IO[0] = 1'bz;\nassign MCU_IO[5:2] = 4'bzzzz;\n",
            "assign MCU_SPI_IO[0] = mcu_burst_ready;\nassign MCU_SPI_IO[1] = 1'bz;\n", "MCU_IO")
    s = sub(s, "	.MCU_SPI_FT_SS(MCU_IO[3]),\n	.MCU_SPI_SD2_SS(MCU_IO[2]),\n	.MCU_BURST_CS_N(MCU_IO[0]),\n",
            "	.MCU_SPI_FT_SS(MCU_SPI_FT_CS_N),\n	.MCU_SPI_SD2_SS(MCU_SPI_SD2_CS_N),\n	.MCU_BURST_CS_N(MCU_SPI_IO[1]),\n",
            "MCU SS")
    s = sub(s, "	.lrck(DAC_WS)\n", "	.lrck(DAC_LRCK)\n", "DAC_LRCK")
    s = sub(s, "   clk_65  65.0 MHz (/10): the video output (1024 x 768 at 60 Hz), the OSD, HDMI\n",
            "   clk_65  65.0 MHz (/10): the video output (1024 x 768 at 60 Hz, VGA), the OSD\n", "clk_65")
    s = sub(s, "   clk_ser 325 MHz (/2, 0 and 180 degrees): the HDMI serialiser; clk_8 8.125 MHz (/80): FT_CLK_OUT\n",
            "   (outputs 1..3, the HDMI serialiser and FT_CLK_OUT of Mini / Mini G, are not used here)\n", "clk_ser")
    s = sub(s, "// FLASH_CS_N (T3) is the SDRAM /CS of Mini G2 (rev G: tied low on the board)\n",
            "// the SDRAM /CS is hard wired on Go: sdr_cs_n is not used\n", "sdr_cs_n")
    s = re.sub(r"assign FLASH_CS_N = [^;]*;", "assign FLASH_CS_N = 1'b1;   // the flash chip; the SDRAM /CS is hard wired on Go", s)
    # the HDMI part: from the audio clock of hdmi_tx to the end
    a = s.index("// into clk_65 for HDMI")
    b = s.index("endmodule")
    s = s[:a] + """// ------------------------------------------------------------------ VGA

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

""" + s[b:]
    return s


MARK = "# ------------------------------------------------------------------------------------------------------------\n# Timing constraints"
TMDS_AG = """# The TMDS serialisers (325 MHz): their shift registers next to the ODDR2 of the pins (top edge), as in
# core-atari2600. Left to PAR they land far from the pins: the route into the ODDR2 was 4.2 - 5.0 ns
# against a period of 3.08 ns (builds 26111102 / 26111103 with map -t 2, -0.6 / -1.7 ns).
INST "hdmi/chn*.serial/*" AREA_GROUP = "AG_TMDS";
INST "hdmi/serial_clk/*" AREA_GROUP = "AG_TMDS";
AREA_GROUP "AG_TMDS" RANGE = SLICE_X26Y68:SLICE_X45Y77;
"""


def ucf(board):
    g = open(os.path.join(SRC, "..", "karabas_minig.ucf")).read()
    timing = g[g.index(MARK):]
    timing = sub(timing, "karabas_minig_top.v", "karabas_%s_top.v" % board, "ucf top")
    if board == "go":
        timing = sub(timing, "#   pll_clk<0> 65.0 MHz (/10): clk_65, the video out, the OSD, HDMI\n"
                     "#   pll_clk<1>, <2> 325 MHz (/2, 0 and 180 degrees): the HDMI serialiser\n"
                     "#   pll_clk<3> 8.125 MHz (/80): FT_CLK_OUT only (an ODDR2)\n",
                     "#   pll_clk<0> 65.0 MHz (/10): clk_65, the video out (VGA, V_CLK), the OSD\n"
                     "#   pll_clk<1>..<3>: not used on Go\n", "ucf go clocks")
    path = os.path.join(SRC, "..", "karabas_%s.ucf" % board)
    pins = open(path).read()
    pins = pins[:pins.index(MARK)] if MARK in pins else pins.rstrip("\n") + "\n\n"
    if board == "mini" and "AG_TMDS" not in pins:
        pins = pins.rstrip("\n") + "\n\n" + TMDS_AG + "\n"
    open(path, "w").write(pins + timing)
    print(os.path.normpath(path))


src = open(os.path.join(SRC, "karabas_minig_top.v")).read()
for name, f in (("karabas_mini_top.v", mini), ("karabas_go_top.v", go)):
    out = os.path.join(SRC, name)
    open(out, "w").write(f(src))
    print(os.path.normpath(out))
for board in ("mini", "go"):
    ucf(board)
