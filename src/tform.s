

        ;; tform.s

        ;; move around the camera in the environment

        ;; note: this contains lots of loose ends which should probably go somewhere else



        .include "rem.i"

        .export scroll_xx, scroll_yy, scroll_prev_xx, scroll_prev_yy

        .export transform

        .export full_update_xx, full_update_en

        .export light_xx, light_yy

        .exportzp tform_tile_mask, tform_room_mask, room_hh_offset, room_vv_offset

        .export transform_update


        ;; zero page scratchpad

scroll_tgt = $0
room_xx = $2
room_yy = $4
tform_pos_xx = $6
tform_pos_yy = $8
barrier_mask = $a
update_flag = $c





        ;; zero page global state

tform_tile_mask = $f8
tform_room_mask = $fa
room_hh_offset = $fc
room_vv_offset = $fe




        .segment "bss"

        ;; .export debug_view
        ;; debug_view:

scroll_xx:      .res $2
scroll_yy:      .res $2

transform:      .res $2
full_update_xx: .res $2
full_update_en: .res $2

scroll_prev_xx: .res $2
scroll_prev_yy: .res $2

light_xx:       .res $2
light_yy:       .res $2


        .segment "code"


tile_index_tform_table:
        .word   $0
        .word   const::tiles_in_room - $1
        .word   const::tiles_in_room * (const::tiles_in_room - $1)
        .word   const::tiles_in_room * (const::tiles_in_room - $1) + const::tiles_in_room - $1
        .word   $0
        .word   const::tiles_in_room - $1
        .word   const::tiles_in_room * (const::tiles_in_room - $1)
        .word   const::tiles_in_room * (const::tiles_in_room - $1) + const::tiles_in_room - $1

room_index_tform_table:
        .word   $0
        .word   const::rooms_in_map - $1
        .word   const::rooms_in_map * (const::rooms_in_map - $1)
        .word   const::rooms_in_map * (const::rooms_in_map - $1) + const::rooms_in_map - $1
        .word   $0
        .word   const::rooms_in_map - $1
        .word   const::rooms_in_map * (const::rooms_in_map - $1)
        .word   const::rooms_in_map * (const::rooms_in_map - $1) + const::rooms_in_map - $1

room_index_tform_hh_offset_table:
        .word   .sizeof(room_entry)
        .word   $10000 - .sizeof(room_entry)
        .word   .sizeof(room_entry)
        .word   $10000 - .sizeof(room_entry)
        .word   .sizeof(room_entry)
        .word   $10000 - .sizeof(room_entry)
        .word   .sizeof(room_entry)
        .word   $10000 - .sizeof(room_entry)

room_index_tform_vv_offset_table:
        .word   .sizeof(room_entry) * const::rooms_in_map
        .word   .sizeof(room_entry) * const::rooms_in_map
        .word   $10000 - .sizeof(room_entry) * const::rooms_in_map
        .word   $10000 - .sizeof(room_entry) * const::rooms_in_map
        .word   .sizeof(room_entry) * const::rooms_in_map
        .word   .sizeof(room_entry) * const::rooms_in_map
        .word   $10000 - .sizeof(room_entry) * const::rooms_in_map
        .word   $10000 - .sizeof(room_entry) * const::rooms_in_map


        ;; TODO : this macro is not needed anymore.

        .macro clamp xx, ll, rr
        lda     ll
        cmp     xx
        bmi     :+
        sta     xx
        :
        lda     rr
        cmp     xx
        bpl     :+
        sta     xx
        :
        .endmacro


        ;; flip the bits aa and bb in the accumulator

        .macro flip_bits aa, bb
        .scope
        tax
        and     #$ffff - (bb | aa)
        tay

        txa
        bit     #aa
        beq     _skip_aa
        tya
        ora     #bb
        tay
_skip_aa:       


        txa
        bit     #bb
        beq     _skip_bb
        tya
        ora     #aa
        tay
