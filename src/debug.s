
        ;; debug.s

        ;; display a small memory viewer for debugging


        .include "rem.i"

        .export debug_mem_addr, debug_init, debug_update, debug_dma, debug_disable_hdma, debug_enable_hdma
        .import debug_frame_sl, debug_vblank_sl
        .import scroll_xx, scroll_yy, debug_view


        .segment "bss"

        ;; pointer to the currently viewed memory location

debug_mem_addr: .res $2
debug_mem_bank: .res $2


        .segment "hdata"

        ;; ram buffer for rendering debug info

rambuffer:
        .res    $40


        .define hdma_end $00

        .define debug_area_height $10

        .define debugtiles_vram_offset $80
        .define debugtiles_vram_addr vram::lighttiles + debugtiles_vram_offset
        .define debugtile_hibyte $6 * $8

        ;; dma tables for switching between the game and debug views

hdma_table_bg2xofs:
        .byte debug_area_height
        .word $0, $ff
        .byte $1
        .word $0, $0
        .byte hdma_end
        
        .segment "rodata"

hdma_table_bg2sc:
        .byte debug_area_height
        .byte ((vram::debugbg / $400) << $2) + $0
        .byte $1
        .byte ((vram::bg2 / $400) << $2) + $0
        .byte hdma_end

;; hdma_table_bg34nba:
;;         .byte debug_area_height
;;         .byte vram::debugtiles / $1000
;;         .byte $1
;;         .byte vram::lighttiles / $1000
;;         .byte hdma_end

hdma_table_tm:
        .byte debug_area_height
        .byte $04
        .byte $1
        .byte setup::mainscreen_bit 
        .byte hdma_end

hdma_table_ts:
        .byte debug_area_height
        .byte $00
        .byte $1
        .byte setup::subscreen_bit
        .byte hdma_end


        ;; table for debug times

divtable:       
        .word $0, $0, $0, $1, $1, $2, $2, $2
        .word $3, $3, $4, $4, $5, $5, $5, $6
        .word $6, $7, $7, $8, $8, $8, $9, $9
        .word $a, $a, $a, $b, $b, $c, $c, $d
        .word $d, $d, $e, $e, $f, $f


        .segment "code"


        ;; intializes debug info

debug_init:

        ;; laod debug tileset

        dma_vram_memcpy2 $00, #debugtiles_vram_addr, #.loword(data_debug), #^data_debug, #$500

        ;; setup debug background

        ldx     #$80
        stx     reg_vmainc

        ldx     #vram::debugbg + $00
        stx     reg_vmadd

        lda     #debugtile_hibyte
        ldx     #$0
        :
        sta     reg_vmdata + $1
        inx
        cpx     #$20
        bne     :-

        ldx     #debugtile_hibyte * $100 + $20 + debugtiles_vram_offset / $8
        :
        stx     reg_vmdata
        inx
        cpx     #debugtile_hibyte * $100 + $40 + debugtiles_vram_offset / $8
        bne     :-

        ;; initialize debug memory pointer

        ldx     #.loword(debug_view)
        stx     debug_mem_addr

        lda     #^debug_view
        sta     debug_mem_addr + $2

        rts


        ;; used to show bytes in hexadecimal representation
        ;; in the debug area

        ;; reg_wmadd : position in ram buffer

        .macro  writebyte byte
        lda     byte
        tax
        lsr
        lsr
        lsr
        lsr

        clc
        adc     #debugtiles_vram_offset / $8

        sta     reg_wmdata

        lda     byte
        and     #$f
        ora     #$10

        clc
        adc     #debugtiles_vram_offset / $8

        sta     reg_wmdata
        .endmacro


        ;; update the debug ram buffer and hdma tables

debug_update:

        ;; setup io port to write into ram buffer

        ldx     #.loword(rambuffer)
        stx     reg_wmadd
        stz     reg_wmadd + $2

        ;; copy debug pointer into zero page

        ldx     debug_mem_addr
        stx     $0
        lda     debug_mem_bank
        sta     $2

        ;; show 12 cpu bus bytes in the debug area

        ldy     #$0

        :
        writebyte {[$0], y}
        iny
        cpy     #$c
        bne     :-

        ;; render indicator for frame time

        sa16

        lda     debug_frame_sl
        cmp     #$e0                          ; = 224
        bpl     :+
        clc
        adc     #$108                         ; = 262
        :
        sec
        sbc     debug_vblank_sl
        lsr
        lsr
        lsr
        lsr
        ora     #$440

        sa8

        clc
        adc     #debugtiles_vram_offset / $8

        sta     reg_wmdata

        ;; render indicator for vblank time

        sa16

        lda     debug_vblank_sl
        cmp     #$e0                          ; = 224
        bmi     :+
        sec
        sbc     #$e0                          ; = 224
        asl
        tax
        lda     f:divtable, x
        bra     :++
        :
        lda     #$f
        :
        ora     #$440

        sa8

        clc
        adc     #debugtiles_vram_offset / $8

        sta     reg_wmdata

        ;; render the memory pointer itself

        writebyte debug_mem_addr
        writebyte debug_mem_addr + $1
        writebyte debug_mem_addr + $2

        ;; initialize the hdma tables

        lda     #$0
        xba

        lda     scroll_xx
        and     #const::pixels_in_tile - $1
        sta     f:hdma_table_bg2xofs + $6

        lda     scroll_yy
        and     #const::pixels_in_tile - $1
        sta     f:hdma_table_bg2xofs + $8

        rts


        ;; copy the ram buffer into vram

debug_dma:
        dma_vram_memcpyl $00, #vram::debugbg, #.loword(rambuffer), #^rambuffer, #$20

        rts


        ;; setup and enable hdma

debug_enable_hdma:

        hdma    $4, #.lobyte(reg_bgxsc + $2) * $100 + $0, hdma_table_bg2sc
        hdma    $5, #.lobyte(reg_tm) * $100 + $0, hdma_table_tm
        hdma    $6, #.lobyte(reg_ts) * $100 + $0, hdma_table_ts
        hdma    $7, #.lobyte(reg_bgxhofs + $2 * $2) * $100 + $3, hdma_table_bg2xofs
        ;; hdma    $5, #.lobyte(reg_bg34nba) * $100 + $0, hdma_table_bg34nba

        lda     #$f0
        sta     reg_hdmaen

        rts


        ;; disable hdma

debug_disable_hdma:

        stz     reg_hdmaen

        ;; restore hdma settings

        jsr     window_hdma_setup

        rts









