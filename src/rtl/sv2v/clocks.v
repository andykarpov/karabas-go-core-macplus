module clocks (
	clk,
	clk8_en_p,
	clk8_en_n,
	busPhase,
	cycleReady,
	videoBusControl,
	cpuBusControl
);
	input clk;
	output wire clk8_en_p;
	output wire clk8_en_n;
	output reg [2:0] busPhase;
	output wire cycleReady;
	output wire videoBusControl;
	output wire cpuBusControl;
	reg busCycle;
	always @(posedge clk) begin
		busPhase <= busPhase + 1'd1;
		if (busPhase == 3'd7)
			busCycle <= !busCycle;
	end
	assign cycleReady = busPhase == 3'd7;
	assign clk8_en_p = busPhase[0];
	assign clk8_en_n = !busPhase[0];
	assign videoBusControl = !busCycle;
	assign cpuBusControl = busCycle;
endmodule
