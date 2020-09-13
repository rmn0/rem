
        ;; window.s

        ;; window animations

        .include "rem.i"

        .export window_hdma_setup, window_hdma_update, window_irq_update, irq_

        .define index_size $10

        .struct frame
        table_offset    .res $4 * $2
        index           .res $4 * index_size
        .endstruct

        ;;zero page scratchpad

window_pointer = $0
temp = $6
window_vpos_near = $8

        .segment "hdma"

hdma_scroll_table:
        .res $100

        .segment "bss"

window_address:
        .res 3

window_hpos:
        .res 2

window_vpos:
        .res 2

clip_pointer:
        .res 8

clip_offset:
        .res 4

firstline:
        .res 4

        .segment "code"


        ;; test values for positioning

        .macro position_xx

        sa16

        lda     scroll_xx
        eor     #$ffff

        and     #$1ff
        sta     window_hpos

        sa8

        .endmacro

        .macro position_yy

        sa16

        lda     scroll_yy
        eor     #$ffff

        and     #$1ff
        cmp     #$e0
        bmi     :+
        cmp     #$100
        bpl     :+
        lda     #$e0
        :
        sta     window_vpos

        sa8

        .endmacro



        ;; for starting hdma
        ;; in the first scanline
        ;; without auto-initialization

        .macro hdma_init channel

        ;; lda     #$00
        ;; sta     f:reg_dasx + (channel + $4) * $10

        ldy     clip_pointer + channel * 2
        sty     reg_a2ax + (channel + $4) * $10

        lda     clip_offset + channel
        inc
        sta     reg_nltrx + (channel + $4) * $10

        .endmacro


irq_:
        php
        sa16
        pha
        sa8

        ;; acknowledge interrupt

        lda     #$1
        sta     f:reg_nmitimen

        ;; for debugging

        ;; read_vcounter_far
        ;; cmp     #1
        ;; :
        ;; bne     :-

        lda     #$f8
        sta     f:reg_hdmaen

        sa16
        pla
        plp
        sei
        rti
        sa8


        .macro reset table

        lda     firstline + table
        tax
        lda     hdma_scroll_table, x
        sta     reg_whx + table

        .endmacro


window_irq_update:

        ;; reset window registers

        lda     #$0
        xba
        reset   $0
        reset   $1
        reset   $2
        reset   $3

        ;; move far pointer to window data to direct page

        ldx     window_address
        stx     window_pointer

        lda     window_address + $2
        sta     window_pointer + $2

        ;; hdma table initialization

        hdma_init $0
        hdma_init $1
        hdma_init $2
        hdma_init $3

        ;; set up irq

        ldx     #$0
        stx     reg_htime
        ldx     #$0
        stx     reg_vtime

        ;; enable irq

        lda     #$01 | $20
        sta     reg_nmitimen

        cli

        rts


        .macro  window_hdma channel

        ldx     #.lobyte(reg_whx + channel) * $100 + $40
        stx     reg_dmapx + (channel + $4) * $10

        ;; can be skipped because a2ax will be initialized
        ;; manually in hdma_init

        ;; sa16
        ;; lda     f:data_noname_window + channel * $2
        ;; clc
        ;; adc     window_address
        ;; sta     reg_a1tx + (channel + $4) * $10
        ;; sa8

        lda     window_address + $2
        sta     reg_a1bx + (channel + $4) * $10

        stz     reg_dasx + (channel + $4) * $10 + 2

        .endmacro



