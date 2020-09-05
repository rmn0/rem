

        ;; init.s

        ;; boot loader


        .import __hdata_load__
        .import __hdata_run__
        .import __hdata_size__

	.include "rem.i"

        .segment "code"

        .global start_
        .import main

start_:

	sei			; disable interrupts

        clc			; switch to native mode
	xce

        .a16
	rep	#$38		; a16i16, decimal mode off

	ldx	#$1fff		; set stack pointer
	txs

	lda	#$0000		; set direct page
	tcd

        .a8
	sep	#$20		; a8i16

        lda	#$80            ; set data bank
	pha
	plb

	jml	$c00000 + histart_

histart_:

        mov     reg_memsel, #$1         ; hi-speed mode
        mov     reg_inidisp, #$8f       ; enter forced blank

        ;; initialize ppu registers

        clear   #reg_objsel, #reg_bgxhofs
        cleard  #reg_bgxhofs, #reg_vmainc
        mov     reg_vmainc, #$80
        mov2    reg_vmadd, #$0000
        stz     reg_m7sel
        cleard  #reg_m7a, #(reg_m7y + $1)
        clear   #reg_w12sel, #reg_mpy
        stz     reg_stat77

        ;; initialize dma registers

        stz     reg_nmitimen
        mov     reg_wrio, $ff
        stz     reg_mdmaen
        stz     reg_hdmaen

        ;; clear vram

        dma_vram_memset2 $00, #$0000, #$0000, #$0000
        stz     reg_vmdata + $1  ; clear last byte

        ;; clear palette

        stz     reg_cgadd
        ldx     #$100
        :
        stzd    $2122
        dex
        bne     :-

        ;; initialize oam

        mov2    reg_oamadd, #$0000
        ldx     #$0080
        lda     #$f0
        :
        sta     reg_oamdata
        sta     reg_oamdata
        stzd    reg_oamdata
        dex
        bne     :-

        ldx     #$0020
        :
        stz     reg_oamdata
        dex
        bne     :-

        ;; erase wram

	dma_wram_memclear $00, #$0000, #$00, #$0000 	; clear low 64k
        dma_enable        #$0                           ; clear high 64k

        ;; load data segment
        dma_wram_memcpy $00, #.loword(__hdata_RUN__), #^__hdata_RUN__, #.loword(__hdata_LOAD__), #^__hdata_LOAD__, #__hdata_SIZE__

        jmp main
