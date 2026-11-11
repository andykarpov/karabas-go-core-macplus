# Apple Macintosh Plus core for Karabas Go / Mini / Mini G

[Русская версия](README.ru.md)

Apple Macintosh Plus for the Karabas Go board family (Xilinx Spartan-6 XC6SLX25). A port of [NanoMac](https://github.com/MiSTle-Dev/NanoMac) by Till Harbaum, itself based on the [MiSTer](https://github.com/MiSTer-devel/MacPlus_MiSTer) and [MiST](https://github.com/mist-devel/plus_too) ports of Steve Chamberlin's [Plus Too](https://www.bigmessowires.com/plus-too/).

| Board | Core file | Video | Sound |
|---|---|---|---|
| Karabas Go | `macplus.kg` | VGA | I2S DAC (PCM5102) |
| Karabas Mini | `macplus.kg` | HDMI | HDMI, analog output (sigma-delta) |
| Karabas Mini G | `macplus.kg` | HDMI | HDMI, I2S DAC |

The core file is in `src/`. The Macintosh ROM and the system software are Apple's: they are not in this repository and not in the core file. Put your own ROM file on the SD card.

Status: checked on Mini G. The Go and Mini builds have not been run on a board yet.

## Features

- **CPU:** 68000 at 7.7 MHz (fx68k; the Mac Plus has 7.83 MHz).
- **Memory:** 1 MB or 4 MB of RAM (OSD item Memory), the 128 KB ROM of the Plus from the SD card.
- **Video:** 512 x 342 monochrome, shown as 1024 x 768 at 60 Hz, every pixel 2 x 2.
- **Floppies:** two 800 KB drives (internal and external), `.dsk` images, read and write.
- **Hard disks:** two SCSI disks (ID 6 and ID 5), `.vhd` / `.img` / `.hda` images, read and write.
- **Clock and PRAM:** the clock of the Mac is set from the clock of the board at start, and the Mac's own setting (Control Panel) goes back to it. The PRAM (the Control Panel settings) is kept in `/config/macplus.eep` on the SD card.
- **Input:** USB keyboard and mouse.
- **Sound:** the 8-bit sound of the Mac.

An image mounted read only (in the file browser of the OSD) is a write protected disk.

Not supported: the serial ports (modem, printer), the physical floppy drive of the Go, the SE / 512Ke / 128K models.

## Getting started

1. Copy `macplus.kg` (one file for Go, Mini and Mini G) to the root of the SD card.
2. Put the Mac Plus ROM as `/macplus/plus.rom` on the SD card (128 KB; the ROM of the Plus, v3, checksum 4D1F8172, works), and your disk images in `/macplus`.
3. Choose Mac Plus in the core menu. Without a disk the Mac shows the disk with the question mark. Open the OSD (**Menu+Esc**) and insert a system disk in Floppy 1 (System 6.0.x on an 800 KB disk works).

"Menu" is the Windows key of the keyboard.

## OSD menu

| Item | Values | Hotkey |
|---|---|---|
| Floppy 1, Floppy 2 | `.dsk` / `.img` image (800 KB) | Menu+F1, Menu+F2 |
| SCSI 6, SCSI 5 | `.vhd` / `.img` / `.hda` image | Menu+F3, Menu+F4 |
| ROM | `.rom` / `.bin` file (autoloaded from `/macplus/plus.rom`) | Menu+R |
| Memory | 1 MB / 4 MB | Menu+M |
| Fastboot | Off / On: no RAM test and no ROM checksum at start | |
| Reset | resets the machine | F12 |

The settings and the chosen images are remembered.

Shut the Mac down (Special > Shut Down) before you switch the core or the board off: the Mac keeps disk writes in its RAM cache, and an image left without them may not start any more.

## Keyboard

| Mac | PC keyboard |
|---|---|
| Command (Apple) | Alt |
| Option | Ctrl |

## Hard disk images

A SCSI disk image needs an Apple partition map with a driver; the Mac offers to initialize a disk with an empty partition (it writes the HFS volume). The `empty_hdd` images of the MiSTer Mac Plus core work.

## Building

Clone with `--recursive` (the `modules` submodule). ISE 14.7: `cd src && make` for all boards or `make minig` for one. The Mini and Go tops are made from the Mini G top by `src/tools/mktops.py`. The checks (Verilator, iverilog): `src/sim/run_checks.sh`. The plan and the design notes are in [docs/PLAN.md](docs/PLAN.md) (Russian).

## License

GPL v3 ([LICENSE](LICENSE)). Imported files keep the licence headers of their authors.
