
        ;; ani.s

        ;; animation control for the player character


        .include "rem.i"

        .export entity_table, rem_entity, rem_sprite_update, rem_sprite_entry


        ;; zero page scratchpad

acceleration = $00
sample_pitch = $2

        .segment "hdata"

rem_sprite_entry:
        .byte   $0
        .byte   $0
        .byte   $20
        .byte   $20
        .byte   $9                              ; starting tile = 9
        .byte   $28                             ; priority = 2, palette = 4
        .word   .loword(data_idle_frame_table)
        .byte   ^data_idle_frame_table
        .word   .loword(oam_mirror) + oam::rem
        .byte   $0
        .byte   $0
        .word   vram::spritetiles + $90
        .word   $0
        


        .segment "bss"

entity_table:   
rem_entity:
        .tag    entity
rem_flags_prev:
        .res    2


        .segment "code"

        .define ani_sound_volume $40


        ;; tables for Rem's sprite animations

ani_idle = $00
ani_walking = $04
ani_running = $08
ani_jumping = $0c
ani_falling = $10
ani_crouching = $14
ani_walljump = $18
ani_dangling = $1c
ani_sliding = $20


animation_table:
        .word   .loword(data_idle_frame_table), ^data_idle_frame_table
        .word   .loword(data_walking_frame_table), ^data_walking_frame_table
        .word   .loword(data_running_frame_table), ^data_running_frame_table
        .word   .loword(data_jumping_frame_table), ^data_jumping_frame_table
        .word   .loword(data_falling_frame_table), ^data_falling_frame_table
        .word   .loword(data_crouching_frame_table), ^data_crouching_frame_table
        .word   .loword(data_walljump_frame_table), ^data_walljump_frame_table
        .word   .loword(data_dangling_frame_table), ^data_dangling_frame_table
        .word   .loword(data_sliding_frame_table), ^data_sliding_frame_table

hitbox_size_table:
        .word   $4, $1b
        .word   $4, $19
        .word   $7, $19
        .word   $4, $17
        .word   $4, $17
        .word   $4, $10
        .word   $4, $17
        .word   $4, $17
        .word   $4, $15


        ;; set animation

        .macro set_ani entry
        .scope

        sa8

        txa
        cmp     rem_entity + entity::animation_index
        beq     _skip_set_ani

        sta     rem_entity + entity::animation_index

        lda     animation_table + $2, x
        sta     f:entry + sprite_entry::animation_table_bank

        lda     f:entry + sprite_entry::flags
        ora     #sprite_entry_flag_bit::update
        sta     f:entry + sprite_entry::flags

        sa16

        lda     animation_table, x
        sta     f:entry + sprite_entry::animation_table

        lda     #$0
        sta     f:entry + sprite_entry::index

        ;; select hitbox

        sa8

        lda     hitbox_size_table, x
        sta     rem_entity + entity::box_ww

        ldy     rem_entity + entity::box_hh

        lda     hitbox_size_table + $2, x
        sta     rem_entity + entity::box_hh

        sa16

        tya
        and     #$ff
        sec
        sbc     hitbox_size_table + $2, x

        clc
        adc     rem_entity + entity::pos_yy       ; move down to avoid loosing
        sta     rem_entity + entity::pos_yy       ; contact with the floor

        sa8

_skip_set_ani:

        .endscope
        .endmacro


        ;; slow movment with friction

        ;; vel : the velocity to reduce
        ;; less : if not blank, less friction is applied

        .macro friction_apply vel
        .scope
        tax
        lsr
        lsr
        lsr
        lsr
        lsr
        sta     vel
        txa
        sec
        sbc     vel
        sec
        sbc     #$8
        bpl     _thresh
        lda     #$0
_thresh:        
        .endscope
        .endmacro

        .macro friction vel, less
        .scope
        lda     vel
        bmi     _neg
        friction_apply vel
        bra     _end
_neg:
        eor     #$ffff
        inc
        friction_apply vel
        eor     #$ffff
        inc
