        
        ;; collision.s

        ;; detect and respond to collisions of the player character with the environment
        

        .include "rem.i"
        
        .scope collision_bit
slope = $10
wall = $40
wall_b = $20
ledge = $10
ledge_b = $20
hmir = $02
vmir = $04
        .endscope
        
        .scope collison

        .export collision_move = move

        .importzp tform_tile_mask, tform_room_mask, room_hh_offset, room_vv_offset

entity_copy = $00

tile_xx     = $12
room_xx     = $14
        
tile_yy     = $16
room_yy     = $18
        
room_addr   = $1a
room_bank   = $1c
                
hitbox_ll   = $1e
hitbox_rr   = $20
hitbox_tt   = $22
hitbox_bb   = $24

hitbox_ww = $26
hitbox_hh = $28
        
vel_xx_copy = $2a
vel_yy_copy = $2c
hit_xx      = $2e
hit_yy      = $30

slope_snap  = $32

slope_pos = $34
slope_vel = $37






        .segment "code"


        ;; add velocity to position

        ;; pos : fixed point 16.8 position
        ;; vel : fixed point 8.8 velocity

        .macro add_velocity pos, vel
        .scope
        lda     pos
        clc
        adc     vel
        sta     pos
        sa8
        lda     $02 + pos
        adc     #$0                           ; transfer the carry
        sta     $02 + pos
        lda     $01 + vel                     ; todo : how to do signed add with carry correctly?
        bpl     _skipdec
        dec     $02 + pos
_skipdec:
        sa16
        .endscope
        .endmacro


        ;; get the collision tile data for a pixel-space coordinate
        ;; and test it with a bitmask. if there is a hit, trigger
        ;; the collision response

        ;; mask : bitmask to test for
        ;; isnot_mask : optional bits that tomake the test fail
        ;; response : label to jump to

        .macro test_pixel mask, response, isnot_mask
        .scope

        ;; todo : do not recalculate coords and room_ii/addr/bank for every test

        scale_pixel_coord hit_xx, tile_xx, room_xx
        scale_pixel_coord hit_yy, tile_yy, room_yy,, pre
        
        room_index x

        lda     f:roomtable + room_entry::data_addr, x
        clc
        adc     #room_data::collision
        sta     room_addr        
        lda     f:roomtable + room_entry::data_bank, x
        sta     room_bank

        tile_index tile_xx, tile_yy
        eor     tform_tile_mask
        tay
        lda     [room_addr], y
        eor     transform

        .ifnblank isnot_mask
        bit     isnot_mask
        bne     _isnot
        .endif

        bit     mask
        beq     _isnot
        jmp     response

_isnot:
        .endscope
        .endmacro
        

        ;; test a column or row of pixels

        ;; parameters are pixel-space coordinates

        ;; ll, rr   : for columns, the left and right extents
        ;;            for rows, the top and bottom extents
        ;; tt       : for columns, the vertical position
        ;;            for rows, the horizontal position
        ;; xx, yy   : temporaries for the coordinates of the individual pixels
        ;; mask     : bitmask to test for
        ;; response : jump label for collision response

        .macro test_pixels ll, rr, tt, xx, yy, mask, response
        .scope
        
        lda     tt
        sta     yy

        lda     ll
