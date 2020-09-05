

        ;; key.s

        ;; code for the keys that can be carried to the statues

        
        .include "rem.i"

        .importzp tform_room_mask, room_hh_offset, room_vv_offset

        .export key_update, lock_state_table, key_carry

        ;; zero page

key_xx = $0
room_xx = $1
key_yy = $2
room_yy = $3
key_screen_xx = $4
key_screen_yy = $6
key_attrib = $8
room_xx_t = $12
lock_entry_copy = $14


        

        .segment "bss"

        .define nlocks $10

lock_state_table:
        .res    nlocks * 2

key_carry:
        .res    2

        .segment "code"



        .macro offset xx, yy
        sa16
        lda     xx
        .ifnblank yy
        clc
        adc     yy
        .endif
        asl
        asl
        asl
        clc
        adc     $1, s
        tax
        lda     #$0
        sa8
        .endmacro

        .macro screen_position pos, scroll
        lda     pos
        sec
        sbc     scroll
        .endmacro

        .macro clip rr, attrib
        bpl     :++
        cmp     #$10000 - 20
        bpl     :+
        sa8
        rts
        .a16
        :
        .ifnblank attrib
        lda     attrib
        sta     key_attrib
        .endif
        bra     :++
        :
        cmp     rr
        bmi     :+
        sa8
        rts
        .a16
        :
        .endmacro

        .macro compare_pos aa, bb
        lda     aa
        sec
        sbc     bb
        sec
        sbc     #$8
        bpl     :+
        eor     #$ffff
        inc
        :
        cmp     #$20
        bpl     _skip_interact
        .endmacro

        .macro key_mirror
        tax
        lda     transform
        bit     #transform_bit::hh
        beq     :+
        txa
        eor     #$20
        tax
        :
        .endmacro


key_room:
        .a8

        ;; load lock state

        lda     f:roominfotable + room_info_entry::lock_entry, x
        bne     :+

        ;; room does not contain a lock

        rts
        :

        sta     lock_entry_copy
        asl
        tay

        ;; load horizontal and vertical key position

        lda     f:roominfotable + room_info_entry::key_xx, x
        sta     key_xx

        lda     transform
        bit     #transform_bit::hh
        beq     :+
        lda     #$f0
        sec
        sbc     key_xx
        sta     key_xx
        :

        lda     f:roominfotable + room_info_entry::key_yy, x
        sta     key_yy

        ;; TODO: vertical transform

        ;; clip key sprite

        sa16

        lda     #$2 | $8 | $20 | $80
        sta     key_attrib

        screen_position key_xx, scroll_xx
        sta     key_screen_xx
        clip    #$100, #$ff

        screen_position key_yy, scroll_yy
        sta     key_screen_yy
        clip    #$e0

        ;; get lock state

        lda     lock_state_table, y
        bne     :+

        ;; lazy load initial lock state

        lda     f:roominfotable + room_info_entry::key, x
        and     #$ff
        ora     #$8000
        sta     lock_state_table, y
        :

        ;; check if this is a duplicate key

        lda     lock_entry_copy
        bit     #$80
        beq     _skip_duplicate

        ;; this is a duplicate key
        ;; no interaction and only render if portals are linked

        lda     lock_state_table, y
        cmp     f:roominfotable + room_info_entry::lock, x
        bne     :+
        jmp     _skip_render
        :
        jmp     _skip_interact_2

_skip_duplicate:
        
        lda     lock_state_table, y
        
        ;; mirror key

        key_mirror

        ;; TODO: vertical key mirror

        ;; player interaction

        compare_pos     rem_entity + entity::pos_xx, key_xx
        compare_pos     rem_entity + entity::pos_yy, key_yy

        lda     joy_prev
        bit     #button_bit::yy | button_bit::bb
        bne     _skip_interact

        lda     joy_current
        bit     #button_bit::yy | button_bit::bb
        beq     _skip_interact

        ;; swap out keys

        phx
        sa8
        ldx     #$7488
        jsr     spc_play_sample
        sa16
        plx

        lda     key_carry
        ora     #$8000
        stx     key_carry

        key_mirror

        txa
        sta     lock_state_table, y

_skip_interact_2:
        
        key_mirror

_skip_interact:

        ;; render key sprite

        sa8        

        lda     key_screen_xx
        sta     f:oam_mirror + oam::key + $0

        lda     key_screen_yy
        dec
        sta     f:oam_mirror + oam::key + $1

        txa
        asl
        and     #$3f
        ora     #$40
        sta     f:oam_mirror + oam::key + $2

        txa
        asl
        and     #$c0
        ora     #($6 * $2) | ($2 * $10)       ; palette #6, priority #2
        sta     f:oam_mirror + oam::key + $3

        lda     key_attrib
        sta     f:oam_mirror + $200 + oam::key / (4 * 4)

_skip_render:   
        ;; modify stack pointer for early out

        plx
        plx

        rts


key_update:
        sa16

        lda     scroll_xx + $1
        and     #(const::rooms_in_map - $1)
        sta     room_xx
        sta     room_xx_t
        lda     scroll_yy + $1
        and     #(const::rooms_in_map - $1)
        sta     room_yy


        ;; clear key sprite

        lda     #$0
        sta     f:oam_mirror + oam::key
        sta     f:oam_mirror + oam::key + $2

        ;; get room index

        room_index a
        asl
        asl
        asl
        tax
        phx

        ;; upper left

        lda     #$0
        sa8
        jsr     key_room

        ;; upper right

        lda     transform
        bit     transform_bit::hh
        bne     :+
        inc     room_xx
        bra     :+
        dec     room_xx
        :

        offset  room_hh_offset

        jsr     key_room

        ;; lower right

        lda     transform
        bit     transform_bit::vv
        bne     :+
        inc     room_yy
        bra     :+
        dec     room_yy
        :

        offset  room_vv_offset, room_hh_offset

        jsr     key_room

        ;; lower left

        lda     room_xx_t
        sta     room_xx

        offset  room_vv_offset

        jsr     key_room

        plx

        rts
