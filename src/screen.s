

        ;; screen.s

        ;; background layers and scrolling code

        ;; supports displaying room data horizontally / vertically mirrored
        ;; transposed room data (rooms rotated by 90 degrees) nearly works, but is currently broken.


        .include "rem.i"

        .import roomtable

        .export blit_buffer
        .export screen_update

        .importzp tform_tile_mask, tform_room_mask, room_hh_offset, room_vv_offset



        ;; zero page scratchpad


        ;; these symbols are shared with the blit module

        .export blit_xx, blit_yy, blit_length, blit_room_addr, blit_room_bank
        .export blit_transform, blit_shader, blit_temp

blit_xx = $00
blit_yy = $02
blit_length = $04
blit_room_addr = $06
blit_room_bank = $08
blit_transform = $0a
blit_shader = $0c
blit_temp = $0e


        ;; internal zero page registers
        ;; (not shared with the blitter)

room_xx = $10
room_yy = $12
room_ii = $14
region_xx = $16
end_xx = $18
blit_xx_copy = $1a

        .segment "hdata"

        ;; reserve memory for blit buffers 

blit_buffer:
        .res $80 * $c


        .segment "code"


        ;; macro definitions
        ;; all the macros in this module expect .a16i16 mode


        ;; address of a 64-byte blit target buffer in wram
        .define buffer_address .loword(blit_buffer) + buffer * $40 + layer * $40 * $c


        ;; select a background in vram
        ;; the a register is ored with the backgrounds vram address

        ;; layer : layer index 0..1

        .macro select_bg layer
        .if (.xmatch(layer, $0))
        ora     #(vram::bg0)
        .elseif (.xmatch(layer, $1))
        ora     #(vram::bg1)
        .else
        ora     #(vram::bg2)
        .endif
        .endmacro


        ;; queue vram dma copy for a vertically aligned (32x4 tile) region

        ;; buffer  : buffer set index
        ;; layer   : layer index 0..1

        ;; blit_yy : vertical offset 0..31

        .macro dma_layer_row buffer, layer
        dmaq_insert $1
        lda     blit_yy
        asl
        asl
        asl
        asl
        asl
        select_bg layer
        sta     dmaq_table_vblock + dmaq_entry::dst_address, x
        lda     #buffer_address
        sta     dmaq_table_vblock + dmaq_entry::src_address, x
        lda     #$100
        sta     dmaq_table_vblock + dmaq_entry::length, x
        .endmacro


        ;; queue vram dma copy for a horizontally aligned (1x32 tile) region

        ;; buffer  : buffer set index
        ;; layer   : layer index 0..1

        ;; blit_yy : horizontal offset 0..31

        .macro dma_layer_column buffer, layer
        dmaq_insert $2
        lda     blit_yy
        select_bg layer
        sta     dmaq_table_hblock + dmaq_entry::dst_address, x
        lda     #buffer_address
        sta     dmaq_table_hblock + dmaq_entry::src_address, x
        lda     #$40
        sta     dmaq_table_hblock + dmaq_entry::length, x
        .endmacro


        ;; blit a single layer from room data into wram buffer

        ;; the blit_* zero page registers are expected to be initialized

        ;; buffer : buffer set index
        ;; layer  : layer index 0..1
        ;; xx     : horizontal or vertical offset 0..31

        .macro  blit_layer buffer, layer, xx
        lda     xx
        asl
        clc
        adc     #buffer_address

        pha
        sa8

        jsl     blit

        plx
        sa16

        .if .xmatch(layer, $1)           ; if this is not the last layer
        .else
        lda     blit_room_addr          ; advance room data pointer
        clc                             ; to next layer
        adc     #$800
        sta     blit_room_addr
        .endif

        .endmacro


        ;; blit all layers of a blit region from room data into wram buffer

        ;; the blit_* zero page registers are expected to be initialized

        ;; buffer : buffer set index
        ;; xx     : horizontal or vertical offset 0..31

        .macro blit_layers buffer, xx
        blit_layer buffer, $0, xx
        blit_layer buffer, $1, xx
        .endmacro



        ;; select a room from the room table and get room data pointer

        ;; room_ii : relative address of room from room table start
        ;; ii      : if not blank, advance the room index by one position
        ;; cln     : if not blank, advance horizontally, else advance vertically

        ;; the resulting far address is stored in blit_room_bank:blit_room_addr

        .macro select_room ii, cln
        .ifblank ii
        ldx     room_ii
        .else
        lda     room_ii
        clc
        .ifblank cln
        adc     room_hh_offset
        .else
        adc     room_vv_offset
        .endif
        and     #const::room_table_size - $1
        tax
        .endif

        lda     f:roomtable + $2, x
        sta     blit_room_bank
        lda     f:roomtable, x 
        sta     blit_room_addr        
        .endmacro




        ;; blit a column for horizontal scrolling or full screen update

        ;; buffer_base : index of a set of wram blit buffers

        ;; scroll_yy : the top border of the screen in world pixel-space
        ;; region_xx : the horizontal position of the blit column in world pixel-space

        ;; also expects blit_transform and blit_shader to be initialized

        .macro  blit_column buffer_base
        .scope

        room_index

        lda     blit_xx_copy
        sta     blit_xx
        sta     blit_length             ; blit_length is actually 32 - tile count

        select_room
        blit_layers buffer_base, blit_xx

        lda     blit_length
        beq     _skip_blit_2            ; the whole row has already been blitted

        eor     #$ffff                  ; negate with xor (-x == (x ^ -1) + 1)
        inc
        and     #$1f

        stz     blit_xx
        sta     blit_length

        select_room $1, $1
        blit_layers buffer_base, #$0

