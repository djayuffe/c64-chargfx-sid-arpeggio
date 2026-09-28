# C64 Character FX + SID Arpeggio

<img src="docs/preview.png" alt="VICE capture of the running PAL C64 demo" width="768">

PAL Commodore 64 demo by Ulf Bertilsson. It combines animated raster bars, a
custom one-bit character-graphics title, a smooth bottom scroller, and a
pulse-wave SID arpeggio.

## Effects

| Effect | VICE capture | Implementation |
| --- | --- | --- |
| Raster bars | [raster-bars.png](docs/screenshots/raster-bars.png) | A raster IRQ cycles phase-shifted background colours through sixteen bands. |
| Character banner | [character-banner.png](docs/screenshots/character-banner.png) | The generated 2 KiB charset supplies the title glyphs and shadow rows. |
| Smooth scroller | [smooth-scroller.png](docs/screenshots/smooth-scroller.png) | Fine horizontal scrolling is applied only at the scroller raster split. |
| SID arpeggio | [sid-arpeggio.png](docs/screenshots/sid-arpeggio.png) | SID voice 1 plays a bounded pulse-wave note sequence. |

The SID effect is audible in the running program; its screenshot documents the
same verified emulator run as the visual effects.

## Build and run

Requires [ACME](https://sourceforge.net/projects/acme-crossass/) 0.97 or newer
and Python 3:

```sh
make
make verify
x64sc -pal -autostart build/c64_chargfx_sid_arpeggio.prg
```

`make verify` assembles with strict segments and checks the `SYS 6144` loader,
boot sequence, interrupt vector, VIC/SID setup, program-owned state, and
embedded deterministic charset. To regenerate only the charset, run
`make charset`.

## Memory layout

The BASIC stub at `$0801` executes `SYS 6144`, entering code at `$1800`.
The custom charset is embedded at `$1000`, screen RAM is `$0400`, and mutable
demo state lives at `$0C84` rather than KERNAL workspace. The raster handler is
installed through the standard RAM IRQ vector at `$0314/$0315` and chains to
the KERNAL IRQ tail at `$EA31`.

## Repository layout

- `c64_chargfx_sid_arpeggio.s` — source and hardware setup.
- `scripts/generate_charset.py` — deterministic charset generator.
- `scripts/verify_build.py` — structural build and boot-contract checks.
- `AUDIT.md` and `docs/FUNCTIONS.md` — audit record and function reference.

## License

Copyright © 2026 Ulf Bertilsson. Released under the
[GNU GPL v3.0](LICENSE) (`GPL-3.0-only`).
