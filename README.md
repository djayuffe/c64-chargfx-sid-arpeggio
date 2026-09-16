# DeepSeek C64 v10k4c

Text-mode PAL C64 demo with a character-graphics banner, smooth scroller, and
SID pulse arpeggio.

## Build

Requires ACME 0.97 or newer:

```sh
make
```

Output: `build/deepseek_c64_v10k4c.prg`. Run with:

```sh
x64sc -autostart build/deepseek_c64_v10k4c.prg
```

## Repository layout

- `deepseek_c64_v10k4c.s` — corrected source.
- `custom_charset_1bpp.bin` — checked-in 2 KiB charset input.
- `Makefile`, `AUDIT.md`, and `SHA256SUMS.txt` — build, audit, and integrity data.

## Audit summary

The missing `SID_Tick` routine and charset dependency were restored. Shadow-row
arguments and centered-row state are now preserved; the `SYS 6144` contract is
unchanged.
