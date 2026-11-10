module fx68k (
	clk,
	HALTn,
	extReset,
	pwrUp,
	enPhi1,
	enPhi2,
	eRWn,
	ASn,
	LDSn,
	UDSn,
	E,
	VMAn,
	E_div,
	E_PosClkEn,
	E_NegClkEn,
	FC0,
	FC1,
	FC2,
	BGn,
	oRESETn,
	oHALTEDn,
	DTACKn,
	VPAn,
	BERRn,
	BRn,
	BGACKn,
	IPL0n,
	IPL1n,
	IPL2n,
	iEdb,
	oEdb,
	eab
);
	reg _sv2v_0;
	input clk;
	input HALTn;
	input extReset;
	input pwrUp;
	input enPhi1;
	input enPhi2;
	output wire eRWn;
	output wire ASn;
	output wire LDSn;
	output wire UDSn;
	output reg E;
	output wire VMAn;
	input E_div;
	output wire E_PosClkEn;
	output wire E_NegClkEn;
	output wire FC0;
	output wire FC1;
	output wire FC2;
	output wire BGn;
	output wire oRESETn;
	output wire oHALTEDn;
	input DTACKn;
	input VPAn;
	input BERRn;
	input BRn;
	input BGACKn;
	input IPL0n;
	input IPL1n;
	input IPL2n;
	input [15:0] iEdb;
	output wire [15:0] oEdb;
	output wire [23:1] eab;
	wire [4:0] Clks;
	assign Clks[4] = clk;
	assign Clks[3] = extReset;
	assign Clks[2] = pwrUp;
	assign Clks[1] = enPhi1;
	assign Clks[0] = enPhi2;
	wire wClk;
	reg [31:0] tState;
	wire enT1 = (Clks[1] & (tState == 32'd4)) & ~wClk;
	wire enT2 = Clks[0] & (tState == 32'd1);
	wire enT3 = Clks[1] & (tState == 32'd2);
	wire enT4 = Clks[0] & ((tState == 32'd0) | (tState == 32'd3));
	always @(posedge Clks[4])
		if (Clks[2])
			tState <= 32'd0;
		else
			case (tState)
				32'd0:
					if (Clks[0])
						tState <= 32'd4;
				32'd1:
					if (Clks[0])
						tState <= 32'd2;
				32'd2:
					if (Clks[1])
						tState <= 32'd3;
				32'd3:
					if (Clks[0])
						tState <= 32'd4;
				32'd4:
					if (Clks[1])
						tState <= (wClk ? 32'd0 : 32'd1);
			endcase
	reg rDtack;
	reg rBerr;
	reg [2:0] rIpl;
	reg [2:0] iIpl;
	reg Vpai;
	reg BeI;
	reg Halti;
	reg BRi;
	reg BgackI;
	reg BeiDelay;
	wire BeDebounced = ~(BeI | BeiDelay);
	always @(posedge Clks[4])
		if (Clks[2]) begin
			rBerr <= 1'b0;
			BeI <= 1'b0;
		end
		else if (Clks[0]) begin
			rDtack <= DTACKn;
			rBerr <= BERRn;
			rIpl <= ~{IPL2n, IPL1n, IPL0n};
			iIpl <= rIpl;
		end
		else if (Clks[1]) begin
			Vpai <= VPAn;
			BeI <= rBerr;
			BeiDelay <= BeI;
			BgackI <= BGACKn;
			BRi <= BRn;
			Halti <= HALTn;
		end
	localparam NANO_WIDTH = 68;
	reg [67:0] nanoLatch;
	wire [67:0] nanoOutput;
	localparam UROM_WIDTH = 17;
	reg [16:0] microLatch;
	wire [16:0] microOutput;
	localparam UADDR_WIDTH = 10;
	reg [9:0] microAddr;
	wire [9:0] nma;
	localparam NADDR_WIDTH = 9;
	reg [8:0] nanoAddr;
	wire [8:0] orgAddr;
	wire rstUrom;
	microToNanoAddr microToNanoAddr(
		.uAddr(nma),
		.orgAddr(orgAddr)
	);
	nanoRom nanoRom(
		.clk(Clks[4]),
		.nanoAddr(nanoAddr),
		.nanoOutput(nanoOutput)
	);
	uRom uRom(
		.clk(Clks[4]),
		.microAddr(microAddr),
		.microOutput(microOutput)
	);
	localparam RSTP0_NMA = 'h2;
	always @(posedge Clks[4]) begin
		if (Clks[2]) begin
			microAddr <= RSTP0_NMA;
			nanoAddr <= RSTP0_NMA;
		end
		else if (enT1) begin
			microAddr <= nma;
			nanoAddr <= orgAddr;
		end
		if (Clks[3]) begin
			microLatch <= 1'sb0;
			nanoLatch <= 1'sb0;
		end
		else if (rstUrom) begin
			{microLatch[16], microLatch[15], microLatch[0]} <= 1'sb0;
			nanoLatch <= 1'sb0;
		end
		else if (enT3) begin
			microLatch <= microOutput;
			nanoLatch <= nanoOutput;
		end
	end
	wire [104:0] Nanod;
	wire [41:0] Irdecod;
	reg Tpend;
	reg intPend;
	reg pswT;
	reg pswS;
	reg [2:0] pswI;
	wire [7:0] ccr;
	wire [15:0] psw = {pswT, 1'b0, pswS, 2'b00, pswI, ccr};
	reg [15:0] ftu;
	reg [15:0] Irc;
	reg [15:0] Ir;
	reg [15:0] Ird;
	wire [15:0] alue;
	wire [15:0] Abl;
	wire prenEmpty;
	wire au05z;
	wire dcr4;
	wire ze;
	wire [9:0] a1;
	wire [9:0] a2;
	wire [9:0] a3;
	wire isPriv;
	wire isIllegal;
	wire isLineA;
	wire isLineF;
	always @(posedge Clks[4])
		if (enT1) begin
			if (Nanod[81])
				Ird <= Ir;
			else if (microLatch[0])
				Ir <= Irc;
		end
	wire [3:0] tvn;
	wire waitBusCycle;
	wire busStarting;
	wire BusRetry = 1'b0;
	wire busAddrErr;
	wire bciWrite;
	wire bgBlock;
	wire busAvail;
	wire addrOe;
	wire busIsByte = Nanod[101] & (Irdecod[32] | Irdecod[31]);
	wire aob0;
	reg iStop;
	reg A0Err;
	reg excRst;
	reg BerrA;
	reg Spuria;
	reg Avia;
	wire Iac;
	reg rAddrErr;
	reg iBusErr;
	reg Err6591;
	wire iAddrErr = rAddrErr & addrOe;
	wire enErrClk;
	assign rstUrom = Clks[1] & enErrClk;
	uaddrDecode uaddrDecode(
		.opcode(Ir),
		.a1(a1),
		.a2(a2),
		.a3(a3),
		.isPriv(isPriv),
		.isIllegal(isIllegal),
		.isLineA(isLineA),
		.isLineF(isLineF),
		.lineBmap()
	);
	sequencer sequencer(
		.Clks(Clks),
		.enT3(enT3),
		.microLatch(microLatch),
		.Ird(Ird),
		.A0Err(A0Err),
		.excRst(excRst),
		.BerrA(BerrA),
		.busAddrErr(busAddrErr),
		.Spuria(Spuria),
		.Avia(Avia),
		.Tpend(Tpend),
		.intPend(intPend),
		.isIllegal(isIllegal),
		.isPriv(isPriv),
		.isLineA(isLineA),
		.isLineF(isLineF),
		.nma(nma),
		.a1(a1),
		.a2(a2),
		.a3(a3),
		.tvn(tvn),
		.psw(psw),
		.prenEmpty(prenEmpty),
		.au05z(au05z),
		.dcr4(dcr4),
		.ze(ze),
		.alue01(alue[1:0]),
		.i11(Irc[11])
	);
	wire [16:1] sv2v_tmp_excUnit_Irc;
	always @(*) Irc = sv2v_tmp_excUnit_Irc;
	excUnit excUnit(
		.Clks(Clks),
		.Nanod(Nanod),
		.Irdecod(Irdecod),
		.enT1(enT1),
		.enT2(enT2),
		.enT3(enT3),
		.enT4(enT4),
		.Ird(Ird),
		.ftu(ftu),
		.iEdb(iEdb),
		.pswS(pswS),
		.prenEmpty(prenEmpty),
		.au05z(au05z),
		.dcr4(dcr4),
		.ze(ze),
		.AblOut(Abl),
		.eab(eab),
		.aob0(aob0),
		.Irc(sv2v_tmp_excUnit_Irc),
		.oEdb(oEdb),
		.alue(alue),
		.ccr(ccr)
	);
	nDecoder3 nDecoder(
		.Clks(Clks),
		.Nanod(Nanod),
		.Irdecod(Irdecod),
		.enT2(enT2),
		.enT4(enT4),
		.microLatch(microLatch),
		.nanoLatch(nanoLatch)
	);
	irdDecode irdDecode(
		.ird(Ird),
		.Irdecod(Irdecod)
	);
	busControl busControl(
		.Clks(Clks),
		.enT1(enT1),
		.enT4(enT4),
		.permStart(Nanod[104]),
		.permStop(Nanod[103]),
		.iStop(iStop),
		.aob0(aob0),
		.isWrite(Nanod[102]),
		.isRmc(Nanod[100]),
		.isByte(busIsByte),
		.busAvail(busAvail),
		.bciWrite(bciWrite),
		.addrOe(addrOe),
		.bgBlock(bgBlock),
		.waitBusCycle(waitBusCycle),
		.busStarting(busStarting),
		.busAddrErr(busAddrErr),
		.rDtack(rDtack),
		.BeDebounced(BeDebounced),
		.Vpai(Vpai),
		.ASn(ASn),
		.LDSn(LDSn),
		.UDSn(UDSn),
		.eRWn(eRWn)
	);
	busArbiter busArbiter(
		.Clks(Clks),
		.BRi(BRi),
		.BgackI(BgackI),
		.Halti(Halti),
		.bgBlock(bgBlock),
		.busAvail(busAvail),
		.BGn(BGn)
	);
	wire [1:0] uFc = microLatch[16:15];
	reg oReset;
	reg oHalted;
	assign oRESETn = !oReset;
	assign oHALTEDn = !oHalted;
	always @(posedge Clks[4])
		if (Clks[2]) begin
			oReset <= 1'b0;
			oHalted <= 1'b0;
		end
		else if (enT1) begin
			oReset <= (uFc == 2'b01) & !Nanod[104];
			oHalted <= (uFc == 2'b10) & !Nanod[104];
		end
	reg [2:0] rFC;
	assign {FC2, FC1, FC0} = rFC;
	assign Iac = {rFC == 3'b111};
	always @(posedge Clks[4])
		if (Clks[3])
			rFC <= 1'sb0;
		else if (enT1 & Nanod[104]) begin
			rFC[2] <= pswS;
			rFC[1] <= microLatch[16] | (~microLatch[15] & Irdecod[41]);
			rFC[0] <= microLatch[15] | (~microLatch[16] & ~Irdecod[41]);
		end
	reg [2:0] inl;
	reg updIll;
	reg prevNmi;
	wire nmi = iIpl == 3'b111;
	wire iplStable = iIpl == rIpl;
	wire iplComp = iIpl > pswI;
	always @(posedge Clks[4]) begin
		if (Clks[3]) begin
			intPend <= 1'b0;
			prevNmi <= 1'b0;
		end
		else begin
			if (Clks[0])
				prevNmi <= nmi;
			if (Clks[0]) begin
				if (iplStable & ((nmi & ~prevNmi) | iplComp))
					intPend <= 1'b1;
				else if (((inl == 3'b111) & Iac) | ((iplStable & !nmi) & !iplComp))
					intPend <= 1'b0;
			end
		end
		if (Clks[3]) begin
			inl <= 1'sb1;
			updIll <= 1'b0;
		end
		else if (enT4)
			updIll <= microLatch[0];
		else if (enT1 & updIll)
			inl <= iIpl;
		if (enT4) begin
			Spuria <= ~BeiDelay & Iac;
			Avia <= ~Vpai & Iac;
		end
	end
	assign enErrClk = iAddrErr | iBusErr;
	assign wClk = ((waitBusCycle | ~BeI) | iAddrErr) | Err6591;
	reg [3:0] eCntr;
	reg rVma;
	assign VMAn = rVma;
	reg en_E;
	wire xVma = (~rVma & (eCntr == 8)) & en_E;
	assign E_PosClkEn = (Clks[0] & (eCntr == 5)) & en_E;
	assign E_NegClkEn = (Clks[0] & (eCntr == 9)) & en_E;
	always @(posedge Clks[4]) begin
		if (Clks[2]) begin
			E <= 1'b0;
			eCntr <= 1'sb0;
			rVma <= 1'b1;
			en_E <= 1;
		end
		if (Clks[1]) begin
			if (E_div)
				en_E <= !en_E;
			else
				en_E <= 1'b1;
		end
		if (Clks[0] & en_E) begin
			if (eCntr == 9)
				E <= 1'b0;
			else if (eCntr == 5)
				E <= 1'b1;
			if (eCntr == 9)
				eCntr <= 1'sb0;
			else
				eCntr <= eCntr + 1'b1;
		end
		if ((((Clks[0] & addrOe) & ~Vpai) & (eCntr == 3)) & en_E)
			rVma <= 1'b0;
		else if ((Clks[1] & (eCntr == {4 {1'sb0}})) & en_E)
			rVma <= 1'b1;
	end
	always @(posedge Clks[4]) begin
		if (Clks[3])
			rAddrErr <= 1'b0;
		else if (Clks[1]) begin
			if (busAddrErr & addrOe)
				rAddrErr <= 1'b1;
			else if (~addrOe)
				rAddrErr <= 1'b0;
		end
		if (Clks[3])
			iBusErr <= 1'b0;
		else if (Clks[1])
			iBusErr <= ((BerrA & ~BeI) & ~Iac) & !BusRetry;
		if (Clks[3])
			BerrA <= 1'b0;
		else if (Clks[0]) begin
			if ((~BeI & ~Iac) & addrOe)
				BerrA <= 1'b1;
			else if (BeI & busStarting)
				BerrA <= 1'b0;
		end
		if (Clks[3])
			excRst <= 1'b1;
		else if (enT2 & Nanod[104])
			excRst <= 1'b0;
		if (Clks[3])
			A0Err <= 1'b1;
		else if (enT3)
			A0Err <= 1'b0;
		else if ((Clks[1] & enErrClk) & (busAddrErr | BerrA))
			A0Err <= 1'b1;
		if (Clks[3]) begin
			iStop <= 1'b0;
			Err6591 <= 1'b0;
		end
		else if (Clks[1])
			Err6591 <= enErrClk;
		else if (Clks[0])
			iStop <= xVma | (Vpai & (iAddrErr | ~rBerr));
	end
	reg irdToCcr_t4;
	always @(posedge Clks[4])
		if (Clks[2]) begin
			Tpend <= 1'b0;
			{pswT, pswS, pswI} <= 1'sb0;
			irdToCcr_t4 <= 1'sb0;
		end
		else if (enT4)
			irdToCcr_t4 <= Irdecod[38];
		else if (enT3) begin
			if (Nanod[97])
				Tpend <= pswT;
			else if (Nanod[96])
				Tpend <= 1'b0;
			if (Nanod[88] & !irdToCcr_t4)
				{pswT, pswS, pswI} <= {ftu[15], ftu[13], ftu[10:8]};
			else begin
				if (Nanod[82]) begin
					pswS <= 1'b1;
					pswT <= 1'b0;
				end
				if (Nanod[89])
					pswI <= inl;
			end
		end
	reg [4:0] ssw;
	reg [3:0] tvnLatch;
	reg [15:0] tvnMux;
	reg inExcept01;
	always @(posedge Clks[4]) begin
		if (Nanod[61] & enT3)
			ssw <= {~bciWrite, inExcept01, rFC};
		if (enT1 & Nanod[81]) begin
			tvnLatch <= tvn;
			inExcept01 <= tvn != 1;
		end
		if (Clks[2])
			ftu <= 1'sb0;
		else if (enT3)
			(* full_case, parallel_case *)
			case (1'b1)
				Nanod[95]: ftu <= tvnMux;
				Nanod[87]: ftu <= {pswT, 1'b0, pswS, 2'b00, pswI, 3'b000, ccr[4:0]};
				Nanod[84]: ftu <= Ird;
				Nanod[83]: ftu[4:0] <= ssw;
				Nanod[85]: ftu <= {12'hfff, pswI, 1'b0};
				Nanod[94]: ftu <= Irdecod[22-:16];
				Nanod[91]: ftu <= Abl;
				default: ftu <= ftu;
			endcase
	end
	localparam TVN_AUTOVEC = 13;
	localparam TVN_INTERRUPT = 15;
	localparam TVN_SPURIOUS = 12;
	always @(*) begin
		if (_sv2v_0)
			;
		if (inExcept01) begin
			if (tvnLatch == TVN_SPURIOUS)
				tvnMux = 16'h0060;
			else if (tvnLatch == TVN_AUTOVEC)
				tvnMux = {11'b00000000011, pswI, 2'b00};
			else if (tvnLatch == TVN_INTERRUPT)
				tvnMux = {6'b000000, Ird[7:0], 2'b00};
			else
				tvnMux = {10'b0000000000, tvnLatch, 2'b00};
		end
		else
			tvnMux = {8'h00, Irdecod[6-:6], 2'b00};
	end
	initial _sv2v_0 = 0;
endmodule
