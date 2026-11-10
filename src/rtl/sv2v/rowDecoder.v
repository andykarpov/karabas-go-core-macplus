module rowDecoder (
	ird,
	row,
	noCcrEn,
	isArX
);
	reg _sv2v_0;
	input [15:0] ird;
	output reg [15:0] row;
	output wire noCcrEn;
	output reg isArX;
	wire eaRdir = ird[5:4] == 2'b00;
	wire eaAdir = ird[5:3] == 3'b001;
	wire size11 = ird[7] & ird[6];
	always @(*) begin
		if (_sv2v_0)
			;
		case (ird[15:12])
			'h4, 'h9, 'hd: isArX = row[10] | row[12];
			default: isArX = 1'b0;
		endcase
	end
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (ird[15:12])
			'h4:
				if (ird[8])
					row = 16'h0040;
				else
					case (ird[11:9])
						'b0: row = 16'h0400;
						'b1: row = 16'h0010;
						'b10: row = 16'h0020;
						'b11: row = 16'h0800;
						'b100: row = (ird[7] ? 16'h0100 : 16'h0200);
						'b101: row = 16'h8000;
						default: row = 0;
					endcase
			'h0:
				if (ird[8])
					row = (ird[7] ? 16'h4000 : 16'h2000);
				else
					case (ird[11:9])
						'b0: row = 16'h4000;
						'b1: row = 16'h0010;
						'b10: row = 16'h0020;
						'b11: row = 16'h0004;
						'b100: row = (ird[7] ? 16'h4000 : 16'h2000);
						'b101: row = 16'h2000;
						'b110: row = 16'h0040;
						default: row = 0;
					endcase
			'h1, 'h2, 'h3: row = 16'h0004;
			'h5:
				if (size11)
					row = 16'h8000;
				else
					row = (ird[8] ? 16'h0020 : 16'h0004);
			'h6: row = 0;
			'h7: row = 16'h0004;
			'h8:
				if (size11)
					row = 16'h0002;
				else if (ird[8] & eaRdir)
					row = 16'h0200;
				else
					row = 16'h4000;
			'h9:
				if ((ird[8] & ~size11) & eaRdir)
					row = 16'h0400;
				else
					row = 16'h0020;
			'hb:
				if ((ird[8] & ~size11) & ~eaAdir)
					row = 16'h2000;
				else
					row = 16'h0040;
			'hc:
				if (size11)
					row = 16'h0080;
				else if (ird[8] & eaRdir)
					row = 16'h0008;
				else
					row = 16'h0010;
			'hd:
				if ((ird[8] & ~size11) & eaRdir)
					row = 16'h1000;
				else
					row = 16'h0004;
			'he: begin : sv2v_autoblock_1
				reg [1:0] stype;
				if (size11)
					stype = ird[10:9];
				else
					stype = ird[4:3];
				case ({stype, ird[8]})
					0: row = 16'h0004;
					1: row = 16'h0008;
					2: row = 16'h0020;
					3: row = 16'h0010;
					4: row = 16'h0100;
					5: row = 16'h0800;
					6: row = 16'h0400;
					7: row = 16'h0200;
				endcase
			end
			default: row = 0;
		endcase
	end
	assign noCcrEn = ((((ird[15] & ~ird[13]) & ird[12]) & size11) | ((ird[15:12] == 4'h5) & eaAdir)) | (((~ird[15] & ~ird[14]) & ird[13]) & (ird[8:6] == 3'b001));
	initial _sv2v_0 = 0;
endmodule