window_hdma_setup:

        ;; test image

        ldx     #.loword(data_noname_window)
        stx     window_address

        lda     #^data_noname_window
        sta     window_address + $2

        ;; setup windowing logic

        lda     #$aa
        sta     reg_w12sel
        sta     reg_w34sel
        sta     reg_wobjsel
        lda     #$ff
        stz     reg_wbglog
        stz     reg_wobjlog
        lda     #$f
        sta     reg_tmw
        sta     reg_tsw

        ;; setup hdma

        window_hdma $0
        window_hdma $1
        window_hdma $2
        window_hdma $3

        ;; initialize variables

        ldx     #$1
        stx     firstline + $0
        stx     firstline + $2

        rts



        .macro  seek table, ofs

        adc     a:ofs * $3, y
        bcc     :+

        sta     f:clip_offset + table

        ;; as the first row will not be rendered
        ;; by hdma, the window register must be set manually

        lda     a:ofs * $3 + $1, y
        sta     f:firstline + table

        ;; the hdma should start in the next row

        sa16
        tya
        adc     #ofs * $3 + $3 - $1                     ; add 1 less because carry is set
        sta     f:clip_pointer + table * $2
        sa8

        jmp     _end
        :

        .endmacro


        .macro vscroll_up table
        .scope

        lda     a:frame::index + table * index_size + $0, x
        sta     temp

        sa16
        and     #$ff
        asl
        adc     temp
        ldy     window_pointer
        adc     a:frame::table_offset + table * $2, y
        adc     window_pointer
        tay
        sa8

        lda     a:frame::index + table * index_size + $1, x
        adc     window_vpos_near

        ;; y points to a table row that is either completely outside the screen or clips
        ;; a contains the rows screen y position

        ;; seek forward until a row clips

        seek    table, $0
        seek    table, $1
        seek    table, $2
        seek    table, $3
        seek    table, $4
        seek    table, $5
        seek    table, $6
        seek    table, $7
        seek    table, $8
        seek    table, $9
        seek    table, $a
        seek    table, $b
        seek    table, $c
        seek    table, $d
        seek    table, $e
        seek    table, $f
        seek    table, $10
        seek    table, $11
        seek    table, $12
        seek    table, $13
        seek    table, $14
        seek    table, $15
        seek    table, $16
        seek    table, $17
        seek    table, $18
        seek    table, $19
        seek    table, $1a
        seek    table, $1b
        seek    table, $1c
        seek    table, $1d
        seek    table, $1e
        seek    table, $1f

_end:   


        .endscope
        .endmacro


        .macro vscroll_down table

        sa16
        ldy     #table * $2
        lda     [window_pointer], y
        clc
        adc     window_pointer
        tay
        sa8

        txa
        cpa     #$78
        bmi     :+
        sbc     #$78
        bra     :++
        :
        iny
        iny
        iny
        :

        sta     clip_offset + table
        sty     clip_pointer + table * $2

        .endmacro


window_hdma_update:

        ;; horizontal scrolling

        ldx     #.loword(hdma_scroll_table)
        stx     reg_wmadd
        lda     #^hdma_scroll_table
        sta     reg_wmadd + $2

        lda     #^_range
        sta     reg_a1tx + $2

        stz     reg_dasx + $1

        lda     #$80
        sta     reg_dmapx + $1

        lda     window_hpos + $1
        bne     _clip_left

_clip_right:

        stz     reg_dmapx

        lda     #$0
        xba
        lda     window_hpos
        bne     :+

        ldx     #.loword(_range)
        stx     reg_a1tx

        ldx     #$100
        stx     reg_dasx

        lda     #$1
        sta     reg_mdmaen

        bra     _horizontal_end

        :

        sa16
        clc
        adc     #.loword(_range)
        sta     reg_a1tx
        sa8

        lda     window_hpos
        eor     #$ff
        inc
        sta     reg_dasx

        lda     #$1
        sta     reg_mdmaen

        ldx     #.loword(_range) + $ff
        stx     reg_a1tx

        lda     window_hpos

        sta     reg_dasx
        lda     #$8
        sta     reg_dmapx

        lda     #$1
        sta     reg_mdmaen

        bra     _horizontal_end

