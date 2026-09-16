
; deepseek_asm_20251009_v10k4c_chargfx_safe_loudsid_clean.s
; Text-mode only, PAL-safe. Single raster IRQ (chained to KERNAL).
; Uses your custom charset at $1000 and draws a char-gfx banner (double row + shadow).
; Smooth bottom scroller + tiny SID arpeggio.
; BASIC stub -> RUN (SYS6144).
; Build with the checked-in charset: acme --strict-segments -I . -f cbm -o v10k4c.prg deepseek_asm_20251009_v10k4c_chargfx_safe_loudsid_clean.s

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

; ---------------- Zero Page ----------------
ZP_SrcLo    = $fb
ZP_SrcHi    = $fc
ZP_DstLo    = $fd
ZP_DstHi    = $fe
ZP_Tmp      = $ff

; ---------------- Small vars ----------------
FrameCount  = $033a
ScrIdx      = $033b
Smooth      = $033c
LenTmp      = $033d
ArpIdx      = $033e
RowTmp      = $033f

; ---------------- Tables ----------------
* = $0C00
RowScrLo:  !for i,0,24 { !byte <(SCREEN + i*40) }
RowScrHi:  !for i,0,24 { !byte >(SCREEN + i*40) }
RowColLo:  !for i,0,24 { !byte <(COLOR  + i*40) }
RowColHi:  !for i,0,24 { !byte >(COLOR  + i*40) }
RasterLines: !byte 50,58,66,74,82,90,98,106,114,122,130,138,146,154,162,170
BarColors:   !byte 2,6,3,1,3,6,2,0,2,6,3,1,3,6,2,0

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
    lda #$1b
    sta CTRL1
    lda #$08
    sta CTRL2

    ; Clear
    jsr ClearScreen
    jsr ClearColor

    ; Draw char-gfx banner (double row + shadow)
    jsr DrawBannerCharGfx

    ; IRQ install
    lda VICIRQFLAG
    sta VICIRQFLAG
    lda #<IRQ_Handler
    sta $0314
    lda #>IRQ_Handler
    sta $0315
    lda #50
    sta RASTER
    lda CTRL1
    and #$7f
    sta CTRL1
    lda #$01
    sta VICIRQEN

    ; Init scroller + SID
    lda #0
    sta ScrIdx
    lda #7
    sta Smooth
    jsr SID_Init

    cli
Forever:
    jmp Forever

; ---------------- Char-GFX banner (double row with shadow) ----------------
Banner1: !scr " UBER CREW "
!byte 0
Banner2: !scr "  2025  "
!byte 0

DrawBannerCharGfx:
    ; Top line row 7 (white)
    lda #7
    lda #<Banner1
    sta ZP_SrcLo
    lda #>Banner1
    sta ZP_SrcHi
    lda #7
    jsr CenterPrintRow
    ; Shadow row 8 (grey)
    lda #8
    lda #<Banner1
    sta ZP_SrcLo
    lda #>Banner1
    sta ZP_SrcHi
    lda #8
    jsr ColorCenteredRowGrey
    ; Second line row 9 (white)
    lda #9
    lda #<Banner2
    sta ZP_SrcLo
    lda #>Banner2
    sta ZP_SrcHi
    lda #9
    jsr CenterPrintRow
    ; Shadow row 10 (grey)
    lda #10
    lda #<Banner2
    sta ZP_SrcLo
    lda #>Banner2
    sta ZP_SrcHi
    lda #10
    jsr ColorCenteredRowGrey
    rts

; Color the centered span for the string pointer (ZP_SrcLo/Hi) on given row in A with grey (color 14).
ColorCenteredRowGrey:
    sta RowTmp
    tay
    ; compute length -> LenTmp
    ldy #0
@len:
    lda (ZP_SrcLo),y
    beq @got
    iny
    bne @len
@got:
    sty LenTmp
    ; start = (40 - len)/2
    tya
    eor #$ff
    clc
    adc #41
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
    lda #14
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
    tay
    ; row base -> ZP_DstLo/Hi
    lda RowScrLo,y
    sta ZP_DstLo
    lda RowScrHi,y
    sta ZP_DstHi
    ; compute length in LenTmp
    ldy #0
@len:
    lda (ZP_SrcLo),y
    beq @got
    iny
    bne @len
@got:
    sty LenTmp
    ; start = (40 - len)/2
    tya
    eor #$ff
    clc
    adc #41
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
    lda VICIRQFLAG
    sta VICIRQFLAG

    pha
    txa : pha
    tya : pha

    inc FrameCount
    jsr SID_Tick

    ; Bars: update background color at scheduled lines
    ldx #0
@nextbar:
@w1: lda RASTER
    cmp RasterLines,x
    bne @w1
@w2: lda CTRL1
    bpl @w2
    lda FrameCount
    and #$0f
    tay
    lda BarColors,y
    sta BGCOL
    inx
    cpx #16
    bne @nextbar

    ; Scroller tick (row 21)
    jsr Scroller_Tick

    ; Arm next frame
    lda #50
    sta RASTER
    lda CTRL1
    and #$7f
    sta CTRL1
    lda #$01
    sta VICIRQEN

    pla : tay
    pla : tax
    pla
.chain:
    jmp $ea31

; ---------------- Scroller ----------------
ScrollTxt:
!scr "  UBER CREW 2025  -  GREETINGS TO: NTEB DOMUS JSWIKI ULF MAGNUS THOMAS ALEKS  "
!scr "  C64 FOREVER  "
!byte 0

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
    lda SCREEN+21*40+1,x
    sta SCREEN+21*40+0,x
    inx
    cpx #39
    bne @mv
    ldx ScrIdx
    lda ScrollTxt,x
    bne @ok
    ldx #0
    lda ScrollTxt,x
@ok:
    sta SCREEN+21*40+39
    inx
    stx ScrIdx
    lda #1
    sta COLOR+21*40+39
    rts

; ---------------- SID (voice 1 pulse arpeggio, louder) ----------------
SID_Init:
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

SID_Tick:
    ldx ArpIdx
    lda ArpSeq,x
    tay
    lda NoteLo,y
    sta $d400
    lda NoteHi,y
    sta $d401
    lda #$41
    sta $d404
    inx
    txa
    and #$0f
    sta ArpIdx
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
    lda #$01
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