_skip_blit_2:

        dma_layer_column buffer_base, $0
        dma_layer_column buffer_base, $1

        .endscope
        .endmacro


        ;; blit a row for vertical scrolling

        ;; buffer_base : index of a set of wram blit buffers

        ;; scroll_xx : the left border of the screen in world pixel-space
        ;; region_xx : the vertical position of the blit row in world pixel-space

        ;; also expects blit_transform and blit_shader to be initialized

        .macro blit_row buffer_base
        .scope

        room_index

        lda     blit_xx_copy
        sta     blit_xx
        sta     blit_length             ; blit_length is actually 32 - tile count

        select_room
        blit_layers buffer_base, blit_xx

        lda     blit_length
        beq     _skip_blit_2            ; the whole row has already been blitted

        eor     #$ffff                  ; negate with xor (-x == (x ^ -1) + 1)
        inc
        and     #$1f                    
        
        stz     blit_xx
        sta     blit_length

        select_room $1
        blit_layers buffer_base, #$0

_skip_blit_2:


        .endscope
        .endmacro


        ;; get and increment full screen update offset

        ;; xx   : the full screen update offset
        ;; sxx  : vertical scrolling coordinate
        ;; skip : address to jump to when no update is needed

        ;; result is written to region_xx

        .macro get_full_update_offset xx, sxx, skip
        lda     xx
        sec
        sbc     #$20
        sta     xx

        cmp     sxx
        bpl     :+
        stz     full_update_en
        jmp     skip
        :

        sta     region_xx
        .endmacro


        ;; get a horizontal or vertical scroll region pixel-space coordinate
        ;; depending on scroll direction

        ;; xx           : current scroll coordinate in pixel-space
        ;; prev_xx      : previous scroll coordinate in pixel-space

        ;; result is written to region_xx, end_xx

        .macro get_scroll_offset xx, prev_xx, lines

        lda     prev_xx
        cmp     xx
        bpl     :+

        ;; scroll right or down

        clc
        adc     #const::pixels_in_room
        and     #$10000 - lines * const::pixels_in_tile
        sta     region_xx

        lda     xx
        clc
        adc     #const::pixels_in_room
        and     #$10000 - lines * const::pixels_in_tile
        sta     end_xx

        bra     :++
        :

        ;; scroll left or up

        and     #$10000 - lines * const::pixels_in_tile
        sta     end_xx

        lda     xx
        and     #$10000 - lines * const::pixels_in_tile
        sta     region_xx

        :
        .endmacro


        .macro blit_condition skip

        lda     region_xx
        eor     end_xx
        bne     :+                      ; if we have arrived in the target
        jmp     skip                    ; column, we have finished blitting
        :

        .endmacro


        .macro advance rxx

        lda     region_xx
        clc
        adc     #const::pixels_in_tile
        sta     region_xx

        xba
        and     #const::rooms_in_map - $1
        sta     rxx

        lda     blit_yy
        inc
        and     #const::tiles_in_room - $1
        sta     blit_yy

        .endmacro


        ;; table with a shader for each transform mode

        ;; since tiles cannot be transposed by hardware, select another
        ;; tileset with prerendered transposed versions of the tiles


