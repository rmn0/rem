

        ;; main.s

        ;; the main loop and initialization code


      	.include "rem.i"

	.global zerobyte

        .global main, nmi_, frame_counter

        .export joy_current, joy_prev, is_paused

        .export debug_frame_sl, debug_vblank_sl, is_debug

        .export fadein, fadeout, master_brightness

        .import light_frame, light_dma

        .import debug_init, debug_update, debug_dma, debug_disable_hdma, debug_enable_hdma

        .import dma_queue_flush

        .import input_test

        .import sprite_test

        


        .segment "bss"


;;         .export debug_view
;; debug_view:
        
frame_counter:          .res $2

joy_current:            .res $2
joy_prev:               .res $2

debug_frame_sl:         .res $2
debug_vblank_sl:        .res $2

is_debug:               .res $2
is_paused:              .res $2

master_brightness_tgt:  .res $1
master_brightness:      .res $1


        .segment "code" 



zerobyte:
        .byte   $0


        ;; int ppu state

        .macro ppu_init
        mov     reg_bgmode, #00 | setup::bgmode

        mov     reg_bgxsc + $00, #(((vram::bg0 / $400) << $2) | $0)
        mov     reg_bgxsc + $01, #(((vram::bg1 / $400) << $2) | $0)
        mov     reg_bgxsc + $02, #(((vram::bg2 / $400) << $2) | $0)

        mov     reg_bg34nba, #(vram::lighttiles / $1000)

        mov     reg_objsel, #(vram::spritetiles / $2000)

        mov     reg_wrio, #$ff
        .endmacro


        ;; init rem's entity and the scroll and update coordinates

        .define start_screen_xx 0
        .define start_screen_yy 10


        .macro rem_init

        sa16

        lda     #start_screen_xx * $100 + $40
        sta     entity_table + entity::pos_xx
        clc
        ;; adc     #$10000 - $80 + $4            
        stz     scroll_xx
        stz     scroll_prev_xx
        lda     #start_screen_yy * $100 + $50
        sta     entity_table + entity::pos_yy
        clc
        adc     #$10000 - $80 + $10
        sta     scroll_yy
        sta     scroll_prev_yy

        clc
        adc     #$100
        and     #$ffe0
        sta     full_update_xx
        lda     #$ffff
        sta     full_update_en

        sa8

        lda     #$7
        sta     entity_table + entity::box_ww
        lda     #$1a
        sta     entity_table + entity::box_hh

        .endmacro


        ;; set the horizontal or vertical scroll coordinates
        ;; for all bg layers

        .macro set_scroll xx, scroll_reg, offset

        lda     xx

        .ifnblank offset
        dec
        .endif

        sta     scroll_reg + $0
        stz     scroll_reg + $0
        sta     scroll_reg + $2
        stz     scroll_reg + $2


        ;; light layer remains in a fixed position,
        ;; only scroll the pixel offset in a tile

        .ifnblank offset
        inc
        .endif

        and     #const::pixels_in_tile - $1

        .ifnblank offset
        dec
        .endif

        sta     scroll_reg + $4
        stz     scroll_reg + $4

        .endmacro


        ;; initialize sprite palette and border sprites

screen_init:

        dma_cgram_memcpy $00, #$c0, #.loword(sprite_palette), #^sprite_palette, #$20
        dma_cgram_memcpy $00, #$e0, #.loword(keys_palette), #^keys_palette, #$20

        dma_vram_memcpy2 $00, #vram::spritetiles, #.loword(data_border), #^data_border, #$20

        dma_vram_memcpy2 $00, #vram::spritetiles + $10, #.loword(data_snow), #^data_snow, #$20 * $8
        dma_vram_memcpy2 $00, #vram::spritetiles + $400, #.loword(data_keys), #^data_keys, #$20 * $20

        ;; screen border in first 24 sprites

        ;; TODO: use larger sprites for this

        ldx     #oam::border

        :
        lda     #$100 - const::pixels_in_tile
        sta     f:oam_mirror + $0, x

        txa
        asl
        sta     f:oam_mirror + $1, x

        lda     #$0
        sta     f:oam_mirror + $2, x

        lda     #$30
        sta     f:oam_mirror + $3, x

        inx
        inx
        inx
        inx

        cpx     #$e0 / $2                          ; = dec 224 / 2
        bne     :-

        rts


        ;; this function is a stub beacuse there is no real initialization function yet

        ;; tilesets should be dynamically loaded instead

