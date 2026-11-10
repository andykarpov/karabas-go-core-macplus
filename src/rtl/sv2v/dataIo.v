module dataIo (
	Clks,
	enT1,
	enT2,
	enT3,
	enT4,
	Nanod,
	Irdecod,
	iEdb,
	aob0,
	dobIdle,
	dobInput,
	Irc,
	dbin,
	oEdb
);
	input wire [4:0] Clks;
	input enT1;
	input enT2;
	input enT3;
	input enT4;
	input wire [104:0] Nanod;
	input wire [41:0] Irdecod;
	input [15:0] iEdb;
	input aob0;
	input dobIdle;
	input [15:0] dobInput;
	output reg [15:0] Irc;
	output reg [15:0] dbin;
	output wire [15:0] oEdb;
	reg [15:0] dob;
	reg xToDbin;
	reg xToIrc;
	reg dbinNoLow;
	reg dbinNoHigh;
	reg byteMux;
	reg isByte_T4;
	always @(posedge Clks[4]) begin
		if (enT4)
			isByte_T4 <= Irdecod[32];
		if (enT3) begin
			dbinNoHigh <= Nanod[98];
			dbinNoLow <= Nanod[99];
			byteMux <= (Nanod[101] & isByte_T4) & ~aob0;
		end
		if (enT1) begin
			xToDbin <= 1'b0;
			xToIrc <= 1'b0;
		end
		else if (enT3) begin
			xToDbin <= Nanod[75];
			xToIrc <= Nanod[74];
		end
		if (xToIrc & Clks[0])
			Irc <= iEdb;
		if (xToDbin & Clks[0]) begin
			if (~dbinNoLow)
				dbin[7:0] <= (byteMux ? iEdb[15:8] : iEdb[7:0]);
			if (~dbinNoHigh)
				dbin[15:8] <= (~byteMux & dbinNoLow ? iEdb[7:0] : iEdb[15:8]);
		end
	end
	reg byteCycle;
	always @(posedge Clks[4]) begin
		if (enT4)
			byteCycle <= Nanod[101] & Irdecod[32];
		if (enT3 & ~dobIdle) begin
			dob[7:0] <= (Nanod[99] ? dobInput[15:8] : dobInput[7:0]);
			dob[15:8] <= (byteCycle | Nanod[98] ? dobInput[7:0] : dobInput[15:8]);
		end
	end
	assign oEdb = dob;
endmodule
