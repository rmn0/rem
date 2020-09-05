
        ;; font.s

        ;; this is currently not used in the game and has not been tested in some time



        ;; variable width font renderer
        ;; renders one line of text into an offscreen buffer in hram

        ;; to render text, set the a:x register to the 24 bit address
        ;; of a null terminated string and call text_render

     	;; the result will be in glyph_buffer in a 16-color format
        ;; in 32 x 2 tiles stored in column-row order like this

        ;; 0 2 4 6 ...
        ;; 1 3 5 7 ...

        ;; only the first bitplane is actually used, the remaining
        ;; bitplanes will be zero.

        ;; the total text length in 1/32 of a pixel will be returned
        ;; in the x register
        ;; and can be used to save bandwith when uploading shorter
        ;; texts or center or right-align the text by scrolling the
        ;; background

        ;; note that the glyph table only contains the ascii
        ;; characters 32 - 127.



	.global text_render
	.global glyph_buffer



        .include "rem.i"



        ;; zero page variables



        glyph_shift = $00
        glyph_offset = $02
        text_pointer = $04



        .segment "bss"

glyph_buffer:
        .res    $800




        .segment "code"

glyph_width_table:
        .include "glyphtable.i"

glyph_data:
        .incbin "../res/glyphdata.bin"



        ;; y : glyph data pointer
        ;; x : tile offset

        .macro  glyph_render_row row, tilerow
        .scope

        .a16

        lda     glyph_data + row - $20 * $10 - $1, y
        and     #$ff00

        ldx     glyph_shift
        jmp     (_jumptable, x)

_shift7:
        lsr
_shift6:
        lsr
_shift5:
        lsr
_shift4:
        lsr
_shift3:
        lsr
_shift2:
        lsr
_shift1:
        lsr
_shift0:

        sa8

        ldx     glyph_offset

	sta     glyph_buffer + tilerow + $40, x
	xba
        ora     glyph_buffer + tilerow, x
        sta     glyph_buffer + tilerow, x

        sa16

        jmp     _skip_jumptable

_jumptable:
        .word _shift0, _shift1, _shift2, _shift3, _shift4, _shift5, _shift6, _shift7

_skip_jumptable:

        .endscope
        .endmacro



        ;; a : glyph index
        ;; x : offset

glyph_render:
        .a16

        phx

        asl
	asl
	asl
	asl
	tay

     	txa
        and     #$7
        asl
        sta     glyph_shift

        txa
        and     #($ffff - $7)
        asl
        asl
        asl
        sta     glyph_offset

        glyph_render_row $0, $0
        glyph_render_row $1, $2
        glyph_render_row $2, $4
        glyph_render_row $3, $6
        glyph_render_row $4, $8
        glyph_render_row $5, $a
        glyph_render_row $6, $c
	glyph_render_row $7, $e

        glyph_render_row $8, $20
        glyph_render_row $9, $22
        glyph_render_row $a, $24
        glyph_render_row $b, $26
        ;; glyph_render_row $c                  ; no glyph is taller than 12 pixels
        ;; glyph_render_row $d
        ;; glyph_render_row $e
        ;; glyph_render_row $f

        tya
        lsr
        lsr
        lsr
        lsr
        tay

        pla

        clc
        adc     glyph_width_table - $20, y
        and     #$ff
        tax

        rts


text_render:
        .a8

      	stx     text_pointer
        sta     text_pointer + $2

        dma_wram_memclear $0, #.loword(glyph_buffer), #^glyph_buffer, #$800

        ldx     #$0
        ldy     #$0

        sa16

        :
        lda     [text_pointer], y
        and     #$7f

        beq     :+

        phy
        jsr    glyph_render
        ply

        iny
        bra     :-

        :

        sa8

        rts
