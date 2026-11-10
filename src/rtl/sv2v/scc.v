module scc (
	clk,
	cep,
	cen,
	reset_hw,
	cs,
	we,
	rs,
	wdata,
	rdata,
	_irq,
	rxd,
	txd,
	cts,
	rts,
	dcd_a,
	dcd_b,
	wreq
);
	input clk;
	input cep;
	input cen;
	input reset_hw;
	input cs;
	input we;
	input [1:0] rs;
	input [7:0] wdata;
	output wire [7:0] rdata;
	output wire _irq;
	input rxd;
	output wire txd;
	input cts;
	output wire rts;
	input dcd_a;
	input dcd_b;
	output wire wreq;
	reg [3:0] rindex;
	reg [3:0] rindex_latch;
	wire wreg_a;
	wire wreg_b;
	wire reset_a;
	wire reset_b;
	wire reset;
	wire [7:0] data_a;
	reg [7:0] data_b = 0;
	wire [7:0] rr0_a;
	wire [7:0] rr0_b;
	wire [7:0] rr1_a;
	wire [7:0] rr1_b;
	wire [7:0] rr2_b;
	wire [7:0] rr3_a;
	wire [7:0] rr10_a;
	wire [7:0] rr10_b;
	wire [7:0] rr15_a;
	wire [7:0] rr15_b;
	reg [7:0] wr1_a;
	reg [7:0] wr1_b;
	reg [7:0] wr2;
	reg [7:0] wr3_a;
	reg [7:0] wr3_b;
	reg [7:0] wr4_a;
	reg [7:0] wr4_b;
	reg [7:0] wr5_a;
	reg [7:0] wr5_b;
	reg [7:0] wr6_a;
	reg [7:0] wr6_b;
	reg [7:0] wr8_a;
	reg [7:0] wr8_b;
	reg [5:0] wr9;
	reg [7:0] wr10_a;
	reg [7:0] wr10_b;
	reg [7:0] wr11_a;
	reg [7:0] wr11_b;
	reg [7:0] wr12_a;
	reg [7:0] wr12_b;
	reg [7:0] wr13_a;
	reg [7:0] wr13_b;
	reg [7:0] wr14_a;
	reg [7:0] wr14_b;
	reg [7:0] wr15_a;
	reg [7:0] wr15_b;
	reg latch_open_a;
	reg latch_open_b;
	reg cts_latch_a;
	reg dcd_latch_a;
	reg dcd_latch_b;
	wire cts_a;
	wire cts_ip_a;
	wire dcd_ip_a;
	wire dcd_ip_b;
	wire do_latch_a;
	wire do_latch_b;
	wire do_extreset_a;
	wire do_extreset_b;
	wire rx_irq_pend_a;
	wire rx_irq_pend_b;
	wire tx_irq_pend_a;
	wire tx_irq_pend_b;
	wire ex_irq_pend_a;
	wire ex_irq_pend_b;
	reg ex_irq_ip_a;
	reg ex_irq_ip_b;
	wire [2:0] rr2_vec_stat;
	reg [7:0] tx_data_a;
	reg wr8_wr_a;
	reg wr8_wr_b;
	assign wreg_a = ((cs & we) & ~rs[1]) & rs[0];
	assign wreg_b = ((cs & we) & ~rs[1]) & ~rs[0];
	always @(posedge clk)
		if (~cs)
			rindex <= rindex_latch;
	reg wr_data_a;
	reg wr_data_b;
	reg rx_wr_a_latch;
	reg rx_first_a = 1;
	wire rx_wr_a;
	wire tx_busy_a;
	always @(posedge clk) begin
		if (rx_wr_a)
			rx_wr_a_latch <= 1;
		if (tx_busy_a)
			wr_data_a <= 0;
		wr_data_b <= 0;
		if (reset) begin
			rindex_latch <= 0;
			tx_data_a <= 0;
			data_b <= 0;
			rx_wr_a_latch <= 0;
			wr_data_a <= 0;
			rx_first_a <= 1;
		end
		else if (cen && cs) begin
			if (!rs[1]) begin
				rindex_latch <= 0;
				if (we && (rindex == 0)) begin
					rindex_latch[2:0] <= wdata[2:0];
					rindex_latch[3] <= wdata[5:3] == 3'b001;
					if (wdata[5:3] == 3'b100)
						rx_first_a <= 1;
				end
			end
			else if (we) begin
				if (rs[0]) begin
					tx_data_a <= wdata;
					wr_data_a <= 1;
				end
				else begin
					data_b <= wdata;
					wr_data_b <= 1;
				end
			end
			else if (rs[0]) begin
				rx_wr_a_latch <= 0;
				rx_first_a <= 0;
			end
		end
	end
	assign reset = (((wreg_a | wreg_b) & (rindex == 9)) & (wdata[7:6] == 2'b11)) | reset_hw;
	assign reset_a = (((wreg_a | wreg_b) & (rindex == 9)) & (wdata[7:6] == 2'b10)) | reset;
	assign reset_b = (((wreg_a | wreg_b) & (rindex == 9)) & (wdata[7:6] == 2'b01)) | reset;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr1_a <= 0;
		else if (cen) begin
			if (reset_a)
				wr1_a <= {2'b00, wr1_a[5], 2'b00, wr1_a[2], 2'b00};
			else if (wreg_a && (rindex == 1))
				wr1_a <= wdata;
		end
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr1_b <= 0;
		else if (cen) begin
			if (reset_b)
				wr1_b <= {2'b00, wr1_b[5], 2'b00, wr1_b[2], 2'b00};
			else if (wreg_b && (rindex == 1))
				wr1_b <= wdata;
		end
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr2 <= 0;
		else if ((cen && (wreg_a || wreg_b)) && (rindex == 2))
			wr2 <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr3_a <= 0;
		else if ((cen && wreg_a) && (rindex == 3))
			wr3_a <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr3_b <= 0;
		else if ((cen && wreg_b) && (rindex == 3))
			wr3_b <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr4_a <= 0;
		else if ((cen && wreg_a) && (rindex == 4))
			wr4_a <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr4_b <= 0;
		else if ((cen && wreg_b) && (rindex == 4))
			wr4_b <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr5_a <= 0;
		else if (cen) begin
			if (reset_a)
				wr5_a <= {1'b0, wr5_a[6:5], 4'b0000, wr5_a[0]};
			else if (wreg_a && (rindex == 5))
				wr5_a <= wdata;
		end
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr5_b <= 0;
		else if (cen) begin
			if (reset_b)
				wr5_b <= {1'b0, wr5_b[6:5], 4'b0000, wr5_b[0]};
			else if (wreg_b && (rindex == 5))
				wr5_b <= wdata;
		end
	always @(posedge clk or posedge reset_hw)
		if (reset_hw) begin
			wr8_a <= 0;
			wr8_wr_a <= 1'b0;
		end
		else if ((cen && (rs[1] & we)) && (rindex == 8)) begin
			wr8_wr_a <= 1'b1;
			wr8_a <= wdata;
		end
		else
			wr8_wr_a <= 1'b0;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw) begin
			wr8_b <= 0;
			wr8_wr_b <= 1'b0;
		end
		else if ((cen && wreg_b) && (rindex == 8)) begin
			wr8_wr_b <= 1'b1;
			wr8_b <= wdata;
		end
		else
			wr8_wr_b <= 1'b0;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr9 <= 0;
		else if ((cen && (wreg_a || wreg_b)) && (rindex == 9))
			wr9 <= wdata[5:0];
	always @(posedge clk or posedge reset)
		if (reset)
			wr10_a <= 0;
		else if (cen) begin
			if (reset_a)
				wr10_a <= {1'b0, wr10_a[6:5], 5'b00000};
			else if (wreg_a && (rindex == 10))
				wr10_a <= wdata;
		end
	always @(posedge clk or posedge reset)
		if (reset)
			wr10_b <= 0;
		else if (cen) begin
			if (reset_b)
				wr10_b <= {1'b0, wr10_b[6:5], 5'b00000};
			else if (wreg_b && (rindex == 10))
				wr10_b <= wdata;
		end
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr11_a <= 0;
		else if ((cen && wreg_a) && (rindex == 11))
			wr11_a <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr11_b <= 0;
		else if ((cen && wreg_b) && (rindex == 11))
			wr11_b <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr12_a <= 0;
		else if ((cen && wreg_a) && (rindex == 12))
			wr12_a <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr12_b <= 0;
		else if ((cen && wreg_b) && (rindex == 12))
			wr12_b <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr13_a <= 0;
		else if ((cen && wreg_a) && (rindex == 13))
			wr13_a <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr13_b <= 0;
		else if ((cen && wreg_b) && (rindex == 13))
			wr13_b <= wdata;
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr14_a <= 0;
		else if (cen) begin
			if (reset)
				wr14_a <= {wr14_a[7:6], 6'b110000};
			else if (reset_a)
				wr14_a <= {wr14_a[7:6], 4'b1000, wr14_a[1:0]};
			else if (wreg_a && (rindex == 14))
				wr14_a <= wdata;
		end
	always @(posedge clk or posedge reset_hw)
		if (reset_hw)
			wr14_b <= 0;
		else if (cen) begin
			if (reset)
				wr14_b <= {wr14_b[7:6], 6'b110000};
			else if (reset_b)
				wr14_b <= {wr14_b[7:6], 4'b1000, wr14_b[1:0]};
			else if (wreg_b && (rindex == 14))
				wr14_b <= wdata;
		end
	always @(posedge clk or posedge reset)
		if (reset) begin
			wr15_a <= 8'b11111000;
			wr15_b <= 8'b11111000;
		end
		else if (cen && (rindex == 15)) begin
			if (wreg_a)
				wr15_a <= wdata;
			if (wreg_b)
				wr15_b <= wdata;
		end
	assign rdata = (rs[1] && rs[0] ? data_a : (rs[1] ? data_b : ((rindex == 0) && rs[0] ? rr0_a : (rindex == 0 ? rr0_b : ((rindex == 1) && rs[0] ? rr1_a : (rindex == 1 ? rr1_b : ((rindex == 2) && rs[0] ? wr2 : (rindex == 2 ? rr2_b : ((rindex == 3) && rs[0] ? rr3_a : (rindex == 3 ? 8'h00 : ((rindex == 4) && rs[0] ? rr0_a : (rindex == 4 ? rr0_b : ((rindex == 5) && rs[0] ? rr1_a : (rindex == 5 ? rr1_b : ((rindex == 6) && rs[0] ? wr2 : (rindex == 6 ? rr2_b : ((rindex == 7) && rs[0] ? rr3_a : (rindex == 7 ? 8'h00 : ((rindex == 8) && rs[0] ? data_a : (rindex == 8 ? data_b : ((rindex == 9) && rs[0] ? wr13_a : (rindex == 9 ? wr13_b : ((rindex == 10) && rs[0] ? rr10_a : (rindex == 10 ? rr10_b : ((rindex == 11) && rs[0] ? rr15_a : (rindex == 11 ? rr15_b : ((rindex == 12) && rs[0] ? wr12_a : (rindex == 12 ? wr12_b : ((rindex == 13) && rs[0] ? wr13_a : (rindex == 13 ? wr13_b : ((rindex == 14) && rs[0] ? rr10_a : (rindex == 14 ? rr10_b : ((rindex == 15) && rs[0] ? rr15_a : (rindex == 15 ? rr15_b : 8'hff))))))))))))))))))))))))))))))))));
	assign rr0_a = {2'b01, (wr15_a[5] ? cts_latch_a : cts_a), 1'b0, (wr15_a[3] ? dcd_latch_a : dcd_a), ~tx_busy_a, 1'b0, rx_wr_a_latch};
	assign rr0_b = {4'b0100, (wr15_b[3] ? dcd_latch_b : dcd_b), 3'b100};
	assign rr1_a = {7'b0000011, ~tx_busy_a};
	assign rr1_b = 8'b00000111;
	assign rr2_b = {wr2[7], (wr9[4] ? rr2_vec_stat[0] : wr2[6]), (wr9[4] ? rr2_vec_stat[1] : wr2[5]), (wr9[4] ? rr2_vec_stat[2] : wr2[4]), (wr9[4] ? wr2[3] : rr2_vec_stat[2]), (wr9[4] ? wr2[2] : rr2_vec_stat[1]), (wr9[4] ? wr2[1] : rr2_vec_stat[0]), wr2[0]};
	assign rr3_a = {2'b00, rx_irq_pend_a, tx_irq_pend_a, ex_irq_pend_a, rx_irq_pend_b, tx_irq_pend_b, ex_irq_pend_b};
	assign rr10_a = 8'b00000000;
	assign rr10_b = 8'b00000000;
	assign rr15_a = {wr15_a[7], wr15_a[6], wr15_a[5], wr15_a[4], wr15_a[3], 1'b0, wr15_a[1], 1'b0};
	assign rr15_b = {wr15_b[7], wr15_b[6], wr15_b[5], wr15_b[4], wr15_b[3], 1'b0, wr15_b[1], 1'b0};
	reg tx_busy_aD;
	reg tx_ip;
	assign tx_irq_pend_a = tx_ip;
	always @(posedge clk)
		if (reset_a)
			tx_ip <= 0;
		else if (cen) begin
			tx_busy_aD <= tx_busy_a;
			if (((wr5_a[3] & wr1_a[1]) & ~tx_busy_a) & tx_busy_aD)
				tx_ip <= 1;
			if ((wreg_a & (rindex == 0)) & (wdata[5:3] == 3'b111))
				tx_ip <= 0;
			if ((wreg_a & (rindex == 0)) & (wdata[5:3] == 3'b101))
				tx_ip <= 0;
			if (wr5_a[3] == 0)
				tx_ip <= 0;
		end
	assign rx_irq_pend_a = ((wr3_a[0] & rx_wr_a_latch) & (wr1_a[3] ^ wr1_a[4])) & ((wr1_a[3] & rx_first_a) | wr1_a[4]);
	assign ex_irq_pend_a = ex_irq_ip_a;
	assign rx_irq_pend_b = 0;
	assign tx_irq_pend_b = 0;
	assign ex_irq_pend_b = ex_irq_ip_b;
	assign _irq = ~(wr9[3] & (((((rx_irq_pend_a | rx_irq_pend_b) | tx_irq_pend_a) | tx_irq_pend_b) | ex_irq_pend_a) | ex_irq_pend_b));
	assign rr2_vec_stat = (rx_irq_pend_a ? 3'b110 : (tx_irq_pend_a ? 3'b100 : (ex_irq_pend_a ? 3'b101 : (rx_irq_pend_b ? 3'b010 : (tx_irq_pend_b ? 3'b000 : (ex_irq_pend_b ? 3'b001 : 3'b011))))));
	assign do_extreset_a = (wreg_a & (rindex == 0)) & (wdata[5:3] == 3'b010);
	assign do_extreset_b = (wreg_b & (rindex == 0)) & (wdata[5:3] == 3'b010);
	assign dcd_ip_a = (dcd_a != dcd_latch_a) & wr15_a[3];
	assign cts_ip_a = (cts_a != cts_latch_a) & wr15_a[5];
	assign dcd_ip_b = (dcd_b != dcd_latch_b) & wr15_b[3];
	assign do_latch_a = latch_open_a & (dcd_ip_a | cts_ip_a);
	assign do_latch_b = latch_open_b & dcd_ip_b;
	always @(posedge clk or posedge reset)
		if (reset)
			ex_irq_ip_a <= 0;
		else if (cep) begin
			if (do_extreset_a)
				ex_irq_ip_a <= 0;
			else if (do_latch_a && wr1_a[0])
				ex_irq_ip_a <= 1;
		end
	always @(posedge clk or posedge reset)
		if (reset)
			ex_irq_ip_b <= 0;
		else if (cep) begin
			if (do_extreset_b)
				ex_irq_ip_b <= 0;
			else if (do_latch_b && wr1_b[0])
				ex_irq_ip_b <= 1;
		end
	always @(posedge clk or posedge reset)
		if (reset)
			latch_open_a <= 1;
		else if (cep) begin
			if (do_extreset_a)
				latch_open_a <= 1;
			else if (do_latch_a)
				latch_open_a <= 0;
		end
	always @(posedge clk or posedge reset)
		if (reset)
			latch_open_b <= 1;
		else if (cep) begin
			if (do_extreset_b)
				latch_open_b <= 1;
			else if (do_latch_b)
				latch_open_b <= 0;
		end
	always @(posedge clk or posedge reset)
		if (reset) begin
			dcd_latch_a <= 0;
			cts_latch_a <= 0;
		end
		else if (cep) begin
			if (do_latch_a)
				dcd_latch_a <= dcd_a;
			cts_latch_a <= cts_a;
		end
	always @(posedge clk or posedge reset)
		if (reset)
			dcd_latch_b <= 0;
		else if (cep) begin
			if (do_latch_b)
				dcd_latch_b <= dcd_b;
		end
	wire parity_ena_a = wr4_a[0];
	wire parity_even_a = wr4_a[1];
	wire [1:0] stop_bits_a = (wr4_a[3:2] == 2'b11 ? 2'd1 : 2'd0);
	wire [1:0] bit_per_char_a = (wr3_a[7:6] == 2'b00 ? 2'd3 : (wr3_a[7:6] == 2'b01 ? 2'd1 : (wr3_a[7:6] == 2'b10 ? 2'd2 : 2'd0)));
	wire clk_src_trxc = wr11_a[4:3] == 2'b01;
	wire [16:0] baud_base = (clk_src_trxc ? 17'd1 : {{wr13_a, wr12_a} + 16'd2, 1'b0});
	wire [23:0] baud_divid_speed_a = (wr4_a[7:6] == 2'b00 ? {7'b0000000, baud_base} : (wr4_a[7:6] == 2'b01 ? {3'b000, baud_base, 4'b0000} : (wr4_a[7:6] == 2'b10 ? {2'b00, baud_base, 5'b00000} : {1'b0, baud_base, 6'b000000})));
	reg [31:0] clk_en_cnt;
	reg clk_en;
	localparam SYSTEM_CLOCK = 32'd15600000;
	localparam SCC_CLOCK = 32'd3686000;
	localparam TRxC_CLOCK = 32'd1000000;
	wire [31:0] target_clock = (clk_src_trxc ? TRxC_CLOCK : SCC_CLOCK);
	always @(posedge clk) begin
		clk_en <= 1'b0;
		if (clk_en_cnt < SYSTEM_CLOCK)
			clk_en_cnt <= clk_en_cnt + target_clock;
		else begin
			clk_en_cnt <= (clk_en_cnt - SYSTEM_CLOCK) + target_clock;
			clk_en <= 1'b1;
		end
	end
	wire [30:0] uart_setup_a = {1'b0, bit_per_char_a, 1'b0, parity_ena_a, 1'b0, parity_even_a, baud_divid_speed_a};
	wire break_a;
	wire parity_err_a;
	wire frame_err_a;
	rxuart rxuart_a(
		.i_clk(clk),
		.i_en(clk_en),
		.i_reset(reset_a | reset_hw),
		.i_setup(uart_setup_a),
		.i_uart_rx(rxd),
		.o_wr(rx_wr_a),
		.o_data(data_a),
		.o_break(break_a),
		.o_parity_err(parity_err_a),
		.o_frame_err(frame_err_a),
		.o_ck_uart()
	);
	txuart txuart_a(
		.i_clk(clk),
		.i_en(clk_en),
		.i_reset(reset_a | reset_hw),
		.i_setup(uart_setup_a),
		.i_break(1'b0),
		.i_wr(wr_data_a),
		.i_data(tx_data_a),
		.i_cts_n(1'b0),
		.o_uart_tx(txd),
		.o_busy(tx_busy_a)
	);
	assign cts_a = ~tx_busy_a;
	assign rts = rx_wr_a_latch;
	assign wreq = 1;
endmodule
