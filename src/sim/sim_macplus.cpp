// sim_macplus.cpp - verilator harness of sim_top.v: the Mac Plus machine of Ф1 on memory models.
//
//   sim_macplus [--ms N] [--ram 0..3] [--model 0 Plus | 1 SE | 2 64K ROM] [--no-fastboot] [--fd0 FILE] [--fd1 FILE] [--scsi0 FILE]
//               [--scsi1 FILE] [--ppm PREFIX] [--every N] [--report MS] [--trace-sdc]
//               [--expect-frames N] [--expect-sdc N] [--expect-pc-in LO:HI] [--expect-black LO:HI]
//
// The ROM is the +rom=FILE plusarg of sim_top.v (run_boot.sh passes it). Clock 16 MHz (the
// 16 MHz busPhase of clocks.v: CPU 8 MHz, one pixel per clock). --ms: the run length in ms of
// machine time. --ram: 0 128K, 1 512K, 2 1M (default), 3 4M. --fd0 / --fd1: raw 400 / 800 KB
// images of the internal / external floppy (sdc index 0, 1), --scsi0 / --scsi1: hard disk
// images (index 2, 3, SCSI ID 6 / 5). --ppm writes every N-th frame (default 30) as
// PREFIX_NNNN.ppm, the visible 512 x 342. "black" counts the black pixels (pixelOut 0). --report: a status line every MS.
// --expect-frames: fail if fewer frames came; --expect-sdc: fail if fewer sectors were read;
// --expect-pc-in: fail unless the CPU address bus was inside LO..HI (hex) at the end;
// --expect-black: fail unless the last frame has LO..HI black pixels (the grey desktop with the
// "?" disk of a Plus without a disk: about 88000).
// Exit code 1 when an --expect fails.

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cstdint>
#include <string>
#include <vector>
#include <ctime>
#include "verilated.h"
#ifdef SIM_BOARD
// sim_board.v: the memory path of the board tops (mac_sdram, mac_sram, the frame buffer), clk = clk_2x
#include "Vsim_board.h"
typedef Vsim_board Vtop;
#else
#include "Vsim_top.h"
typedef Vsim_top Vtop;
#endif

static Vtop *tb;
static double sim_ms = 0;
static const double TICK_MS = 1000.0 / 16000000.0;

// ------------------------------------------------------------------ disk images (sdc index 0..3)

struct Image {
	std::vector<uint8_t> data;
	std::string name;
	bool dirty = false;
};
static Image img[4];
static bool trace_sdc = false;
static long sectors_read = 0, sectors_written = 0;

static bool load_image(int i, const char *fn) {
	FILE *f = fopen(fn, "rb");
	if (!f) { perror(fn); return false; }
	fseek(f, 0, SEEK_END);
	long n = ftell(f);
	fseek(f, 0, SEEK_SET);
	img[i].data.resize(n);
	if (fread(img[i].data.data(), 1, n, f) != (size_t)n) { fclose(f); return false; }
	fclose(f);
	img[i].name = fn;
	return true;
}

// the sector interface as img_sdc gives it: a request bit held until busy, then the 512 bytes as
// data_en strobes (read) or taken from sdc_data_out a few clocks after sdc_addr (write), then
// busy down with a done pulse. One request at a time, the lowest index first.
enum { S_IDLE, S_WAIT, S_RD, S_WR, S_END };
static int sdc_state = S_IDLE, sdc_idx = 0, sdc_cnt = 0, sdc_pos = 0;
static bool sdc_write = false;
static uint32_t sdc_lba = 0;
static uint8_t sdc_buf[512];
static int mount_step = 0;   // the mount strobes, one index at a time after the reset