_loop:  
        sta     xx
        
        test_pixel mask, response
        
        lda     xx
        clc
        adc     #const::pixels_in_tile
        cmp     rr
        bmi     _loop
        
        lda     rr
        sta     xx
        
        test_pixel mask, response

        .endscope
        .endmacro


        ;; helper macros for testing hitbox borders

        .macro test_uu mask, response
        test_pixels hitbox_ll, hitbox_rr, hitbox_tt, hit_xx, hit_yy, mask, response
        .endmacro
        
        .macro test_dd mask, response
        test_pixels hitbox_ll, hitbox_rr, hitbox_bb, hit_xx, hit_yy, mask, response
        .endmacro
        
        .macro test_ll mask, response
        test_pixels hitbox_tt, hitbox_bb, hitbox_ll, hit_yy, hit_xx, mask, response
        .endmacro
        
        .macro test_rr mask, response
        test_pixels hitbox_tt, hitbox_bb, hitbox_rr, hit_yy, hit_xx, mask, response
        .endmacro
        

        ;; collision response when a wall or the floor or ceiling is hit
        ;; zeros the volicity and modies the position so that
        ;; the hitbox border will be ligned up with a tile boundary

        ;; vel  : the 8.8 fixed point velocity
        ;; pos  : the 16.8 fixed point position to modify in pixel-space
        ;; hit  : the pixel-space coordinate of the hitbox border
        ;; mask : set to #$ffff for positive movement, or to #$7 for negative movement

        .macro response pos, hit, mask
        lda     hit
        and     #const::pixels_in_tile - $1
        eor     mask
        clc
        adc     entity_copy + pos + $1
        stz     entity_copy + pos
        sta     entity_copy + pos + $1
        .endmacro


        ;; additional collision response when a wall is hit

        .macro horizontal_response wall

        ;; get flags

        ldy     entity_copy + entity::flags

        ;; zero velocity

        stz     entity_copy + entity::vel_xx

        ;; check wether we can wall jump or grab a ledge

        lda     hit_yy
        and     #$10000 - const::pixels_in_tile
        clc
        adc     #$12                          ; vertical distance from sprite center to hand
        sta     hit_yy
        cmp     entity_copy + entity::pos_yy
        bpl     :++

        txa
        bit     #collision_bit::ledge
        beq     :+

        ;; we can ledge grab here

        lda     hit_yy
        inc
        inc
        inc
        sta     entity_copy + entity::pos_yy
        stz     entity_copy + entity::vel_yy

        tya
        ora     #entity_flag_bit::ledge | entity_flag_bit::wall
        tay
        txa
        bit     #collision_bit::ledge_b
        bne     :++

        ;; this is a dangling ledge

        tya
        ora     #entity_flag_bit::ledge_b
        tay
        bra     :++
        :

        ;; we can wall-jump here

        txa
        bit     #collision_bit::wall_b
        beq     :+

        tya
        ora     #entity_flag_bit::wall
        tay
        :

        sty     entity_copy + entity::flags

        .endmacro

        ;; get the hitbox horizontal or vertical extents

        ;; xx    : 16.0 position in pixel-space
        ;; ww    : hitbox width or height
        ;; ll    : hitbox left or top border
        ;; rr    : hitbox right or bottom border
        ;; small : if not blank, shrink extents by one pixel

        .macro hitbox_coord xx, ww, ll, rr, small
        lda     entity_copy + xx
        tay
        clc
        adc     ww
        .ifnblank small
        dec
        .endif
        sta     rr

        tya
        sec
        sbc     ww
        .ifnblank small
        inc
        .endif
        sta     ll
        .endmacro


        ;; copy entity data and make additional copys of
        ;; velocity and hitbox info

        ;; from          : source address
        ;; to            : destination address

        .macro copy_entity from, to
        lda     $00 + from
        sta     $00 + to
        lda     $02 + from
        sta     $02 + to
        lda     $04 + from
        sta     $04 + to
        lda     $06 + from
        sta     $06 + to
        sta     vel_xx_copy
        lda     $08 + from
        sta     $08 + to
        sta     vel_yy_copy
        lda     $0a + from
        sta     $0a + to
        tay
        and     #$ff
        sta     hitbox_ww
        tya
        xba
        and     #$ff
        sta     hitbox_hh
        lda     $0c + from
        sta     $0c + to
        lda     $0e + from
        sta     $0e + to
        .endmacro

        ;; copy the modified entity data
        ;; back into the entity table

        .macro copy_entity_back from, to
        lda     $00 + from
        sta     $00 + to
        lda     $02 + from
        sta     $02 + to
        lda     $04 + from
        sta     $04 + to
        lda     $06 + from
        sta     $06 + to
        lda     $08 + from
        sta     $08 + to
        ;; lda     $0a + from   ; hitbox is not modified
        ;; sta     $0a + to
        lda     $0c + from
        sta     $0c + to
        ;; lda     $0e + from   ; animation index is not modified
        ;; sta     $0e + to
        .endmacro


        ;; negative velocity step

        .macro advance_negative pos_xx, vel_xx
        cmp     #$10000 - $800
        bpl     :+
        clc
        adc     #$800
        sta     vel_xx
        lda     $01 + pos_xx
        clc
        adc     #$10000 - $8
        sta     $01 + pos_xx
        bra     :++
        :
        add_velocity    pos_xx, vel_xx
        stz     vel_xx
        :
        .endmacro


        ;; positive velocity step

        .macro advance_positive pos_xx, vel_xx
        cmp     #$800
        bmi     :+
        clc
        adc     #$10000 - $800
        sta     vel_xx
        lda     $01 + pos_xx
        clc
        adc     #$8
        sta     $01 + pos_xx
        bra     :++
        :
        add_velocity    pos_xx, vel_xx
        stz     vel_xx
        :
        .endmacro



        ;; module main routine

move:
        .a16

        copy_entity rem_entity, entity_copy

        ;; detect and respond to slopes

        lda     entity_copy + entity::flags
        bit     #entity_flag_bit::air
        beq     :+
        lda     vel_yy_copy
        bpl     :+
        jmp     _noslope
        :

        lda     entity_copy + entity::pos_xx_frac
        sta     slope_pos
        lda     entity_copy + entity::pos_xx_frac + $1
        sta     slope_pos + $1
        add_velocity slope_pos, vel_xx_copy

        hitbox_coord entity::pos_yy, hitbox_hh, hitbox_tt, hitbox_bb

        lda     slope_pos + $1
        sta     hit_xx
        lda     hitbox_bb
        sta     hit_yy

        test_pixel #collision_bit::slope, _slope, #collision_bit::wall | collision_bit::vmir

        lda     hit_yy
        sec
        sbc     #$8
        sta     hit_yy

        test_pixel #collision_bit::slope, _slope, #collision_bit::wall | collision_bit::vmir

        lda     hit_yy
        clc
        adc     #$10
        sta     hit_yy

        test_pixel #collision_bit::slope, _slope, #collision_bit::wall | collision_bit::vmir
        
        bra     _noslope

