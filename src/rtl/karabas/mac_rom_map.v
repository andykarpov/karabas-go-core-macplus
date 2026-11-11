`timescale 1ns / 1ps
`default_nettype wire

/*
 mac_rom_map.v

 Where the ROM files are in the SRAM (mac_sram: byte addresses for the writes of the file loader,
 word addresses for the reads of the machine), and which one the model reads:
   ROM Plus (FL slot 7, 128 KB) at byte 000000 (word 000000)
   ROM SE   (FL slot 6, 256 KB) at byte 040000 (word 020000)
   ROM 64K  (FL slot 5,  64 KB) at byte 080000 (word 040000): the ROM of the 128K and the 512K
 The bytes of a file past its size are dropped. The machine gives A18..A1 of its ROM space (romAddr
 of addrController: A17 / A16 forced for the 64K ROM, A17 for the 128K one): the low 17 / 16 / 15
 bits are the word in the file.
*/

module mac_rom_map (
	input  wire [1:0]  rom_size,     // 0 64K (128K / 512K), 1 128K (Plus, 512Ke), 2 256K (SE)
	input  wire [17:0] rom_addr,     // romAddr of the machine (a word address)
	output wire [20:0] raddr,        // mac_sram

	input  wire [7:0]  file_slot,
	input  wire [31:0] file_addr,
	input  wire        file_wr,
	output wire        we,           // mac_sram
	output wire [21:0] waddr
);

assign raddr = rom_size == 2'd2 ? { 4'b0001, rom_addr[16:0] } :
	rom_size == 2'd0 ? { 6'b001000, rom_addr[14:0] } : { 5'd0, rom_addr[15:0] };

assign we = file_wr && (
	(file_slot == 8'd7 && file_addr[31:17] == 15'd0) ||
	(file_slot == 8'd6 && file_addr[31:18] == 14'd0) ||
	(file_slot == 8'd5 && file_addr[31:16] == 16'd0));

assign waddr = file_slot == 8'd6 ? { 4'b0001, file_addr[17:0] } :
	file_slot == 8'd5 ? { 6'b001000, file_addr[15:0] } : { 5'd0, file_addr[16:0] };

endmodule
