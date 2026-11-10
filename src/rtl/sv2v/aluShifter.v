module aluShifter (
	data,
	isByte,
	isLong,
	swapWords,
	dir,
	cin,
	result
);
	reg _sv2v_0;
	input [31:0] data;
	input isByte;
	input isLong;
	input swapWords;
	input dir;
	input cin;
	output reg [31:0] result;
	reg [31:0] tdata;
	always @(*) begin
		if (_sv2v_0)
			;
		tdata = data;
		if (isByte & dir)
			tdata[8] = cin;
		else if (!isLong & dir)
			tdata[16] = cin;
	end
	always @(*) begin
		if (_sv2v_0)
			;
		if (swapWords & dir)
			result = {tdata[0], tdata[31:17], cin, tdata[15:1]};
		else if (swapWords)
			result = {tdata[30:16], cin, tdata[14:0], tdata[31]};
		else if (dir)
			result = {cin, tdata[31:1]};
		else
			result = {tdata[30:0], cin};
	end
	initial _sv2v_0 = 0;
endmodule
