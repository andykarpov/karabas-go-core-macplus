module pren (
	mask,
	hbit
);
	parameter size = 16;
	parameter outbits = 4;
	input [size - 1:0] mask;
	output reg [outbits - 1:0] hbit;
	always @(mask) begin : sv2v_autoblock_1
		integer i;
		hbit = 0;
		for (i = size - 1; i >= 0; i = i - 1)
			if (mask[i])
				hbit = i;
	end
endmodule