_end:
        sta     vel
        .endscope
        .endmacro


        ;; adds yy to xx if one of the bits in mask is set.
        ;; result is stored in xx

        .macro add_if mask, xx, yy
        bit     mask
        beq     :+
        lda     xx
        clc
        adc     yy
        sta     xx
        txa
        :
        .endmacro


        ;; subtracts yy from xx if one of the bits in mask is set.

        ;; result is stored in xx

        .macro sub_if mask, xx, yy
        bit     mask
        beq     :+
        lda     xx
        sec
        sbc     yy
        sta     xx
        txa
        :
        .endmacro


        .macro play_sample mask
        phx
        lda     f:rem_sprite_entry + sprite_entry::xx
        lsr
        lsr
        lsr
        lsr
        and     #$000f
        ora     mask | ani_sound_volume
        tax
        sa8
        jsr     spc_play_sample
        sa16
        plx
        .endmacro

        .macro footstep frame
        .scope
        sa8
        ldx     #$0800
        lda     f:rem_sprite_entry + sprite_entry::index
        beq     _play
        ldx     #$0900
        cmp     frame
        beq     _play
        bra     _skip
_play:
        lda     f:rem_sprite_entry + sprite_entry::xx
        lsr
        lsr
        lsr
        lsr
        sa16
        and     #$000f
        stx     sample_pitch
        ora     sample_pitch
        ora     #$6020
        tax
        sa8
        jsr     spc_play_sample
_skip:
        sa16
        .endscope
        .endmacro


        ;; update Rem's sprite data

rem_sprite_update:
        sa16

        ;; gravity

        lda     rem_entity + entity::flags
        bit     #(entity_flag_bit::ledge | entity_flag_bit::ledge_b)
        bne     :++

        bit     #entity_flag_bit::all_wall_flags
        bne     :+

        lda     rem_entity + entity::vel_yy
        clc
        adc     #$58
        sta     rem_entity + entity::vel_yy
        bra     :++
        :

        lda     rem_entity + entity::vel_yy
        clc
        adc     #$28
        sta     rem_entity + entity::vel_yy
        :

        ;; friction

        lda     rem_entity + entity::flags
        bit     #entity_flag_bit::ground
        bne     :+
        friction        rem_entity + entity::vel_xx, $2
        bra     :++
        :
        friction        rem_entity + entity::vel_xx, $2
        :

        friction        rem_entity + entity::vel_yy, $2


        ;; player input

        ldx     joy_current

        ;; set speed

        lda     rem_entity + entity::flags
        bit     #entity_flag_bit::ground
        bne     :+
        lda     #$a * $4
        bra     _set_acceleration
        :

        txa
        bit     #button_bit::aa
        beq     :+
        lda     #$b * $4
        bra     _set_acceleration
        :
        lda     #$4 * $4

_set_acceleration:      
        sta     acceleration

        ;; move left or right

        txa

        bit     #button_bit::ll
        beq     :+
        jmp     _skip_move
        :

        sub_if  #button_bit::left,  rem_entity + entity::vel_xx, acceleration
        add_if  #button_bit::right, rem_entity + entity::vel_xx, acceleration

        ;; jump

        bit     #button_bit::xx
        beq     _fall

        lda     joy_prev
        bit     #button_bit::xx
        bne     _skip_jump

        lda     rem_entity + entity::flags

        bit     #(entity_flag_bit::ground | entity_flag_bit::all_wall_flags)
        beq     _skip_jump

        bit     #entity_flag_bit::ledge_b
        bne     _skip_jump

        tay

        and     #$ffff - (entity_flag_bit::ground | entity_flag_bit::all_wall_flags)
        ora     #entity_flag_bit::air
        sta     rem_entity + entity::flags

        lda     rem_entity + entity::vel_xx
        bmi     :+
        eor     #$ffff
        inc
        :
        cmp     #$8000
        ror
        sec
        sbc     #$880

        sta     rem_entity + entity::vel_yy

        tya

        bit     #entity_flag_bit::left_wall
        beq     :+
        lda     #$400
        sta     rem_entity + entity::vel_xx
        :

        bit     #entity_flag_bit::right_wall
        beq     :+
        lda     #$10000 - $400
        sta     rem_entity + entity::vel_xx
        :

        play_sample #$9800
        
        bra     _skip_jump

