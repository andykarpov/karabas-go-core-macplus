`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_sdram.v

 The RAM of the Mac (up to 4 MB = 2M words) in the SDRAM of the board (MT48LC16M16A2, 16 bit), one
 access per bus cycle of the machine, as the SDRAM controller of the NanoMac Tang top (src/rtl/tang/
 sdram.v) but on a clock twice the machine clock, so that the read data are there earlier.

 clk is clk_2x, the machine runs on clk_sys = clk_2x / 2 of the same PLL (rising edges together).
 sys_t is a register of clk_sys that toggles every clock: the clk_2x edges where sys_t equals its
 copy of the previous clk_2x clock are the edges of clk_sys. At the clk_sys edge that ends busPhase
 2 (phase == 2 there):
   - ACTIVE with the row, or AUTO REFRESH when the machine has no access in this bus cycle;
   - at the clk_2x edge in the middle of busPhase 4 READ or WRITE with auto precharge: which one,
     the write data and DQM are taken there. The Tang controller decides at the end of phase 3 and
     its SDRAM takes DQM and the data in the middle of phase 4: the 68000 drives R/W low after
     phase 2 and UDS / LDS of a write later still (at the end of phase 3 they are not there yet);
   - CL 2: the data are taken at the clk_sys edge that ends busPhase 5 and held until the next
     read. The machine takes them at the end of busPhase 6 / 7 (the Tang controller gives them
     during phase 6, the simulation of NanoMac from the end of phase 5).

 SDR_CLK is clk_2x inverted (an ODDR2 in the top): the SDRAM takes a command in the middle of its
 clock. Rows 4096 x columns 512 of bank 0 hold the 2M words. Refresh: the bus cycles without an
 access (most of the video cycles in the blanking, idle CPU cycles) are AUTO REFRESH: far more than
 the 8192 per 64 ms the chip needs.

 Initialisation after reset_n (the PLL locked, 200 us waited by the top): PRECHARGE ALL, 8 x AUTO
 REFRESH, LOAD MODE (burst 1, CL 2, single writes), then ready.
*/

module mac_sdram (
	input  wire        clk,        // clk_2x
	input  wire        reset_n,
	output reg         ready = 1'b0,

	// the machine (clk_sys registers)
	input  wire        sys_t,
	input  wire [2:0]  phase,
	input  wire [20:0] addr,       // word address
	input  wire [15:0] din,
	output reg  [15:0] dout = 16'd0,
	input  wire [1:0]  ds,         // [1] upper, [0] lower byte
	input  wire        oe,
	input  wire        we,

	// the chip
	output reg  [12:0] SDR_A = 13'd0,
	output reg  [1:0]  SDR_BA = 2'b00,
	inout  wire [15:0] SDR_DQ,
	output reg  [1:0]  SDR_DQM = 2'b11,
	output wire        SDR_CS_N,
	output wire        SDR_RAS_N,
	output wire        SDR_CAS_N,
	output wire        SDR_WE_N
);

localparam CMD_NOP       = 4'b0111;
localparam CMD_ACTIVE    = 4'b0011;
localparam CMD_READ      = 4'b0101;
localparam CMD_WRITE     = 4'b0100;
localparam CMD_PRECHARGE = 4'b0010;
localparam CMD_REFRESH   = 4'b0001;
localparam CMD_LOAD_MODE = 4'b0000;
localparam CMD_INHIBIT   = 4'b1111;

// burst 1, sequential, CL 2, standard, single location writes
localparam [12:0] MODE = 13'b000_1_00_010_0_000;

(* IOB = "TRUE" *) reg [3:0] cmd = CMD_INHIBIT;
assign { SDR_CS_N, SDR_RAS_N, SDR_CAS_N, SDR_WE_N } = cmd;

(* IOB = "TRUE" *) reg [15:0] dq_out = 16'd0;
reg dq_oe = 1'b0;
assign SDR_DQ = dq_oe ? dq_out : 16'bz;

// the edges of clk_sys
reg sys_t_d = 1'b0;
always @(posedge clk) sys_t_d <= sys_t;
wire sys_edge = (sys_t == sys_t_d);
wire start = sys_edge && phase == 3'd2;

reg [3:0] st = 4'd0;   // 0 idle; 1, 2 wait; 3 read / write; 4, 5 wait; the data at 6
reg rd = 1'b0;

// initialisation: a counter of start slots (one per bus cycle, 1 us)
reg [7:0] init = 8'd0;

always @(posedge clk) begin
	cmd <= CMD_NOP;
	dq_oe <= 1'b0;

	if (!reset_n) begin
		ready <= 1'b0;
		init <= 8'd0;
		st <= 4'd0;
		cmd <= CMD_INHIBIT;
	end
	else if (!ready) begin
		if (start) begin
			init <= init + 8'd1;
			case (init)
			8'd4: begin cmd <= CMD_PRECHARGE; SDR_A[10] <= 1'b1; end
			8'd6, 8'd8, 8'd10, 8'd12, 8'd14, 8'd16, 8'd18, 8'd20: cmd <= CMD_REFRESH;
			8'd22: begin cmd <= CMD_LOAD_MODE; SDR_A <= MODE; SDR_BA <= 2'b00; end
			8'd24: ready <= 1'b1;
			default: ;
			endcase
		end
	end
	else begin
		case (st)
		4'd0:
			if (start) begin
				if (oe || we) begin
					cmd <= CMD_ACTIVE;
					SDR_BA <= 2'b00;
					SDR_A <= { 1'b0, addr[20:9] };
					st <= 4'd1;
				end
				else
					cmd <= CMD_REFRESH;
			end
		4'd1, 4'd2: st <= st + 4'd1;
		4'd3: begin
			// the edge in the middle of busPhase 4: we, din and ds of the machine are there
			cmd <= we ? CMD_WRITE : CMD_READ;
			rd <= !we;
			SDR_A <= { 2'b00, 1'b1, 1'b0, addr[8:0] };   // A10: auto precharge
			SDR_DQM <= we ? ~ds : 2'b00;
			dq_out <= din;
			dq_oe <= we;
			st <= 4'd4;
		end
		4'd4, 4'd5: st <= st + 4'd1;
		4'd6: begin
			if (rd) dout <= SDR_DQ;
			SDR_DQM <= 2'b11;
			st <= 4'd0;
		end
		default: st <= 4'd0;
		endcase
	end
end

endmodule
