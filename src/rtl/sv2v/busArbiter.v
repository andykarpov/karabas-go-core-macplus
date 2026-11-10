module busArbiter (
	Clks,
	BRi,
	BgackI,
	Halti,
	bgBlock,
	busAvail,
	BGn
);
	reg _sv2v_0;
	input wire [4:0] Clks;
	input BRi;
	input BgackI;
	input Halti;
	input bgBlock;
	output wire busAvail;
	output reg BGn;
	reg [31:0] dmaPhase;
	reg [31:0] next;
	always @(*) begin
		if (_sv2v_0)
			;
		case (dmaPhase)
			32'd0: next = 32'd1;
			32'd1:
				if (bgBlock)
					next = 32'd1;
				else if (~BgackI)
					next = 32'd4;
				else if (~BRi)
					next = 32'd2;
				else
					next = 32'd1;
			32'd4:
				if (~BRi & !bgBlock)
					next = 32'd6;
				else if (~BgackI & !bgBlock)
					next = 32'd4;
				else
					next = 32'd1;
			32'd2: next = 32'd3;
			32'd3: next = (~BRi & BgackI ? 32'd3 : 32'd4);
			32'd6: next = 32'd5;
			32'd5:
				case ({BgackI, BRi})
					2'b11: next = 32'd1;
					2'b10: next = 32'd3;
					2'b01: next = 32'd7;
					2'b00: next = 32'd5;
				endcase
			32'd7: next = 32'd4;
			default: next = 32'd1;
		endcase
	end
	reg granting;
	always @(*) begin
		if (_sv2v_0)
			;
		(* full_case, parallel_case *)
		case (next)
			32'd2, 32'd6, 32'd3, 32'd5: granting = 1'b1;
			default: granting = 1'b0;
		endcase
	end
	reg rGranted;
	assign busAvail = ((Halti & BRi) & BgackI) & ~rGranted;
	always @(posedge Clks[4]) begin
		if (Clks[3]) begin
			dmaPhase <= 32'd0;
			rGranted <= 1'b0;
		end
		else if (Clks[0]) begin
			dmaPhase <= next;
			rGranted <= granting;
		end
		if (Clks[3])
			BGn <= 1'b1;
		else if (Clks[1])
			BGn <= ~rGranted;
	end
	initial _sv2v_0 = 0;
endmodule
