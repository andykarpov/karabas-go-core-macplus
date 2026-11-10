module aluCorf (
	binResult,
	bAdd,
	cin,
	hCarry,
	bcdResult,
	dC,
	ov
);
	reg _sv2v_0;
	input [7:0] binResult;
	input bAdd;
	input cin;
	input hCarry;
	output wire [7:0] bcdResult;
	output wire dC;
	output reg ov;
	reg [8:0] htemp;
	reg [4:0] hNib;
	function gt9;
		input [3:0] nib;
		gt9 = nib[3] & (nib[2] | nib[1]);
	endfunction
	wire lowC = hCarry | (bAdd ? gt9(binResult[3:0]) : 1'b0);
	wire highC = cin | (bAdd ? gt9(htemp[7:4]) | htemp[8] : 1'b0);
	always @(*) begin
		if (_sv2v_0)
			;
		if (bAdd) begin
			htemp = {1'b0, binResult} + (lowC ? 4'h6 : 4'h0);
			hNib = htemp[8:4] + (highC ? 4'h6 : 4'h0);
			ov = hNib[3] & ~binResult[7];
		end
		else begin
			htemp = {1'b0, binResult} - (lowC ? 4'h6 : 4'h0);
			hNib = htemp[8:4] - (highC ? 4'h6 : 4'h0);
			ov = ~hNib[3] & binResult[7];
		end
	end
	assign bcdResult = {hNib[3:0], htemp[3:0]};
	assign dC = hNib[4] | cin;
	initial _sv2v_0 = 0;
endmodule
