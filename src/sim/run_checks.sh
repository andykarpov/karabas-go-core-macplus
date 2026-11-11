#!/bin/bash
# The checks of the core (about five minutes):
#   tb_mac_sdc (iverilog, seconds): the sector bytes of img_sdc into the clock of the machine
#   tb_floppy_swap (iverilog, seconds): a new floppy image in a drive drops the buffered track
#   tb_mac_video (iverilog, ~35 s): the frame buffer out as 1024 x 768, every pixel of a frame
#   the Plus ROM without a disk up to the grey desktop with the "?" disk (3 s of machine time, 1 MB,
#   fastboot) on the memory models of NanoMac (~85 s) and on the memory path of the boards
#   (BOARD=1: mac_sdram + SDRAM model, mac_sram + SRAM model, the frame buffer; ~135 s)
# A floppy boot to the Finder takes minutes: run_boot.sh --fd0 ... by hand.
set -e
cd "$(dirname "$0")"
mkdir -p build
echo "==== sim/tb_mac_sdc"
iverilog -o build/tb_mac_sdc tb_mac_sdc.v ../rtl/karabas/mac_sdc.v
vvp -n build/tb_mac_sdc | tee build/tb_mac_sdc.log | tail -1
grep -q "tb_mac_sdc: 0 errors" build/tb_mac_sdc.log
echo "==== sim/tb_floppy_swap"
iverilog -g2005 -o build/tb_floppy_swap tb_floppy_swap.v ../rtl/sv2v/floppy_track_buffer.v
vvp -n build/tb_floppy_swap | tee build/tb_floppy_swap.log | tail -2 | head -1
grep -q "tb_floppy_swap: 0 errors" build/tb_floppy_swap.log
echo "==== sim/tb_mac_video"
iverilog -o build/tb_mac_video tb_mac_video.v ../rtl/karabas/mac_video.v
vvp -n build/tb_mac_video | tee build/tb_mac_video.log | tail -1
grep -q "tb_mac_video: 0 errors" build/tb_mac_video.log
CHECK="--ms 3000 --report 1000 --every 1000 --expect-frames 175 --expect-pc-in 400000:41ffff --expect-black 86000:90000"
echo "==== sim/run_boot.sh: no disk, \"?\" icon"
./run_boot.sh $CHECK --ppm sim/build/nodisk
echo "==== sim/run_boot.sh BOARD=1: no disk, \"?\" icon"
BOARD=1 ./run_boot.sh $CHECK --ppm sim/build/board
