
; c64_chargfx_sid_arpeggio.s
; Copyright (C) 2026 Ulf Bertilsson
; SPDX-License-Identifier: GPL-3.0-only
; Text-mode only, PAL-safe. Single raster IRQ (chained to KERNAL).
; Uses your custom charset at $1000 and draws a char-gfx banner (double row + shadow).
; Smooth bottom scroller + tiny SID arpeggio.
; BASIC stub -> RUN (SYS6144).
; Build with the checked-in charset: acme --strict-segments -I . -f cbm -o c64_chargfx_sid_arpeggio.prg c64_chargfx_sid_arpeggio.s

; ---------------- BASIC stub: 10 SYS6144 ----------------
* = $0801
!word $080b
!word 10
!byte $9e
!text "6144"
!byte 0
!word 0

; ---------------- Constants ----------------
BORDERCOL   = $d020
BGCOL       = $d021
RASTER      = $d012
CTRL1       = $d011
CTRL2       = $d016
MEMPTR      = $d018
VICIRQEN    = $d01a
VICIRQFLAG  = $d019
CIA1_ICR    = $dc0d
CIA2_ICR    = $dd0d
CIA2_PRA    = $dd00

SCREEN      = $0400
COLOR       = $d800
SCREEN_WIDTH = 40
SCREEN_ROWS = 25
SCROLLER_ROW = 21
IRQ_RASTER = 48
AFTER_BARS_RASTER = 178
SCROLLER_RASTER = 210
BAR_COUNT = 16
COLOR_BLACK = 0
COLOR_WHITE = 1
COLOR_YELLOW = 7
COLOR_GREY = 14

; ---------------- Zero Page ----------------
ZP_SrcLo    = $fb
ZP_SrcHi    = $fc
ZP_DstLo    = $fd
ZP_DstHi    = $fe

; ---------------- Tables ----------------
* = $0C00
RowScrLo:  !for i,0,24 { !byte <(SCREEN + i*SCREEN_WIDTH) }
RowScrHi:  !for i,0,24 { !byte >(SCREEN + i*SCREEN_WIDTH) }
RowColLo:  !for i,0,24 { !byte <(COLOR  + i*SCREEN_WIDTH) }
RowColHi:  !for i,0,24 { !byte >(COLOR  + i*SCREEN_WIDTH) }
RasterLines: !byte 50,58,66,74,82,90,98,106,114,122,130,138,146,154,162,170
BarColors:   !byte 2,6,3,1,3,6,2,0,2,6,3,1,3,6,2,0

; Keep mutable state in memory owned by the program.  The earlier $033a-$033f
; placement overlapped KERNAL workspace/cassette-buffer storage.
FrameCount:  !byte 0
ScrIdx:      !byte 0
Smooth:      !byte 7
LenTmp:      !byte 0
ArpIdx:      !byte 0
RowTmp:      !byte 0
ColorTmp:    !byte 0

; ---------------- Custom charset (embedded at $1000) ----------------
* = $1000
!bin "custom_charset_1bpp.bin"

; ---------------- Code ----------------
* = $1800
Start:
    sei

    ; Disable CIA IRQs
    lda CIA1_ICR : lda CIA2_ICR
    lda #$7f
    sta CIA1_ICR : sta CIA2_ICR
    lda CIA1_ICR : lda CIA2_ICR

    ; VIC bank 0, screen $0400, charset $1000
    lda CIA2_PRA
    and #%11111100
    ora #%00000011
    sta CIA2_PRA
    lda #$14
    sta MEMPTR

    ; Video setup
    ; 25 rows, screen on, zero vertical fine-scroll: keep 8x8 glyphs aligned.
    lda #$18
    sta CTRL1
    lda #$08
    sta CTRL2

    ; Do not inherit colors or animation state from the loading environment.
    lda #COLOR_BLACK
    sta BORDERCOL
    sta BGCOL
    sta FrameCount
    sta ScrIdx
    sta ArpIdx
    lda #7
    sta Smooth

    ; Clear
    jsr ClearScreen
    jsr ClearColor

    ; Draw char-gfx banner (double row + shadow)
    jsr DrawBannerCharGfx

    ; Initialize audio before arming interrupts, so the first raster event
    ; always starts from a fully initialized machine state.
    jsr SID_Init

    ; IRQ install
    lda #$0f
    sta VICIRQFLAG
    lda #<IRQ_Handler
    sta $0314
    lda #>IRQ_Handler
    sta $0315
    lda #IRQ_RASTER
    sta RASTER
    lda CTRL1
    and #$7f
    sta CTRL1
    lda #$01
    sta VICIRQEN

    cli
Forever:
    jmp Forever