_clip_left:

        lda     #$8
        sta     reg_dmapx

        ldx     #.loword(_range)
        stx     reg_a1tx

        lda     window_hpos
        bne     :+

        ldx     #$100
        stx     reg_dasx

        lda     #$1
        sta     reg_mdmaen

        bra     _horizontal_end

        :

        eor     #$ff
        inc
        sta     reg_dasx

        lda     #$1
        sta     reg_mdmaen

        lda     window_hpos
        sta     reg_dasx

        stz     reg_dmapx

        lda     #$1
        sta     reg_mdmaen

_horizontal_end:
        sa8

        ;; restore direct page

        lda     #$00
        xba
        lda     #$00
        tcd

        ;; position updates need to happen now
        ;; because horizontal scrolling will be visible in the current frame
        ;; but vertical scrolling is in preparation for the next frame

        position_xx
        position_yy


        ;; vertical scrolling

        ldx     window_address
        stx     window_pointer

        lda     window_address + $2
        sta     window_pointer + $2

        ldx     window_vpos

        cpx     #$100
        bpl     _clip_up

_clip_down:

        vscroll_down $0
        vscroll_down $1
        vscroll_down $2
        vscroll_down $3

        jmp     _vertical_end

_clip_up:       

        stz     temp + $1

        lda     #$00
        xba

        txa
        sta     window_vpos_near

        eor     #$ff
        lsr
        lsr
        lsr
        lsr
        and     #$fe

        sa16
        clc
        adc     window_pointer
        tax
        sa8

        lda     window_pointer + $2
        pha
        plb

        vscroll_up $0
        vscroll_up $1
        vscroll_up $2
        vscroll_up $3

        lda     #$80
        pha
        plb

_vertical_end:

        rts
        rts
        rts


_range:
        .byte $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0a, $0b, $0c, $0d, $0e, $0f
        .byte $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $1a, $1b, $1c, $1d, $1e, $1f
        .byte $20, $21, $22, $23, $24, $25, $26, $27, $28, $29, $2a, $2b, $2c, $2d, $2e, $2f
        .byte $30, $31, $32, $33, $34, $35, $36, $37, $38, $39, $3a, $3b, $3c, $3d, $3e, $3f
        .byte $40, $41, $42, $43, $44, $45, $46, $47, $48, $49, $4a, $4b, $4c, $4d, $4e, $4f
        .byte $50, $51, $52, $53, $54, $55, $56, $57, $58, $59, $5a, $5b, $5c, $5d, $5e, $5f
        .byte $60, $61, $62, $63, $64, $65, $66, $67, $68, $69, $6a, $6b, $6c, $6d, $6e, $6f
        .byte $70, $71, $72, $73, $74, $75, $76, $77, $78, $79, $7a, $7b, $7c, $7d, $7e, $7f
        .byte $80, $81, $82, $83, $84, $85, $86, $87, $88, $89, $8a, $8b, $8c, $8d, $8e, $8f
        .byte $90, $91, $92, $93, $94, $95, $96, $97, $98, $99, $9a, $9b, $9c, $9d, $9e, $9f
        .byte $a0, $a1, $a2, $a3, $a4, $a5, $a6, $a7, $a8, $a9, $aa, $ab, $ac, $ad, $ae, $af
        .byte $b0, $b1, $b2, $b3, $b4, $b5, $b6, $b7, $b8, $b9, $ba, $bb, $bc, $bd, $be, $bf
        .byte $c0, $c1, $c2, $c3, $c4, $c5, $c6, $c7, $c8, $c9, $ca, $cb, $cc, $cd, $ce, $cf
        .byte $d0, $d1, $d2, $d3, $d4, $d5, $d6, $d7, $d8, $d9, $da, $db, $dc, $dd, $de, $df
        .byte $e0, $e1, $e2, $e3, $e4, $e5, $e6, $e7, $e8, $e9, $ea, $eb, $ec, $ed, $ee, $ef
        .byte $f0, $f1, $f2, $f3, $f4, $f5, $f6, $f7, $f8, $f9, $fa, $fb, $fc, $fd, $fe, $ff







