module onehotEncoder4 (
	bin,
	bitMap
);
	reg _sv2v_0;
	input [3:0] bin;
	output reg [15:0] bitMap;
	always @(*) begin
		if (_sv2v_0)
			;
		case (bin)
			'b0: bitMap = 16'h0001;
			'b1: bitMap = 16'h0002;
			'b10: bitMap = 16'h0004;
			'b11: bitMap = 16'h0008;
			'b100: bitMap = 16'h0010;
			'b101: bitMap = 16'h0020;
			'b110: bitMap = 16'h0040;
			'b111: bitMap = 16'h0080;
			'b1000: bitMap = 16'h0100;
			'b1001: bitMap = 16'h0200;
			'b1010: bitMap = 16'h0400;
			'b1011: bitMap = 16'h0800;
			'b1100: bitMap = 16'h1000;
			'b1101: bitMap = 16'h2000;
			'b1110: bitMap = 16'h4000;
			'b1111: bitMap = 16'h8000;
		endcase
	end
	initial _sv2v_0 = 0;
endmodule
