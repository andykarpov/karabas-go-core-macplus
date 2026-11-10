module sequencer (
	Clks,
	enT3,
	microLatch,
	A0Err,
	BerrA,
	busAddrErr,
	Spuria,
	Avia,
	Tpend,
	intPend,
	isIllegal,
	isPriv,
	excRst,
	isLineA,
	isLineF,
	psw,
	prenEmpty,
	au05z,
	dcr4,
	ze,
	i11,
	alue01,
	Ird,
	a1,
	a2,
	a3,
	tvn,
	nma
);
	reg _sv2v_0;
	input wire [4:0] Clks;
	input enT3;
	localparam UROM_WIDTH = 17;
	input [16:0] microLatch;
	input A0Err;
	input BerrA;
	input busAddrErr;
	input Spuria;
	input Avia;
	input Tpend;
	input intPend;
	input isIllegal;
	input isPriv;
	input excRst;
	input isLineA;
	input isLineF;
	input [15:0] psw;
	input prenEmpty;
	input au05z;
	input dcr4;
	input ze;
	input i11;
	input [1:0] alue01;
	input [15:0] Ird;
	localparam UADDR_WIDTH = 10;
	input [9:0] a1;
	input [9:0] a2;
	input [9:0] a3;
	output reg [3:0] tvn;
	output reg [9:0] nma;
	reg [9:0] uNma;
	reg [9:0] grp1Nma;
	reg [1:0] c0c1;
	reg a0Rst;
	wire A0Sel;
	wire inGrp0Exc;
	wire [9:0] dbNma = {microLatch[14:13], microLatch[6:5], microLatch[10:7], microLatch[12:11]};
	localparam BSER1_NMA = 'h3;
	localparam HALT1_NMA = 'h1;
	localparam RSTP0_NMA = 'h2;
	always @(*) begin
		if (_sv2v_0)
			;
		if (A0Err) begin
			if (a0Rst)
				nma = RSTP0_NMA;
			else if (inGrp0Exc)
				nma = HALT1_NMA;
			else
				nma = BSER1_NMA;
		end
		else
			nma = uNma;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (microLatch[1])
			uNma = {microLatch[14:13], c0c1, microLatch[10:7], microLatch[12:11]};
		else
			case (microLatch[3:2])
				0: uNma = dbNma;
				1: uNma = (A0Sel ? grp1Nma : a1);
				2: uNma = a2;
				3: uNma = a3;
			endcase
	end
	wire [1:0] enl = {Ird[6], prenEmpty};
	wire [1:0] ms0 = {Ird[8], alue01[0]};
	wire [3:0] m01 = {au05z, Ird[8], alue01};
	localparam NF = 3;
	localparam ZF = 2;
	wire [1:0] nz1 = {psw[NF], psw[ZF]};
	localparam VF = 1;
	wire [1:0] nv = {psw[NF], psw[VF]};
	reg ccTest;
	wire [4:0] cbc = microLatch[6:2];
	localparam CF = 0;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (cbc)
			'h0: c0c1 = {i11, i11};
			'h1: c0c1 = (au05z ? 2'b01 : 2'b11);
			'h11: c0c1 = (au05z ? 2'b00 : 2'b11);
			'h2: c0c1 = {1'b0, ~psw[CF]};
			'h12: c0c1 = {1'b1, ~psw[CF]};
			'h3: c0c1 = {psw[ZF], psw[ZF]};
			'h4:
				case (nz1)
					'b0: c0c1 = 2'b10;
					'b10: c0c1 = 2'b01;
					'b1, 'b11: c0c1 = 2'b11;
				endcase
			'h5: c0c1 = {psw[NF], 1'b1};
			'h15: c0c1 = {1'b1, psw[NF]};
			'h6: c0c1 = {~nz1[1] & ~nz1[0], 1'b1};
			'h7:
				case (ms0)
					'b10, 'b0: c0c1 = 2'b11;
					'b1: c0c1 = 2'b01;
					'b11: c0c1 = 2'b10;
				endcase
			'h8:
				case (m01)
					'b0, 'b1, 'b100, 'b111: c0c1 = 2'b11;
					'b10, 'b11, 'b101: c0c1 = 2'b01;
					'b110: c0c1 = 2'b10;
					default: c0c1 = 2'b00;
				endcase
			'h9: c0c1 = (ccTest ? 2'b11 : 2'b01);
			'h19: c0c1 = (ccTest ? 2'b11 : 2'b10);
			'hc: c0c1 = (dcr4 ? 2'b01 : 2'b11);
			'h1c: c0c1 = (dcr4 ? 2'b10 : 2'b11);
			'ha: c0c1 = (ze ? 2'b11 : 2'b00);
			'hb: c0c1 = (nv == 2'b00 ? 2'b00 : 2'b11);
			'hd: c0c1 = {~psw[VF], ~psw[VF]};
			'he, 'h1e:
				case (enl)
					2'b00: c0c1 = 'b10;
					2'b10: c0c1 = 'b11;
					2'b01, 2'b11: c0c1 = {1'b0, microLatch[6]};
				endcase
			default: c0c1 = 1'sbx;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (Ird[11:8])
			'h0: ccTest = 1'b1;
			'h1: ccTest = 1'b0;
			'h2: ccTest = ~psw[CF] & ~psw[ZF];
			'h3: ccTest = psw[CF] | psw[ZF];
			'h4: ccTest = ~psw[CF];
			'h5: ccTest = psw[CF];
			'h6: ccTest = ~psw[ZF];
			'h7: ccTest = psw[ZF];
			'h8: ccTest = ~psw[VF];
			'h9: ccTest = psw[VF];
			'ha: ccTest = ~psw[NF];
			'hb: ccTest = psw[NF];
			'hc: ccTest = (psw[NF] & psw[VF]) | (~psw[NF] & ~psw[VF]);
			'hd: ccTest = (psw[NF] & ~psw[VF]) | (~psw[NF] & psw[VF]);
			'he: ccTest = ((psw[NF] & psw[VF]) & ~psw[ZF]) | ((~psw[NF] & ~psw[VF]) & ~psw[ZF]);
			'hf: ccTest = (psw[ZF] | (psw[NF] & ~psw[VF])) | (~psw[NF] & psw[VF]);
		endcase
	end
	reg rTrace;
	reg rInterrupt;
	reg rIllegal;
	reg rPriv;
	reg rLineA;
	reg rLineF;
	reg rExcRst;
	reg rExcAdrErr;
	reg rExcBusErr;
	reg rSpurious;
	reg rAutovec;
	wire grp1LatchEn;
	wire grp0LatchEn;
	assign grp1LatchEn = microLatch[0] & (microLatch[1] | !microLatch[4]);
	assign grp0LatchEn = microLatch[4] & !microLatch[1];
	assign inGrp0Exc = (rExcRst | rExcBusErr) | rExcAdrErr;
	localparam SF = 13;
	always @(posedge Clks[4]) begin
		if (grp0LatchEn & enT3) begin
			rExcRst <= excRst;
			rExcBusErr <= BerrA;
			rExcAdrErr <= busAddrErr;
			rSpurious <= Spuria;
			rAutovec <= Avia;
		end
		if (grp1LatchEn & enT3) begin
			rTrace <= Tpend;
			rInterrupt <= intPend;
			rIllegal <= (isIllegal & ~isLineA) & ~isLineF;
			rLineA <= isLineA;
			rLineF <= isLineF;
			rPriv <= isPriv & !psw[SF];
		end
	end
	localparam ITLX1_NMA = 'h1c4;
	localparam TRAC1_NMA = 'h1c0;
	localparam TVN_AUTOVEC = 13;
	localparam TVN_INTERRUPT = 15;
	localparam TVN_SPURIOUS = 12;
	always @(*) begin
		if (_sv2v_0)
			;
		grp1Nma = TRAC1_NMA;
		if (rExcRst)
			tvn = 1'sb0;
		else if (rExcBusErr | rExcAdrErr)
			tvn = {1'b1, rExcAdrErr};
		else if (rSpurious | rAutovec)
			tvn = (rSpurious ? TVN_SPURIOUS : TVN_AUTOVEC);
		else if (rTrace)
			tvn = 9;
		else if (rInterrupt) begin
			tvn = TVN_INTERRUPT;
			grp1Nma = ITLX1_NMA;
		end
		else
			(* full_case, parallel_case *)
			case (1'b1)
				rIllegal: tvn = 4;
				rPriv: tvn = 8;
				rLineA: tvn = 10;
				rLineF: tvn = 11;
				default: tvn = 1;
			endcase
	end
	assign A0Sel = ((((rIllegal | rLineF) | rLineA) | rPriv) | rTrace) | rInterrupt;
	always @(posedge Clks[4])
		if (Clks[3])
			a0Rst <= 1'b1;
		else if (enT3)
			a0Rst <= 1'b0;
	initial _sv2v_0 = 0;
endmodule
