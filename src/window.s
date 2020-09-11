
        ;; window.s

        ;; window animations

        .include "rem.i"


        .define bounds_group_size $8

        .struct frame
        top                     .res $2
        height                  .res $2
        left                    .res $2
        right                   .res $2
        data                    .res $1       ;variable length
        .endstruct

        .struct span_group
        bounds                  .res 4
        spans                   .res $4 * bounds_group_size
        .endstruct

        .export window_hdma_setup, window_hdma_update


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


        .segment "code2"



        .macro  index
        lda     #$1
        sta     reg_wmdata_direct
        .endmacro

        .macro  noclip xx
        tya
        adc     a:xx + frame::data + span_group::spans, x
        sta     reg_wmdata_direct
        adc     a:xx + frame::data + span_group::spans + 1, x
        sta     reg_wmdata_direct
        .endmacro

        .macro  clip
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        .endmacro


        ;;
        ;; no-clipping macros for different situations
        ;; 

        .macro noclip_both offset

        index

        noclip  $0 + offset
        noclip  $2 + offset

        .endmacro



        .macro noclip_one offset

        index

        noclip  $0 + offset
        clip

        .endmacro



        ;;
        ;; clipping macros for different situations
        ;; 



        .macro clip_always offset

        index

        clip
        clip

        .endmacro



        .macro clip_right offset
        .scope

        index

        noclip  $0 + offset

        tya

        adc     a:$2 + frame::data + span_group::spans + offset, x
        bcc     :+
        clip
        clc
        bra     _end        
        :
        sta     reg_wmdata_direct

        adc     a:$3 + frame::data + span_group::spans + offset, x
        bcc     :+
        lda     #$ff
        clc
        :
        sta     reg_wmdata_direct

_end:   
        .endscope
        .endmacro



        .macro clip_one offset
        .scope

        index

        clip

        tya                                   ; a = scrolling coordinate

        adc     a:$0 + frame::data + span_group::spans + offset, x
        bcc     :+
        clip
        clc
        bra     _end
        :
        sta     reg_wmdata_direct

        adc     a:$1 + frame::data + span_group::spans + offset, x
        bcc     :+
        lda     #$ff
        clc
        :
        sta     reg_wmdata_direct

_end:   
        .endscope
        .endmacro


        .macro clip_both_2 offset                       
        .scope

        index

        tya

        adc     a:$2 + frame::data + span_group::spans + offset, x
        bcs     _clip_right

_noclip_right:  

        sta     reg_wmdata_direct

        adc     a:$3 + frame::data + span_group::spans + offset, x
        bcc     :+
        lda     #$ff
        clc
        :
        sta     reg_wmdata_direct

        noclip  $0 + offset

        bra     _end

_clip_right:

        clip

        tya
        clc

        adc     a:$0 + frame::data + span_group::spans + offset, x
        bcc     :+
        clip
        clc
        bra     _end
        :

        sta     reg_wmdata_direct

        adc     a:$1 + frame::data + span_group::spans + offset, x
        bcc     :+
        lda     #$ff
        clc
        :
        sta     reg_wmdata_direct

_end:   
        .endscope
        .endmacro


        .macro clip_both offset                       
        .scope

        index

        tya
        clc

        adc     a:$0 + frame::data + span_group::spans + offset, x
        bcs     _clip4
        sta     reg_wmdata_direct

        adc     a:$1 + frame::data + span_group::spans + offset, x
        bcs     _clip3
        sta     reg_wmdata_direct

        tya

        adc     a:$2 + frame::data + span_group::spans + offset, x
        bcs     _clip2
        sta     reg_wmdata_direct

        adc     a:$3 + frame::data + span_group::spans + offset, x
        bcs     _clip1
        sta     reg_wmdata_direct

        bra     _end

_clip4:
        clip
_clip2:
        clip
        bra     _end

_clip3: 
        lda     #$ff
        sta     reg_wmdata_direct
        clip
        bra     _end

_clip1: 
        lda     #$ff
        sta     reg_wmdata_direct

