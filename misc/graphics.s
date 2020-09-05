


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



        .include "lib.i"



        ;; zero page variables



        glyph_shift = $00
        save_y = $02
        save_s = $04
        text_pointer = $06



        .segment "bss"

glyph_buffer:
        .res    $800




        .segment "code"

glyph_width_table:
        .include "glyphtable.i"

glyph_data:
        .incbin "../res/glyphdata.bin"

shift_table:
        .byte 8, 7, 6, 5, 4, 3, 2, 1


      	.segment "hdata"

        ;; y : glyph data pointer
        ;; x : tile offset

        .macro  glyph_render_row row, tilerow
        .scope

        lda     glyph_data + row - $20 * $10, y                         ; 2
        xba                                                             ; 1
	lda     #$0                                                     ; 2

      	.a16
	rep     #$20                                                    ; 2

        bra     _modify                                                 ; 1 = 8
_modify:

        lsr
        lsr
        lsr
        lsr
        lsr
        lsr
        lsr

        .a8
        sep     #$20

	sta     glyph_buffer + tilerow + $40, x
	xba
        ora     glyph_buffer + tilerow, x
        sta     glyph_buffer + tilerow, x

        .endscope
        .endmacro



        ;; a : glyph index
        ;; x : offset

glyph_render:
        .a8

      	.a16
	rep     #$20

        asl
	asl
	asl
	asl
	tay

      	.a8
        sep     #$20

     	txa
        sta     glyph_shift
        lda     #$8
        clc
        sbc     glyph_shift
        and     #$7

        .define _offset 9

        sta     f:_row0 + _offset
       	sta     f:_row1 + _offset
	sta     f:_row2 + _offset
	sta     f:_row3 + _offset

	sta     f:_row4 + _offset
	sta     f:_row5 + _offset
	sta     f:_row6 + _offset
	sta     f:_row7 + _offset

	sta     f:_row8 + _offset
	sta     f:_row9 + _offset
	sta     f:_rowa + _offset
	sta     f:_rowb + _offset

       	.a16
	rep     #$20

        txa
        and     #($ffff - $7)
        asl
        asl
        asl
        tax

     	.a8
        sep     #$20

_row0:  glyph_render_row $0, $0
_row1:  glyph_render_row $1, $2
_row2:  glyph_render_row $2, $4
_row3:  glyph_render_row $3, $6

_row4:  glyph_render_row $4, $8
_row5:  glyph_render_row $5, $a
_row6:  glyph_render_row $6, $c
_row7:  glyph_render_row $7, $e

_row8:  glyph_render_row $8, $20
_row9:  glyph_render_row $9, $22
_rowa:  glyph_render_row $a, $24
_rowb:  glyph_render_row $b, $26

       	.a16
	rep     #$20

        tya
        lsr
        lsr
        lsr
        lsr
        tay

      	.a8
        sep     #$20

        lda     glyph_shift
        clc
        adc     glyph_width_table - $20, y
        tax

        bra     _return


text_render:
        .a8


      	stx     text_pointer
        sta     text_pointer + 2

        dma_wram_memclear 0, #.loword(glyph_buffer), #^glyph_buffer, #$800

        ldx     #0
        ldy     #0

        :
        lda     [text_pointer], y
        beq     :+

        sty     save_y
        jmp     glyph_render
_return:
        ldy     save_y

        iny
        bra     :-

        :

        rtl