_slope:

        bit     #collision_bit::hmir
        beq     :+
        lda     entity::vel_xx
        eor     #$ffff
        inc
        sta     entity_copy + entity::vel_yy

        lda     hit_xx
        eor     #$ffff
        bra     :++
        :
        lda     entity::vel_xx
        sta     entity_copy + entity::vel_yy

        lda     hit_xx
        :

        and     #$7
        sta     slope_snap

        lda     hit_yy
        and     #$10000 - $8
        ora     slope_snap
        sec
        sbc     hitbox_hh
        stz     entity_copy + entity::pos_yy_frac
        sta     entity_copy + entity::pos_yy

        lda     entity_copy + entity::flags
        and     #$ffff - entity_flag_bit::air
        ora     #entity_flag_bit::ground | entity_flag_bit::slope
        sta     entity_copy + entity::flags

        jmp     _vertical_end

_noslope:

        lda     entity_copy + entity::flags
        and     #$ffff - entity_flag_bit::ground
        sta     entity_copy + entity::flags


        ;; vertical movement
        
        hitbox_coord entity::pos_xx, hitbox_ww, hitbox_ll, hitbox_rr, small
        
        lda     vel_yy_copy
        bne     :+
        jmp     _vertical_end
        :
        bmi     :+
        jmp     _down

        lda     entity_copy + entity::flags
        bit     #entity_flag_bit::air
        beq     _up
        jmp     _vertical_end
        
_up:
        advance_negative entity_copy + entity::pos_yy_frac, vel_yy_copy
        hitbox_coord entity::pos_yy, hitbox_hh, hitbox_tt, hitbox_bb
        test_uu #collision_bit::wall, _up_wall

        lda     vel_yy_copy
        beq     :+
        jmp     _up
        :

        jmp     _vertical_end
        
_up_wall:       
        response entity::pos_yy_frac, hitbox_tt, #const::pixels_in_tile - $1

        stz     entity_copy + entity::vel_yy

        jmp     _vertical_end
        
_down:
        advance_positive entity_copy + entity::pos_yy_frac, vel_yy_copy
        hitbox_coord entity::pos_yy, hitbox_hh, hitbox_tt, hitbox_bb
        
        test_dd #collision_bit::wall, _down_wall

        lda     vel_yy_copy
        beq     :+
        jmp     _down
        :

        bra     _vertical_end
        
_down_wall:
        lda     entity_copy + entity::flags
        and     #$ffff - entity_flag_bit::air
        ora     #entity_flag_bit::ground
        sta     entity_copy + entity::flags

        response entity::pos_yy_frac, hitbox_bb, #$ffff

        stz     entity_copy + entity::vel_yy

        ;; todo : improve / move to response
        inc     entity_copy + entity::pos_yy
        
_vertical_end:

        
        ;; horizontal movement
        
        hitbox_coord entity::pos_yy, hitbox_hh, hitbox_tt, hitbox_bb, small   

        lda     entity_copy + entity::flags
        tax
        bit     #entity_flag_bit::slope
        beq     :+
        lda     hitbox_bb                     ; raise lower hitbox border
        sec                                   ; when moving on a slope
        sbc     #$10
        sta     hitbox_bb

        lda     entity_copy + entity::vel_yy
        bpl     :+
        lda     #$1
        sta     entity_copy + entity::vel_yy        
        :

        txa
        and     #$ffff - (entity_flag_bit::slope | entity_flag_bit::all_wall_flags)
        sta     entity_copy + entity::flags

        lda     vel_xx_copy
        bne     :+
        jmp     _horizontal_end
        :
        bmi     _left
        jmp     _right
        
_left:
        advance_negative entity_copy + entity::pos_xx_frac, vel_xx_copy
        hitbox_coord entity::pos_xx, hitbox_ww, hitbox_ll, hitbox_rr
        test_ll #collision_bit::wall, _left_wall

        lda     vel_xx_copy
        beq     :+
        jmp     _left
        :

        jmp     _horizontal_end
        
_left_wall:
        tax

        response entity::pos_xx_frac, hitbox_ll, #const::pixels_in_tile - $1

        horizontal_response left_wall

        jmp     _horizontal_end
        
_right:
        advance_positive entity_copy + entity::pos_xx_frac, vel_xx_copy
        hitbox_coord entity::pos_xx, hitbox_ww, hitbox_ll, hitbox_rr
        test_rr #collision_bit::wall, _right_wall

        lda     vel_xx_copy
        beq     :+
        jmp     _right
        :

        bra     _horizontal_end
        
_right_wall:
        tax

        response entity::pos_xx_frac, hitbox_rr, #$ffff

        ;; todo : improve / move to response
        inc     entity_copy + entity::pos_xx

        horizontal_response right_wall

_horizontal_end:


        copy_entity_back entity_copy, rem_entity
        
        rts
        
        .endscope
