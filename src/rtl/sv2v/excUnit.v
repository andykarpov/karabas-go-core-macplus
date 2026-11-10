module excUnit (
	Clks,
	enT1,
	enT2,
	enT3,
	enT4,
	Nanod,
	Irdecod,
	Ird,
	pswS,
	ftu,
	iEdb,
	ccr,
	alue,
	prenEmpty,
	au05z,
	dcr4,
	ze,
	aob0,
	AblOut,
	Irc,
	oEdb,
	eab
);
	reg _sv2v_0;
	input wire [4:0] Clks;
	input enT1;
	input enT2;
	input enT3;
	input enT4;
	input wire [104:0] Nanod;
	input wire [41:0] Irdecod;
	input [15:0] Ird;
	input pswS;
	input [15:0] ftu;
	input [15:0] iEdb;
	output wire [7:0] ccr;
	output wire [15:0] alue;
	output wire prenEmpty;
	output wire au05z;
	output reg dcr4;
	output wire ze;
	output wire aob0;
	output wire [15:0] AblOut;
	output wire [15:0] Irc;
	output wire [15:0] oEdb;
	output wire [23:1] eab;
	localparam REG_USP = 15;
	localparam REG_SSP = 16;
	localparam REG_DT = 17;
	reg [15:0] regs68L [0:17];
	reg [15:0] regs68H [0:17];
	initial begin : sv2v_autoblock_1
		reg signed [31:0] i;
		for (i = 0; i < 18; i = i + 1)
			begin
				regs68L[i] <= 1'sb0;
				regs68H[i] <= 1'sb0;
			end
	end
	wire [31:0] SSP = {regs68H[REG_SSP], regs68L[REG_SSP]};
	wire [15:0] aluOut;
	wire [15:0] dbin;
	reg [15:0] dcrOutput;
	reg [15:0] PcL;
	reg [15:0] PcH;
	reg [31:0] auReg;
	reg [31:0] aob;
	reg [15:0] Ath;
	reg [15:0] Atl;
	reg [15:0] Dbl;
	reg [15:0] Dbh;
	reg [15:0] Abh;
	reg [15:0] Abl;
	reg [15:0] Abd;
	reg [15:0] Dbd;
	assign AblOut = Abl;
	assign au05z = ~|auReg[5:0];
	reg [15:0] dblMux;
	reg [15:0] dbhMux;
	reg [15:0] abhMux;
	reg [15:0] ablMux;
	reg [15:0] abdMux;
	reg [15:0] dbdMux;
	reg abdIsByte;
	reg Pcl2Dbl;
	reg Pch2Dbh;
	reg Pcl2Abl;
	reg Pch2Abh;
	reg [4:0] actualRx;
	reg [4:0] actualRy;
	reg [3:0] movemRx;
	reg byteNotSpAlign;
	reg [4:0] rxMux;
	reg [4:0] ryMux;
	reg [3:0] rxReg;
	reg [3:0] ryReg;
	reg rxIsSp;
	reg ryIsSp;
	reg rxIsAreg;
	reg ryIsAreg;
	always @(*) begin
		if (_sv2v_0)
			;
		if (Nanod[50]) begin
			rxMux = REG_SSP;
			rxIsSp = 1'b1;
			rxReg = 1'bx;
		end
		else if (Irdecod[35]) begin
			rxMux = REG_USP;
			rxIsSp = 1'b1;
			rxReg = 1'bx;
		end
		else if (Irdecod[37] & !Irdecod[39]) begin
			rxMux = REG_DT;
			rxIsSp = 1'b0;
			rxReg = 1'bx;
		end
		else begin
			if (Irdecod[39])
				rxReg = 15;
			else if (Irdecod[34])
				rxReg = movemRx;
			else
				rxReg = {Irdecod[24], Irdecod[30-:3]};
			if (&rxReg) begin
				rxMux = (pswS ? REG_SSP : 15);
				rxIsSp = 1'b1;
			end
			else begin
				rxMux = {1'b0, rxReg};
				rxIsSp = 1'b0;
			end
		end
		if (Irdecod[36] & !Nanod[29]) begin
			ryMux = REG_DT;
			ryIsSp = 1'b0;
			ryReg = 1'sbx;
		end
		else begin
			ryReg = (Nanod[29] ? Irc[15:12] : {Irdecod[23], Irdecod[27-:3]});
			ryIsSp = &ryReg;
			if (ryIsSp & pswS)
				ryMux = REG_SSP;
			else
				ryMux = {1'b0, ryReg};
		end
	end
	always @(posedge Clks[4]) begin
		if (enT4) begin
			byteNotSpAlign <= Irdecod[32] & ~(Nanod[28] ? rxIsSp : ryIsSp);
			actualRx <= rxMux;
			actualRy <= ryMux;
			rxIsAreg <= rxIsSp | rxMux[3];
			ryIsAreg <= ryIsSp | ryMux[3];
		end
		if (enT4)
			abdIsByte <= Nanod[0] & Irdecod[32];
	end
	wire ryl2Abl = Nanod[34] & (ryIsAreg | Nanod[4]);
	wire ryl2Abd = Nanod[34] & (~ryIsAreg | Nanod[4]);
	wire ryl2Dbl = Nanod[35] & (ryIsAreg | Nanod[2]);
	wire ryl2Dbd = Nanod[35] & (~ryIsAreg | Nanod[2]);
	wire rxl2Abl = Nanod[40] & (rxIsAreg | Nanod[4]);
	wire rxl2Abd = Nanod[40] & (~rxIsAreg | Nanod[4]);
	wire rxl2Dbl = Nanod[41] & (rxIsAreg | Nanod[2]);
	wire rxl2Dbd = Nanod[41] & (~rxIsAreg | Nanod[2]);
	reg abhIdle;
	reg ablIdle;
	reg abdIdle;
	reg dbhIdle;
	reg dblIdle;
	reg dbdIdle;
	always @(*) begin
		if (_sv2v_0)
			;
		{abhIdle, ablIdle, abdIdle} = 1'sb0;
		{dbhIdle, dblIdle, dbdIdle} = 1'sb0;
		(* full_case, parallel_case *)
		case (1'b1)
			ryl2Dbd: dbdMux = regs68L[actualRy];
			rxl2Dbd: dbdMux = regs68L[actualRx];
			Nanod[16]: dbdMux = alue;
			Nanod[7]: dbdMux = dbin;
			Nanod[13]: dbdMux = aluOut;
			Nanod[18]: dbdMux = dcrOutput;
			default: begin
				dbdMux = 1'sbx;
				dbdIdle = 1'b1;
			end
		endcase
		(* full_case, parallel_case *)
		case (1'b1)
			rxl2Dbl: dblMux = regs68L[actualRx];
			ryl2Dbl: dblMux = regs68L[actualRy];
			Nanod[93]: dblMux = ftu;
			Nanod[11]: dblMux = auReg[15:0];
			Nanod[70]: dblMux = Atl;
			Pcl2Dbl: dblMux = PcL;
			default: begin
				dblMux = 1'sbx;
				dblIdle = 1'b1;
			end
		endcase
		(* full_case, parallel_case *)
		case (1'b1)
			Nanod[45]: dbhMux = regs68H[actualRx];
			Nanod[33]: dbhMux = regs68H[actualRy];
			Nanod[11]: dbhMux = auReg[31:16];
			Nanod[67]: dbhMux = Ath;
			Pch2Dbh: dbhMux = PcH;
			default: begin
				dbhMux = 1'sbx;
				dbhIdle = 1'b1;
			end
		endcase
		(* full_case, parallel_case *)
		case (1'b1)
			ryl2Abd: abdMux = regs68L[actualRy];
			rxl2Abd: abdMux = regs68L[actualRx];
			Nanod[8]: abdMux = dbin;
			Nanod[12]: abdMux = aluOut;
			default: begin
				abdMux = 1'sbx;
				abdIdle = 1'b1;
			end
		endcase
		(* full_case, parallel_case *)
		case (1'b1)
			Pcl2Abl: ablMux = PcL;
			rxl2Abl: ablMux = regs68L[actualRx];
			ryl2Abl: ablMux = regs68L[actualRy];
			Nanod[92]: ablMux = ftu;
			Nanod[10]: ablMux = auReg[15:0];
			Nanod[62]: ablMux = aob[15:0];
			Nanod[71]: ablMux = Atl;
			default: begin
				ablMux = 1'sbx;
				ablIdle = 1'b1;
			end
		endcase
		(* full_case, parallel_case *)
		case (1'b1)
			Pch2Abh: abhMux = PcH;
			Nanod[44]: abhMux = regs68H[actualRx];
			Nanod[32]: abhMux = regs68H[actualRy];
			Nanod[10]: abhMux = auReg[31:16];
			Nanod[62]: abhMux = aob[31:16];
			Nanod[66]: abhMux = Ath;
			default: begin
				abhMux = 1'sbx;
				abhIdle = 1'b1;
			end
		endcase
	end
	reg [15:0] preAbh;
	reg [15:0] preAbl;
	reg [15:0] preAbd;
	reg [15:0] preDbh;
	reg [15:0] preDbl;
	reg [15:0] preDbd;
	always @(posedge Clks[4]) begin
		if (enT1) begin
			{preAbh, preAbl, preAbd} <= {abhMux, ablMux, abdMux};
			{preDbh, preDbl, preDbd} <= {dbhMux, dblMux, dbdMux};
		end
		if (enT2) begin
			if (Nanod[5])
				Abh <= {16 {(ablIdle ? preAbd[15] : preAbl[15])}};
			else if (abhIdle)
				Abh <= (ablIdle ? preAbd : preAbl);
			else
				Abh <= preAbh;
			if (~ablIdle)
				Abl <= preAbl;
			else
				Abl <= (Nanod[3] ? preAbh : preAbd);
			Abd <= (~abdIdle ? preAbd : (ablIdle ? preAbh : preAbl));
			if (Nanod[6])
				Dbh <= {16 {(dblIdle ? preDbd[15] : preDbl[15])}};
			else if (dbhIdle)
				Dbh <= (dblIdle ? preDbd : preDbl);
			else
				Dbh <= preDbh;
			if (~dblIdle)
				Dbl <= preDbl;
			else
				Dbl <= (Nanod[1] ? preDbh : preDbd);
			Dbd <= (~dbdIdle ? preDbd : (dblIdle ? preDbh : preDbl));
		end
	end
	wire au2Aob = Nanod[63] | (Nanod[11] & Nanod[65]);
	always @(posedge Clks[4])
		if (enT1 & au2Aob)
			aob <= auReg;
		else if (enT2) begin
			if (Nanod[65])
				aob <= {preDbh, (~dblIdle ? preDbl : preDbd)};
			else if (Nanod[64])
				aob <= {preAbh, (~ablIdle ? preAbl : preAbd)};
		end
	assign eab = aob[23:1];
	assign aob0 = aob[0];
	reg [31:0] auInpMux;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (Nanod[78-:3])
			3'b000: auInpMux = 0;
			3'b001: auInpMux = (byteNotSpAlign | Nanod[79] ? 1 : 2);
			3'b010: auInpMux = -4;
			3'b011: auInpMux = {Abh, Abl};
			3'b100: auInpMux = 2;
			3'b101: auInpMux = 4;
			3'b110: auInpMux = -2;
			3'b111: auInpMux = (byteNotSpAlign | Nanod[79] ? -1 : -2);
			default: auInpMux = 1'sbx;
		endcase
	end
	wire [16:0] aulow = Dbl + auInpMux[15:0];
	wire [31:0] auResult = {(Dbh + auInpMux[31:16]) + aulow[16], aulow[15:0]};
	always @(posedge Clks[4])
		if (Clks[2])
			auReg <= 1'sb0;
		else if (enT3 & Nanod[80])
			auReg <= auResult;
	always @(posedge Clks[4])
		if (enT3) begin
			if (Nanod[43] | Nanod[39]) begin
				if (~rxIsAreg) begin
					if (Nanod[43])
						regs68L[actualRx] <= Dbd;
					else if (abdIsByte)
						regs68L[actualRx][7:0] <= Abd[7:0];
					else
						regs68L[actualRx] <= Abd;
				end
				else
					regs68L[actualRx] <= (Nanod[43] ? Dbl : Abl);
			end
			if (Nanod[31] | Nanod[30]) begin
				if (~ryIsAreg) begin
					if (Nanod[31])
						regs68L[actualRy] <= Dbd;
					else if (abdIsByte)
						regs68L[actualRy][7:0] <= Abd[7:0];
					else
						regs68L[actualRy] <= Abd;
				end
				else
					regs68L[actualRy] <= (Nanod[31] ? Dbl : Abl);
			end
			if (Nanod[42] | Nanod[38])
				regs68H[actualRx] <= (Nanod[42] ? Dbh : Abh);
			if (Nanod[37] | Nanod[36])
				regs68H[actualRy] <= (Nanod[37] ? Dbh : Abh);
		end
	reg dbl2Pcl;
	reg dbh2Pch;
	reg abh2Pch;
	reg abl2Pcl;
	always @(posedge Clks[4]) begin
		if (Clks[3]) begin
			{dbl2Pcl, dbh2Pch, abh2Pch, abl2Pcl} <= 1'sb0;
			Pcl2Dbl <= 1'b0;
			Pch2Dbh <= 1'b0;
			Pcl2Abl <= 1'b0;
			Pch2Abh <= 1'b0;
		end
		else if (enT4) begin
			dbl2Pcl <= Nanod[53] & Nanod[48];
			dbh2Pch <= Nanod[54] & Nanod[49];
			abh2Pch <= Nanod[58] & Nanod[46];
			abl2Pcl <= Nanod[57] & Nanod[47];
			Pcl2Dbl <= Nanod[52] & Nanod[48];
			Pch2Dbh <= Nanod[51] & Nanod[49];
			Pcl2Abl <= Nanod[56] & Nanod[47];
			Pch2Abh <= Nanod[55] & Nanod[46];
		end
		if (enT1 & Nanod[9])
			PcL <= auReg[15:0];
		else if (enT3) begin
			if (dbl2Pcl)
				PcL <= Dbl;
			else if (abl2Pcl)
				PcL <= Abl;
		end
		if (enT1 & Nanod[9])
			PcH <= auReg[31:16];
		else if (enT3) begin
			if (dbh2Pch)
				PcH <= Dbh;
			else if (abh2Pch)
				PcH <= Abh;
		end
		if (enT3) begin
			if (Nanod[73])
				Atl <= Dbl;
			else if (Nanod[72])
				Atl <= Abl;
		end
		if (enT3) begin
			if (Nanod[69])
				Ath <= Abh;
			else if (Nanod[68])
				Ath <= Dbh;
		end
	end
	wire rmIdle;
	wire [3:0] prHbit;
	reg [15:0] prenLatch;
	assign prenEmpty = ~|prenLatch;
	pren rmPren(
		.mask(prenLatch),
		.hbit(prHbit)
	);
	always @(posedge Clks[4])
		if (enT1 & Nanod[91])
			prenLatch <= dbin;
		else if (enT3 & Nanod[90]) begin
			prenLatch[prHbit] <= 1'b0;
			movemRx <= (Irdecod[33] ? ~prHbit : prHbit);
		end
	wire [15:0] dcrCode;
	wire [3:0] dcrInput = (abdIsByte ? {1'b0, Abd[2:0]} : Abd[3:0]);
	onehotEncoder4 dcrDecoder(
		.bin(dcrInput),
		.bitMap(dcrCode)
	);
	always @(posedge Clks[4])
		if (Clks[2])
			dcr4 <= 1'sb0;
		else if (enT3 & Nanod[19]) begin
			dcrOutput <= dcrCode;
			dcr4 <= Abd[4];
		end
	reg [15:0] alub;
	always @(posedge Clks[4])
		if (enT3) begin
			if (Nanod[15])
				alub <= Dbd;
			else if (Nanod[14])
				alub <= Abd;
		end
	wire alueClkEn = enT3 & Nanod[17];
	reg [15:0] dobInput;
	wire dobIdle = ~|Nanod[60-:2];
	localparam NANO_DOB_ADB = 2'b10;
	localparam NANO_DOB_ALU = 2'b11;
	localparam NANO_DOB_DBD = 2'b01;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (Nanod[60-:2])
			NANO_DOB_ADB: dobInput = Abd;
			NANO_DOB_DBD: dobInput = Dbd;
			NANO_DOB_ALU: dobInput = aluOut;
			default: dobInput = 1'sbx;
		endcase
	end
	dataIo dataIo(
		.Clks(Clks),
		.enT1(enT1),
		.enT2(enT2),
		.enT3(enT3),
		.enT4(enT4),
		.Nanod(Nanod),
		.Irdecod(Irdecod),
		.iEdb(iEdb),
		.dobIdle(dobIdle),
		.dobInput(dobInput),
		.aob0(aob0),
		.Irc(Irc),
		.dbin(dbin),
		.oEdb(oEdb)
	);
	fx68kAlu alu(
		.clk(Clks[4]),
		.pwrUp(Clks[2]),
		.enT1(enT1),
		.enT3(enT3),
		.enT4(enT4),
		.ird(Ird),
		.aluColumn(Nanod[27-:3]),
		.aluAddrCtrl(Nanod[22]),
		.init(Nanod[21]),
		.finish(Nanod[20]),
		.aluIsByte(Irdecod[32]),
		.ftu2Ccr(Nanod[86]),
		.alub(alub),
		.ftu(ftu),
		.alueClkEn(alueClkEn),
		.alue(alue),
		.aluDataCtrl(Nanod[24-:2]),
		.iDataBus(Dbd),
		.iAddrBus(Abd),
		.ze(ze),
		.aluOut(aluOut),
		.ccr(ccr)
	);
	initial _sv2v_0 = 0;
endmodule