static void sdc_step(void) {
	tb->sdc_done = 0;
	tb->sdc_data_en = 0;
	// mount: sdc_image_mounted[i] one clock with sdc_image_size
	if (mount_step < 8 && sim_ms > 1.0) {
		int i = mount_step >> 1;
		if (!(mount_step & 1) && !img[i].data.empty()) {
			tb->sdc_image_size = img[i].data.size();
			tb->sdc_image_mounted = 1 << i;
			printf("%9.3f ms mount %d: %s (%zu bytes)\n", sim_ms, i, img[i].name.c_str(), img[i].data.size());
		} else
			tb->sdc_image_mounted = 0;
		mount_step++;
		return;
	}
	switch (sdc_state) {
	case S_IDLE: {
		int req = tb->sdc_rd | tb->sdc_wr;
		if (!req) break;
		for (sdc_idx = 0; sdc_idx < 4 && !(req & (1 << sdc_idx)); sdc_idx++);
		sdc_write = (tb->sdc_wr >> sdc_idx) & 1;
		sdc_lba = tb->sdc_lba;
		tb->sdc_busy = 1;
		sdc_state = S_WAIT;
		sdc_cnt = 200;   // the mcu needs some time
		if (trace_sdc)
			printf("%9.3f ms sdc %s %d lba %u\n", sim_ms, sdc_write ? "write" : "read", sdc_idx, sdc_lba);
		break;
	}
	case S_WAIT:
		if (--sdc_cnt) break;
		sdc_pos = 0;
		sdc_cnt = 0;
		if (sdc_write) {
			sdc_state = S_WR;
		} else {
			size_t off = (size_t)sdc_lba * 512;
			for (int k = 0; k < 512; k++)
				sdc_buf[k] = off + k < img[sdc_idx].data.size() ? img[sdc_idx].data[off + k] : 0;
			sdc_state = S_RD;
		}
		break;
	case S_RD:
		// a byte every 4 clocks
		if ((sdc_cnt++ & 3) == 0) {
			tb->sdc_addr = sdc_pos;
			tb->sdc_data_in = sdc_buf[sdc_pos];
			tb->sdc_data_en = 1;
			if (++sdc_pos == 512) { sdc_state = S_END; sectors_read++; }
		}
		break;
	case S_WR:
		// sdc_addr, then the byte 3 clocks later
		if ((sdc_cnt & 3) == 0) tb->sdc_addr = sdc_pos;
		if ((sdc_cnt & 3) == 3) {
			sdc_buf[sdc_pos] = tb->sdc_data_out;
			if (++sdc_pos == 512) {
				size_t off = (size_t)sdc_lba * 512;
				if (off + 512 <= img[sdc_idx].data.size()) {
					memcpy(&img[sdc_idx].data[off], sdc_buf, 512);
					img[sdc_idx].dirty = true;
				}
				sectors_written++;
				sdc_state = S_END;
			}
		}
		sdc_cnt++;
		break;
	case S_END:
		tb->sdc_busy = 0;
		tb->sdc_done = 1;
		sdc_state = S_IDLE;
		break;
	}
}

// ------------------------------------------------------------------ video

// the raster of videoTimer.v: 704 x 370, one pixel per clock, hsync 526..529, vsync lines
// 342..346. A line starts at the rising edge of hs (xpos 530), a frame at the rising edge of vs.
static const int LINE = 704, FRAME = 370;
static const int X0 = LINE - 530, Y0 = FRAME - 347;   // the first visible pixel / line after them
static int x_off = 6;                                  // the pixel pipeline delay (videoShifter)
static uint8_t frame[FRAME][LINE];
static int px = 0, py = 0, last_hs = 1, last_vs = 1, frames = 0;
static const char *ppm_prefix = nullptr;
static int ppm_every = 30;
static long last_black = 0;

static void write_ppm(void) {
	char fn[512];
	snprintf(fn, sizeof fn, "%s_%04d.ppm", ppm_prefix, frames);
	FILE *f = fopen(fn, "wb");
	if (!f) return;
	fprintf(f, "P6\n512 342\n255\n");
	for (int y = 0; y < 342; y++)
		for (int x = 0; x < 512; x++) {
			uint8_t v = frame[Y0 + y][X0 + x_off + x] ? 0 : 255;
			fputc(v, f); fputc(v, f); fputc(v, f);
		}
	fclose(f);
}

static void video_step(void) {
	if (px < LINE && py < FRAME) frame[py][px] = !tb->pix;   // pixelOut 0 = black
	px++;
	if (tb->hs && !last_hs) { px = 0; py++; }
	last_hs = tb->hs;
	if (tb->vs && !last_vs) {
		long black = 0;
		for (int y = 0; y < 342; y++)
			for (int x = 0; x < 512; x++) black += frame[Y0 + y][X0 + x_off + x];
		last_black = black;
		if (ppm_prefix && (frames % ppm_every) == 0) write_ppm();
		frames++;
		py = 0;
	}
	last_vs = tb->vs;
}

// ------------------------------------------------------------------ main

