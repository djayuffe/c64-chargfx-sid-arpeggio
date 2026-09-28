# Audit record

## Corrected defects

- Restored the missing SID data/tick path and made the arpeggio index explicitly
  bounded by the sequence length.
- Replaced the non-deterministic checked-in charset with a deterministic 2 KiB
  generated asset that is checked against its generator during verification.
- Moved frame, scroll, and SID state out of `$033A-$033F`, a KERNAL/cassette
  workspace region, into program-owned memory at `$0C84`.
- Repaired the raster wait logic. The former D011 bit-7 wait could not complete
  below raster line 256 and could consume whole frames; waits now target the
  intended PAL lines without the invalid condition.
- Applied a different colour phase to every raster band and restored the normal
  background colour after the bar region.
- Split the VIC display setup at raster boundaries: D016 resets before the
  banner and the fine-scroll value is set immediately before the scroller.
  This prevents the global horizontal scroll register from moving the banner.
- Reworked banner/shadow drawing so text is written before its colour rows are
  applied, and bounds-checked text helper rows and lengths.
- Cleared the SID register block before setting voice 1, clearing stale sound
  state left by a prior program.
- Simplified the IRQ prologue/epilogue to match the KERNAL IRQ trampoline:
  acknowledge VIC IRQs, perform the demo work, then jump to `$EA31`, which
  restores the registers saved by the standard IRQ entry.

## Boot and vector contract

The PRG retains a BASIC loader at `$0801` containing `10 SYS6144`, which enters
`Start` at `$1800`. Startup disables interrupts, initializes VIC, screen,
charset, colour RAM, state, and SID in that order, writes the IRQ handler to
the standard RAM vector `$0314/$0315`, enables raster IRQs, then executes CLI.
The handler acknowledges `$D019`, chains to `$EA31`, and no longer relies on
undefined KERNAL workspace.

## Validation

`make verify` assembles with ACME `--strict-segments` and verifies the BASIC
loader, start/CLI loop, IRQ vector install and chain, VIC/SID initialization,
state allocation, charset bytes, and bounded table sizes. A live PAL VICE run
confirmed the program counter in the main loop, the installed handler vector,
changing frame/scroll/arpeggio state, VIC split setup, and SID voice registers.
The captures in `docs/screenshots/` were saved from that VICE run.
