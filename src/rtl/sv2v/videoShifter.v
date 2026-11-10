module videoShifter (
	clk,
	clk8_en_n,
	clk8_en_p,
	dataIn,
	loadPixels,
	pixelOut
);
	input clk;
	input clk8_en_n;
	input clk8_en_p;
	input [15:0] dataIn;
	input loadPixels;
	output wire pixelOut;
	reg [15:0] shiftRegister = 16'hffff;
	assign pixelOut = ~shiftRegister[15];
	always @(posedge clk)
		if (clk8_en_n || clk8_en_p) begin
			if (loadPixels)
				shiftRegister <= dataIn;
			else
				shiftRegister <= {shiftRegister[14:0], 1'b1};
		end
endmodule