int main(int argc, char **argv) {
	double run_ms = 3000, report_ms = 250;
	int ram = 2, fastboot = 1, expect_frames = -1, model = 0;
	long expect_sdc = -1;
	long pc_lo = -1, pc_hi = -1, black_lo = -1, black_hi = -1;
	for (int i = 1; i < argc; i++) {
		std::string a = argv[i];
		if (a == "--ms" && i + 1 < argc) run_ms = atof(argv[++i]);
		else if (a == "--ram" && i + 1 < argc) ram = atoi(argv[++i]);
		else if (a == "--no-fastboot") fastboot = 0;
		else if (a == "--model" && i + 1 < argc) model = atoi(argv[++i]);   // 0 Plus, 1 SE, 2 64K ROM
		else if (a == "--fd0" && i + 1 < argc) { if (!load_image(0, argv[++i])) return 2; }
		else if (a == "--fd1" && i + 1 < argc) { if (!load_image(1, argv[++i])) return 2; }
		else if (a == "--scsi0" && i + 1 < argc) { if (!load_image(2, argv[++i])) return 2; }
		else if (a == "--scsi1" && i + 1 < argc) { if (!load_image(3, argv[++i])) return 2; }
		else if (a == "--ppm" && i + 1 < argc) ppm_prefix = argv[++i];
		else if (a == "--every" && i + 1 < argc) ppm_every = atoi(argv[++i]);
		else if (a == "--report" && i + 1 < argc) report_ms = atof(argv[++i]);
		else if (a == "--xoff" && i + 1 < argc) x_off = atoi(argv[++i]);
		else if (a == "--trace-sdc") trace_sdc = true;
		else if (a == "--expect-frames" && i + 1 < argc) expect_frames = atoi(argv[++i]);
		else if (a == "--expect-sdc" && i + 1 < argc) expect_sdc = atol(argv[++i]);
		else if (a == "--expect-pc-in" && i + 1 < argc) {
			if (sscanf(argv[++i], "%lx:%lx", &pc_lo, &pc_hi) != 2) return 2;
		}
		else if (a == "--expect-black" && i + 1 < argc) {
			if (sscanf(argv[++i], "%ld:%ld", &black_lo, &black_hi) != 2) return 2;
		}
		else if (a[0] == '+') ;   // plusargs of sim_top.v
		else { fprintf(stderr, "unknown argument %s\n", argv[i]); return 2; }
	}

	Verilated::commandArgs(argc, argv);
	tb = new Vtop;
	tb->reset = 1;
	tb->ram_size = ram;
	tb->fastboot = fastboot;
	tb->machine_se = model == 1;
	tb->rom_size = model == 1 ? 2 : model == 2 ? 0 : 1;
	tb->floppy_wprot = 0;
	tb->mouse = 0x1f;
	tb->kbd_strobe = 0;
	tb->kbd_data = 0;
	tb->sdc_busy = 0;
	tb->sdc_done = 0;
	tb->sdc_image_mounted = 0;

	time_t t0 = time(nullptr);
	double next_report = report_ms;
	int last_leds = -1;
	while (sim_ms < run_ms && !Verilated::gotFinish()) {
		if (tb->reset && sim_ms > 0.5) tb->reset = 0;
#ifdef SIM_BOARD
		// two clocks of clk_2x per clock of the machine: clk_sys rises with the first, in the same eval
		tb->clk = 0; tb->eval(); tb->clk = 1; tb->clk_sys = 1; tb->eval();
		tb->clk = 0; tb->eval(); tb->clk = 1; tb->clk_sys = 0; tb->eval();
#else
		tb->clk = 0; tb->eval();
		tb->clk = 1; tb->eval();
#endif
		sdc_step();
		video_step();
		if (tb->leds != last_leds) {
			last_leds = tb->leds;
			printf("%9.3f ms leds %02x\n", sim_ms, last_leds);
		}
		sim_ms += TICK_MS;
		if (sim_ms >= next_report) {
			next_report += report_ms;
			printf("%9.3f ms frames %d, black %ld, cpu at %06x, sectors read %ld written %ld (%lds)\n",
				sim_ms, frames, last_black, (unsigned)tb->cpu_addr << 1, sectors_read, sectors_written,
				(long)(time(nullptr) - t0));
			fflush(stdout);
		}
	}
	if (ppm_prefix) write_ppm();
#ifdef SIM_BOARD
	// the frame buffer of mac_video as PREFIX_fb.ppm (black = bit set)
	if (ppm_prefix) {
		char fn[512];
		snprintf(fn, sizeof fn, "%s_fb.ppm", ppm_prefix);
		FILE *f = fopen(fn, "wb");
		if (f) {
			fprintf(f, "P6\n512 342\n255\n");
			for (int y = 0; y < 342; y++)
				for (int x = 0; x < 512; x += 16) {
					tb->fb_addr = y * 32 + x / 16;
					tb->eval();
					for (int b = 15; b >= 0; b--) {
						uint8_t v = (tb->fb_word >> b) & 1 ? 0 : 255;
						fputc(v, f); fputc(v, f); fputc(v, f);
					}
				}
			fclose(f);
		}
	}
#endif
	printf("%9.3f ms end: frames %d, black %ld, sectors read %ld written %ld\n",
		sim_ms, frames, last_black, sectors_read, sectors_written);

	int fail = 0;
	if (expect_frames >= 0 && frames < expect_frames) { printf("FAIL: %d frames < %d\n", frames, expect_frames); fail = 1; }
	if (expect_sdc >= 0 && sectors_read < expect_sdc) { printf("FAIL: %ld sectors < %ld\n", sectors_read, expect_sdc); fail = 1; }
	if (pc_lo >= 0) {
		long pc = (long)tb->cpu_addr << 1;
		if (pc < pc_lo || pc > pc_hi) { printf("FAIL: cpu at %06lx, not in %06lx..%06lx\n", pc, pc_lo, pc_hi); fail = 1; }
	}
	if (black_lo >= 0 && (last_black < black_lo || last_black > black_hi)) {
		printf("FAIL: %ld black pixels, not in %ld..%ld\n", last_black, black_lo, black_hi); fail = 1;
	}
	if (!fail && (expect_frames >= 0 || expect_sdc >= 0 || pc_lo >= 0 || black_lo >= 0)) printf("PASS\n");
	tb->final();
	delete tb;
	return fail;
}
