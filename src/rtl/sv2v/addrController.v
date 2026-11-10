module addrController (
	clk,
	clk8_en_p,
	clk8_en_n,
	videoBusControl,
	cpuBusControl,
	cycleReady,
	configROMSize,
	configRAMSize,
	cpuAddr,
	_cpuUDS,
	_cpuLDS,
	_cpuRW,
	_cpuAS,
	romAddr,
	ramAddr,
	_memoryUDS,
	_memoryLDS,
	_romOE,
	_ramOE,
	_ramWE,
	selectSCSI,
	selectSCC,
	selectIWM,
	selectVIA,
	selectRAM,
	selectROM,
	selectSEOverlay,
	hsync,
	vsync,
	_hblank,
	_vblank,
	loadPixels,
	vid_alt,
	snd_alt,
	loadSound,
	memoryOverlayOn,
	refresh
);
	input clk;
	input clk8_en_p;
	input clk8_en_n;
	input videoBusControl;
	input cpuBusControl;
	input cycleReady;
	input [1:0] configROMSize;
	input [1:0] configRAMSize;
	input [23:1] cpuAddr;
	input _cpuUDS;
	input _cpuLDS;
	input _cpuRW;
	input _cpuAS;
	output wire [17:0] romAddr;
	output wire [20:0] ramAddr;
	output wire _memoryUDS;
	output wire _memoryLDS;
	output wire _romOE;
	output wire _ramOE;
	output wire _ramWE;
	output wire selectSCSI;
	output wire selectSCC;
	output wire selectIWM;
	output wire selectVIA;
	output wire selectRAM;
	output wire selectROM;
	output wire selectSEOverlay;
	output wire hsync;
	output wire vsync;
	output wire _hblank;
	output wire _vblank;
	output wire loadPixels;
	input vid_alt;
	input snd_alt;
	output wire loadSound;
	input memoryOverlayOn;
	output wire refresh;
	reg sndReq;
	reg sndReqCycle;
	assign loadSound = videoBusControl & sndReqCycle;
	reg [20:0] audioAddr;
	reg vblankD;
	reg hblankD;
	always @(posedge clk) begin
		if (cycleReady) begin
			sndReqCycle <= sndReq;
			if (loadSound) begin
				sndReq <= 1'b0;
				audioAddr <= audioAddr + 21'd1;
			end
		end
		if (clk8_en_p) begin
			vblankD <= _vblank;
			hblankD <= _hblank;
			if (vblankD && !_vblank)
				audioAddr <= (snd_alt ? 21'h1fd080 : 21'h1ffe80);
			else if (hblankD && !_hblank)
				sndReq <= 1'b1;
		end
	end
	wire [20:0] videoAddr;
	assign _romOE = ~(selectROM && _cpuRW);
	wire va_ram_access = videoBusControl && (loadPixels || loadSound);
	wire cpu_ram_access = selectRAM & (cpuBusControl || ((videoBusControl && !loadPixels) && !loadSound));
	assign _ramOE = ~((cpu_ram_access && _cpuRW) || va_ram_access);
	assign _ramWE = ~(cpu_ram_access && !_cpuRW);
	assign _memoryUDS = (va_ram_access ? 1'b0 : _cpuUDS);
	assign _memoryLDS = (va_ram_access ? 1'b0 : _cpuLDS);
	wire [20:0] addrMux = (loadPixels ? videoAddr : (loadSound ? audioAddr : cpuAddr[21:1]));
	assign ramAddr = {(configRAMSize != 2'b11 ? 2'b00 : addrMux[20:19]), (configRAMSize[1] == 1'b0 ? 1'b0 : addrMux[18]), (configRAMSize == 2'b00 ? 2'b00 : addrMux[17:16]), addrMux[15:0]};
	assign romAddr = {(configROMSize != 2'b11 ? 1'b0 : cpuAddr[18]), (configROMSize == 2'b01 ? 1'b0 : (configROMSize == 2'b00 ? 1'b1 : cpuAddr[17])), (configROMSize == 2'b00 ? 1'b0 : cpuAddr[16]), cpuAddr[15:1]};
	addrDecoder ad(
		.configROMSize(configROMSize),
		.address(cpuAddr),
		._cpuAS(_cpuAS),
		.memoryOverlayOn(memoryOverlayOn),
		.selectRAM(selectRAM),
		.selectROM(selectROM),
		.selectSCSI(selectSCSI),
		.selectSCC(selectSCC),
		.selectIWM(selectIWM),
		.selectVIA(selectVIA),
		.selectSEOverlay(selectSEOverlay)
	);
	videoTimer vt(
		.clk(clk),
		.clk8_en_p(clk8_en_p),
		.clk8_en_n(clk8_en_n),
		.videoCycle(videoBusControl),
		.vid_alt(vid_alt),
		.videoAddr(videoAddr),
		.hsync(hsync),
		.vsync(vsync),
		._hblank(_hblank),
		._vblank(_vblank),
		.refresh(refresh),
		.loadPixels(loadPixels)
	);
endmodule