tileset_init:   

        dma_cgram_memcpy $00, #$20, #(.loword(data_tileset_0) + $2000), #^data_tileset_0, #$20
        dma_cgram_memcpy $00, #$30, #(.loword(data_tileset_1) + $2000), #^data_tileset_1, #$20
        dma_cgram_memcpy $00, #$40, #(.loword(data_tileset_2) + $2000), #^data_tileset_2, #$20

        dma_cgram_memcpy $00, #$50, #(.loword(data_tileset_0) + $2020), #^data_tileset_0, #$20
        dma_cgram_memcpy $00, #$60, #(.loword(data_tileset_1) + $2020), #^data_tileset_1, #$20
        dma_cgram_memcpy $00, #$70, #(.loword(data_tileset_2) + $2020), #^data_tileset_2, #$20

        dma_cgram_memcpy $00, #$00, #.loword(light_palette), #^light_palette, #$40

        dma_vram_memcpy2 $00, #vram::tileset0, #.loword(data_tileset_0), #^data_tileset_0, #$2000
        dma_vram_memcpy2 $00, #vram::tileset1, #.loword(data_tileset_1), #^data_tileset_1, #$2000
        dma_vram_memcpy2 $00, #vram::tileset2, #.loword(data_tileset_2), #^data_tileset_2, #$2000

        dma_vram_memcpy2 $00, #vram::lighttiles + $0000, #(.loword(data_light) + $00), #^data_light, #$10
        dma_vram_memcpy2 $00, #vram::lighttiles + $0800, #(.loword(data_light) + $10), #^data_light, #$10
        dma_vram_memcpy2 $00, #vram::lighttiles + $1000, #(.loword(data_light) + $20), #^data_light, #$10
        dma_vram_memcpy2 $00, #vram::lighttiles + $1800, #(.loword(data_light) + $30), #^data_light, #$10

        ;; key is a 16x16 sprite

        lda     #$2 | $8 | $20 | $80
        sta     f:oam_mirror + $200 + oam::key / (4 * 4)

        rts


;; wait:
;;         lda     #$81
;;         sta     reg_nmitimen

;;         lda     #$20
;;         :
;;         pha
;;         wai
;;         pla
;;         dec
;;         bne     :-

;;         lda     #$01
;;         sta     reg_nmitimen

;;         rts

        ;; go out of forced blanking mode and fade in screen

fadein:
        lda     #setup::master_brightness_bit + 1
        sta     master_brightness_tgt

        ;; enable vblank interrupt

        lda     #$81
        sta     reg_nmitimen

        rts


        ;; fade out screen and go into forced blanking mode

fadeout:
        stz     master_brightness_tgt

        rts



main:
        jsr     sound_test

        ;; jsr     font_test

        jsr     debug_init

        ;; lda     #$1
        ;; sta     is_debug

title_screen:
                
        jsr     title_init

        jsr     snow_init

        jsr     screen_init

        set_scroll #$ff, reg_bgxvofs

        ppu_init

        jsr     fadein

        jsr     title_loop
        
        ;; wait for forced blank

        ldx     #$4000
        :
        dex
        bne     :-

        ;; set color math mode

        mov     reg_tm, #setup::mainscreen_bit 
        mov     reg_ts, #setup::subscreen_bit
        mov     reg_cgadsub, #$9f

        jsr     snow_clear

        jsr     snow_init_2

        rem_init

        jsr     tileset_init

        jsr     sound_test_2

        ;; dma_vram_memseth $00, #vram::bg2, #$00, #($20 * $1d)


        jsr     fadein

        ;; reset the paused flag

        stz     is_paused

;;; main loop

_loop:
        lda     #$01
        sta     reg_nmitimen

        ;; if debug is enabled, update the debug area ram buffer

        lda     is_debug
        bit     #$1
        beq     :+
        jsr     debug_update
        :

        sa16

        ;; reset the dma queues

        stz     dmaq_length + $0
        stz     dmaq_length + $2
        stz     dmaq_length + $4

        inc     frame_counter

        jsr     input_test

        sa8

        ;; call main update routines

        jsr     transform_update

        jsr     rem_sprite_update

        jsr     screen_update

        jsr     light_frame

        jsr     key_update

        jsr     snow_update

        ;; if debug is enabled, get frame time

        lda     is_debug
        bit     #$1
        beq     :+
        read_vcounter debug_frame_sl
        :

        lda     #$81
        sta     reg_nmitimen

        wai

        ;; check end of game
        
        lda     master_brightness
        beq     :+
        jmp     _loop
        :

        jsr     end_screen
        

;;; vblank interrupt

nmi_:
        sa8

        ;; screen fade

        lda     master_brightness
        cmp     master_brightness_tgt
        beq     _skip_fade
        bpl     :+
        sta     reg_inidisp
        inc
        sta     master_brightness
        bra     _skip_fade
        :
        dec
        beq     :+
        sta     master_brightness
        dec
        sta     reg_inidisp
        bra     _skip_fade
        :
        stz     master_brightness
        lda     #$80            ; enable forced blank
        sta     reg_inidisp
        lda     #$01            ; disable vblank interrupt
        sta     reg_nmitimen

_skip_fade:     

        ;; update sprites

        jsr     sprite_oam_dma

        ;; skip updates if paused

        lda     is_paused
        bne     _skip_updates

        ;; update scroll registers

        set_scroll scroll_xx, reg_bgxhofs
        set_scroll scroll_yy, reg_bgxvofs, offset

        ;; flush the dma queues

        jsr     dmaq_flush

        jsr     light_dma

_skip_updates:  

        ;; if debug is enabled, get the vblank time
        ;; and trigger debug dma

        lda     is_debug
        bit     #$1

        bne     :+

        bit     #$2                     ; if debug was enabled before
        beq     _skip_debug

        stz     is_debug
        jsr     debug_disable_hdma            
        bra     _skip_debug
        :

        bit     #$2                     ; if debug was disabled before
        bne     :+

        lda     #$3
        sta     is_debug
        jsr     debug_enable_hdma
        :

        jsr     debug_dma

        read_vcounter   debug_vblank_sl

_skip_debug:    

        rti

