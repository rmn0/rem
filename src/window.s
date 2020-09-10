
        ;; window.s

        ;; window animations

        .include "rem.i"


        .define bounds_group_size $10

        .struct frame
        width                   .res $2
        height                  .res $2
        bounds_table_left       .res $100 / bounds_group_size
        bounds_table_right      .res $100 / bounds_group_size
        data                    .res $1       ;variable length
        .endstruct

        .export window_hdma_setup, window_hdma_update, window_hdma_update_8bits


        .segment "bss"

hdma_table:
        .res $500


        .segment "code"

        .define reg_wmdata_direct .lobyte(reg_wmdata)

prefill:
        .repeat $100
        .byte   $1, $0, $0, $0, $0
        .endrep

window_hdma_setup:

        ;; setup windowing logic

        lda     #$aa
        sta     reg_w12sel
        sta     reg_w34sel
        sta     reg_wobjsel
        lda     #$ff
        stz     reg_wbglog
        stz     reg_wobjlog
        lda     #$f
        sta     reg_tmw
        sta     reg_tsw

        ;; setup hdma

        hdma    $1, #.lobyte(reg_whx) * $100 + $4, hdma_table

        rts




        .macro unroll_loop unroll_offset, unroll_page_offset
        .scope

        tya
	adc	a:$2 + $4 + unroll_offset, x
	bpl	_noclip_both

        bit     #$80
        bne     _end_second                   ; can be skipped because of prefill
	ora	#$ff80        
	sta	unroll_page_offset + $2

_end_second:     

        tya
	adc	a:$0 + $4 + unroll_offset, x
	bpl	_noclip_first

        bit     #$80
        bne     _end_first                    ; can be skipped because of prefill
	ora	#$ff80

	sta	unroll_page_offset + $0

        bra     _end_first

_noclip_both:
	ora	#$8080
	sta	unroll_page_offset + $2

        tya
	adc	a:$0 + $4 + unroll_offset, x

_noclip_first:  
	ora	#$8080
	sta	unroll_page_offset + $0

_end_first:   

        .endscope
        .endmacro


        .define page_size 200

        .macro unroll ofs, page_ofs

        lda     #hdma_table + ofs * page_size + 6
        pha
        pld

        unroll_loop   0 + ofs * page_size,   0
        unroll_loop   5 + ofs * page_size,   5
        unroll_loop  10 + ofs * page_size,  10
        unroll_loop  15 + ofs * page_size,  15
        unroll_loop  20 + ofs * page_size,  20
        unroll_loop  25 + ofs * page_size,  25
        unroll_loop  30 + ofs * page_size,  30
        unroll_loop  35 + ofs * page_size,  35
        unroll_loop  40 + ofs * page_size,  40
        unroll_loop  45 + ofs * page_size,  45
        unroll_loop  50 + ofs * page_size,  50
        unroll_loop  55 + ofs * page_size,  55
        unroll_loop  60 + ofs * page_size,  60
        unroll_loop  65 + ofs * page_size,  65
        unroll_loop  70 + ofs * page_size,  70
        unroll_loop  75 + ofs * page_size,  75
        unroll_loop  80 + ofs * page_size,  80
        unroll_loop  85 + ofs * page_size,  85
        unroll_loop  90 + ofs * page_size,  90
        unroll_loop  95 + ofs * page_size,  95
        unroll_loop 100 + ofs * page_size, 100
        unroll_loop 105 + ofs * page_size, 105
        unroll_loop 110 + ofs * page_size, 110
        unroll_loop 115 + ofs * page_size, 115
        unroll_loop 120 + ofs * page_size, 120
        unroll_loop 125 + ofs * page_size, 125
        unroll_loop 130 + ofs * page_size, 130
        unroll_loop 135 + ofs * page_size, 135
        unroll_loop 140 + ofs * page_size, 140
        unroll_loop 145 + ofs * page_size, 145
        unroll_loop 150 + ofs * page_size, 150
        unroll_loop 155 + ofs * page_size, 155
        unroll_loop 160 + ofs * page_size, 160
        unroll_loop 165 + ofs * page_size, 165
        unroll_loop 170 + ofs * page_size, 170
        unroll_loop 175 + ofs * page_size, 175
        unroll_loop 180 + ofs * page_size, 180
        unroll_loop 185 + ofs * page_size, 185
        unroll_loop 190 + ofs * page_size, 190
        unroll_loop 195 + ofs * page_size, 195

        .endmacro




window_hdma_update:

        ;; prefill dma table

        dma_wram_memcpy $0, #.loword(hdma_table), #^hdma_table, #.loword(prefill), #^prefill, #164 * 5

        ;; setup scrolling

        lda     frame_counter
        and     #$7f
        xba
        lda     frame_counter
        and     #$7f
        tay

        ;; vertical position

        lda     f:data_noname_window
        sta     hdma_table

        ;; setup bank register to point at the window data

        lda     #^data_noname_window
        pha
        plb

        ldx     #.loword(data_noname_window)


        ;; main loop

        sa16
        clc                                   ; nothing should ever set the carry in this loop

        unroll  0
        unroll  1
        unroll  2
        unroll  3


        sa8
        stz     hdma_table + 5 + 164 * 5             ; flag end of dma table

        ;; restore direct page and bank registers

        lda     #$80
        pha
        plb

        ldx     #$00
        phx
        pld

        rts


        .segment "code2"


        .macro get_data_address

        sa16

        lda     3, s
        tax
        clc
        adc     #80
        sta     3, s

        sa8

        .endmacro


        .macro unroll_noclip_8bits offset

        lda     #$1
        sta     reg_wmdata_direct

        tya

        adc     a:$0 + frame::data + offset, x
        sta     reg_wmdata_direct

        adc     a:$1 + frame::data + offset, x
        sta     reg_wmdata_direct

        adc     a:$2 + frame::data + offset, x
        sta     reg_wmdata_direct

        adc     a:$3 + frame::data + offset, x
        sta     reg_wmdata_direct

        .endmacro


        .macro unroll_rightclip_8bits offset
        .scope

        lda     #$1
        sta     reg_wmdata_direct

        tya                                   ; a = scrolling coordinate
        clc

        adc     a:$0 + frame::data + offset, x
        sta     reg_wmdata_direct

        adc     a:$1 + frame::data + offset, x
        sta     reg_wmdata_direct

        adc     a:$2 + frame::data + offset, x
        bcs     _clip2
        sta     reg_wmdata_direct

        adc     a:$3 + frame::data + offset, x
        bcs     _clip1
        sta     reg_wmdata_direct

        bra     _end

