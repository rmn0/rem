
        ;; macro.i

        ;; macros for general use


        .macro sa16
        .a16
        rep     #$20
        .endmacro

        .macro sa8
        .a8
        sep     #$20
        .endmacro

        .macro mov to, from
        .if .xmatch(from, #$00)
        stz to
        .else
        lda from
        sta to
        .endif
        .endmacro

        .macro mov2 to, from
        .if .xmatch(from, #$0000)
        stz to
        stz to + 1
        .else
        ldx from
        stx to
        .endif
        .endmacro

        .macro mov3 to, froml, fromh
        mov2 to, froml
        mov to + 2, fromh
        .endmacro

        .macro stzd addr
        stz addr
        stz addr
        .endmacro

        .macro cmp2 aa, bb
        ldx aa
        cpx bb
        .endmacro

        .macro clear from, to
        ldx from
        :
        stz 0, x
        inx
        cpx to
        bne :-
        .endmacro

	.macro cleard from, to
        ldx from
        :
        stz 0, x
        stz 0, x
        inx
        cpx to
        bne :-
        .endmacro

        .macro dma_control channel, word
	mov2    reg_dmapx + (channel << 4), word
        .endmacro

        .macro dma_source_addr channel, lo, hi
       	mov3    reg_a1tx + (channel << 4), lo, hi
        .endmacro

        .macro dma_length channel, bytes
     	mov2    reg_dasx + (channel << 4), bytes
        .endmacro

        .macro dma_enable channel
     	mov     reg_mdmaen, channel
        .endmacro

        .macro dma_wram_memset channel, addressl, addressh, length, byte
   	mov3            reg_wmadd, addressl, addressh
	dma_control     channel, #$8008
        dma_source_addr channel, #.loword(byte), #^byte
        dma_length      channel, length
        dma_enable      #(1 << channel)
        .endmacro

        .macro dma_wram_memclear channel, addressl, addressh, length
   	mov3            reg_wmadd, addressl, addressh
	dma_control     channel, #$8008
        dma_source_addr channel, #.loword(zerobyte), #^zerobyte
        dma_length      channel, length
        dma_enable      #(1 << channel)
        .endmacro

        .macro dma_vram_memset2 channel, address, data, length
        mov2            $00, data
     	mov             reg_vmainc, #$80
        mov2            reg_vmadd, address
        dma_control     channel, #$1809
        dma_source_addr channel, #$0000, #$00
        dma_length      channel, length
        dma_enable      #(1 << channel)
        .endmacro

        .macro dma_vram_memseth channel, address, data, length
	mov             $00, data
	mov             reg_vmainc, #$80
	mov2            reg_vmadd, address
	dma_control     channel, #$1908
	dma_source_addr channel, #$0000, #$00
	dma_length      channel, length
	dma_enable      #(1 << channel)
	.endmacro

        .macro dma_wram_memcpy channel, addressl, addressh, sourcel, sourceh, length
        mov3            reg_wmadd, addressl, addressh
        dma_control     channel, #$8000
        dma_source_addr channel, sourcel, sourceh
        dma_length      channel, length
        dma_enable      #(1 << channel)
        .endmacro

        .macro dma_vram_memcpy2 channel, address, sourcel, sourceh, length
        mov             reg_vmainc, #$80
        mov2            reg_vmadd, address
        dma_control     channel, #$1801
        dma_source_addr channel, sourcel, sourceh
        dma_length      channel, length
        dma_enable      #(1 << channel)
        .endmacro

	.macro dma_vram_memcpyl channel, address, sourcel, sourceh, length
	stz             reg_vmainc
        mov2            reg_vmadd, address
	dma_control     channel, #$1800
	dma_source_addr channel, sourcel, sourceh
	dma_length      channel, length
	dma_enable      #(1 << channel)
	.endmacro

        .macro dma_cgram_memcpy channel, address, sourceh, sourcel, length
        mov             reg_cgadd, address
        dma_control     channel, #$2202
        dma_source_addr channel, sourceh, sourcel
        dma_length      channel, length
        dma_enable      #(1 << channel)
        .endmacro


        .macro mul aa, bb
        .if .xmatch({aa},{a})
        sta     reg_wrmpya
        .else
        mov     reg_wrmpya, aa
        .endif
        mov     reg_wrmpyb, bb
        .endmacro

