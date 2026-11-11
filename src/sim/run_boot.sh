#!/bin/bash
# Builds the verilator model of sim_top.v (the machine of rtl/sv2v = the files of macplus.prj, on
# memory models) and runs sim_macplus with the given arguments (see sim_macplus.cpp). The build
# goes to src/sim/build. The ROM: $MAC_ROM, default ~/Downloads/karabas-sd-macplus/macplus/plus.rom
# (the user's Plus ROM, never in the repo).
#   ./run_boot.sh --ms 3000 --ppm build/frame
#   ./run_boot.sh --ms 8000 --fd0 ~/Downloads/karabas-sd-macplus/macplus/Disk605.dsk --ppm build/frame
set -e
cd "$(dirname "$0")"
SRC=..
mkdir -p build
PRJ=$(sed -n 's/^verilog work "\(.*\)"/\1/p' $SRC/macplus.prj)
STAMP=build/obj/Vsim_top
if [ ! -x $STAMP ] || [ -n "$(cd $SRC && find $PRJ sim/sim_top.v sim/sim_macplus.cpp sim/run_boot.sh -newer sim/$STAMP 2>/dev/null)" ]; then
	echo "JOB-STAGE: build"
	(cd $SRC && verilator -O3 --x-assign fast -Wno-fatal -Wno-lint -Wno-style -Wno-BLKANDNBLK -Wno-MULTIDRIVEN \
		--no-timing --top-module sim_top -Mdir sim/build/obj --cc $PRJ sim/sim_top.v \
		--exe $PWD/sim/sim_macplus.cpp -o Vsim_top > sim/build/verilator.log 2>&1) || { tail -30 build/verilator.log; exit 1; }
	make -s -j8 -C build/obj -f Vsim_top.mk OPT_FAST=-O2 > build/make.log 2>&1 || { tail -30 build/make.log; exit 1; }
fi
ROM=${MAC_ROM:-$HOME/Downloads/karabas-sd-macplus/macplus/plus.rom}
echo "JOB-STAGE: sim"
# run from src/ so that the $readmem paths (rtl/...) resolve
cd $SRC
exec sim/build/obj/Vsim_top +rom=$ROM "$@"
