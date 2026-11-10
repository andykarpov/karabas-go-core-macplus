module floppy (
	clk,
	cep,
	cen,
	_reset,
	ca,
	SEL,
	lstrb,
	_enable,
	readData,
	writeData,
	writeDataStrobe,
	writeDataDecoded,
	writeAddr,
	writeSector,
	writeStrobe,
	advanceDriveHead,
	newByteReady,
	insertDisk,
	diskSides,
	diskEject,
	diskWProt,
	motor,
	act,
	error,
	trackSide,
	trackIndex,
	trackAddr,
	trackData,
	trackSpt,
	trackReady
);
	input clk;
	input cep;
	input cen;
	input _reset;
	input [2:0] ca;
	input SEL;
	input lstrb;
	input _enable;
	output wire [7:0] readData;
	input [7:0] writeData;
	input writeDataStrobe;
	output wire [7:0] writeDataDecoded;
	output wire [8:0] writeAddr;
	output wire [3:0] writeSector;
	output wire writeStrobe;
	input advanceDriveHead;
	output reg newByteReady;
	input insertDisk;
	input diskSides;
	output wire diskEject;
	input diskWProt;
	output wire motor;
	output wire act;
	output wire error;
	output wire trackSide;
	output wire [6:0] trackIndex;
	output wire [13:0] trackAddr;
	input [7:0] trackData;
	input [3:0] trackSpt;
	input trackReady;
	reg [15:0] driveRegs;
	reg [6:0] driveTrack;
	reg driveSide;
	reg [7:0] diskDataIn;
	wire stepReady;
	assign motor = ~driveRegs[4];
	assign trackIndex = driveTrack;
	assign trackSide = driveSide;
	wire [15:0] driveRegsAsRead = {8'b00010000, driveRegs[7], 1'b0, ~(driveTrack == 7'h00), driveRegs[4], ~diskWProt, stepReady, driveRegs[1], driveRegs[0]};
	wire [7:0] dskReadDataEnc;
	reg old_newByteReady;
	always @(posedge clk) old_newByteReady <= newByteReady;
	floppy_track_codec codec(
		.clk(clk),
		.en(cen),
		.ready((~old_newByteReady & newByteReady) & trackReady),
		.rst(!_reset),
		.side(driveSide),
		.sides(diskSides),
		.track(driveTrack),
		.addr(trackAddr),
		.data(trackData),
		.spt(trackSpt),
		.odata(dskReadDataEnc),
		.writeData(writeData),
		.writeDataStrobe(writeDataStrobe),
		.error(error),
		.writeDataDecoded(writeDataDecoded),
		.writeAddr(writeAddr),
		.writeSector(writeSector),
		.writeStrobe(writeStrobe)
	);
	wire [3:0] driveReadAddr = {ca, SEL};
	reg [6:0] diskDataByteTimer;
	reg [7:0] diskImageData;
	reg readyToAdvanceHead;
	always @(posedge clk or negedge _reset)
		if (_reset == 0) begin
			driveSide <= 0;
			diskImageData <= 8'h00;
			diskDataIn <= 8'hff;
			diskDataByteTimer <= 0;
			readyToAdvanceHead <= 1;
			newByteReady <= 1'b0;
		end
		else if (cep) begin
			if (((diskDataByteTimer == 0) && readyToAdvanceHead) && (diskImageData != 0)) begin
				diskDataIn <= diskImageData;
				newByteReady <= 1;
				diskDataByteTimer <= 1;
				diskImageData <= 0;
				readyToAdvanceHead <= 1'b1;
			end
			else begin
				diskDataByteTimer <= diskDataByteTimer + 1'b1;
				newByteReady <= 1'b0;
				if (diskDataByteTimer == 1)
					diskImageData <= dskReadDataEnc;
				if (advanceDriveHead)
					readyToAdvanceHead <= 1'b1;
			end
			if ((driveReadAddr == 8) && (lstrb == 1'b0))
				driveSide <= 0;
			if ((driveReadAddr == 9) && (lstrb == 1'b0))
				driveSide <= 1;
		end
	reg lstrbPrev;
	always @(posedge clk)
		if (cep)
			lstrbPrev <= lstrb;
	wire lstrbEdge = (lstrb == 1'b0) && (lstrbPrev == 1'b1);
	reg [15:0] act_cnt;
	assign act = act_cnt != 0;
	always @(posedge clk)
		if (cep) begin
			if (lstrbEdge)
				act_cnt <= 16'hffff;
			else if (act_cnt)
				act_cnt <= act_cnt - 16'd1;
		end
	assign readData = (_enable ? 8'hff : ((driveReadAddr == 8) || (driveReadAddr == 9) ? diskDataIn : {driveRegsAsRead[driveReadAddr], 7'h00}));
	wire [2:0] driveWriteAddr = {ca[1:0], SEL};
	always @(posedge clk or negedge _reset)
		if (_reset == 1'b0)
			driveRegs[0] <= 1'b0;
		else if (((cep && (_enable == 1'b0)) && (lstrbEdge == 1'b1)) && (driveWriteAddr == 0))
			driveRegs[0] <= ca[2];
	reg [7:0] ejectIndicatorTimer;
	assign diskEject = ejectIndicatorTimer != 0;
	always @(posedge clk or negedge _reset)
		if (_reset == 1'b0) begin
			driveRegs[1] <= 1'b1;
			ejectIndicatorTimer <= 8'd0;
		end
		else if (cep) begin
			if ((((_enable == 1'b0) && (lstrbEdge == 1'b1)) && (driveWriteAddr == 6)) && ca[2]) begin
				driveRegs[1] <= 1'b1;
				ejectIndicatorTimer <= 8'hff;
			end
			else if (insertDisk)
				driveRegs[1] <= 1'b0;
			else if (ejectIndicatorTimer != 0)
				ejectIndicatorTimer <= ejectIndicatorTimer - 8'd1;
		end
	reg [31:0] stepBusy;
	assign stepReady = stepBusy == 16'd0;
	always @(posedge clk or negedge _reset)
		if (_reset == 1'b0) begin
			driveTrack <= 0;
			stepBusy <= 16'd0;
		end
		else if ((((cep && (_enable == 1'b0)) && (lstrbEdge == 1'b1)) && (driveWriteAddr == 2)) && (ca[2] == 1'b0)) begin
			stepBusy <= 2400;
			if ((driveRegs[0] == 1'b0) && (driveTrack != 7'h4f))
				driveTrack <= driveTrack + 1'b1;
			if ((driveRegs[0] == 1'b1) && (driveTrack != 0))
				driveTrack <= driveTrack - 1'b1;
		end
		else if (cep && stepBusy)
			stepBusy <= stepBusy - 16'd1;
	always @(posedge clk or negedge _reset)
		if (_reset == 1'b0)
			driveRegs[4] <= 1'b1;
		else if (((cep && (_enable == 1'b0)) && (lstrbEdge == 1'b1)) && (driveWriteAddr == 4))
			driveRegs[4] <= ca[2];
	reg [13:0] driveTachTimer;
	reg [13:0] driveTachPeriod;
	always @(*)
		case (driveTrack[6:4])
			0: driveTachPeriod <= 9996;
			1: driveTachPeriod <= 9122;
			2: driveTachPeriod <= 8292;
			3: driveTachPeriod <= 7463;
			default: driveTachPeriod <= 6634;
		endcase
	always @(posedge clk or negedge _reset)
		if (_reset == 1'b0) begin
			driveRegs[7] <= 1'b0;
			driveTachTimer <= 0;
		end
		else if (cep) begin
			if (driveTachTimer == driveTachPeriod) begin
				driveTachTimer <= 0;
				driveRegs[7] <= ~driveRegs[7];
			end
			else
				driveTachTimer <= driveTachTimer + 1'b1;
		end
endmodule
