#!/bin/bash
# The Ф1 check of the machine (about a minute): the Plus ROM without a disk up to the grey desktop
# with the "?" disk (3 s of machine time, 1 MB RAM, fastboot), the last frame as build/nodisk_*.ppm.
# A floppy boot to the Finder takes minutes: run_boot.sh --fd0 ... by hand.
set -e
cd "$(dirname "$0")"
echo "==== sim/run_checks.sh: no disk, \"?\" icon"
./run_boot.sh --ms 3000 --report 1000 --ppm sim/build/nodisk --every 1000 \
	--expect-frames 175 --expect-pc-in 400000:41ffff --expect-black 86000:90000
