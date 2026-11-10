module dataController (
	clk,
	clk8_en_p,
	clk8_en_n,
	E_rising,
	E_falling,
	machineType,
	_systemReset,
	floppy_wprot,
	scsi_wprot,
	_cpuReset,
	_cpuIPL,
	cpuDataIn,
	cpuAddrRegHi,
	cpuAddrRegMid,
	cpuAddrRegLo,
	_cpuUDS,
	_cpuLDS,
	_cpuRW,
	cpuDataOut,
	selectSCSI,
	selectSCC,
	selectIWM,
	selectVIA,
	selectSEOverlay,
	_cpuVMA,
	videoBusControl,
	cpuBusControl,
	cycleReady,
	romSel,
	ramDataIn,
	romDataIn,
	memoryDataOut,
	mouse,
	kbd_strobe,
	kbd_data,
	serialIn,
	serialOut,
	serialCTS,
	serialRTS,
	timestamp,
	pixelOut,
	_hblank,
	_vblank,
	loadPixels,
	vid_alt,
	audioOut,
	snd_alt,
	loadSound,
	memoryOverlayOn,
	diskLED,
	sdc_img_size,
	sdc_img_mounted,
	sdc_lba,
	sdc_rd,
	sdc_wr,
	sdc_done,
	sdc_busy,
	sdc_data_in,
	sdc_data_out,
	sdc_data_en,
	sdc_addr
);
	input clk;
	input clk8_en_p;
	input clk8_en_n;
	input E_rising;
	input E_falling;
	input machineType;
	input _systemReset;
	input [1:0] floppy_wprot;
	input scsi_wprot;
	output wire _cpuReset;
	output wire [2:0] _cpuIPL;
	input [15:0] cpuDataIn;
	input [3:0] cpuAddrRegHi;
	input [2:0] cpuAddrRegMid;
	input [1:0] cpuAddrRegLo;
	input _cpuUDS;
	input _cpuLDS;
	input _cpuRW;
	output wire [15:0] cpuDataOut;
	input selectSCSI;
	input selectSCC;
	input selectIWM;
	input selectVIA;
	input selectSEOverlay;
	input _cpuVMA;
	input videoBusControl;
	input cpuBusControl;
	input cycleReady;
	input romSel;
	input [15:0] ramDataIn;
	input [15:0] romDataIn;
	output wire [15:0] memoryDataOut;
	input [4:0] mouse;
	input kbd_strobe;
	input [9:0] kbd_data;
	input serialIn;
	output wire serialOut;
	input serialCTS;
	output wire serialRTS;
	input [32:0] timestamp;
	output wire pixelOut;
	input _hblank;
	input _vblank;
	input loadPixels;
	output wire vid_alt;
	output wire [11:0] audioOut;
	output wire snd_alt;
	input loadSound;
	output wire memoryOverlayOn;
	output wire [4:0] diskLED;
	input [31:0] sdc_img_size;
	parameter SCSI_DEVS = 2;
	input [SCSI_DEVS + 1:0] sdc_img_mounted;
	output wire [31:0] sdc_lba;
	output reg [SCSI_DEVS + 1:0] sdc_rd;
	output reg [SCSI_DEVS + 1:0] sdc_wr;
	input sdc_done;
	input sdc_busy;
	input [7:0] sdc_data_in;
	output wire [7:0] sdc_data_out;
	input sdc_data_en;
	input [8:0] sdc_addr;
	reg [15:0] scsiLED_cnt [0:1];
	assign diskLED[3:2] = {scsiLED_cnt[1] != 32'sd0, scsiLED_cnt[0] != 32'sd0};
	reg scsi_io = 1'b1;
	reg scsi_dev = 1'b0;
	wire [1:0] iwm_rd;
	wire [1:0] iwm_wr;
	wire [1:0] scsi_rd;
	wire [1:0] scsi_wr;
	always @(posedge clk) begin
		if (scsi_rd[0] || scsi_wr[0])
			scsiLED_cnt[0] <= 16'hffff;
		else if (scsiLED_cnt[0])
			scsiLED_cnt[0] <= scsiLED_cnt[0] - 16'd1;
		if (scsi_rd[1] || scsi_wr[1])
			scsiLED_cnt[1] <= 16'hffff;
		else if (scsiLED_cnt[1])
			scsiLED_cnt[1] <= scsiLED_cnt[1] - 16'd1;
		sdc_rd <= {scsi_rd, iwm_rd};
		sdc_wr <= {scsi_wr, iwm_wr};
		if (|{iwm_rd, iwm_wr})
			scsi_io <= 1'b0;
		if (|{scsi_rd, scsi_wr})
			scsi_io <= 1'b1;
		if (scsi_rd[1] | scsi_wr[1])
			scsi_dev <= 1'b1;
		if (scsi_rd[0] | scsi_wr[0])
			scsi_dev <= 1'b0;
	end
	wire [1:0] io_ack = (scsi_io && !scsi_dev ? {1'b0, sdc_busy} : (scsi_io && scsi_dev ? {sdc_busy, 1'b0} : 2'b00));
	wire [(SCSI_DEVS * 8) - 1:0] scsi_data_out;
	wire [7:0] iwm_data_out;
	assign sdc_data_out = (scsi_io ? scsi_data_out[((SCSI_DEVS - 1) - scsi_dev) * 8+:8] : iwm_data_out);
	wire [10:0] iwm_lba;
	wire [(SCSI_DEVS * 32) - 1:0] scsi_lba;
	assign sdc_lba = (scsi_io ? scsi_lba[((SCSI_DEVS - 1) - scsi_dev) * 32+:32] : {21'd0, iwm_lba});
	reg [7:0] audio_latch;
	wire [10:0] audio_x1 = {{3 {audio_latch[7]}}, audio_latch};
	wire [10:0] audio_x2 = {{2 {audio_latch[7]}}, audio_latch, 1'b0};
	wire [10:0] audio_x4 = {audio_latch[7], audio_latch, 2'b00};
	wire [2:0] snd_vol;
	wire [10:0] audioVol = ((snd_vol[0] ? audio_x1 : 11'd0) + (snd_vol[1] ? audio_x2 : 11'd0)) + (snd_vol[2] ? audio_x4 : 11'd0);
	reg [10:0] audioFilterLatch [0:1];
	wire [11:0] audioFilter0 = {{2 {audioVol[10]}}, audioVol[10:1]};
	wire [11:0] audioFilter1 = {audioFilterLatch[0][10], audioFilterLatch[0]};
	wire [11:0] audioFilter2 = {{2 {audioFilterLatch[1][10]}}, audioFilterLatch[1][10:1]};
	assign audioOut = (audioFilter0 + audioFilter1) + audioFilter2;
	wire snd_ena;
	always @(posedge clk)
		if (cycleReady && loadSound) begin
			if (snd_ena)
				audio_latch <= 8'h7f;
			else
				audio_latch <= ramDataIn[15:8] - 8'd128;
			audioFilterLatch[0] <= audioVol;
			audioFilterLatch[1] <= audioFilterLatch[0];
		end
	reg [19:0] resetDelay = 20'hfffff;
	wire isResetting = resetDelay != 0;
	always @(posedge clk or negedge _systemReset)
		if (_systemReset == 1'b0)
			resetDelay <= 20'hfffff;
		else if (clk8_en_p && isResetting)
			resetDelay <= resetDelay - 1'b1;
	assign _cpuReset = (isResetting ? 1'b0 : 1'b1);
	wire SEL;
	wire _viaIrq;
	wire _sccIrq;
	wire sccWReq;
	wire [15:0] viaDataOut;
	wire [15:0] iwmDataOut;
	wire [7:0] sccDataOut;
	wire [7:0] scsiDataOut;
	wire mouseY1 = mouse[0];
	wire mouseY2 = mouse[1];
	wire mouseX1 = mouse[2];
	wire mouseX2 = mouse[3];
	wire mouseButton = mouse[4];
	assign _cpuIPL = (!_viaIrq ? 3'b110 : (!_sccIrq ? 3'b101 : 3'b111));
	assign cpuDataOut = (selectIWM ? iwmDataOut : (selectVIA ? viaDataOut : (selectSCC ? {sccDataOut, 8'hef} : (selectSCSI ? {scsiDataOut, 8'hef} : (romSel ? romDataIn : ramDataIn)))));
	assign memoryDataOut = cpuDataIn;
	wire [1:0] scsi_wr_int;
	wire [1:0] scsi_ack;
	assign scsi_wr = (scsi_wprot ? 2'b00 : scsi_wr_int);
	assign scsi_ack = (scsi_wprot ? io_ack | scsi_wr_int : io_ack);
	ncr5380 #(.DEVS(SCSI_DEVS)) scsi(
		.clk(clk),
		.reset(!_cpuReset),
		.bus_cs(selectSCSI),
		.bus_rs(cpuAddrRegMid),
		.ior(!_cpuUDS),
		.iow(!_cpuLDS),
		.dack(cpuAddrRegHi[0]),
		.wdata(cpuDataIn[15:8]),
		.rdata(scsiDataOut),
		.img_mounted(sdc_img_mounted[SCSI_DEVS + 1:2]),
		.img_size({9'd0, sdc_img_size[31:9]}),
		.wr_prot(scsi_wprot),
		.io_lba(scsi_lba),
		.io_rd(scsi_rd),
		.io_wr(scsi_wr_int),
		.io_ack(scsi_ack),
		.sd_buff_addr(sdc_addr),
		.sd_buff_dout(sdc_data_in),
		.sd_buff_din(scsi_data_out),
		.sd_buff_wr(sdc_data_en)
	);
	reg [5:0] vblankCount;
	reg _lastVblank;
	always @(posedge clk)
		if (clk8_en_n) begin
			_lastVblank <= _vblank;
			if ((_vblank == 1'b0) && (_lastVblank == 1'b1)) begin
				if (vblankCount != 59)
					vblankCount <= vblankCount + 1'b1;
				else
					vblankCount <= 6'h00;
			end
		end
	wire onesec = vblankCount == 59;
	reg SEOverlay;
	always @(posedge clk)
		if (!_cpuReset)
			SEOverlay <= 1;
		else if (clk8_en_n && selectSEOverlay)
			SEOverlay <= 0;
	wire driveSel;
	wire [7:0] via_pa_i;
	wire [7:0] via_pa_o;
	wire [7:0] via_pa_oe;
	wire [7:0] via_pb_i;
	wire [7:0] via_pb_o;
	wire [7:0] via_pb_oe;
	wire viaIrq;
	reg kbddata_o;
	reg kbdclk;
	wire cb2_i = kbddata_o;
	wire cb2_o;
	wire cb2_t;
	assign _viaIrq = ~viaIrq;
	assign via_pa_i = {sccWReq, ~via_pa_oe[6:0] | via_pa_o[6:0]};
	assign snd_vol = ~via_pa_oe[2:0] | via_pa_o[2:0];
	assign snd_alt = (machineType ? 1'b0 : ~(~via_pa_oe[3] | via_pa_o[3]));
	assign driveSel = (machineType ? ~via_pa_oe[4] | via_pa_o[4] : 1'b1);
	assign memoryOverlayOn = (machineType ? SEOverlay : ~via_pa_oe[4] | via_pa_o[4]);
	assign SEL = ~via_pa_oe[5] | via_pa_o[5];
	assign vid_alt = ~via_pa_oe[6] | via_pa_o[6];
	wire _ADBint;
	wire rtcdat_o;
	assign via_pb_i = {1'b1, {3 {machineType}} | {_hblank, mouseY2, mouseX2}, (machineType ? _ADBint : mouseButton), 2'b11, rtcdat_o};
	assign snd_ena = ~via_pb_oe[7] | via_pb_o[7];
	assign viaDataOut[7:0] = 8'hef;
	via6522 via(
		.clock(clk),
		.rising(E_rising),
		.falling(E_falling),
		.reset(!_cpuReset),
		.addr(cpuAddrRegHi),
		.wen((selectVIA && !_cpuVMA) && !_cpuRW),
		.ren((selectVIA && !_cpuVMA) && _cpuRW),
		.data_in(cpuDataIn[15:8]),
		.data_out(viaDataOut[15:8]),
		.phi2_ref(),
		.port_a_o(via_pa_o),
		.port_a_t(via_pa_oe),
		.port_a_i(via_pa_i),
		.port_b_o(via_pb_o),
		.port_b_t(via_pb_oe),
		.port_b_i(via_pb_i),
		.ca1_i(_vblank),
		.ca2_i(onesec),
		.cb1_i(kbdclk),
		.cb2_i(cb2_i),
		.cb2_o(cb2_o),
		.cb2_t(cb2_t),
		.irq(viaIrq)
	);
	wire _rtccs = ~via_pb_oe[2] | via_pb_o[2];
	wire rtcck = ~via_pb_oe[1] | via_pb_o[1];
	wire rtcdat_i = ~via_pb_oe[0] | via_pb_o[0];
	rtc pram(
		.clk(clk),
		.reset(!_cpuReset),
		.timestamp(timestamp),
		._cs(_rtccs),
		.ck(rtcck),
		.dat_i(rtcdat_i),
		.dat_o(rtcdat_o)
	);
	wire ADBST0 = ~via_pb_oe[4] | via_pb_o[4];
	wire ADBST1 = ~via_pb_oe[5] | via_pb_o[5];
	wire ADBListen;
	reg [10:0] kbdclk_count;
	reg kbd_transmitting;
	reg kbd_wait_receiving;
	reg kbd_receiving;
	reg [2:0] kbd_bitcnt;
	wire kbddat_i = ~cb2_t | cb2_o;
	reg [7:0] kbd_to_mac;
	reg kbd_data_valid;
	reg [7:0] kbd_out_data;
	always @(posedge clk)
		if (clk8_en_p) begin
			if ((kbd_transmitting && !kbd_wait_receiving) || kbd_receiving) begin
				kbdclk_count <= kbdclk_count + 1'd1;
				if (kbdclk_count == (machineType ? 8'd80 : 12'd1300)) begin
					kbdclk <= ~kbdclk;
					kbdclk_count <= 0;
					if (kbdclk) begin
						if (kbd_transmitting)
							kbd_out_data <= {kbd_out_data[6:0], kbddat_i};
						if (kbd_receiving)
							kbddata_o <= kbd_to_mac[7 - kbd_bitcnt];
					end
				end
			end
			else begin
				kbdclk_count <= 0;
				kbdclk <= 1;
			end
		end
	reg [7:0] adb_din;
	reg adb_din_strobe;
	wire [7:0] adb_dout;
	wire adb_dout_strobe;
	wire [7:0] kbd_in_data;
	wire kbd_in_strobe;
	reg kbd_out_strobe;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg kbdclk_d;
		reg ADBListenD;
		if (!_cpuReset) begin
			kbd_bitcnt <= 0;
			kbd_transmitting <= 0;
			kbd_wait_receiving <= 0;
			kbd_data_valid <= 0;
			ADBListenD <= 0;
		end
		else if (clk8_en_p) begin
			if (kbd_in_strobe && !machineType) begin
				kbd_to_mac <= kbd_in_data;
				kbd_data_valid <= 1;
			end
			if (adb_dout_strobe && machineType) begin
				kbd_to_mac <= adb_dout;
				kbd_receiving <= 1;
			end
			kbd_out_strobe <= 0;
			adb_din_strobe <= 0;
			kbdclk_d <= kbdclk;
			if (((!machineType && !kbd_transmitting) && !kbd_receiving) && !kbddat_i) begin
				kbd_transmitting <= 1;
				kbd_bitcnt <= 0;
			end
			if ((machineType && !kbd_transmitting) && !kbd_receiving) begin
				ADBListenD <= ADBListen;
				if (!ADBListenD && ADBListen) begin
					kbd_transmitting <= 1;
					kbd_bitcnt <= 0;
				end
			end
			if ((kbd_wait_receiving && kbddat_i) && kbd_data_valid) begin
				kbd_wait_receiving <= 0;
				kbd_receiving <= 1;
				kbd_transmitting <= 0;
			end
			if (~kbdclk_d & kbdclk) begin
				kbd_bitcnt <= kbd_bitcnt + 1'd1;
				if (kbd_bitcnt == 3'd7) begin
					if (kbd_transmitting) begin
						if (!machineType) begin
							kbd_out_strobe <= 1;
							kbd_wait_receiving <= 1;
						end
						else begin
							adb_din_strobe <= 1;
							adb_din <= kbd_out_data;
							kbd_transmitting <= 0;
						end
					end
					if (kbd_receiving) begin
						kbd_receiving <= 0;
						kbd_data_valid <= 0;
					end
				end
			end
		end
	end
	iwm i(
		.clk(clk),
		.cep(clk8_en_p),
		.cen(clk8_en_n),
		._reset(_cpuReset),
		.selectIWM(selectIWM),
		._cpuRW(_cpuRW),
		._cpuLDS(_cpuLDS),
		.dataIn(cpuDataIn),
		.cpuAddr(cpuAddrRegHi),
		.SEL(SEL),
		.driveSel(driveSel),
		.diskWProt(floppy_wprot),
		.dataOut(iwmDataOut),
		.diskLED({diskLED[4], diskLED[1:0]}),
		.sd_img_size(sdc_img_size),
		.sd_img_mounted(sdc_img_mounted[1:0]),
		.sd_lba(iwm_lba),
		.sd_rd(iwm_rd),
		.sd_wr(iwm_wr),
		.sd_busy(sdc_busy),
		.sd_done(sdc_done),
		.sd_data_in(sdc_data_in),
		.sd_data_out(iwm_data_out),
		.sd_data_en(sdc_data_en),
		.sd_addr(sdc_addr)
	);
	scc s(
		.clk(clk),
		.cep(clk8_en_p),
		.cen(clk8_en_n),
		.reset_hw(~_cpuReset),
		.cs(selectSCC && ((_cpuLDS == 1'b0) || (_cpuUDS == 1'b0))),
		.we(!_cpuLDS),
		.rs(cpuAddrRegLo),
		.wdata(cpuDataIn[15:8]),
		.rdata(sccDataOut),
		._irq(_sccIrq),
		.dcd_a(mouseX1),
		.dcd_b(mouseY1),
		.wreq(sccWReq),
		.txd(serialOut),
		.rxd(serialIn),
		.cts(serialCTS),
		.rts(serialRTS)
	);
	videoShifter vs(
		.clk(clk),
		.clk8_en_p(clk8_en_p),
		.clk8_en_n(clk8_en_n),
		.dataIn(ramDataIn),
		.loadPixels(loadPixels & cycleReady),
		.pixelOut(pixelOut)
	);
	keyboard kbd(
		.clk(clk),
		.en(clk8_en_p),
		.reset(~_cpuReset),
		.kbd_strobe(kbd_strobe),
		.kbd_data(kbd_data),
		.data_out(kbd_out_data),
		.strobe_out(kbd_out_strobe),
		.data_in(kbd_in_data),
		.strobe_in(kbd_in_strobe)
	);
	adb adb(
		.clk(clk),
		.clk_en(clk8_en_p),
		.reset(~_cpuReset),
		.st({ADBST1, ADBST0}),
		._int(_ADBint),
		.viaBusy(kbd_transmitting || kbd_receiving),
		.listen(ADBListen),
		.adb_din(adb_din),
		.adb_din_strobe(adb_din_strobe),
		.adb_dout(adb_dout),
		.adb_dout_strobe(adb_dout_strobe),
		.ps2_mouse(25'h0000000),
		.ps2_key(12'h000)
	);
endmodule
