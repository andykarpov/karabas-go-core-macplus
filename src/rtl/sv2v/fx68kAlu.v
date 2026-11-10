module fx68kAlu (
	clk,
	pwrUp,
	enT1,
	enT3,
	enT4,
	ird,
	aluColumn,
	aluDataCtrl,
	aluAddrCtrl,
	alueClkEn,
	ftu2Ccr,
	init,
	finish,
	aluIsByte,
	ftu,
	alub,
	iDataBus,
	iAddrBus,
	ze,
	alue,
	ccr,
	aluOut
);
	reg _sv2v_0;
	input clk;
	input pwrUp;
	input enT1;
	input enT3;
	input enT4;
	input [15:0] ird;
	input [2:0] aluColumn;
	input [1:0] aluDataCtrl;
	input aluAddrCtrl;
	input alueClkEn;
	input ftu2Ccr;
	input init;
	input finish;
	input aluIsByte;
	input [15:0] ftu;
	input [15:0] alub;
	input [15:0] iDataBus;
	input [15:0] iAddrBus;
	output wire ze;
	output reg [15:0] alue;
	output reg [7:0] ccr;
	output wire [15:0] aluOut;
	localparam CF = 0;
	localparam VF = 1;
	localparam ZF = 2;
	localparam NF = 3;
	localparam XF = 4;
	reg [15:0] aluLatch;
	reg [4:0] pswCcr;
	reg [4:0] ccrCore;
	reg [15:0] result;
	reg [4:0] ccrTemp;
	reg coreH;
	reg [15:0] subResult;
	reg subHcarry;
	reg subCout;
	reg subOv;
	assign aluOut = aluLatch;
	assign ze = ~ccrCore[ZF];
	reg [15:0] row;
	reg isArX;
	reg noCcrEn;
	reg isByte;
	reg [4:0] ccrMask;
	reg [4:0] oper;
	reg [15:0] aOperand;
	reg [15:0] dOperand;
	wire isCorf = aluDataCtrl == 2'b10;
	wire [15:0] cRow;
	wire cIsArX;
	wire cNoCcrEn;
	rowDecoder rowDecoder(
		.ird(ird),
		.row(cRow),
		.noCcrEn(cNoCcrEn),
		.isArX(cIsArX)
	);
	wire [4:0] cMask;
	wire [4:0] aluOp;
	aluGetOp aluGetOp(
		.row(row),
		.col(aluColumn),
		.isCorf(isCorf),
		.aluOp(aluOp)
	);
	ccrTable ccrTable(
		.col(aluColumn),
		.row(row),
		.finish(finish),
		.ccrMask(cMask)
	);
	wire shftIsMul = row[7];
	wire shftIsDiv = row[1];
	wire [31:0] shftResult;
	reg [7:0] bcdLatch;
	reg bcdCarry;
	reg bcdOverf;
	reg isLong;
	reg rIrd8;
	reg isShift;
	reg shftCin;
	reg shftRight;
	reg addCin;
	always @(posedge clk) begin
		if (enT3) begin
			row <= cRow;
			isArX <= cIsArX;
			noCcrEn <= cNoCcrEn;
			rIrd8 <= ird[8];
			isByte <= aluIsByte;
		end
		if (enT4) begin
			isLong <= ((ird[7] & ~ird[6]) | shftIsMul) | shftIsDiv;
			ccrMask <= cMask;
			oper <= aluOp;
		end
	end
	always @(*) begin
		if (_sv2v_0)
			;
		aOperand = (aluAddrCtrl ? alub : iAddrBus);
		case (aluDataCtrl)
			2'b00: dOperand = iDataBus;
			2'b01: dOperand = 'h0;
			2'b11: dOperand = 'hffff;
			2'b10: dOperand = 1'sbx;
		endcase
	end
	wire shftMsb = (isLong ? alue[15] : (isByte ? aOperand[7] : aOperand[15]));
	aluShifter shifter(
		.data({alue, aOperand}),
		.swapWords(shftIsMul | shftIsDiv),
		.cin(shftCin),
		.dir(shftRight),
		.isByte(isByte),
		.isLong(isLong),
		.result(shftResult)
	);
	wire [7:0] bcdResult;
	wire bcdC;
	wire bcdV;
	localparam OP_SBCD = 6;
	aluCorf aluCorf(
		.binResult(aluLatch[7:0]),
		.hCarry(coreH),
		.bAdd(oper != OP_SBCD),
		.cin(pswCcr[XF]),
		.bcdResult(bcdResult),
		.dC(bcdC),
		.ov(bcdV)
	);
	always @(posedge clk)
		if (enT1) begin
			bcdLatch <= bcdResult;
			bcdCarry <= bcdC;
			bcdOverf <= bcdV;
		end
	localparam OP_ADD = 4;
	localparam OP_ADDC = 11;
	localparam OP_ADDX = 12;
	localparam OP_SUB = 2;
	localparam OP_SUB0 = 7;
	localparam OP_SUBC = 10;
	localparam OP_SUBX = 3;
	always @(*) begin
		if (_sv2v_0)
			;
		case (oper)
			OP_ADD, OP_SUB: addCin = 1'b0;
			OP_SUB0: addCin = 1'b1;
			OP_ADDC, OP_SUBC: addCin = ccrCore[CF];
			OP_ADDX, OP_SUBX: addCin = pswCcr[XF];
			default: addCin = 1'bx;
		endcase
	end
	localparam OP_ASL = 13;
	localparam OP_ASR = 14;
	localparam OP_LSL = 15;
	localparam OP_LSR = 16;
	localparam OP_ROL = 17;
	localparam OP_ROR = 18;
	localparam OP_ROXL = 19;
	localparam OP_ROXR = 20;
	localparam OP_SLAA = 21;
	always @(*) begin
		if (_sv2v_0)
			;
		case (oper)
			OP_LSL, OP_ASL, OP_ROL, OP_ROXL, OP_SLAA: shftRight = 1'b0;
			OP_LSR, OP_ASR, OP_ROR, OP_ROXR: shftRight = 1'b1;
			default: shftRight = 1'bx;
		endcase
		case (oper)
			OP_LSR, OP_ASL, OP_LSL: shftCin = 1'b0;
			OP_ROL, OP_ASR: shftCin = shftMsb;
			OP_ROR: shftCin = aOperand[0];
			OP_ROXL, OP_ROXR:
				if (shftIsMul)
					shftCin = (rIrd8 ? pswCcr[NF] ^ pswCcr[VF] : pswCcr[CF]);
				else
					shftCin = pswCcr[XF];
			OP_SLAA: shftCin = aluColumn[1];
			default: shftCin = 1'sbx;
		endcase
	end
	task mySubber;
		input [15:0] inpa;
		input [15:0] inpb;
		input cin;
		input bAdd;
		input isByte;
		output reg [15:0] result;
		output reg cout;
		output reg ov;
		reg [16:0] rtemp;
		reg rm;
		reg sm;
		reg dm;
		reg tsm;
		begin
			if (isByte) begin
				rtemp = (bAdd ? ({1'b0, inpb[7:0]} + {1'b0, inpa[7:0]}) + cin : ({1'b0, inpb[7:0]} - {1'b0, inpa[7:0]}) - cin);
				result = {{8 {rtemp[7]}}, rtemp[7:0]};
				cout = rtemp[8];
			end
			else begin
				rtemp = (bAdd ? ({1'b0, inpb} + {1'b0, inpa}) + cin : ({1'b0, inpb} - {1'b0, inpa}) - cin);
				result = rtemp[15:0];
				cout = rtemp[16];
			end
			rm = (isByte ? rtemp[7] : rtemp[15]);
			dm = (isByte ? inpb[7] : inpb[15]);
			tsm = (isByte ? inpa[7] : inpa[15]);
			sm = (bAdd ? tsm : ~tsm);
			ov = ((sm & dm) & ~rm) | ((~sm & ~dm) & rm);
			subHcarry = (inpa[4] ^ inpb[4]) ^ rtemp[4];
		end
	endtask
	localparam OP_ABCD = 22;
	localparam OP_AND = 1;
	localparam OP_EOR = 9;
	localparam OP_EXT = 5;
	localparam OP_OR = 8;
	always @(*) begin
		if (_sv2v_0)
			;
		mySubber(aOperand, dOperand, addCin, ((oper == OP_ADD) | (oper == OP_ADDC)) | (oper == OP_ADDX), isByte, subResult, subCout, subOv);
		isShift = 1'b0;
		case (oper)
			OP_AND: result = aOperand & dOperand;
			OP_OR: result = aOperand | dOperand;
			OP_EOR: result = aOperand ^ dOperand;
			OP_EXT: result = {{8 {aOperand[7]}}, aOperand[7:0]};
			OP_SLAA, OP_ASL, OP_ASR, OP_LSL, OP_LSR, OP_ROL, OP_ROR, OP_ROXL, OP_ROXR: begin
				result = shftResult[15:0];
				isShift = 1'b1;
			end
			OP_ADD, OP_ADDC, OP_ADDX, OP_SUB, OP_SUBC, OP_SUB0, OP_SUBX: result = subResult;
			OP_ABCD, OP_SBCD: result = {8'hxx, bcdLatch};
			default: result = 1'sbx;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		ccrTemp[XF] = pswCcr[XF];
		ccrTemp[CF] = 0;
		ccrTemp[VF] = 0;
		ccrTemp[ZF] = (isByte ? ~(|result[7:0]) : ~(|result));
		ccrTemp[NF] = (isByte ? result[7] : result[15]);
		(* full_case, parallel_case *)
		case (oper)
			OP_EXT:
				if (aluColumn == 5) begin
					ccrTemp[VF] = 1'b1;
					ccrTemp[NF] = 1'b1;
					ccrTemp[ZF] = 1'b0;
				end
			OP_SUB0, OP_OR, OP_EOR: begin
				ccrTemp[CF] = 0;
				ccrTemp[VF] = 0;
			end
			OP_AND: begin
				if ((aluColumn == 1) & (row[11] | row[8]))
					ccrTemp[CF] = pswCcr[XF];
				else
					ccrTemp[CF] = 0;
				ccrTemp[VF] = 0;
			end
			OP_SLAA: ccrTemp[CF] = aOperand[15];
			OP_LSL, OP_ROXL: begin
				ccrTemp[CF] = shftMsb;
				ccrTemp[XF] = shftMsb;
				ccrTemp[VF] = 1'b0;
			end
			OP_LSR, OP_ROXR: begin
				ccrTemp[CF] = (shftIsMul ? 1'b0 : aOperand[0]);
				ccrTemp[XF] = aOperand[0];
				ccrTemp[VF] = 0;
			end
			OP_ASL: begin
				ccrTemp[XF] = shftMsb;
				ccrTemp[CF] = shftMsb;
				ccrTemp[VF] = pswCcr[VF] | (shftMsb ^ (isLong ? alue[14] : (isByte ? aOperand[6] : aOperand[14])));
			end
			OP_ASR: begin
				ccrTemp[XF] = aOperand[0];
				ccrTemp[CF] = aOperand[0];
				ccrTemp[VF] = 0;
			end
			OP_ROL: ccrTemp[CF] = shftMsb;
			OP_ROR: ccrTemp[CF] = aOperand[0];
			OP_ADD, OP_ADDC, OP_ADDX, OP_SUB, OP_SUBC, OP_SUBX: begin
				ccrTemp[CF] = subCout;
				ccrTemp[XF] = subCout;
				ccrTemp[VF] = subOv;
			end
			OP_ABCD, OP_SBCD: begin
				ccrTemp[XF] = bcdCarry;
				ccrTemp[CF] = bcdCarry;
				ccrTemp[VF] = bcdOverf;
			end
		endcase
	end
	reg [4:0] ccrMasked;
	always @(*) begin
		if (_sv2v_0)
			;
		ccrMasked = (ccrTemp & ccrMask) | (pswCcr & ~ccrMask);
		if (finish | isArX)
			ccrMasked[ZF] = ccrTemp[ZF] & pswCcr[ZF];
	end
	always @(posedge clk) begin
		if (enT3) begin
			if (|aluColumn) begin
				aluLatch <= result;
				coreH <= subHcarry;
				if (|aluColumn)
					ccrCore <= ccrTemp;
			end
			if (alueClkEn)
				alue <= iDataBus;
			else if (isShift & |aluColumn)
				alue <= shftResult[31:16];
		end
		if (pwrUp)
			pswCcr <= 1'sb0;
		else if (enT3 & ftu2Ccr)
			pswCcr <= ftu[4:0];
		else if ((enT3 & ~noCcrEn) & (finish | init))
			pswCcr <= ccrMasked;
	end
	wire [8:1] sv2v_tmp_D1156;
	assign sv2v_tmp_D1156 = {3'b000, pswCcr};
	always @(*) ccr = sv2v_tmp_D1156;
	initial _sv2v_0 = 0;
endmodule
