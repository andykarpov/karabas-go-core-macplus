module busControl (
	Clks,
	enT1,
	enT4,
	permStart,
	permStop,
	iStop,
	aob0,
	isWrite,
	isByte,
	isRmc,
	busAvail,
	bgBlock,
	busAddrErr,
	waitBusCycle,
	busStarting,
	addrOe,
	bciWrite,
	rDtack,
	BeDebounced,
	Vpai,
	ASn,
	LDSn,
	UDSn,
	eRWn
);
	reg _sv2v_0;
	input wire [4:0] Clks;
	input enT1;
	input enT4;
	input permStart;
	input permStop;
	input iStop;
	input aob0;
	input isWrite;
	input isByte;
	input isRmc;
	input busAvail;
	output wire bgBlock;
	output wire busAddrErr;
	output wire waitBusCycle;
	output wire busStarting;
	output reg addrOe;
	output wire bciWrite;
	input rDtack;
	input BeDebounced;
	input Vpai;
	output wire ASn;
	output wire LDSn;
	output wire UDSn;
	output wire eRWn;
	reg rAS;
	reg rLDS;
	reg rUDS;
	reg rRWn;
	assign ASn = rAS;
	assign LDSn = rLDS;
	assign UDSn = rUDS;
	assign eRWn = rRWn;
	reg bcPend;
	reg isWriteReg;
	reg bciByte;
	reg isRmcReg;
	reg wendReg;
	assign bciWrite = isWriteReg;
	reg addrOeDelay;
	reg isByteT4;
	wire canStart;
	wire busEnd;
	wire bcComplete;
	wire bcReset;
	wire isRcmReset = (bcComplete & bcReset) & isRmcReg;
	assign busAddrErr = aob0 & ~bciByte;
	wire busRetry = ~busAddrErr & 1'b0;
	reg [31:0] busPhase;
	reg [31:0] next;
	always @(posedge Clks[4])
		if (Clks[3])
			busPhase <= 32'd0;
		else if (Clks[1])
			busPhase <= next;
	always @(*) begin
		if (_sv2v_0)
			;
		case (busPhase)
			32'd0: next = 32'd1;
			32'd6: next = 32'd1;
			32'd2: next = 32'd3;
			32'd3: next = 32'd4;
			32'd4: next = (busEnd ? 32'd5 : 32'd4);
			32'd5: next = (isRcmReset ? 32'd6 : (canStart ? 32'd2 : 32'd1));
			32'd1: next = (canStart ? 32'd2 : 32'd1);
			default: next = 32'd1;
		endcase
	end
	wire rmcIdle = ((busPhase == 32'd1) & ~ASn) & isRmcReg;
	assign canStart = (((busAvail | rmcIdle) & (bcPend | permStart)) & !busRetry) & !bcReset;
	wire busEnding = (next == 32'd1) | (next == 32'd2);
	assign busStarting = busPhase == 32'd2;
	assign busEnd = ~rDtack | iStop;
	assign bcComplete = busPhase == 32'd5;
	wire bciClear = bcComplete & ~busRetry;
	assign bcReset = Clks[3] | ((addrOeDelay & BeDebounced) & Vpai);
	assign waitBusCycle = wendReg & !bcComplete;
	assign bgBlock = ((busPhase == 32'd2) & ASn) | (busPhase == 32'd6);
	always @(posedge Clks[4]) begin
		if (Clks[3])
			addrOe <= 1'b0;
		else if (Clks[0] & (busPhase == 32'd2))
			addrOe <= 1'b1;
		else if (Clks[1] & (busPhase == 32'd6))
			addrOe <= 1'b0;
		else if ((Clks[1] & ~isRmcReg) & busEnding)
			addrOe <= 1'b0;
		if (Clks[1])
			addrOeDelay <= addrOe;
		if (Clks[3]) begin
			rAS <= 1'b1;
			rUDS <= 1'b1;
			rLDS <= 1'b1;
			rRWn <= 1'b1;
		end
		else begin
			if (Clks[1] & busEnding)
				rRWn <= 1'b1;
			else if (Clks[1] & isWriteReg) begin
				if ((busPhase == 32'd2) & isWriteReg)
					rRWn <= 1'b0;
			end
			if (Clks[1] & (busPhase == 32'd2))
				rAS <= 1'b0;
			else if (Clks[0] & (busPhase == 32'd6))
				rAS <= 1'b1;
			else if ((Clks[0] & bcComplete) & ~32'd6) begin
				if (~isRmcReg)
					rAS <= 1'b1;
			end
			if (Clks[1] & (busPhase == 32'd2)) begin
				if (~isWriteReg & !busAddrErr) begin
					rUDS <= ~(~bciByte | ~aob0);
					rLDS <= ~(~bciByte | aob0);
				end
			end
			else if (((Clks[1] & isWriteReg) & (busPhase == 32'd3)) & !busAddrErr) begin
				rUDS <= ~(~bciByte | ~aob0);
				rLDS <= ~(~bciByte | aob0);
			end
			else if (Clks[0] & bcComplete) begin
				rUDS <= 1'b1;
				rLDS <= 1'b1;
			end
		end
	end
	always @(posedge Clks[4])
		if (enT4)
			isByteT4 <= isByte;
	always @(posedge Clks[4])
		if (Clks[2]) begin
			bcPend <= 1'b0;
			wendReg <= 1'b0;
			isWriteReg <= 1'b0;
			bciByte <= 1'b0;
			isRmcReg <= 1'b0;
		end
		else if (Clks[0] & (bciClear | bcReset)) begin
			bcPend <= 1'b0;
			wendReg <= 1'b0;
		end
		else begin
			if (enT1 & permStart) begin
				isWriteReg <= isWrite;
				bciByte <= isByteT4;
				isRmcReg <= isRmc & ~isWrite;
				bcPend <= 1'b1;
			end
			if (enT1)
				wendReg <= permStop;
		end
	initial _sv2v_0 = 0;
endmodule