_end:   
        .endscope
        .endmacro



        ;;
        ;; loop unrolling
        ;;



        .macro unroll mm, unroll_ofs

        mm      $0 + unroll_ofs
        mm      $4 + unroll_ofs
        mm      $8 + unroll_ofs
        mm      $c + unroll_ofs
        mm      $10 + unroll_ofs
        mm      $14 + unroll_ofs
        mm      $18 + unroll_ofs
        mm      $1c + unroll_ofs
        ;; mm      $20 + unroll_ofs
        ;; mm      $24 + unroll_ofs
        ;; mm      $28 + unroll_ofs
        ;; mm      $2c + unroll_ofs
        ;; mm      $30 + unroll_ofs
        ;; mm      $34 + unroll_ofs
        ;; mm      $38 + unroll_ofs
        ;; mm      $3c + unroll_ofs

        .endmacro



        ;;
        ;; scanline group no-clipping macros
        ;;



        .macro scanline_group_noclip group_ofs
        .scope

        lda     a:$2 + frame::data + span_group::bounds + group_ofs, x
        cmp     #$ff
        beq     :+
        jmp     _noclip_both
        :

        unroll  noclip_one, group_ofs
        jmp     _group_end

_noclip_both:
        unroll  noclip_both, group_ofs

_group_end:   
        .endscope
        .endmacro



        ;;
        ;; scaline group clipping macros
        ;;



        .macro scanline_group group_ofs
        .scope

        clc

        tya                                   
        adc     a:$0 + frame::data + span_group::bounds + group_ofs, x
        bcc     :+
        ;; this group is completely outside the screen
        clc
        jmp     _clip_always
        :

        tya
        adc     a:$2 + frame::data + span_group::bounds + group_ofs, x
        bcc     :+
        ;; all the right spans in this group are completely outside the screen
        ;; or the group only has the left spans
        clc
        jmp     _test_left
        :

        tya
        adc     a:$1 + frame::data + span_group::bounds + group_ofs, x
        bcs     :+
        ;; all the left spans in this group are completely inside the screen
        jmp     _test_right
        :
        clc

        tya
        adc     a:$3 + frame::data + span_group::bounds + group_ofs, x
        bcc     :+
        ;; we do not know whether any of the left or right spans will clip
        clc
        jmp     _clip_both
        :

        ;; all spans in this group are completely inside the screen
        jmp     _noclip_both

_test_right:
        tya
        adc     a:$3 + frame::data + span_group::bounds + group_ofs, x
        bcc     :+
        ;; we do not know whether any of the right spans will clip
        ;; but the left spans are completely inside the screen
        clc
        jmp     _clip_right
        :

        ;; all spans in this group are completely inside the screen
        jmp     _noclip_both


_test_left:      
        tya
        adc     a:$1 + frame::data + span_group::bounds + group_ofs, x
        bcc     :+
        ;; this group only has the left spans and we do not know if they clip
        jmp     _clip_one
        :

        ;; this group only has the left span and is completely inside the screen

_noclip_one:    
        unroll  noclip_one, group_ofs
        jmp     _group_end
        
_clip_one:      
        unroll  clip_one, group_ofs
        jmp     _group_end

_clip_right:    
        unroll  clip_right, group_ofs
        jmp     _group_end

_clip_always:
        unroll  clip_always, group_ofs
        jmp     _group_end

_clip_both:
        unroll  clip_both, group_ofs
        jmp     _group_end

_noclip_both:
        unroll  noclip_both, group_ofs


_group_end:
        .endscope
        .endmacro




window_hdma_update:

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

        ;; no windowing above sprite

        lda     a:data_noname_window
        sta     reg_wmdata_direct

        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct
        stz     reg_wmdata_direct

        tya
        clc
        adc     a:$0 + frame::right, x
        bcc     _loop_noclip
        jmp     _loop_clip


_loop_noclip:
        scanline_group_noclip 0 * .sizeof(span_group)
        scanline_group_noclip 1 * .sizeof(span_group)

        sa16
        txa
        clc
        adc     #2 * .sizeof(span_group)
        tax
        sa8

        cpx     #.loword(data_noname_window) + 20 * .sizeof(span_group)
        bpl     :+
        jmp     _loop_noclip
        :

        jmp     _end

        ;; main loop

_loop_clip:
        scanline_group 0 * .sizeof(span_group)
        scanline_group 1 * .sizeof(span_group)

        sa16
        txa
        clc
        adc     #2 * .sizeof(span_group)
        tax
        sa8

        cpx     #.loword(data_noname_window) + 20 * .sizeof(span_group)
        bpl     :+
        jmp     _loop_clip
        :

_end:

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



