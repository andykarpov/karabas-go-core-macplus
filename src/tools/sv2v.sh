#!/bin/bash
# Converts the upstream RTL (SystemVerilog of NanoMac / MiSTer and fx68k) to Verilog-2001 for XST
# with sv2v (/opt/sv2v/sv2v): one file per module in rtl/sv2v/. The tops: macplus (the machine) and
# hid (+ keymap), which the board tops use.
# rtl/sv2v/ is generated and in git; change the sources (with a "karabas:" comment), then run this.
set -e
cd "$(dirname "$0")/../rtl"
SV2V=${SV2V:-/opt/sv2v/sv2v}
SRC="macplus/macplus.sv macplus/clocks.v macplus/addrController.v macplus/addrDecoder.v
 macplus/videoTimer.v macplus/videoShifter.v macplus/dataController.sv macplus/iwm.v
 macplus/floppy.v macplus/floppy_track_codec.v macplus/floppy_track_buffer.v
 macplus/ncr5380.sv macplus/scsi.v macplus/scc.v macplus/uart/rxuart.v macplus/uart/txuart.v
 macplus/via6522.v macplus/adb.sv macplus/keyboard.v macplus/rtc.v
 fx68k/fx68k.sv fx68k/fx68kAlu.sv fx68k/uaddrPla.sv
 companion/hid.v companion/macplus_keymap.v"
rm -rf sv2v && mkdir sv2v
$SV2V --top=macplus --top=hid $SRC -w sv2v 2>&1 | grep -v -E '^\s*$|Warning: Number literal|^ *[0-9]* \||^\s*\|' || true
ls sv2v | wc -l
# macplus.prj: the machine alone (make macplus-xst) and the source list of the simulations
{ for f in sv2v/*.v; do echo "verilog work \"rtl/$f\""; done; } > ../macplus.prj
