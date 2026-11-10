# План ядра Apple Macintosh Plus для Karabas Go / Mini / Mini G

Цель: Macintosh Plus (68000 8 МГц, 128 КБ ROM, RAM 1–4 МБ, экран 512 × 342 × 1, IWM + две дискеты 800 КБ, SCSI, VIA, SCC, RTC / PRAM) на платах Karabas (XC6SLX25, ISE 14.7). Основа — [NanoMac](https://github.com/MiSTle-Dev/NanoMac) Тиля Харбаума (порт PlusToo на Tang Nano 20K), доноры — [MacPlus_MiSTer](https://github.com/MiSTer-devel/MacPlus_MiSTer) и [plus_too](https://github.com/mist-devel/plus_too) MiST. Файлы идут через прошивку (OSD, `FL`, `img_sdc`): загрузчика и soft-CPU в ядре нет. Имя `macplus` (`macplus.kg`, папка `/macplus`), репозиторий `andykarpov/karabas-go-core-macplus`, публичный.

## Что изучено (2026-11-11)

| Проект | Состояние | Что берём |
|---|---|---|
| [MiSTle-Dev/NanoMac](https://github.com/MiSTle-Dev/NanoMac) 7af8fbd (2026-03) | основа: вычищенные тайминги видео и шины, дискеты с SD по дорожкам, 2 SCSI, модем, MIDI, симуляция Verilator | `src/macplus/` целиком, `fx68k`, `companion/hid.v` + `macplus_keymap.v`, `sim/` |
| [MiSTer-devel/MacPlus_MiSTer](https://github.com/MiSTer-devel/MacPlus_MiSTer) 47c7ecf (2026-10-29) | очень живой (danielb0): модели 128K / 512K / 512Ke / SE, HD20, CD-ROM, запись и форматирование дискет, точный тайминг 8 МГц, исправление ADB | доноры для Ф5; готовые ROM и `Disk605.dsk` в `releases/` |
| [mist-devel/plus_too](https://github.com/mist-devel/plus_too) 7c96eaf (2025-03) | оригинальный порт MiST | сверка |
| [PlusToo](https://www.bigmessowires.com/2012/12/15/plus-too-files/) (2011) | исходный проект Steve Chamberlin | `plusrom.bin` (= `boot0.rom` MiSTer), справка |

NanoMac: один клок 15,6 МГц (Tang: 78 / 5), `busPhase` 0..7, CPU 8 МГц по разрешающим сигналам `clk8_en_p` / `clk8_en_n`, видео и CPU занимают шину RAM по очереди (`videoBusControl` / `cpuBusControl`). RAM 128K / 512K / 1M / 4M в SDRAM, 16 бит (`ram_addr` 21 бит слов), ROM 128 КБ из SPI flash (`romAddr` 18 бит). Fastboot — патч ROM (без проверки RAM и контрольной суммы). Дискеты — `.dsk` 800 КБ, чтение и запись, `floppy_track_buffer` читает дорожку с SD. SCSI — `ncr5380` + 2 × `scsi.v`. Интерфейс SD у всех — `sdc_lba` / `sdc_rd` / `sdc_wr` / буфер 8 бит, как у MiSTeryNano (atarist). RTC — `rtc.v` с unix-временем. HDMI у NanoMac — родной растр 704 × 370 на 15,6 МГц: для обычных приёмников HDMI слишком низкая частота пикселей, нам не подходит.

Лицензии: `macplus.sv` — GPL v2 (Sorgelig), fx68k — GPL v3; файла LICENSE в корне NanoMac нет, заголовки сохраняем. ROM Mac — Apple: только файл пользователя, в репозиторий и `.kg` не кладём.

Тестовые файлы (локально, не в репозитории): `~/Downloads/karabas-sd-macplus/` — `plusrom.bin` (Plus v3, контрольная сумма 4D1F8172) из архива PlusToo, `boot1.rom` (SE), `boot2.rom` (128K / 512K), `Disk605.dsk` (System 6.0.5, raw 819200), `empty_hdd.zip` (`boot.vhd` 20 МБ) из `releases/` MiSTer. Официальные System 6.0.x / 7.0.1 — со старой страницы Apple (через web.archive.org), DiskCopy 4.2 → `.dsk` утилитой `dc2dsk`.

## Решения

Пользователь (2026-11-11): основа NanoMac + PlusToo; имя `macplus`, публичный репозиторий (создаёт пользователь); **RAM в SDRAM, ROM в SRAM**; **видео 1024 × 768 @ 60 с масштабом 2×**; ROM и System искать самим (найдены, см. выше).

1. **Основа** — rtl NanoMac как есть (`src/rtl/macplus/`, `fx68k`) и его `sv2v` в `src/rtl/sv2v/` (как atarist); правки для XST в исходниках с пометкой `// karabas:`.
2. **Память** как в atarist: RAM 4 МБ в SDRAM MT48LC16M16A2 (16 бит; контроллер, синхронный с `busPhase`), ROM 128 КБ в SRAM (загрузчик прошивки, `FL` `/macplus/plus.rom`, автозагрузка). Размер RAM 1 / 4 МБ (и 128K / 512K) — опция OSD.
3. **Видео: кадровый буфер в BRAM.** 512 × 342 × 1 = 21888 байт = 11 RAMB16. Пиксели машины пишутся в буфер на её клоке, вывод — **1024 × 768 @ 60 Гц (65 МГц)**, каждый пиксель 2 × 2 → 1024 × 684 по центру, сверху и снизу по 42 строки рамки. Мак — 60,15 Гц, расхождение с 60 Гц почти незаметно (1 бит на пиксель, разрыв строки раз в несколько секунд). Go — VGA тем же растром.
4. **Клавиатура и мышь** — `hid.v` + `macplus_keymap.v` NanoMac поверх `kg_mcu_hid` (как в atarist), мышь — квадратура `MOUSE[5:0]`.
5. **Дискеты** — 2 × `.dsk` 800 КБ (`floppy_track_buffer` → `img_sdc`), защита от записи по образу. **SCSI** — 2 × `.vhd` / `.img` (ID 6 и 5). **RTC** — время от прошивки, PRAM (20 байт у Plus, `rtc.v`) — `.eep`. Счётчик секунд `rtc.v` рассчитан на клок 15,6 МГц: при другом клоке машины — правка.
6. **Свой верх платы**, общий код через modules (`kg_mcu`, `img_sdc`, OSD, HDMI, PCM5102), Makefile. Первой — Mini G, затем Go и Mini. Mini G2: T3 = 0 (SDRAM ~CS).

## Архитектура

```
 macplus (NanoMac) ├── fx68k (8 МГц по CE) ── addrController / dataController ── RAM 4 МБ (SDRAM)
                   │                                                         └── ROM 128 КБ (SRAM) ← FL
                   ├── videoShifter ── пиксель ── кадровый буфер BRAM 512×342 ── вывод 1024×768@60 (2×) ── OSD ── HDMI / VGA
                   ├── звук (буфер PWM 8 бит, 22,25 кГц) ──────────────────── HDMI / PCM5102 / сигма-дельта
                   ├── VIA / ADB-клавиатура ── hid.v + keymap ── kg_mcu HID (клавиатура, мышь)
                   ├── IWM ── floppy_track_buffer ──┐
                   ├── NCR5380 ── scsi × 2 ─────────┴── img_sdc ── kg_mcu (file mounter)
                   ├── SCC ── UART (ESP / MIDI, Ф5)
                   └── rtc.v ← время kg_mcu ; PRAM ↔ .eep
```

## Фазы

Ветка и один PR на фазу, слияние в конце фазы.

- **Ф0. Импорт и fit.** rtl NanoMac без правок, `src/tools/sv2v.sh` → `src/rtl/sv2v/`, правки XST, Makefile, `core.json`. `make macplus-xst` — машина отдельно: LUT / FF / RAMB16 / частота. Ожидание по atarist: около 60 % LUT xc6slx25 — проверка.
  **Итог (2026-11-11):** машина (`macplus` + `hid`) — 7902 LUT (52 %), 3621 FF, 13 RAMB16, 0 DSP, один клок, защёлок нет, оценка XST 70 МГц (нужно 15,6). Правки XST: пути `microrom.mem` / `nanorom.mem` из `src/`; `latch_reset_pattern` VIA — `localparam`; дорожечный буфер `floppy_track_buffer` (12 КБ, две записи и два чтения, у XST — распределённая RAM на LUT и синтез >10 мин) — блочная RAM с одним портом записи и одним чтения, записи и чтения взаимоисключающие по состоянию, тайминг прежний. Справочно в `src/rtl/tang/`: верх Tang, его SDRAM и модель SD-карты симуляции (не собираются).
- **Ф1. Симуляция.** Verilator по `sim/` NanoMac: ROM до иконки «дискета с ?», затем загрузка `Disk605.dsk` до рабочего стола (128 КБ RAM для скорости). Быстрая проверка — секунды; рабочий стол — долго, только с согласия.
- **Ф2. Mini G.** PLL (машина + 65 МГц видео), SDRAM, ROM в SRAM через `FL`, кадровый буфер и вывод 1024 × 768, HDMI со звуком, HID, OSD, сброс. Первый запуск на плате: «Happy Mac», клавиатура, мышь.
- **Ф3. Дискеты и SCSI.** 2 × `.dsk` (чтение, запись, WP, смена диска), 2 × SCSI.
- **Ф4. RTC, PRAM, опции, другие платы.** Время от прошивки, PRAM в `.eep`, RAM, fastboot; верхи Go и Mini; README / GUIDE; релиз.
- **Ф5. Дополнения.** Модели SE / 512Ke (MiSTer), HD20, форматирование дискет, модем через ESP, MIDI.
