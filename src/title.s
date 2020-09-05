

        ;; title.s

        ;; title and end screen


        .include "rem.i"

        .export title_init, title_loop, end_screen

        .segment "code"


        ;; init the title screen

title_init:

        lda     #$ff
        sta     is_paused
        
        ;; set color math

        mov     reg_tm, #$1f
        mov     reg_ts, #$0f

        mov     reg_cgadsub, #$10
        mov     reg_cgswsel, #$02

        ;; copy palettes

        dma_cgram_memcpy $00, #$00, #.loword(title_palette), #^title_palette, #$20
        dma_cgram_memcpy $00, #$d0, #.loword(title_palette), #^title_palette, #$20

        ;; copy tilesets

        dma_vram_memcpy2 $00, #vram::tileset0, #.loword(data_castle_tiles), #^data_castle_tiles, #(data_castle_tiles_end - data_castle_tiles)
        dma_vram_memcpy2 $00, #vram::tileset1, #.loword(data_title_tiles), #^data_title_tiles, #(data_title_tiles_end - data_title_tiles)

        ;; copy screen

        dma_vram_memcpy2 $00, #vram::bg1, #.loword(data_castle_screen), #^data_castle_screen, #(data_castle_screen_end - data_castle_screen)
        dma_vram_memcpy2 $00, #vram::bg0, #.loword(data_title_screen), #^data_title_screen, #(data_title_screen_end - data_title_screen)

        rts


        ;; title screen main loop

title_loop:

        wai

_loop:  

        ;; update debug

        lda     is_debug
        bit     #$1
        beq     :+
        jsr     debug_update
        :

        ;; update snow

        jsr     snow_update

        ;; check if button is pressed

        lda     master_brightness
        cmp     #$10
        bne     :+

        lda     reg_joyx + $1
        bit     #button_bit::start >> 8
        beq     :+
        jsr     spc_fade
        jsr     fadeout
        :

        ;; if debug is enabled, get frame time

        lda     is_debug
        bit     #$1
        beq     :+
        read_vcounter debug_frame_sl
        :

        wai

        lda     master_brightness
        bne     _loop

        jsr     spc_reset

        ;; show help screen

        dma_vram_memcpy2 $00, #vram::tileset0, #.loword(data_help_tiles), #^data_help_tiles, #(data_help_tiles_end - data_help_tiles)

        dma_vram_memcpy2 $00, #vram::bg0, #.loword(data_help_screen), #^data_help_screen, #(data_help_screen_end - data_help_screen)

        mov     reg_tm, #$1
        mov     reg_ts, #$0

        jsr     fadein

        wai

_help_loop:

        ;; wait before reading joypad

        ldx     #$100
        :
        dex
        bne     :-
        
        sa16
        lda     reg_joyx
        bit     #button_bit::aa | button_bit::bb | button_bit::xx | button_bit::yy
        beq     :+
        sa8
        jsr     fadeout
        :
        sa8

        wai

        lda     master_brightness
        bne     _help_loop

        
        rts


end_screen:
        jsr     spc_reset

        ;; wait for forced blank

        ldx     #$4000
        :
        dex
        bne     :-
        
        lda     #$ff
        sta     is_paused
        
        stz     reg_bgxhofs
        stz     reg_bgxhofs
        sta     reg_bgxvofs
        sta     reg_bgxvofs
        
        ;; show end screen

        dma_cgram_memcpy $00, #$00, #.loword(title_palette), #^title_palette, #$20
        
        dma_vram_memcpy2 $00, #vram::tileset0, #.loword(data_end_tiles), #^data_end_tiles, #(data_end_tiles_end - data_end_tiles)

        dma_vram_memcpy2 $00, #vram::bg0, #.loword(data_end_screen), #^data_end_screen, #(data_end_screen_end - data_end_screen)

        mov     reg_tm, #$1
        mov     reg_ts, #$0

        jsr     sound_test_3
        
        jsr     fadein

        :
        wai
        bra     :-