_skip_bb:

        tya

        .endscope
        .endmacro


        ;; look around

        .macro scroll_look button_ll, button_rr
        tax
        lda     joy_current
        bit     #button_bit::ll
        beq     :++
        bit     #button_ll
        beq     :+
        txa
        clc
        adc     #$10000 - $58
        bra     :+++
        :
        lda     joy_current
        bit     #button_rr
        beq     :+
        txa
        clc
        adc     #$58
        bra     :++
        :
        txa
        :
        .endmacro

        ;; test and respond to scroll barriers

        .macro scroll_barriers pos, ofs, barrier_ll, barrier_rr

        tax
        sec
        sbc     scroll_tgt
        cmp     #const::pixels_in_room / $2 - ofs
        bpl     :+
        lda     barrier_mask
        bit     #barrier_ll
        beq     :+
        lda     scroll_tgt
        ora     #const::pixels_in_room / $2 - ofs
        tax
        :

        txa
        sec
        sbc     scroll_tgt
        cmp     #const::pixels_in_room / $2 + ofs
        bmi     :+
        lda     barrier_mask
        bit     #barrier_rr
        beq     :+
        lda     scroll_tgt
        ora     #const::pixels_in_room / $2 + ofs
        tax
        :
        txa

        .endmacro


        ;; update horizontal or vertical scroll coordinate

        ;; pos        : Rem's horizontal or vertical position
        ;; vel        : Rem's horizontal or vertical velocity
        ;; scroll     : horizontal or vertical scroll coordinate
        ;; ofs        : offset to apply to the window and the barriers
        ;; barrier_ll : left or top barrier to check for
        ;; barrier_rr : right or bottom barrier to check for

        .macro update_scroll_coordinate pos, vel, scroll, ofs, barrier_ll, barrier_rr, button_ll, button_rr
        lda     rem_entity + entity::pos
        and     #$ff00
        sta     scroll_tgt

        lda     rem_entity + entity::vel
        cmp     #$8000                        ; arithmetic shift right
        ror
        cmp     #$8000                        ; arithmetic shift right
        ror
        cmp     #$8000                        ; arithmetic shift right
        ror
        cmp     #$8000                        ; arithmetic shift right
        ror

        clc
        adc     rem_entity + entity::pos
        scroll_look button_ll, button_rr

        scroll_barriers pos, ofs, barrier_ll, barrier_rr
        clc
        adc     #$10000 - const::pixels_in_room / $2 + ofs
        sta     scroll_tgt

        lda     scroll
        asl
        asl
        asl
        asl
        sec
        sbc     scroll
        clc
        adc     scroll_tgt
        lsr
        lsr
        lsr
        lsr
        cmp     scroll_tgt
        bpl     :+
        inc
        :
        sta     scroll
        .endmacro


        ;; test if a position is inside a portal

        ;; xx  : the horizontal position
        ;; yy  : the vertical position

        ;; jumps to the _skip_portal label if test fails

        .macro test_portal xx, yy
        lda     xx
        cmp     f:roominfotable + room_info_entry::portal_ll, x
        bcs     :+
        jmp     _skip_portal
        :

        lda     xx
        cmp     f:roominfotable + room_info_entry::portal_rr, x
        bcc     :+
        jmp     _skip_portal
        :

        lda     yy
        cmp     f:roominfotable + room_info_entry::portal_tt, x
        bcs     :+
        jmp     _skip_portal
        :

        lda     yy
        cmp     f:roominfotable + room_info_entry::portal_bb, x
        bcc     :+
        jmp     _skip_portal
        :
        .endmacro


        ;; teleport

        ;; portal : the portal coordinate
        ;; pos    : the position coordinate
        ;; scroll : the sroll coordinate

        .macro teleport portal, pos, scroll
        lda     f:roominfotable + room_info_entry::portal, x
        tay
        clc
        adc     scroll
        sta     scroll
        tya
        clc
        adc     pos
        sta     pos
        .endmacro


        ;; transform coords from world-space to mirror-space or vice versa

        ;; mask : the bit in the transfom to check for
        ;; xx   : source coordinate
        ;; txx  : target coordinates
        ;; ofs  : if not empty, subtract offset

        .macro tform_coords mask, xx, txx, ofs
        .scope
        lda     transform
        bit     mask
        bne     :+
        lda     xx
        sta     txx
        bra     :++
        :
        lda     xx
        eor     #const::pixels_in_room * const::rooms_in_map - $1
        .ifnblank ofs
        sec
        sbc     ofs
        .endif
        sta     txx
        :
        .endscope
        .endmacro



        ;; set horizontal or vertical sprite position

        ;; xx : position in pixel-space
        ;; sxx : scroll coordinate in pixel-space

        ;; result is stored in rxx

        .macro sprite_pos xx, sxx, rxx, ofs
        lda     xx
        sec
        sbc     sxx
        .ifnblank ofs
        sec
        sbc     ofs
        .endif
        sta     rxx
        .endmacro


        ;; sets the horizontal or vertical light position

        ;; xx : position in pixel-space
        ;; sxx : scroll coordinate in pixel-space

        ;; result is stored in lxx

        .macro light_pos xx, sxx, lxx
        lda     sxx
        and     #$100 - $8
        sec
        sbc     xx
        lsr
        lsr
        lsr
        inc
        sta     lxx
        .endmacro


        .define victory_screen_xx 4
        .define victory_screen_yy 10
        

