# DeepSeek v10k4c chargfx

Text-mode PAL C64 demo with a character-graphics banner, smooth scroller, and
SID pulse arpeggio.

## Build and run

```sh
acme --strict-segments -I . -f cbm -o v10k4c.prg \
  deepseek_asm_20251009_v10k4c_chargfx_safe_loudsid_clean.s
x64sc -autostart v10k4c.prg
```

The checked-in 2 KiB charset makes the build self-contained. The missing
`SID_Tick` routine and two shadow-row parameter losses were repaired; see
`AUDIT.md` for the validation record.
