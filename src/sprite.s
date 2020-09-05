

        ;; sprite.c

        ;; sprite setup and update using sprite-pumping


	.import dma_queue_buffer
	.import dma_queue_head
        
	.include "rem.i"
        
	.scope sprite
        
	.export sprite_setup, oam_mirror, sprite_oam_dma
        
	.define entry sprite_entry
	.define frame ani_frame
        
        
	;; sprite zero page scratchpad variables
        
entry_base = $0
frame_base = $18
object_table_ptr = $20
entry_ptr = $23	                    


        .segment "hdata"

oam_mirror:
        .res    $200
oam_hi_mirror:
        .res    $20


	.segment "code"

	;; macro definitions
        
	.macro x_to_wmdata
	sa16
	txa
        sa8
	sta   reg_wmdata
	xba
	sta   reg_wmdata
        xba
	.endmacro
        
	.macro sum_to_wmdata aa, bb
	lda   aa
	clc
	adc   bb
        dec
	sta   reg_wmdata
	.endmacro
        
	.macro dif_to_wmdata aa, bb
	lda   aa
	sec
	sbc   bb
	sta   reg_wmdata
	.endmacro
        
        
        
	;; v : if clear, vram update is forced
	;; x : address of sprite entry
        
	;; note: this function expects that the dma queue, the sprite oam buffer and the sprite entry
	;; all are stored in the first ram bank ($7e)
        
        
sprite_setup:

        ;; copy sprite entry into zero page scratchpad
        
        lda     #$7e
        sta     entry_ptr + $2
        stx     entry_ptr

        lda     #$0
        xba
        lda     #.sizeof(entry)

        ldy     #$0
        phb
        mvn     #$7e, #$00
        plb
       
	;; initialize far pointers

	stz   reg_wmadd + $2
	lda   entry::animation_table + $2
	sta   object_table_ptr + $2

        ;; copy animation table entry into zero page scratchpad
                
        lda     entry::index

        sa16

        and     #$ff

        asl
        asl
        asl
        tay

        iny
        iny
        lda     [.lobyte(entry_base + entry::animation_table)], y
        sta     frame_base + $0

        iny
        iny
        lda     [.lobyte(entry_base + entry::animation_table)], y
        sta     frame_base + $2

        iny
        iny
        lda     [.lobyte(entry_base + entry::animation_table)], y
        sta     frame_base + $4

        iny
        iny
        lda     [.lobyte(entry_base + entry::animation_table)], y
        sta     frame_base + $6

        sa8

        ;; skip vram update if sprite index remained unchanged

        lda     entry::flags
        bit     #sprite_entry_flag_bit::update
        beq     _skip_vram_update

        and     #$ff - sprite_entry_flag_bit::update
        sta     entry::flags

        ;; queue sprite vram dma

        sa16

        dmaq_insert $0

        lda     entry::vram_address
        sta     dmaq_table_rblock + dmaq_entry::dst_address, x
        lda     frame_base + frame::data_pointer
        sta     dmaq_table_rblock + dmaq_entry::src_address, x
        lda     frame_base + frame::data_bank
        sta     dmaq_table_rblock + dmaq_entry::src_bank, x
                
        lda     frame_base + frame::object_table_length
        asl                                     ; each tile is 32 bytes
        asl
        asl
        asl
        sta     dmaq_table_rblock + dmaq_entry::length, x

        sa8

_skip_vram_update:

        ;; make object table data

        ldx     frame_base + frame::object_pointer
        stx     object_table_ptr

        ldx     entry::oam_buffer_address
        stx     reg_wmadd
        
        ldx     entry::oam_attribute_2 ; x = oam attributes 2 and 3
        ldy     #$0
        
        lda     entry::oam_attribute_3
        bit     #$40
        bne      _mirror
        
        :
        sum_to_wmdata entry::xx, {[object_table_ptr], y}
        iny
        
        sum_to_wmdata entry::yy, {[object_table_ptr], y}
        iny
        
        x_to_wmdata
        inx
        
        cpy     frame_base + frame::object_table_length
        bne     :-
        bra     _zero
        
_mirror:
        :
	dif_to_wmdata entry::xx, {[object_table_ptr], y}
        iny
        
        sum_to_wmdata entry::yy, {[object_table_ptr], y}
        iny
        
        x_to_wmdata
        inx
        
        cpy     frame_base + frame::object_table_length
        bne     :-
        
_zero:

	;; zero out rest of buffer
        
        tyx
        
        stz     entry::oam_buffer_length + $1
        lda     #$e0
        
        cpy     entry::oam_buffer_length
        bpl     :++
        
        :
        sta     reg_wmdata
        sta     reg_wmdata
        sta     reg_wmdata
        sta     reg_wmdata
        
        iny
        cpy     entry::oam_buffer_length
        bne     :-
        :

        ;; update buffer length

        tya
        ldy     #entry::oam_buffer_length
        sta     [entry_ptr], y

        ;; advance sprite frame counter and index

        lda     frame_base + frame::frame_delay
        bne     :+

        lda     entry::flags
        ora     #sprite_entry_flag_bit::stop
        sta     entry::flags

        bra     _skip_frame_counter_inc
        :

        lda     entry::frame_counter
        inc
        sta     entry::frame_counter
        cmp     frame_base + frame::frame_delay
        bne     :++
        
        lda     entry::index
        inc
        sta     entry::index
        cmp     [entry::animation_table]        ; animation table length
        bne     :+
        
        stz     entry::index

        :

        lda     entry::flags
        ora     #sprite_entry_flag_bit::update
        sta     entry::flags

        stz     entry::frame_counter
        :

        ldy     #entry::index
        lda     entry::index
        sta     [entry_ptr], y

        ldy     #entry::frame_counter
        lda     entry::frame_counter
        sta     [entry_ptr], y

_skip_frame_counter_inc:

        ;; update flags

        ldy     #entry::flags
        lda     entry::flags
        sta     [entry_ptr], y

        rts
        
        
        .endscope
        


sprite_oam_dma:

        ;; object table dma

        stz     reg_oamadd + $0
        stz     reg_oamadd + $1

        ldx     #.lobyte(reg_oamdata) * $100
        stx     reg_dmapx

        ldx     #.loword(oam_mirror)
        stx     reg_a1tx

        lda     #^oam_mirror
        sta     reg_a1bx

        ldx     #$220
        stx     reg_dasx

        lda     #$1
        sta     reg_mdmaen
        
        rts

