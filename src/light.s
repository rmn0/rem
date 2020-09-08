

        ;; light.s

        ;; dynamic lighting

        .include "rem.i"

        .export light_origin, visibility_origin, light_frame, light_dma

        .import scroll_xx, scroll_yy, light_xx, light_yy, light_pixel_xx, light_pixel_yy

        .importzp tform_tile_mask, tform_room_mask, room_hh_offset, room_vv_offset

        ;; zero page scratchpad

tile_xx = $0
tile_yy = $2
room_xx = $4
room_yy = $6
room_ii = $8
blit_ww = $a
blit_hh = $c
dst_addr_end = $e
tform_offset = $10
room_vv_hh_offset = $12


        .segment "bss"

        ;; position of frame inside ram buffers

visibility_dst_addr_base:
        .res $2

light_dst_addr_base:
        .res $2


        .segment "hdata"

        ;; light ram buffer


visibility_origin:
        .res $20 * $40

light_origin:
        .res $20 * $40
        

        .segment "code"


        ;; blit a rectangle into the visibility ram buffer

        ;; all coordinates are in tile-space
        ;; vertical coordinates have to be premultiplied

        ;; src_left  : left border in source room
        ;; src_top   : top border in source room
        ;; dest_left : left border in ram buffer
        ;; dest_top  : top border in ram buffer
        ;; ww        : blit region width
        ;; hh        : blit region height
        ;; room_sel  : room offset (from room index)

        ;; room_ii   : room index

        .macro blit_rect src_left, src_top, dest_left, dest_top, ww, hh, room_sel
        .scope

        lda     ww
        beq     _skip
        lda     hh
        beq     _skip
        bmi     _skip

        lda     room_ii
        clc
        adc     room_sel
        and     #const::room_table_size - $1
        tax

        sa8

        stz     reg_wmadd + $2
        lda     f:roomtable + room_entry::data_bank, x
        sta     reg_a1bx

        sa16

        clc

        tile_index src_left, src_top
        eor     tform_tile_mask

        adc     f:roomtable + room_entry::data_addr, x
        adc     #room_data::vis

        tay                                   ; y = src address

        tile_index dest_left, dest_top
        adc     visibility_dst_addr_base
        tax                                   ; x = dst address

        adc     hh
        sta     dst_addr_end

_loop:  
        clc

        txa
        sta     reg_wmadd
        adc     #const::tiles_in_room         ; light buffer width
        tax

        tya
        sta     reg_a1tx
        adc     tform_offset                  ; room width
        tay

        lda     ww
        sta     reg_dasx

        sa8

        lda     #$1
        sta     reg_mdmaen

        sa16

        cpx     dst_addr_end
        bne     _loop

_skip:  
        .endscope
        .endmacro

        .macro get_tform_info

        lda     transform
        bit     #transform_bit::hh
        bne     :+
        ldx     #$8000
        bra     :++
        :
        ldx     #$8010
        :
        stx     reg_dmapx

        bit     #transform_bit::vv
        bne     :+
        ldx     #const::tiles_in_room
        bra     :++
        :
        ldx     #$10000 - const::tiles_in_room
        :
        stx     tform_offset

        tax
        lda     room_vv_offset
        clc
        adc     room_hh_offset
        sta     room_vv_hh_offset

        .endmacro

        ;; blit vis info

        .macro blit_vis_info

        sec

        lda     #const::tiles_in_room
        sbc     tile_xx
        sta     blit_ww

        lda     #const::tiles_in_room * const::tiles_in_room
        sbc     tile_yy
        sta     blit_hh

        blit_rect       tile_xx, tile_yy, #$0, #$0, blit_ww, blit_hh, #0
        blit_rect       #$0, tile_yy, blit_ww, #$0, tile_xx, blit_hh, room_hh_offset

        sec

        lda     tile_yy
        sbc     #const::tiles_in_room * $3
        sta     tile_yy

        blit_rect       tile_xx, #$0, #$0, blit_hh, blit_ww, tile_yy, room_vv_offset
        blit_rect       #$0, #$0, blit_ww, blit_hh, tile_xx, tile_yy, room_vv_hh_offset

        .endmacro

        ;; main routine

        ;; blits full screen light data into ram buffer
        ;; and then does lighting calculation

        ;; light_xx : horizontal light xcoordinate in tile-space
        ;; light_yy : vertical light coordinate in tile-space

        ;; scroll_xx : horizontal scroll coordinate in pixel-space
        ;; scroll_yy : vertical scroll coordinatein pixel-space

_black_byte:
        .byte $ff

light_frame:
        sa16

        get_tform_info

        clc

        lda     light_yy
        asl
        asl
        asl
        asl
        asl
        ora     light_xx

        pha

        pha
        adc     #.loword(light_origin)
        sta     light_dst_addr_base
        pla

        adc     #.loword(visibility_origin)
        sta     visibility_dst_addr_base

        scale_pixel_coord scroll_xx, tile_xx, room_xx 
        scale_pixel_coord scroll_yy, tile_yy, room_yy,, pre

        room_index

        blit_vis_info

        sa8

        dma_wram_memset $00, light_dst_addr_base, #^light_origin, #$20 * $1e, _black_byte

        plx                                   ; light coordinates

        lda     #224
        sta     f:light_origin + $20 * $1e

                                              ; viscast routine is generated by tools/vis.c

        lda     light_pixel_xx

        cmp     #6
        bpl     :+++
        cmp     #4
        bpl     :++
        cmp     #2
        bpl     :+

        jsl     viscast_3
        bra     _end
        :
        jsl     viscast_2
        bra     _end
        :
        jsl     viscast_1
        bra     _end
        :
        jsl     viscast_0

_end:

        rts


        ;; streams light ram buffer to vram

light_dma:

        lda     #$80
        sta     reg_vmainc

        ldx     #vram::bg2
        stx     reg_vmadd

        ldx     #$1900
        stx     reg_dmapx

        ldx     light_dst_addr_base
        stx     reg_a1tx

        lda     #^light_origin
        sta     reg_a1bx

        ldx     #($20 * $1d)
        stx     reg_dasx

        lda     #$1
        sta     reg_mdmaen

        rts

