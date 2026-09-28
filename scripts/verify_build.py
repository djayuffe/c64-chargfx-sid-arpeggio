#!/usr/bin/env python3
"""Verify binary layout plus the boot, initialization, and IRQ contracts."""

# Copyright (C) 2026 Ulf Bertilsson
# SPDX-License-Identifier: GPL-3.0-only

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

from generate_charset import build_charset


BASIC_START = 0x0801
ENTRY_POINT = 0x1800
EXPECTED_BASIC = bytes.fromhex("0b 08 0a 00 9e 36 31 34 34 00 00 00")


def fail(message: str) -> None:
    raise AssertionError(message)


def parse_symbols(path: Path) -> dict[str, int]:
    symbols: dict[str, int] = {}
    pattern = re.compile(r"(?:!addr\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\$([0-9a-fA-F]+)")
    for line in path.read_text(encoding="utf-8").splitlines():
        match = pattern.search(line)
        if match:
            symbols[match.group(1)] = int(match.group(2), 16)
    return symbols


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--prg", type=Path, required=True)
    parser.add_argument("--symbols", type=Path, required=True)
    parser.add_argument("--charset", type=Path, required=True)
    parser.add_argument("--source", type=Path, required=True)
    args = parser.parse_args()

    source = args.source.read_text(encoding="utf-8")
    charset = args.charset.read_bytes()
    prg = args.prg.read_bytes()
    symbols = parse_symbols(args.symbols)

    if len(charset) != 2048:
        fail(f"charset must be 2048 bytes, got {len(charset)}")
    if charset != build_charset():
        fail("checked-in charset differs from scripts/generate_charset.py output")
    if "SPDX-License-Identifier: GPL-3.0-only" not in source:
        fail("source is missing the GPL-3.0-only SPDX identifier")
    if "Copyright (C) 2026 Ulf Bertilsson" not in source:
        fail("source is missing the Ulf Bertilsson copyright notice")

    if len(prg) < 2:
        fail("PRG is truncated")
    load_address = int.from_bytes(prg[:2], "little")
    if load_address != BASIC_START:
        fail(f"PRG load address is ${load_address:04x}, expected $0801")
    payload = prg[2:]

    def memory(address: int, size: int) -> bytes:
        offset = address - load_address
        if offset < 0 or offset + size > len(payload):
            fail(f"${address:04x}..${address + size - 1:04x} is outside the PRG")
        return payload[offset : offset + size]

    if memory(BASIC_START, len(EXPECTED_BASIC)) != EXPECTED_BASIC:
        fail("BASIC line is not exactly '10 SYS6144' with a valid end marker")

    required = {
        "Start",
        "Forever",
        "IRQ_Handler",
        "FrameCount",
        "ScrIdx",
        "Smooth",
        "ArpIdx",
        "ScrollTxtLength",
        "ArpSeqLength",
    }
    missing = sorted(required - symbols.keys())
    if missing:
        fail(f"symbol list is missing: {', '.join(missing)}")
    if symbols["Start"] != ENTRY_POINT:
        fail(f"Start is ${symbols['Start']:04x}, but BASIC boots $1800")
    if memory(ENTRY_POINT, 1) != b"\x78":
        fail("entry point does not begin with SEI")

    forever = symbols["Forever"]
    if memory(forever - 1, 1) != b"\x58":
        fail("CLI must be the final initialization instruction before Forever")
    if memory(forever, 3) != bytes((0x4C, forever & 0xFF, forever >> 8)):
        fail("Forever is not a self-jump idle loop")

    irq = symbols["IRQ_Handler"]
    install_vector = bytes(
        (0xA9, irq & 0xFF, 0x8D, 0x14, 0x03, 0xA9, irq >> 8, 0x8D, 0x15, 0x03)
    )
    initialized_code = memory(ENTRY_POINT, forever - ENTRY_POINT)
    if install_vector not in initialized_code:
        fail("initialization does not install IRQ_Handler at $0314/$0315")

    required_init_sequences = {
        "VIC memory map $D018=$14": bytes.fromhex("a9 14 8d 18 d0"),
        "VIC control $D011=$18": bytes.fromhex("a9 18 8d 11 d0"),
        "40-column control $D016=$08": bytes.fromhex("a9 08 8d 16 d0"),
        "raster line $D012=$30": bytes.fromhex("a9 30 8d 12 d0"),
        "raster IRQ enable $D01A=$01": bytes.fromhex("a9 01 8d 1a d0"),
    }
    for description, sequence in required_init_sequences.items():
        if sequence not in initialized_code:
            fail(f"missing initialization sequence: {description}")

    scan_length = min(0x100, load_address + len(payload) - irq)
    if bytes.fromhex("4c 31 ea") not in memory(irq, scan_length):
        fail("IRQ handler does not chain to the KERNAL handler at $EA31")

    for state_name in ("FrameCount", "ScrIdx", "Smooth", "ArpIdx"):
        address = symbols[state_name]
        if not 0x0C00 <= address < 0x0D00:
            fail(f"{state_name} at ${address:04x} is outside program-owned state RAM")

    if memory(0x1000, len(charset)) != charset:
        fail("embedded charset at $1000 differs from the checked-in charset")
    if not 0 < symbols["ScrollTxtLength"] <= 0xFF:
        fail("scroll text length must fit the 8-bit index")
    if not 0 < symbols["ArpSeqLength"] <= 0xFF:
        fail("arpeggio sequence length must fit the 8-bit index")

    print("verified: BASIC 10 SYS6144 -> $1800")
    print(f"verified: IRQ vector target ${irq:04x}, CLI gate, and KERNAL $EA31 chain")
    print("verified: VIC/SID initialization layout and program-owned mutable state")
    print("verified: deterministic 2048-byte charset embedded at $1000")
    print(f"verified: {len(prg)}-byte PRG ({len(payload)}-byte payload)")


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, ValueError) as error:
        print(f"verification failed: {error}", file=sys.stderr)
        raise SystemExit(1)
