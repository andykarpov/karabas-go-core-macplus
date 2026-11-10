module uaddrDecode (
	opcode,
	a1,
	a2,
	a3,
	isPriv,
	isIllegal,
	isLineA,
	isLineF,
	lineBmap
);
	reg _sv2v_0;
	input [15:0] opcode;
	localparam UADDR_WIDTH = 10;
	output wire [9:0] a1;
	output wire [9:0] a2;
	output wire [9:0] a3;
	output reg isPriv;
	output wire isIllegal;
	output wire isLineA;
	output wire isLineF;
	output wire [15:0] lineBmap;
	wire [3:0] line = opcode[15:12];
	wire [3:0] eaCol;
	wire [3:0] movEa;
	onehotEncoder4 irLineDecod(
		.bin(line),
		.bitMap(lineBmap)
	);
	assign isLineA = lineBmap['ha];
	assign isLineF = lineBmap['hf];
	pla_lined pla_lined(
		.movEa(movEa),
		.col(eaCol),
		.opcode(opcode),
		.lineBmap(lineBmap),
		.palIll(isIllegal),
		.plaA1(a1),
		.plaA2(a2),
		.plaA3(a3)
	);
	function [3:0] eaDecode;
		input [5:0] eaBits;
		(* full_case, parallel_case *)
		case (eaBits[5:3])
			3'b111:
				case (eaBits[2:0])
					3'b000: eaDecode = 7;
					3'b001: eaDecode = 8;
					3'b010: eaDecode = 9;
					3'b011: eaDecode = 10;
					3'b100: eaDecode = 11;
					default: eaDecode = 12;
				endcase
			default: eaDecode = eaBits[5:3];
		endcase
	endfunction
	assign eaCol = eaDecode(opcode[5:0]);
	assign movEa = eaDecode({opcode[8:6], opcode[11:9]});
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (lineBmap)
			'h1: isPriv = (opcode & 16'hf5ff) == 16'h007c;
			'h10:
				if ((opcode & 16'hffc0) == 16'h46c0)
					isPriv = 1'b1;
				else if ((opcode & 16'hfff0) == 16'h4e60)
					isPriv = 1'b1;
				else if (((opcode == 16'h4e70) || (opcode == 16'h4e73)) || (opcode == 16'h4e72))
					isPriv = 1'b1;
				else
					isPriv = 1'b0;
			default: isPriv = 1'b0;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