_clip2: 
        lda     #$ff
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        bra     _end

_clip1: 
        lda     #$ff
        sta     reg_wmdata_direct

_end:   
        .endscope
        .endmacro


        .macro unroll_clip_8bits offset
        .scope

        lda     #$1
        sta     reg_wmdata_direct

        tya                                   ; a = scrolling coordinate
        clc

        adc     a:$0 + frame::data + offset, x
        bcs     _clip4
        sta     reg_wmdata_direct

        adc     a:$1 + frame::data + offset, x
        bcs     _clip3
        sta     reg_wmdata_direct

        adc     a:$2 + frame::data + offset, x
        bcs     _clip2
        sta     reg_wmdata_direct

        adc     a:$3 + frame::data + offset, x
        bcs     _clip1
        sta     reg_wmdata_direct

        bra     _end

_clip4: 
        lda     #$ff
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        bra     _end

_clip3: 
        lda     #$ff
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        bra     _end

_clip2: 
        lda     #$ff
        sta     reg_wmdata_direct
        sta     reg_wmdata_direct
        bra     _end

_clip1: 
        lda     #$ff
        sta     reg_wmdata_direct

_end:   
        .endscope
        .endmacro


        .macro scanline_group
        .scope

        tya                                   ; a = scrolling coordinate
        clc
        adc     a:$0 + frame::bounds_table_right, x
        bcs     _clip

        tya
        adc     a:$0 + frame::bounds_table_left, x
        bcc     :+
        jmp     _rightclip
        :
        jmp     _noclip

_clip:  
        phx
        get_data_address

        clc

        unroll_clip_8bits 0
        unroll_clip_8bits 5
        unroll_clip_8bits 10
        unroll_clip_8bits 15
        unroll_clip_8bits 20
        unroll_clip_8bits 25
        unroll_clip_8bits 30
        unroll_clip_8bits 35
        unroll_clip_8bits 40
        unroll_clip_8bits 45
        unroll_clip_8bits 50
        unroll_clip_8bits 55
        unroll_clip_8bits 60
        unroll_clip_8bits 65
        unroll_clip_8bits 70
        unroll_clip_8bits 75

        plx
        jmp     _group_end

_rightclip:
        phx
        get_data_address

        unroll_rightclip_8bits 0
        unroll_rightclip_8bits 5
        unroll_rightclip_8bits 10
        unroll_rightclip_8bits 15
        unroll_rightclip_8bits 20
        unroll_rightclip_8bits 25
        unroll_rightclip_8bits 30
        unroll_rightclip_8bits 35
        unroll_rightclip_8bits 40
        unroll_rightclip_8bits 45
        unroll_rightclip_8bits 50
        unroll_rightclip_8bits 55
        unroll_rightclip_8bits 60
        unroll_rightclip_8bits 65
        unroll_rightclip_8bits 70
        unroll_rightclip_8bits 75

_noclip:
        phx
        get_data_address

        unroll_noclip_8bits 0
        unroll_noclip_8bits 5
        unroll_noclip_8bits 10
        unroll_noclip_8bits 15
        unroll_noclip_8bits 20
        unroll_noclip_8bits 25
        unroll_noclip_8bits 30
        unroll_noclip_8bits 35
        unroll_noclip_8bits 40
        unroll_noclip_8bits 45
        unroll_noclip_8bits 50
        unroll_noclip_8bits 55
        unroll_noclip_8bits 60
        unroll_noclip_8bits 65
        unroll_noclip_8bits 70
        unroll_noclip_8bits 75

        plx

_group_end:
        inx
        .endscope
        .endmacro

window_hdma_update_8bits:

        ;; setup scrolling

        ldy     frame_counter


        ;; point wmdata into the hdma table

        ldx     #.loword(hdma_table)
        stx     reg_wmadd

        lda     #^hdma_table
        sta     reg_wmadd + $2


        ;; setup direct page and bank registers for faster reads / writes

        lda     #^data_noname_window
        pha
        plb

        ldx     #.loword(reg_wmadd) & $ff00
        phx
        pld

        ldx     #.loword(data_noname_window)
        phx                                   ; keep a copy of x on the stack for inner loop

        ;; no windowing above sprite

        lda     a:data_noname_window
        sta     reg_wmdata_direct

        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct


        ;; main loop

_loop:  
        scanline_group
        scanline_group
        scanline_group
        scanline_group
        scanline_group

        cpx     #.loword(data_noname_window) + 160 / bounds_group_size
        bpl     :+
        jmp     _loop
        :

        plx

        ;; no windowing below sprite

        lda     #$1
        sta     reg_wmdata_direct

        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct

        ;; end of table

        stz     reg_wmdata_direct



        ;; restore direct page and bank registers

        lda     #$80
        pha
        plb

        ldx     #$00
        phx
        pld

        rtl



