# Audit record

The source failed assembly because `IRQ_Handler` called an undefined
`SID_Tick`, and it referenced a missing custom charset. Both shadow-row calls
also loaded their row number before overwriting `A` with a pointer high byte.
`ColorCenteredRowGrey` then used the measured text length as its row index.

Repairs:

- checked in the 2 KiB charset input;
- added `NoteLo`, `NoteHi`, `ArpSeq`, and a bounded `SID_Tick`;
- restored row 8/10 before each shadow-color call;
- preserved the row argument with `RowTmp`.

Validation: ACME `--strict-segments` succeeds and the PRG remains a
`SYS 6144` program. Corrected build SHA-256:
`2214fb8f8ccf4bb8aa13ed9eb5ffcb82cbe2ba521c306d798ebe98ccf001e0f5`.