; ---------------- Char-GFX banner (double row with shadow) ----------------
; The deterministic custom charset contains the readable banner and scroller
; glyphs used below.
Banner1: !scr " UBER CREW "
!byte 0
Banner2: !scr "  2025  "
!byte 0

DrawBannerCharGfx:
    ; The title starts below the raster field, on the restored black background.
    ; This keeps its character graphics and shadow legible at every bar phase.
    ; Top line row 16 (yellow)
    lda #<Banner1
    sta ZP_SrcLo
    lda #>Banner1
    sta ZP_SrcHi
    lda #16
    jsr CenterPrintRow
    ldx #COLOR_YELLOW
    lda #16
    jsr ColorCenteredRow
    ; Shadow row 17 (grey)
    lda #<Banner1
    sta ZP_SrcLo
    lda #>Banner1
    sta ZP_SrcHi
    lda #17
    jsr CenterPrintRow
    ldx #COLOR_GREY
    lda #17
    jsr ColorCenteredRow
    ; Second line row 18 (yellow)
    lda #<Banner2
    sta ZP_SrcLo
    lda #>Banner2
    sta ZP_SrcHi
    lda #18
    jsr CenterPrintRow
    ldx #COLOR_YELLOW
    lda #18
    jsr ColorCenteredRow
    ; Shadow row 19 (grey)
    lda #<Banner2
    sta ZP_SrcLo
    lda #>Banner2
    sta ZP_SrcHi
    lda #19
    jsr CenterPrintRow
    ldx #COLOR_GREY
    lda #19
    jsr ColorCenteredRow
    rts

; Color the centered span for the string pointer (ZP_SrcLo/Hi).
; In: A=row, X=color.
ColorCenteredRow:
    cmp #SCREEN_ROWS
    bcc @validrow
    rts
@validrow:
    sta RowTmp
    stx ColorTmp
    ; compute length -> LenTmp
    ldy #0
@len:
    cpy #SCREEN_WIDTH
    beq @got
    lda (ZP_SrcLo),y
    beq @got
    iny
    bne @len
@got:
    sty LenTmp
    ; start = (SCREEN_WIDTH - len)/2
    tya
    eor #$ff
    clc
    adc #SCREEN_WIDTH+1
    lsr
    tax
    ; color row base -> ZP_Dst
    ldy RowTmp
    lda RowColLo,y
    sta ZP_DstLo
    lda RowColHi,y
    sta ZP_DstHi
@adv:
    cpx #0
    beq @paint
    inc ZP_DstLo
    bne @ok
    inc ZP_DstHi
@ok: dex
    bne @adv
@paint:
    ldy #0
    lda ColorTmp
@loop:
    cpy LenTmp
    beq @done
    sta (ZP_DstLo),y
    iny
    bne @loop
@done:
    rts

; ---------------- Centered text (row in A) ----------------
; In: A=row, (ZP_SrcLo/ZP_SrcHi)=ptr to 0-terminated text
CenterPrintRow:
    cmp #SCREEN_ROWS
    bcc @validrow
    rts
@validrow:
    tay
    ; row base -> ZP_DstLo/Hi
    lda RowScrLo,y
    sta ZP_DstLo
    lda RowScrHi,y
    sta ZP_DstHi
    ; compute length in LenTmp
    ldy #0
@len:
    cpy #SCREEN_WIDTH
    beq @got
    lda (ZP_SrcLo),y
    beq @got
    iny
    bne @len
@got:
    sty LenTmp
    ; start = (SCREEN_WIDTH - len)/2
    tya
    eor #$ff
    clc
    adc #SCREEN_WIDTH+1
    lsr
    tax
@adv:
    cpx #0
    beq @wr
    inc ZP_DstLo
    bne @ok
    inc ZP_DstHi
@ok: dex
    bne @adv
@wr:
    ldy #0
@wloop:
    cpy LenTmp
    beq @done
    lda (ZP_SrcLo),y
    sta (ZP_DstLo),y
    iny
    bne @wloop
@done:
    rts

; ---------------- IRQ (single, chain to KERNAL) ----------------
IRQ_Handler:
    lda VICIRQFLAG
    and #$01
    beq .chain

    ; ACK
    lda #$01
    sta VICIRQFLAG

    ; The KERNAL hardware-IRQ trampoline at $FF48 has already saved A/X/Y.
    ; $EA31 restores those original registers when the chained handler exits.

    inc FrameCount

    ; Fine scrolling is a screen-wide VIC-II setting.  Reset it before the
    ; active display begins; Scroller_Tick enables it again below the banner.
    lda #$08
    sta CTRL2

    ; Trigger two lines early, then draw each band on its exact scheduled line.
    ; The 8-line spacing leaves ample time for the short color update.
    ldx #0
@nextbar:
    txa
    clc
    adc FrameCount
    and #$0f
    tay
    lda BarColors,y
    tay