transform_update:
        sa16

        stz     update_flag

        scale_pixel_coord rem_entity + entity::pos_xx,, room_xx
        scale_pixel_coord rem_entity + entity::pos_yy,, room_yy        

        room_index a
        
        asl
        asl
        asl
        tax

        ;; check victory condition

        cpx     #(victory_screen_xx + victory_screen_yy * const::rooms_in_map) * 32
        bne     :+
        sa8
        jsr     fadeout
        jsr     spc_fade
        sa16
        :
        
        ;; check wether the room contains a portal

        lda     f:roominfotable + room_info_entry::portal_type, x
        and     #$ff

        bne     :+
        jmp     _skip_portal
        :

        ;; check wether the portal is locked

        sa8
        lda     f:roominfotable + room_info_entry::lock_entry, x
        beq     :+

        asl
        tay
        lda     lock_state_table, y
        cmp     f:roominfotable + room_info_entry::lock, x
        beq     :+
        jmp     _skip_portal
        :
        sa16

        ;; transform coordinates into mirror-space

        tform_coords #transform_bit::hh, rem_entity + entity::pos_xx, tform_pos_xx
        tform_coords #transform_bit::vv, rem_entity + entity::pos_yy, tform_pos_yy

        ;; check if we are inside the portal

        sa8
        test_portal tform_pos_xx, tform_pos_yy
        sa16

        ;; we are inside the portal

        tform_coords #transform_bit::hh, scroll_xx, scroll_xx
        tform_coords #transform_bit::vv, scroll_yy, scroll_yy

        ;; modify entity coordinates

        teleport portal_xx, tform_pos_xx, scroll_xx
        teleport portal_yy, tform_pos_yy, scroll_yy

        ;; transform the coordinates back into world-space

        tform_coords #transform_bit::hh, tform_pos_xx, rem_entity + entity::pos_xx
        tform_coords #transform_bit::vv, tform_pos_yy, rem_entity + entity::pos_yy

        tform_coords #transform_bit::hh, scroll_xx, scroll_xx
        tform_coords #transform_bit::vv, scroll_yy, scroll_yy

        ;; modify the transform

        lda     f:roominfotable + room_info_entry::portal_type, x
        and     #(transform_bit::hh | transform_bit::vv | transform_bit::tt)
        eor     transform
        sta     transform

        ;; trigger a full screen update

        lda     #$ffff
        sta     update_flag

_skip_portal:
        sa16

        ;; transform scroll barrier mask

        lda     f:roominfotable + room_info_entry::flags, x
        sta     barrier_mask

        lda     transform
        bit     #transform_bit::hh
        beq     :+
        lda     barrier_mask
        flip_bits room_info_flag_bit::barrier_ll, room_info_flag_bit::barrier_rr
        sta     barrier_mask
        :

        lda     transform
        bit     #transform_bit::vv
        beq     :+
        lda     barrier_mask
        flip_bits room_info_flag_bit::barrier_tt, room_info_flag_bit::barrier_bb
        sta     barrier_mask
        :

        ;; transform mask and offset update

        ldx     transform
        lda     tile_index_tform_table, x
        sta     tform_tile_mask
        lda     room_index_tform_table, x
        sta     tform_room_mask
        lda     room_index_tform_hh_offset_table, x
        sta     room_hh_offset
        lda     room_index_tform_vv_offset_table, x
        sta     room_vv_offset

        ;; update scroll coordinates 

        lda     scroll_yy                     ; save old scroll coordinate
        sta     tform_pos_yy                  ; reuse temporary

        update_scroll_coordinate pos_xx, vel_xx, scroll_xx, $4, room_info_flag_bit::barrier_ll, room_info_flag_bit::barrier_rr, button_bit::left, button_bit::right
        update_scroll_coordinate pos_yy, vel_yy, scroll_yy, $10, room_info_flag_bit::barrier_tt, room_info_flag_bit::barrier_bb, button_bit::up, button_bit::down

        ;; full screen update, if needed

        lda     update_flag
        beq     :+

        lda     scroll_xx
        sta     scroll_prev_xx
        lda     scroll_yy
        sta     scroll_prev_yy
        clc
        adc     #$100
        and     #$ffe0
        sta     full_update_xx
        lda     #$ffff
        sta     full_update_en
        :


        sa8

        ;; sprite position update

        sprite_pos rem_entity + entity::pos_xx, scroll_xx, f:rem_sprite_entry + sprite_entry::xx, #$3
        sprite_pos rem_entity + entity::pos_yy, scroll_yy, f:rem_sprite_entry + sprite_entry::yy, #$ff

        ;; sprite update

        ldx     #.loword(rem_sprite_entry)
        jsr     sprite_setup

        ;; light update

        light_pos     rem_entity + entity::pos_xx, scroll_xx, light_xx
        light_pos     rem_entity + entity::pos_yy, scroll_yy, light_yy

        rts
