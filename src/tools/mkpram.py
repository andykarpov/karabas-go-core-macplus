#!/usr/bin/env python3
"""Writes pram.bin, the eeprom_init of core.json: the first content of /config/macplus.eep.

The firmware keeps registers 0x0E..0xFF of the MC146818A layout of kg_mcu (rtc_mode 0) in that file;
mac_clock puts the 20 PRAM bytes of the Mac at 0x10..0x23 (rtc.v ram[i] = register 0x10 + i).
Registers 0x0A / 0x0B: 26 / 02 (32 kHz, 24 hours, BCD) as core-archie. The PRAM defaults are those
of rtc.v of NanoMac / plus_too (byte 0x10 of the Mac, A8, says the PRAM is valid).
"""
import os

PRAM = [0xA8, 0x00, 0x00, 0x22, 0xCC, 0x0A, 0xCC, 0x0A, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x02, 0x63, 0x00, 0x03, 0x88, 0x00, 0x6C]

data = bytearray(256)
data[0x0A] = 0x26
data[0x0B] = 0x02
data[0x10:0x10 + len(PRAM)] = bytes(PRAM)
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "pram.bin")
with open(out, "wb") as f:
    f.write(data)
print(out)
