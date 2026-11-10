module aluGetOp (
	row,
	col,
	isCorf,
	aluOp
);
	reg _sv2v_0;
	input [15:0] row;
	input [2:0] col;
	input isCorf;
	output reg [4:0] aluOp;
	localparam OP_ABCD = 22;
	localparam OP_ADD = 4;
	localparam OP_ADDC = 11;
	localparam OP_ADDX = 12;
	localparam OP_AND = 1;
	localparam OP_ASL = 13;
	localparam OP_ASR = 14;
	localparam OP_EOR = 9;
	localparam OP_EXT = 5;
	localparam OP_LSL = 15;
	localparam OP_LSR = 16;
	localparam OP_OR = 8;
	localparam OP_ROL = 17;
	localparam OP_ROR = 18;
	localparam OP_ROXL = 19;
	localparam OP_ROXR = 20;
	localparam OP_SBCD = 6;
	localparam OP_SLAA = 21;
	localparam OP_SUB = 2;
	localparam OP_SUB0 = 7;
	localparam OP_SUBC = 10;
	localparam OP_SUBX = 3;
	always @(*) begin
		if (_sv2v_0)
			;
		aluOp = 1'sbx;
		(* full_case, parallel_case *)
		case (col)
			1: aluOp = OP_AND;
			5: aluOp = OP_EXT;
			default:
				(* full_case, parallel_case *)
				case (1'b1)
					row[1]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_SUB;
							3: aluOp = OP_SUBC;
							4, 6: aluOp = OP_SLAA;
						endcase
					row[2]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_ADD;
							3: aluOp = OP_ADDC;
							4: aluOp = OP_ASR;
						endcase
					row[3]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_ADDX;
							3: aluOp = (isCorf ? OP_ABCD : OP_ADD);
							4: aluOp = OP_ASL;
						endcase
					row[4]: aluOp = (col == 4 ? OP_LSL : OP_AND);
					row[5], row[6]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_SUB;
							3: aluOp = OP_SUBC;
							4: aluOp = OP_LSR;
						endcase
					row[7]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_SUB;
							3: aluOp = OP_ADD;
							4: aluOp = OP_ROXR;
						endcase
					row[8]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_EXT;
							3: aluOp = OP_AND;
							4: aluOp = OP_ROXR;
						endcase
					row[9]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_SUBX;
							3: aluOp = OP_SBCD;
							4: aluOp = OP_ROL;
						endcase
					row[10]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_SUBX;
							3: aluOp = OP_SUBC;
							4: aluOp = OP_ROR;
						endcase
					row[11]:
						(* full_case, parallel_case *)
						case (col)
							2: aluOp = OP_SUB0;
							3: aluOp = OP_SUB0;
							4: aluOp = OP_ROXL;
						endcase
					row[12]: aluOp = OP_ADDX;
					row[13]: aluOp = OP_EOR;
					row[14]: aluOp = (col == 4 ? OP_EOR : OP_OR);
					row[15]: aluOp = (col == 3 ? OP_ADD : OP_OR);
				endcase
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
