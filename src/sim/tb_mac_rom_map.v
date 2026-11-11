`timescale 1ns / 1ps

// tb_mac_rom_map.v (iverilog): the three ROM files written through their FL slots (each a little
// past its size, those bytes must be dropped) into a byte model of the SRAM, then every word of
// each read back with the ROM addresses the machine gives for its model (romAddr of addrController:
// the 128K ROM with A17 = 0, the 64K one with A17 = 1, A16 = 0) and compared with the file.

module tb_mac_rom_map;

reg [1:0] rom_size = 0;
reg [17:0] rom_addr = 0;
wire [20:0] raddr;
reg [7:0] file_slot = 0;
reg [31:0] file_addr = 0;
reg file_wr = 0;
wire we;
wire [21:0] waddr;

mac_rom_map dut (
	.rom_size(rom_size), .rom_addr(rom_addr), .raddr(raddr),
	.file_slot(file_slot), .file_addr(file_addr), .file_wr(file_wr), .we(we), .waddr(waddr)
);

reg [7:0] sram [0:2097151];
integer errors = 0, i, m, words;

function [7:0] fbyte(input integer slot, input integer a);
	fbyte = (slot * 8'h35) ^ a[7:0] ^ (a >> 8) ^ (a >> 16);
endfunction

task load(input integer slot, input integer size);
	begin
		for (i = 0; i < size + 4096; i = i + 1) begin
			file_slot = slot; file_addr = i; file_wr = 1;
			#1;
			if (we) sram[waddr] = fbyte(slot, i);
			if (we && i >= size) begin
				if (errors < 10) $display("ERROR: slot %0d byte %0d past its size written", slot, i);
				errors = errors + 1;
			end
			if (!we && i < size) begin
				if (errors < 10) $display("ERROR: slot %0d byte %0d not written", slot, i);
				errors = errors + 1;
			end
		end
		file_wr = 0;
	end
endtask

initial begin
	for (i = 0; i < 2097152; i = i + 1) sram[i] = 8'hxx;
	load(7, 131072);
	load(6, 262144);
	load(5, 65536);
	// model: ROM size, file slot, words
	for (m = 0; m < 3; m = m + 1) begin
		rom_size = m == 0 ? 2'd1 : m == 1 ? 2'd2 : 2'd0;
		words = m == 0 ? 65536 : m == 1 ? 131072 : 32768;
		for (i = 0; i < words; i = i + 1) begin
			rom_addr = m == 0 ? { 2'b00, i[15:0] } : m == 1 ? { 1'b0, i[16:0] } : { 3'b010, i[14:0] };
			#1;
			if ({ sram[{ raddr, 1'b0 }], sram[{ raddr, 1'b1 }] } !==
			    { fbyte(m == 0 ? 7 : m == 1 ? 6 : 5, 2 * i), fbyte(m == 0 ? 7 : m == 1 ? 6 : 5, 2 * i + 1) }) begin
				if (errors < 10) $display("ERROR: ROM size %0d word %0d at %06x: %02x%02x", rom_size, i, raddr,
					sram[{ raddr, 1'b0 }], sram[{ raddr, 1'b1 }]);
				errors = errors + 1;
			end
		end
	end
	$display("tb_mac_rom_map: %0d errors", errors);
	$finish;
end

endmodule