@waitbar:
    lda RASTER
    cmp RasterLines,x
    bcc @waitbar
    ; Y already contains the next color, minimizing line-start latency and
    ; keeping the transition in the left border rather than across the screen.
    sty BGCOL
    inx
    cpx #BAR_COUNT
    bne @nextbar
@barsdone:
    ; Restore the normal background after the final band rather than letting
    ; its color bleed through the lower screen and into the next frame.
@waitend:
    lda RASTER
    cmp #AFTER_BARS_RASTER
    bcc @waitend
    lda #0
    sta BGCOL

    jsr SID_Tick

    ; Do not set the global D016 fine-scroll until just before row 21.  The
    ; title rows above remain stationary while the bottom row scrolls smoothly.
@waitscroll:
    lda RASTER
    cmp #SCROLLER_RASTER
    bcc @waitscroll

    ; Scroller tick (row 21)
    jsr Scroller_Tick

    ; Arm next frame
    lda #IRQ_RASTER
    sta RASTER
    lda CTRL1
    and #$7f
    sta CTRL1
    lda #$01
    sta VICIRQEN

.chain:
    jmp $ea31

; ---------------- Scroller ----------------
ScrollTxt:
!scr "  UBER CREW 2025  -  GREETINGS TO: NTEB DOMUS JSWIKI ULF MAGNUS THOMAS ALEKS  "
!scr "  C64 FOREVER  "
ScrollTxtEnd:
!byte 0
ScrollTxtLength = ScrollTxtEnd - ScrollTxt

Scroller_Tick:
    lda Smooth
    beq @shift
    dec Smooth
    lda Smooth
    ora #$08
    sta CTRL2
    rts
@shift:
    lda #7
    sta Smooth
    lda #$0f
    sta CTRL2
    ldx #0
@mv:
    lda SCREEN+SCROLLER_ROW*SCREEN_WIDTH+1,x
    sta SCREEN+SCROLLER_ROW*SCREEN_WIDTH+0,x
    inx
    cpx #SCREEN_WIDTH-1
    bne @mv
    ldx ScrIdx
    cpx #ScrollTxtLength
    bcc @ok
    ldx #0
@ok:
    lda ScrollTxt,x
    sta SCREEN+SCROLLER_ROW*SCREEN_WIDTH+SCREEN_WIDTH-1
    inx
    stx ScrIdx
    lda #COLOR_WHITE
    sta COLOR+SCROLLER_ROW*SCREEN_WIDTH+SCREEN_WIDTH-1
    rts

; ---------------- SID (voice 1 pulse arpeggio, louder) ----------------
SID_Init:
    ; Clear every SID register so stale voices/filter state from a previously
    ; running program cannot leak into this effect.
    lda #0
    ldx #$18
@clear:
    sta $d400,x
    dex
    bpl @clear

    ; Master volume
    lda #$0f
    sta $d418

    ; Set pulse width to ~50% (0x0800)
    lda #<$0800
    sta $d402
    lda #>$0800
    sta $d403

    ; ADSR: attack 15, decay 5
    lda #$f5
    sta $d405
    ; sustain 12, release 5
    lda #$c5
    sta $d406

    ; Start on the first note immediately
    lda #<$11ED
    sta $d400
    lda #>$11ED
    sta $d401

    ; Control: pulse + gate
    lda #$41
    sta $d404

    lda #0
    sta ArpIdx
    rts

NoteLo: !byte <$11ED, <$0FEA, <$0E10
NoteHi: !byte >$11ED, >$0FEA, >$0E10
ArpSeq: !byte 0,1,2,0,1,2,0,1,2,0,1,2,0,1,2,0
ArpSeqEnd:
ArpSeqLength = ArpSeqEnd - ArpSeq

SID_Tick:
    ldx ArpIdx
    cpx #ArpSeqLength
    bcc @valid
    ldx #0
@valid:
    lda ArpSeq,x
    tay
    lda NoteLo,y
    sta $d400
    lda NoteHi,y
    sta $d401
    lda #$41
    sta $d404
    inx
    cpx #ArpSeqLength
    bcc @store
    ldx #0
@store:
    stx ArpIdx
    rts

; ---------------- Clear helpers ----------------
ClearScreen:
    lda #$20
    ldx #0
@cs1: sta $0400,x
    sta $0500,x
    sta $0600,x
    inx
    bne @cs1
    ldx #231
@cs2: sta $0700,x
    dex
    bpl @cs2
    rts

ClearColor:
    lda #COLOR_WHITE
    ldx #0
@cc1: sta $d800,x
    sta $d900,x
    sta $da00,x
    inx
    bne @cc1
    ldx #231
@cc2: sta $db00,x
    dex
    bpl @cc2
    rts
