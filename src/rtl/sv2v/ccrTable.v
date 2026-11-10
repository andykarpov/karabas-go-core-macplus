module ccrTable (
	col,
	row,
	finish,
	ccrMask
);
	reg _sv2v_0;
	input [2:0] col;
	input [15:0] row;
	input finish;
	localparam MASK_NBITS = 5;
	output reg [4:0] ccrMask;
	localparam KNZ00 = 5'b01111;
	localparam KKZKK = 5'b00100;
	localparam KNZKK = 5'b01100;
	localparam KNZ10 = 5'b01111;
	localparam KNZ0C = 5'b01111;
	localparam KNZVC = 5'b01111;
	localparam XNKVC = 5'b11011;
	localparam CUPDALL = 5'b11111;
	localparam CUNUSED = 5'bxxxxx;
	reg [4:0] ccrMask1;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (col)
			1: ccrMask = ccrMask1;
			2, 3:
				(* full_case, parallel_case *)
				case (1'b1)
					row[1]: ccrMask = KNZ0C;
					row[3], row[9]: ccrMask = (col == 2 ? XNKVC : CUPDALL);
					row[2], row[5], row[10], row[12]: ccrMask = CUPDALL;
					row[6], row[7], row[11]: ccrMask = KNZVC;
					row[4], row[8], row[13], row[14]: ccrMask = KNZ00;
					row[15]: ccrMask = 5'b00000;
					default: ccrMask = CUNUSED;
				endcase
			4:
				(* full_case, parallel_case *)
				case (row)
					16'h0004, 16'h0008, 16'h0010, 16'h0020: ccrMask = CUPDALL;
					16'h0080: ccrMask = KNZ00;
					16'h0200, 16'h0400: ccrMask = KNZ00;
					16'h0100, 16'h0800: ccrMask = CUPDALL;
					default: ccrMask = CUNUSED;
				endcase
			5: ccrMask = (row[1] ? KNZ10 : 5'b00000);
			default: ccrMask = CUNUSED;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (finish)
			ccrMask1 = (row[7] ? KNZ00 : KNZKK);
		else
			ccrMask1 = (row[13] | row[14] ? KKZKK : KNZ00);
	end
	initial _sv2v_0 = 0;
endmodule
