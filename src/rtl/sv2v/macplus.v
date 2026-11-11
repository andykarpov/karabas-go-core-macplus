module macplus (
	CLKIN,
	RESET,
	pixelOut,
	vidLoad,
	vsync,
	hsync,
	audio,
	leds,
	ADC_BUS,
	MOUSE,
	kbd_strobe,
	kbd_data,
	configROMSize,
	configFastboot,
	configRAMSize,
	configMachineType,
	configFloppyWProt,
	configSCSIWProt,
	sdc_image_size,
	sdc_image_mounted,
	sdc_lba,
	sdc_rd,
	sdc_wr,
	sdc_done,
	sdc_busy,
	sdc_data_out,
	sdc_data_in,
	sdc_data_en,
	sdc_addr,
	UART_TXD,
	UART_RXD,
	UART_RTS,
	UART_CTS,
	_romOE,
	romAddr,
	romData,
	busPhase,
	ram_addr,
	sdram_din,
	sdram_ds,
	sdram_we,
	sdram_oe,
	sdram_do
);
	input CLKIN;
	input RESET;
	output wire pixelOut;
	output wire vidLoad;
	output wire vsync;
	output wire hsync;
	output wire [11:0] audio;
	output wire [4:0] leds;
	inout [3:0] ADC_BUS;
	input [5:0] MOUSE;
	input kbd_strobe;
	input [9:0] kbd_data;
	input configROMSize;
	input configFastboot;
	input [1:0] configRAMSize;
	input configMachineType;
	input [1:0] configFloppyWProt;
	input configSCSIWProt;
	input [31:0] sdc_image_size;
	localparam SCSI_DEVS = 2;
	input [3:0] sdc_image_mounted;
	output wire [31:0] sdc_lba;
	output wire [3:0] sdc_rd;
	output wire [3:0] sdc_wr;
	input sdc_done;
	input sdc_busy;
	output wire [7:0] sdc_data_out;
	input [7:0] sdc_data_in;
	input sdc_data_en;
	input [8:0] sdc_addr;
	output wire UART_TXD;
	input UART_RXD;
	output wire UART_RTS;
	input UART_CTS;
	output wire _romOE;
	output wire [17:0] romAddr;
	input [15:0] romData;
	output wire [2:0] busPhase;
	output wire [20:0] ram_addr;
	output wire [15:0] sdram_din;
	output wire [1:0] sdram_ds;
	output wire sdram_we;
	output wire sdram_oe;
	input [15:0] sdram_do;
	assign ADC_BUS = 1'sbz;
	wire clk_sys = CLKIN;
	wire clk8_en_p;
	wire clk8_en_n;
	wire videoBusControl;
	wire cpuBusControl;
	clocks clocks(
		.clk(clk_sys),
		.clk8_en_p(clk8_en_p),
		.clk8_en_n(clk8_en_n),
		.busPhase(busPhase),
		.videoBusControl(videoBusControl),
		.cpuBusControl(cpuBusControl)
	);
	reg n_reset = 0;
	wire _cpuReset_o;
	always @(posedge clk_sys) begin : sv2v_autoblock_1
		reg [15:0] rst_cnt;
		if (clk8_en_p) begin
			if (RESET || ~_cpuReset_o) begin
				rst_cnt <= 1'sb1;
				n_reset <= 0;
			end
			else if (rst_cnt)
				rst_cnt <= rst_cnt - 1'd1;
			else
				n_reset <= 1;
		end
	end
	wire pixel;
	assign pixelOut = (n_reset ? pixel : 1'b0);
	wire [1:0] buttons;
	wire [32:0] TIMESTAMP;
	wire serialOut;
	wire serialIn = UART_RXD;
	wire serialRTS;
	wire serialCTS = UART_CTS;
	assign UART_TXD = serialOut;
	assign UART_RTS = serialRTS;
	wire _cpuReset;
	wire _cpuUDS;
	wire _cpuLDS;
	wire _cpuRW;
	wire _cpuAS;
	wire _cpuVMA;
	wire _cpuVPA;
	wire _cpuDTACK;
	wire E_rising;
	wire E_falling;
	wire [2:0] _cpuIPL;
	wire [2:0] cpuFC;
	wire [23:1] cpuAddr;
	wire [15:0] cpuDataOut;
	wire _ramOE;
	wire _ramWE;
	wire _memoryUDS;
	wire _memoryLDS;
	wire vid_alt;
	wire loadPixels;
	wire _hblank;
	wire _vblank;
	assign vidLoad = loadPixels;
	wire memoryOverlayOn;
	wire selectSCSI;
	wire selectSCC;
	wire selectIWM;
	wire selectVIA;
	wire selectRAM;
	wire selectROM;
	wire selectSEOverlay;
	wire [15:0] dataControllerDataOut;
	wire snd_alt;
	wire loadSound;
	reg _cpuAS_I;
	always @(posedge clk_sys) begin
		if (busPhase == 2)
			_cpuAS_I <= _cpuAS;
		if ((busPhase == 7) && _cpuAS)
			_cpuAS_I <= 1'b1;
	end
	wire _cpuAS_R = !(!_cpuAS && !_cpuAS_I);
	assign _cpuVPA = (cpuFC == 3'b111 ? 1'b0 : ~(!_cpuAS && selectVIA));
	wire refreshCycle;
	wire cpuBusCycleDone = busPhase >= 4;
	wire cpuOnVideoBusControl = ((((!loadPixels && !loadSound) && !refreshCycle) && videoBusControl) && !_cpuAS) && selectRAM;
	assign _cpuDTACK = ~((((((!_cpuAS_R && selectRAM) && cpuBusControl) && cpuBusCycleDone) || (((!_cpuAS_R && selectRAM) && cpuOnVideoBusControl) && cpuBusCycleDone)) || ((!_cpuAS_R && selectROM) && cpuBusCycleDone)) || (((!_cpuAS && !selectVIA) && !selectRAM) && !selectROM));
	fx68k fx68k(
		.clk(clk_sys),
		.extReset(!_cpuReset),
		.pwrUp(!_cpuReset),
		.enPhi1(clk8_en_p),
		.enPhi2(clk8_en_n),
		.eRWn(_cpuRW),
		.ASn(_cpuAS),
		.LDSn(_cpuLDS),
		.UDSn(_cpuUDS),
		.E(),
		.E_div(1'b0),
		.E_PosClkEn(E_falling),
		.E_NegClkEn(E_rising),
		.VMAn(_cpuVMA),
		.FC0(cpuFC[0]),
		.FC1(cpuFC[1]),
		.FC2(cpuFC[2]),
		.BGn(),
		.oRESETn(_cpuReset_o),
		.oHALTEDn(),
		.DTACKn(_cpuDTACK),
		.VPAn(_cpuVPA),
		.HALTn(1'b1),
		.BERRn(1'b1),
		.BRn(1'b1),
		.BGACKn(1'b1),
		.IPL0n(_cpuIPL[0]),
		.IPL1n(_cpuIPL[1]),
		.IPL2n(_cpuIPL[2]),
		.iEdb(dataControllerDataOut),
		.oEdb(cpuDataOut),
		.eab(cpuAddr)
	);
	addrController ac0(
		.clk(clk_sys),
		.clk8_en_p(clk8_en_p),
		.clk8_en_n(clk8_en_n),
		.cpuAddr(cpuAddr),
		._cpuUDS(_cpuUDS),
		._cpuLDS(_cpuLDS),
		._cpuRW(_cpuRW),
		._cpuAS(_cpuAS),
		.configROMSize({configMachineType, ~configMachineType}),
		.configRAMSize(configRAMSize),
		.romAddr(romAddr),
		.ramAddr(ram_addr),
		._memoryUDS(_memoryUDS),
		._memoryLDS(_memoryLDS),
		._romOE(_romOE),
		._ramOE(_ramOE),
		._ramWE(_ramWE),
		.videoBusControl(videoBusControl),
		.cpuBusControl(cpuBusControl),
		.cycleReady(busPhase == 3'd7),
		.selectSCSI(selectSCSI),
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.selectRAM(selectRAM),
		.selectROM(selectROM),
		.selectSEOverlay(selectSEOverlay),
		.hsync(hsync),
		.vsync(vsync),
		._hblank(_hblank),
		._vblank(_vblank),
		.loadPixels(loadPixels),
		.vid_alt(vid_alt),
		.memoryOverlayOn(memoryOverlayOn),
		.refresh(refreshCycle),
		.snd_alt(snd_alt),
		.loadSound(loadSound)
	);
	wire [15:0] romDataPatched = ({romAddr, 1'b0} == 18'h00d7a ? 16'h6022 : ({romAddr, 1'b0} == 18'h00ea8 ? 16'h4e71 : ({romAddr, 1'b0} == 18'h00e90 ? 16'h4e71 : romData)));
	wire [15:0] romDataMod = (configFastboot ? romDataPatched : romData);
	wire trigger = cpuAddr == 0;
	dataController #(.SCSI_DEVS(SCSI_DEVS)) dc0(
		.clk(clk_sys),
		.clk8_en_p(clk8_en_p),
		.clk8_en_n(clk8_en_n),
		.E_rising(E_rising),
		.E_falling(E_falling),
		.machineType(configMachineType),
		.floppy_wprot(configFloppyWProt),
		.scsi_wprot(configSCSIWProt),
		._systemReset(n_reset),
		._cpuReset(_cpuReset),
		._cpuIPL(_cpuIPL),
		._cpuUDS(_cpuUDS),
		._cpuLDS(_cpuLDS),
		._cpuRW(_cpuRW),
		._cpuVMA(_cpuVMA),
		.cpuDataIn(cpuDataOut),
		.cpuDataOut(dataControllerDataOut),
		.cpuAddrRegHi(cpuAddr[12:9]),
		.cpuAddrRegMid(cpuAddr[6:4]),
		.cpuAddrRegLo(cpuAddr[2:1]),
		.selectSCSI(selectSCSI),
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.selectSEOverlay(selectSEOverlay),
		.cpuBusControl(cpuBusControl),
		.videoBusControl(videoBusControl),
		.cycleReady(busPhase == 3'd7),
		.memoryDataOut(sdram_din),
		.romSel(!_romOE),
		.ramDataIn(sdram_do),
		.romDataIn(romDataMod),
		.sdc_img_mounted(sdc_image_mounted),
		.sdc_img_size(sdc_image_size),
		.sdc_lba(sdc_lba),
		.sdc_rd(sdc_rd),
		.sdc_wr(sdc_wr),
		.sdc_busy(sdc_busy),
		.sdc_done(sdc_done),
		.sdc_data_in(sdc_data_in),
		.sdc_data_out(sdc_data_out),
		.sdc_data_en(sdc_data_en),
		.sdc_addr(sdc_addr),
		.mouse(MOUSE),
		.kbd_strobe(kbd_strobe),
		.kbd_data(kbd_data),
		.serialIn(serialIn),
		.serialOut(serialOut),
		.serialCTS(serialCTS),
		.serialRTS(serialRTS),
		.timestamp(TIMESTAMP),
		._hblank(_hblank),
		._vblank(_vblank),
		.pixelOut(pixel),
		.loadPixels(loadPixels),
		.vid_alt(vid_alt),
		.memoryOverlayOn(memoryOverlayOn),
		.audioOut(audio),
		.snd_alt(snd_alt),
		.loadSound(loadSound),
		.diskLED(leds)
	);
	assign sdram_ds = {!_memoryUDS, !_memoryLDS};
	assign sdram_we = !_ramWE;
	assign sdram_oe = !_ramOE;
endmodule
