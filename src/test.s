

        ;; test.s

        ;; for debugging stuff


        .include "rem.i"


        .export sound_test, sound_test_2, sound_test_3, font_test

        .import sprite_setup

        .import data_sound_test

        .import oam_mirror




        .segment "rodata"


text_test:
        .byte	"Hail and scream, fat angels cant fly", $0



        .segment "code"


        ;; upload and play a module

sound_test:

        jsr     spc_upload

        lda     #^data_sound_test
        jsr     spc_set_bank

        lda     #$0
        jsr     spc_upload_module

        jsr     spc_play

        rts

sound_test_2:

        lda     #^data_ambient
        jsr     spc_set_bank

        lda     #$0
        jsr     spc_upload_module

        jsr     spc_play

        rts

sound_test_3:

        lda     #^data_clock
        jsr     spc_set_bank

        lda     #$0
        jsr     spc_upload_module

        jsr     spc_play

        rts

        
        ;; render a text into the vram buffer

font_test:

        lda     #^text_test
        ldx     #.loword(text_test)
        jsr     text_render

        dma_vram_memcpy2 $00, #vram::bogus, #.loword(glyph_buffer), #^glyph_buffer, #$800

        rts



        .segment "code"


        .macro set_if_held mask, xx, dir, val
        bit     mask
        beq     :+
        tax
        lda     val
        .if     .xmatch(dir, $1)
        eor     #$ffff                        ; negate with xor
        inc
        .endif
        sta     xx
        txa
        :
        .endmacro

        .macro scroll_if_held mask, xx, dir, vel
        bit     mask
        beq     :+
        tax
        lda     xx
        .if .xmatch(dir, $1)
        sec
        sbc     vel
        .else
        clc
        adc     vel
        .endif
        sta     xx
        txa
        :
        .endmacro

        .macro scroll_if_down mask, xx, dir, vel
        bit     mask
        beq     :+
        tax
        lda     joy_prev
        bit     mask
        bne     :+
        lda     xx
        .if .xmatch(dir, $1)
        sec
        sbc     vel
        .else
        clc
        adc     vel
        .endif
        sta     xx
        :
        txa
        .endmacro



        .export input_test


input_test:
        .a16

        ;; wait a bit before reading joypad

        ;; ldx     #$ff
        ;; :
        ;; dex
        ;; bne     :-

        ldx     joy_current
        stx     joy_prev

        ldx     reg_joyx
        stx     joy_current

        ;; enable or disable debug

        txa

        bit     #button_bit::start
        beq     :+
        lda     joy_prev
        bit     #button_bit::start
        bne     :+
        lda     is_debug
        eor     #$1
        sta     is_debug
        :

        ;; modify debug mem pointer

        lda     is_debug
        bne     :+
        jmp     _skip_debug
        :

        txa

        bit     #button_bit::ll
        beq     _skip_debug_mem_addr

        scroll_if_held #button_bit::left,  debug_mem_addr, $1, #$8
        scroll_if_held #button_bit::right, debug_mem_addr, $0, #$8
        scroll_if_down #button_bit::up,    debug_mem_addr, $0, #$8
        scroll_if_down #button_bit::down,  debug_mem_addr, $1, #$8

        jmp     _skip_all
_skip_debug_mem_addr:

        bit     #button_bit::rr
        beq     _skip_debug

        scroll_if_held #button_bit::left,  debug_mem_addr + $2, $1, #$1
        scroll_if_held #button_bit::right, debug_mem_addr + $2, $0, #$1
        scroll_if_down #button_bit::up,    debug_mem_addr + $2, $0, #$1
        scroll_if_down #button_bit::down,  debug_mem_addr + $2, $1, #$1

        jmp     _skip_all

_skip_debug:

_skip_all:

        rts

