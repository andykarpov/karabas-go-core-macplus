module ncr5380 (
	clk,
	reset,
	bus_cs,
	bus_rs,
	ior,
	iow,
	dack,
	dreq,
	wdata,
	rdata,
	img_mounted,
	img_size,
	wr_prot,
	io_lba,
	io_rd,
	io_wr,
	io_ack,
	sd_buff_addr,
	sd_buff_dout,
	sd_buff_din,
	sd_buff_wr
);
	input clk;
	input reset;
	input bus_cs;
	input [2:0] bus_rs;
	input ior;
	input iow;
	input dack;
	output wire dreq;
	input [7:0] wdata;
	output wire [7:0] rdata;
	parameter DEVS = 2;
	input [DEVS - 1:0] img_mounted;
	input [31:0] img_size;
	input wr_prot;
	output reg [(DEVS * 32) - 1:0] io_lba;
	output wire [DEVS - 1:0] io_rd;
	output wire [DEVS - 1:0] io_wr;
	input [DEVS - 1:0] io_ack;
	input [8:0] sd_buff_addr;
	input [7:0] sd_buff_dout;
	output wire [(DEVS * 8) - 1:0] sd_buff_din;
	input sd_buff_wr;
	reg dma_en;
	reg scsi_req;
	assign dreq = scsi_req & dma_en;
	reg [7:0] mr;
	reg [7:0] icr;
	reg [3:0] tcr;
	wire [7:0] csr;
	reg [7:0] din;
	reg [7:0] dout;
	reg dma_wr;
	reg reg_wr;
	reg dma_ack;
	wire i_dma_rd = (bus_cs & dack) & ior;
	wire i_dma_wr = (bus_cs & dack) & iow;
	wire i_reg_wr = (bus_cs & ~dack) & iow;
	always @(posedge clk) begin : sv2v_autoblock_1
		reg old_dma_rd;
		reg old_dma_wr;
		reg old_reg_wr;
		old_dma_rd <= i_dma_rd;
		old_dma_wr <= i_dma_wr;
		old_reg_wr <= i_reg_wr;
		dma_wr <= 0;
		dma_ack <= 0;
		reg_wr <= 0;
		if (~old_dma_wr & i_dma_wr)
			dma_wr <= 1;
		if (~old_reg_wr & i_reg_wr)
			reg_wr <= 1;
		if ((old_dma_wr & ~i_dma_wr) | (old_dma_rd & ~i_dma_rd))
			dma_ack <= dma_en;
	end
	wire bsr_berr = 1'b0;
	wire bsr_dmarq = scsi_req & dma_en;
	wire bsr_eodma = 1'b0;
	wire bsr_irq = 1'b0;
	wire bsr_perr = 1'b0;
	reg scsi_cd;
	reg scsi_io;
	reg scsi_msg;
	wire bsr_pmatch = ((tcr[2] == scsi_msg) && (tcr[1] == scsi_cd)) && (tcr[0] == scsi_io);
	wire scsi_ack = icr[4] | dma_ack;
	wire scsi_atn = icr[1];
	wire [7:0] bsr = {bsr_eodma, bsr_dmarq, bsr_perr, bsr_irq, bsr_pmatch, bsr_berr, scsi_atn, scsi_ack};
	wire out_en = icr[0] | mr[0];
	wire [7:0] cur_data = (out_en ? dout : din);
	wire icr_aip = mr[0];
	wire icr_la = 0;
	wire [7:0] icr_read = {icr[7], icr_aip, icr_la, icr[4], icr[3], icr[2], icr[1], icr[0]};
	assign rdata = (dack ? cur_data : (bus_rs == 3'h0 ? cur_data : (bus_rs == 3'h1 ? icr_read : (bus_rs == 3'h2 ? mr : (bus_rs == 3'h3 ? {4'h0, tcr} : (bus_rs == 3'h4 ? csr : (bus_rs == 3'h5 ? bsr : (bus_rs == 3'h6 ? cur_data : (bus_rs == 3'h7 ? 8'hff : 8'hff)))))))));
	always @(posedge clk)
		if ((reg_wr && (bus_rs == 3'h0)) || dma_wr)
			dout <= wdata;
	always @(posedge clk or posedge reset)
		if (reset)
			icr <= 0;
		else if (reg_wr && (bus_rs == 3'h1))
			icr <= wdata;
	always @(posedge clk or posedge reset)
		if (reset)
			mr <= 8'b00000000;
		else if (reg_wr && (bus_rs == 3'h2))
			mr <= wdata;
	always @(posedge clk or posedge reset)
		if (reset)
			tcr <= 4'b0000;
		else if (reg_wr && (bus_rs == 3'h3))
			tcr <= wdata[3:0];
	always @(posedge clk or posedge reset)
		if (reset)
			dma_en <= 0;
		else if (!mr[1])
			dma_en <= 0;
		else if (reg_wr && (bus_rs == 3'h5))
			dma_en <= 1;
		else if (reg_wr && (bus_rs == 3'h7))
			dma_en <= 1;
	wire [DEVS - 1:0] target_bsy;
	wire scsi_bsy = (icr[3] | (|target_bsy)) | mr[0];
	wire scsi_rst = icr[7];
	wire scsi_sel = icr[2];
	assign csr = {scsi_rst, scsi_bsy, scsi_req, scsi_msg, scsi_cd, scsi_io, scsi_sel, 1'b0};
	wire [DEVS - 1:0] target_cd;
	wire [7:0] target_dout [0:DEVS - 1];
	wire [DEVS - 1:0] target_io;
	wire [DEVS - 1:0] target_msg;
	wire [DEVS - 1:0] target_req;
	always @(*) begin : sv2v_autoblock_2
		integer i;
		scsi_cd = 0;
		scsi_io = 0;
		scsi_msg = 0;
		scsi_req = 0;
		din = 8'h55;
		for (i = 0; i < DEVS; i = i + 1)
			if (target_bsy[i]) begin
				scsi_cd = target_cd[i];
				scsi_io = target_io[i];
				scsi_msg = target_msg[i];
				scsi_req = target_req[i];
				din = target_dout[i];
			end
	end
	genvar _gv_i_1;
	generate
		for (_gv_i_1 = 0; _gv_i_1 < DEVS; _gv_i_1 = _gv_i_1 + 1) begin : target
			localparam i = _gv_i_1;
			wire [32:1] sv2v_tmp_target_io_lba;
			always @(*) io_lba[((DEVS - 1) - i) * 32+:32] = sv2v_tmp_target_io_lba;
			scsi #(.ID(3'd6 - i[2:0])) target(
				.clk(clk),
				.rst(scsi_rst),
				.sel(scsi_sel),
				.atn(scsi_atn),
				.ack(scsi_ack),
				.bsy(target_bsy[i]),
				.msg(target_msg[i]),
				.cd(target_cd[i]),
				.io(target_io[i]),
				.req(target_req[i]),
				.dout(target_dout[i]),
				.din(dout),
				.img_mounted(img_mounted[i]),
				.img_blocks(img_size),
				.wr_prot(wr_prot),
				.io_lba(sv2v_tmp_target_io_lba),
				.io_rd(io_rd[i]),
				.io_wr(io_wr[i]),
				.io_ack(io_ack[i] & target_bsy[i]),
				.sd_buff_addr(sd_buff_addr),
				.sd_buff_dout(sd_buff_dout),
				.sd_buff_din(sd_buff_din[((DEVS - 1) - i) * 8+:8]),
				.sd_buff_wr(sd_buff_wr & target_bsy[i])
			);
		end
	endgenerate
endmodule
