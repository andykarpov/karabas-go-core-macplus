module iwm (
	clk,
	cep,
	cen,
	_reset,
	selectIWM,
	_cpuRW,
	_cpuLDS,
	dataIn,
	cpuAddr,
	SEL,
	driveSel,
	diskWProt,
	dataOut,
	diskLED,
	sd_img_size,
	sd_img_mounted,
	sd_lba,
	sd_rd,
	sd_wr,
	sd_done,
	sd_busy,
	sd_data_in,
	sd_data_out,
	sd_data_en,
	sd_addr
);
	input clk;
	input cep;
	input cen;
	input _reset;
	input selectIWM;
	input _cpuRW;
	input _cpuLDS;
	input [15:0] dataIn;
	input [3:0] cpuAddr;
	input SEL;
	input driveSel;
	input [1:0] diskWProt;
	output wire [15:0] dataOut;
	output wire [2:0] diskLED;
	input [31:0] sd_img_size;
	input [1:0] sd_img_mounted;
	output wire [10:0] sd_lba;
	output wire [1:0] sd_rd;
	output wire [1:0] sd_wr;
	input sd_done;
	input sd_busy;
	input [7:0] sd_data_in;
	output wire [7:0] sd_data_out;
	input sd_data_en;
	input [8:0] sd_addr;
	reg selectExternalDrive;
	wire [1:0] diskEject;
	wire [1:0] diskSides;
	wire [1:0] insertDisk;
	wire [1:0] diskAct;
	wire [1:0] diskMotor;
	wire [1:0] driveMask = (selectExternalDrive ? 2'b10 : 2'b01);
	wire dirty;
	assign diskLED = {dirty, ((driveMask & insertDisk) & diskAct) & diskMotor};
	wire errorInt;
	wire errorExt;
	wire sideInt;
	wire sideExt;
	wire [6:0] trackInt;
	wire [6:0] trackExt;
	wire ready;
	wire readyInt = (selectExternalDrive ? 1'b0 : ready);
	wire readyExt = (selectExternalDrive ? ready : 1'b0);
	wire [7:0] data;
	wire [3:0] spt;
	wire [13:0] addrInt;
	wire [13:0] addrExt;
	wire [13:0] addr = (selectExternalDrive ? addrExt : addrInt);
	reg [7:0] writeData;
	reg writeDataStrobe;
	wire [7:0] writeDataDecodedInt;
	wire [7:0] writeDataDecodedExt;
	wire [7:0] writeDataDecoded = (selectExternalDrive ? writeDataDecodedExt : writeDataDecodedInt);
	wire [8:0] writeAddrInt;
	wire [8:0] writeAddrExt;
	wire [8:0] writeAddr = (selectExternalDrive ? writeAddrExt : writeAddrInt);
	wire [3:0] writeSectorInt;
	wire [3:0] writeSectorExt;
	wire [3:0] writeSector = (selectExternalDrive ? writeSectorExt : writeSectorInt);
	wire writeStrobeInt;
	wire writeStrobeExt;
	wire writeStrobe = (selectExternalDrive ? writeStrobeExt : writeStrobeInt);
	reg select0;
	reg select;
	reg selectIWMD;
	always @(posedge clk)
		if (cen) begin
			selectIWMD <= selectIWM;
			select0 <= selectIWM && !selectIWMD;
			if (_cpuRW)
				select <= selectIWM && !selectIWMD;
			else
				select <= select0;
		end
	reg [31:0] act_cnt;
	wire activity = act_cnt != 32'd0;
	always @(posedge clk)
		if (!_reset)
			act_cnt <= 32'd0;
		else if (cen) begin
			if (diskAct != 2'b00)
				act_cnt <= 32'd8000000;
			else if (act_cnt != 32'd0)
				act_cnt <= act_cnt - 32'd1;
		end
	floppy_track_buffer fb(
		.clk(clk),
		.rst(!_reset),
		.inserted(insertDisk),
		.eject(diskEject),
		.activity(activity),
		.drive(selectExternalDrive),
		.sides(diskSides),
		.side((selectExternalDrive ? sideExt : sideInt)),
		.track((selectExternalDrive ? trackExt : trackInt)),
		.addr(addr),
		.data(data),
		.spt(spt),
		.ready(ready),
		.dirty(dirty),
		.writeDataDecoded(writeDataDecoded),
		.writeAddr(writeAddr),
		.writeSector(writeSector),
		.writeStrobe(writeStrobe),
		.sd_img_size(sd_img_size),
		.sd_img_mounted(sd_img_mounted),
		.sd_lba(sd_lba),
		.sd_rd(sd_rd),
		.sd_wr(sd_wr),
		.sd_busy(sd_busy),
		.sd_done(sd_done),
		.sd_data_in(sd_data_in),
		.sd_data_out(sd_data_out),
		.sd_data_en(sd_data_en),
		.sd_addr(sd_addr)
	);
	reg [2:0] ca;
	reg lstrb;
	reg [7:6] q;
	wire advanceDriveHead;
	reg [7:0] readDataLatch;
	wire _iwmBusy;
	wire _writeUnderrun;
	reg diskEnable;
	wire newByteReadyInt;
	wire newByteReadyExt;
	wire newByteReady = (selectExternalDrive ? newByteReadyExt : newByteReadyInt);
	wire [7:0] readDataInt;
	wire [7:0] readDataExt;
	wire [7:0] readData = (selectExternalDrive ? readDataExt : readDataInt);
	floppy floppyInt(
		.clk(clk),
		.cep(cep),
		.cen(cen),
		._reset(_reset),
		.ca(ca),
		.SEL(SEL),
		.lstrb(lstrb),
		._enable(~((!selectExternalDrive & diskEnable) & driveSel)),
		.writeData(writeData),
		.writeDataStrobe(!selectExternalDrive & writeDataStrobe),
		.writeDataDecoded(writeDataDecodedInt),
		.writeAddr(writeAddrInt),
		.writeSector(writeSectorInt),
		.writeStrobe(writeStrobeInt),
		.readData(readDataInt),
		.advanceDriveHead(advanceDriveHead),
		.newByteReady(newByteReadyInt),
		.insertDisk(insertDisk[0]),
		.diskSides(diskSides[0]),
		.diskEject(diskEject[0]),
		.diskWProt(diskWProt[0]),
		.motor(diskMotor[0]),
		.act(diskAct[0]),
		.error(errorInt),
		.trackSide(sideInt),
		.trackIndex(trackInt),
		.trackReady(readyInt),
		.trackAddr(addrInt),
		.trackData(data),
		.trackSpt(spt)
	);
	floppy floppyExt(
		.clk(clk),
		.cep(cep),
		.cen(cen),
		._reset(_reset),
		.ca(ca),
		.SEL(SEL),
		.lstrb(lstrb),
		._enable(~(selectExternalDrive && diskEnable)),
		.writeData(writeData),
		.writeDataStrobe(selectExternalDrive & writeDataStrobe),
		.writeDataDecoded(writeDataDecodedExt),
		.writeAddr(writeAddrExt),
		.writeSector(writeSectorExt),
		.writeStrobe(writeStrobeExt),
		.readData(readDataExt),
		.advanceDriveHead(advanceDriveHead),
		.newByteReady(newByteReadyExt),
		.insertDisk(insertDisk[1]),
		.diskSides(diskSides[1]),
		.diskEject(diskEject[1]),
		.diskWProt(diskWProt[1]),
		.motor(diskMotor[1]),
		.act(diskAct[1]),
		.error(errorExt),
		.trackSide(sideExt),
		.trackIndex(trackExt),
		.trackReady(readyExt),
		.trackAddr(addrExt),
		.trackData(data),
		.trackSpt(spt)
	);
	reg writeBusy;
	assign _iwmBusy = !writeBusy;
	assign _writeUnderrun = 1'b1;
	reg [4:0] iwmMode;
	always @(posedge clk)
		if (!_reset) begin
			ca <= 3'b000;
			lstrb <= 1'b0;
			diskEnable <= 0;
			selectExternalDrive <= 0;
			q <= 2'b00;
		end
		else if (cen) begin
			if (selectIWM && !_cpuLDS)
				case (cpuAddr[3:1])
					3'h0: ca[0] <= cpuAddr[0];
					3'h1: ca[1] <= cpuAddr[0];
					3'h2: ca[2] <= cpuAddr[0];
					3'h3: lstrb <= cpuAddr[0];
					3'h4: diskEnable <= cpuAddr[0];
					3'h5: selectExternalDrive <= cpuAddr[0];
					3'h6: q[6] <= cpuAddr[0];
					3'h7: q[7] <= cpuAddr[0];
				endcase
		end
	assign dataOut = {8'hbe, (q == 2'b00 ? readDataLatch : (q == 2'b01 ? {readData[7], 1'b0, diskEnable, iwmMode} : (q == 2'b10 ? {_iwmBusy, _writeUnderrun, 6'b000000} : 8'h00)))};
	always @(posedge clk or negedge _reset)
		if (!_reset) begin
			iwmMode <= 0;
			writeBusy <= 1'b0;
			writeDataStrobe <= 1'b0;
		end
		else if (cen) begin
			if (newByteReady)
				writeBusy <= 1'b0;
			if ((!_cpuRW && select) && !_cpuLDS)
				case (q)
					2'b11:
						if (diskEnable) begin
							writeData <= dataIn[7:0];
							writeDataStrobe <= !writeDataStrobe;
							writeBusy <= 1'b1;
						end
						else
							iwmMode <= dataIn[4:0];
				endcase
		end
	reg [3:0] readLatchClearTimer;
	always @(posedge clk or negedge _reset)
		if (!_reset) begin
			readDataLatch <= 0;
			readLatchClearTimer <= 0;
		end
		else if (cen) begin
			if (readLatchClearTimer != 0)
				readLatchClearTimer <= readLatchClearTimer - 4'd1;
			if (((_cpuRW && selectIWM) && !_cpuLDS) && readDataLatch[7])
				readLatchClearTimer <= 4'd14;
			if (newByteReady)
				readDataLatch <= readData;
			else if (readLatchClearTimer == 4'd1)
				readDataLatch <= 0;
		end
	assign advanceDriveHead = readLatchClearTimer == 4'd1;
endmodule