_fall:
        txa
        bit     #button_bit::up | button_bit::rr
        bne     _skip_jump

        lda     rem_entity + entity::vel_yy
        bpl     _skip_jump
        lda     rem_entity + entity::flags
        bit     #entity_flag_bit::ground
        bne     _skip_jump
        stz     rem_entity + entity::vel_yy

_skip_jump:     

        ;; pull up ledges
        
        txa
        bit     #button_bit::up | button_bit::rr
        beq     :+

        lda     rem_entity + entity::flags
        bit     #(entity_flag_bit::ledge | entity_flag_bit::ledge_b)
        beq     :+

        and     #$ffff - (entity_flag_bit::ground | entity_flag_bit::all_wall_flags)
        ora     #entity_flag_bit::air
        sta     rem_entity + entity::flags

        lda     #$10000 - $680
        sta     rem_entity + entity::vel_yy
        
        play_sample #$9800 
        :

_skip_move:

        ;; face direction

        txa

        bit     #button_bit::left
        beq     :+
        lda     rem_entity + entity::flags
        ora     #entity_flag_bit::facing
        sta     rem_entity + entity::flags
        bra     :++
        :

        bit     #button_bit::right
        beq     :+
        lda     rem_entity + entity::flags
        and     #$ffff - entity_flag_bit::facing
        sta     rem_entity + entity::flags
        :

        ;; move and collide

        jsr     collision_move

        ;; play sound if wall or ground is hit

        lda     rem_entity + entity::flags
        bit     #entity_flag_bit::all_wall_flags | entity_flag_bit::ground
        beq     :+
        lda     rem_flags_prev
        bit     #entity_flag_bit::all_wall_flags | entity_flag_bit::ground
        bne     :+
        play_sample #$8800
        :

        ;; select animation

        lda     rem_entity + entity::flags

        ;; bit     #entity_flag_bit::crouched
        ;; beq     :+

        ;; ldx     #ani_crouching
        ;; jmp     _select
        ;; :

        bit     #entity_flag_bit::ground
        bne     _ground_animation

        bit     #(entity_flag_bit::left_wall | entity_flag_bit::right_wall)
        beq     :++

        bit     #(entity_flag_bit::ledge_b)
        beq     :+

        ldx     #ani_dangling
        jmp     _select
        :

        ldx     #ani_walljump
        jmp     _select
        :

        lda     rem_entity + entity::vel_yy
        bpl     :+

        ldx     #ani_jumping
        jmp     _select
        :

        ldx     #ani_falling
        jmp     _select

_ground_animation:

        lda     rem_entity + entity::vel_xx
        bne     :+

        ldx     #ani_idle
        jmp     _select
        :

        eor     rem_entity + entity::flags
        bit     #entity_flag_bit::facing
        beq     :+

        ldx     #ani_sliding
        jmp     _select
        :

        lda     rem_entity + entity::vel_xx
        bpl     :+

        eor     #$ffff
        inc
        :
        
        cmp     #$240
        bmi     :+

        footstep #$9
        
        ldx     #ani_running
        bra     _select

        :
        cmp     #$40
        bmi     :+

        footstep #$5
        
        ldx     #ani_walking
        bra     _select

        :
        ldx     #ani_idle

_select:
        set_ani rem_sprite_entry

        sa16
        lda     rem_entity + entity::flags
        sta     rem_flags_prev
        bit     #entity_flag_bit::facing
        beq     :+
        sa8
        lda     f:rem_sprite_entry + sprite_entry::oam_attribute_3
        and     #$3f
        ora     #$40
        sta     f:rem_sprite_entry + sprite_entry::oam_attribute_3
        bra     :++
        :
        sa8
        lda     f:rem_sprite_entry + sprite_entry::oam_attribute_3
        and     #$3f
        sta     f:rem_sprite_entry + sprite_entry::oam_attribute_3
        :

        rts