shader_table:
        .word   $0000, $4000, $8000, $c000, $0000, $4000, $8000, $c000


        ;; table for transposed versions of transform
        ;; flags for blitting columns

transform_flip_table:
        .word   $0008, $000c, $000a, $000e, $0000, $0004, $0002, $0006


        ;; update screen (main routine)

        .import scroll_xx
        .import scroll_yy
        .import scroll_prev_xx
        .import scroll_prev_yy
        .import transform
        .import full_update_xx


        ;; scroll_xx      : current horizontal scroll pixel-space coordinate
        ;; scroll_yy      : current vertical scroll pixel-space coordinate
        ;; scroll_prev_xx : previous horizontal scroll pixel-space coordinate
        ;; scroll_prev_yy : previous vertical scroll pixel-space coordinate
        ;; full_update_yy : full screen update position

        ;; transform      : transform flags

screen_update:

        stz     reg_wmadd + $2                 ; use low ram bank

        sa16

        ;; setup transform and shader blit registers

        ldx     transform
        stx     blit_transform
        lda     shader_table, x
        sta     blit_shader

        ;; full screen update

        lda     full_update_en
        bne     :+
        jmp     _skip_full_update
        :

        get_full_update_offset full_update_xx, scroll_yy, _skip_full_update

        scale_pixel_coord region_xx, blit_yy, room_yy,,, $4
        scale_pixel_coord scroll_xx, blit_xx_copy, room_xx

        blit_row $8

        dma_layer_row $8, $0
        dma_layer_row $8, $1

        advance room_yy

        blit_row $9
        advance room_yy

        blit_row $a
        advance room_yy

        blit_row $b

_skip_full_update:

        ;; blit vertical scroll region

        get_scroll_offset scroll_yy, scroll_prev_yy, $4

        blit_condition _skip_row

        scale_pixel_coord region_xx, blit_yy, room_yy,,, $4
        scale_pixel_coord scroll_xx, blit_xx_copy, room_xx

        blit_row $0

        dma_layer_row $0, $0
        dma_layer_row $0, $1

        advance room_yy

        blit_row $1
        advance room_yy

        blit_row $2
        advance room_yy

        blit_row $3

_skip_row:

        ;; blit horizontal scroll region

        ldx     blit_transform
        lda     transform_flip_table, x
        sta     blit_transform

        get_scroll_offset scroll_xx, scroll_prev_xx, $1

        blit_condition _skip_column

        scale_pixel_coord scroll_yy, blit_xx_copy, room_yy,,, $4
        scale_pixel_coord region_xx, blit_yy, room_xx

        blit_column $4
        advance room_xx

        blit_condition _skip_column
        blit_column $5
        advance room_xx

        blit_condition _skip_column
        blit_column $6
        advance room_xx

        blit_condition _skip_column
        blit_column $7

_skip_column:

        lda     scroll_xx
        sta     scroll_prev_xx

        lda     scroll_yy
        sta     scroll_prev_yy

        sa8

        rts
