module irdDecode (
	ird,
	Irdecod
);
	reg _sv2v_0;
	input [15:0] ird;
	output reg [41:0] Irdecod;
	wire [3:0] line = ird[15:12];
	wire [15:0] lineOnehot;
	onehotEncoder4 irdLines(
		.bin(line),
		.bitMap(lineOnehot)
	);
	wire isRegShift = lineOnehot['he] & (ird[7:6] != 2'b11);
	wire isDynShift = isRegShift & ird[5];
	wire [1:1] sv2v_tmp_9D785;
	assign sv2v_tmp_9D785 = ((&ird[5:3] & ~isDynShift) & !ird[2]) & ird[1];
	always @(*) Irdecod[41] = sv2v_tmp_9D785;
	wire [1:1] sv2v_tmp_1BD44;
	assign sv2v_tmp_1BD44 = lineOnehot[4] & (ird[11:6] == 6'b101011);
	always @(*) Irdecod[40] = sv2v_tmp_1BD44;
	wire [3:1] sv2v_tmp_C005B;
	assign sv2v_tmp_C005B = ird[11:9];
	always @(*) Irdecod[30-:3] = sv2v_tmp_C005B;
	wire [3:1] sv2v_tmp_603B5;
	assign sv2v_tmp_603B5 = ird[2:0];
	always @(*) Irdecod[27-:3] = sv2v_tmp_603B5;
	wire isPreDecr = ird[5:3] == 3'b100;
	wire eaAreg = ird[5:3] == 3'b001;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			lineOnehot[1], lineOnehot[2], lineOnehot[3]: Irdecod[24] = |ird[8:6];
			lineOnehot[4]: Irdecod[24] = &ird[8:6];
			lineOnehot['h8]: Irdecod[24] = (eaAreg & ird[8]) & ~ird[7];
			lineOnehot['hc]: Irdecod[24] = (eaAreg & ird[8]) & ~ird[7];
			lineOnehot['h9], lineOnehot['hb], lineOnehot['hd]: Irdecod[24] = (ird[7] & ird[6]) | ((eaAreg & ird[8]) & (ird[7:6] != 2'b11));
			default: Irdecod[24] = Irdecod[39];
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		Irdecod[34] = (lineOnehot[4] & ~ird[8]) & ~Irdecod[39];
	end
	wire [1:1] sv2v_tmp_2D301;
	assign sv2v_tmp_2D301 = Irdecod[34] & isPreDecr;
	always @(*) Irdecod[33] = sv2v_tmp_2D301;
	wire [1:1] sv2v_tmp_40C9E;
	assign sv2v_tmp_40C9E = lineOnehot[5] | (lineOnehot[0] & ~ird[8]);
	always @(*) Irdecod[37] = sv2v_tmp_40C9E;
	wire [1:1] sv2v_tmp_26777;
	assign sv2v_tmp_26777 = lineOnehot[4] & (ird[11:4] == 8'he6);
	always @(*) Irdecod[35] = sv2v_tmp_26777;
	wire eaImmOrAbs = (ird[5:3] == 3'b111) & ~ird[1];
	wire [1:1] sv2v_tmp_E109D;
	assign sv2v_tmp_E109D = eaImmOrAbs & ~isRegShift;
	always @(*) Irdecod[36] = sv2v_tmp_E109D;
	always @(*) begin : sv2v_autoblock_1
		reg eaIsAreg;
		if (_sv2v_0)
			;
		eaIsAreg = (ird[5:3] != 3'b000) & (ird[5:3] != 3'b111);
		(* full_case, parallel_case *)
		case (1'b1)
			default: Irdecod[23] = eaIsAreg;
			lineOnehot[5]: Irdecod[23] = eaIsAreg & (ird[7:3] != 5'b11001);
			lineOnehot[6], lineOnehot[7]: Irdecod[23] = 1'b0;
			lineOnehot['he]: Irdecod[23] = ~isRegShift;
		endcase
	end
	wire xIsScc = (ird[7:6] == 2'b11) & (ird[5:3] != 3'b001);
	wire xStaticMem = (ird[11:8] == 4'b1000) & (ird[5:4] == 2'b00);
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			lineOnehot[0]: Irdecod[32] = (((ird[8] & (ird[5:4] != 2'b00)) | ((ird[11:8] == 4'b1000) & (ird[5:4] != 2'b00))) | ((ird[8:7] == 2'b10) & (ird[5:3] == 3'b001))) | ((ird[8:6] == 3'b000) & !xStaticMem);
			lineOnehot[1]: Irdecod[32] = 1'b1;
			lineOnehot[4]: Irdecod[32] = (ird[7:6] == 2'b00) | Irdecod[40];
			lineOnehot[5]: Irdecod[32] = (ird[7:6] == 2'b00) | xIsScc;
			lineOnehot[8], lineOnehot[9], lineOnehot['hb], lineOnehot['hc], lineOnehot['hd], lineOnehot['he]: Irdecod[32] = ird[7:6] == 2'b00;
			default: Irdecod[32] = 1'b0;
		endcase
	end
	wire [1:1] sv2v_tmp_4419B;
	assign sv2v_tmp_4419B = (lineOnehot[0] & ird[8]) & eaAreg;
	always @(*) Irdecod[31] = sv2v_tmp_4419B;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			lineOnehot[6]: Irdecod[39] = ird[11:8] == 4'b0001;
			lineOnehot[4]: Irdecod[39] = (ird[11:8] == 4'b1110) | (ird[11:6] == 6'b100001);
			default: Irdecod[39] = 1'b0;
		endcase
	end
	wire [1:1] sv2v_tmp_03DA9;
	assign sv2v_tmp_03DA9 = (lineOnehot[4] & ((ird[11:0] == 12'he77) | (ird[11:6] == 6'b010011))) | (lineOnehot[0] & (ird[8:6] == 3'b000));
	always @(*) Irdecod[38] = sv2v_tmp_03DA9;
	reg [15:0] ftuConst;
	wire [3:0] zero28 = (ird[11:9] == 0 ? 4'h8 : {1'b0, ird[11:9]});
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (1'b1)
			lineOnehot[6], lineOnehot[7]: ftuConst = {{8 {ird[7]}}, ird[7:0]};
			lineOnehot['h5], lineOnehot['he]: ftuConst = {12'b000000000000, zero28};
			lineOnehot['h8], lineOnehot['hc]: ftuConst = 16'h000f;
			lineOnehot[4]: ftuConst = 16'h0080;
			default: ftuConst = 1'sb0;
		endcase
	end
	wire [16:1] sv2v_tmp_D48F4;
	assign sv2v_tmp_D48F4 = ftuConst;
	always @(*) Irdecod[22-:16] = sv2v_tmp_D48F4;
	always @(*) begin
		if (_sv2v_0)
			;
		if (lineOnehot[4])
			case (ird[6:5])
				2'b00, 2'b01: Irdecod[6-:6] = 6;
				2'b11: Irdecod[6-:6] = 7;
				2'b10: Irdecod[6-:6] = {2'b10, ird[3:0]};
			endcase
		else
			Irdecod[6-:6] = 5;
	end
	wire eaAdir = ird[5:3] == 3'b001;
	wire size11 = ird[7] & ird[6];
	wire [1:1] sv2v_tmp_04E16;
	assign sv2v_tmp_04E16 = (((lineOnehot[9] | lineOnehot['hd]) & size11) | (lineOnehot[5] & eaAdir)) | ((lineOnehot[2] | lineOnehot[3]) & (ird[8:6] == 3'b001));
	always @(*) Irdecod[0] = sv2v_tmp_04E16;
	initial _sv2v_0 = 0;
endmodule
