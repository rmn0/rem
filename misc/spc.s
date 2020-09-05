
        .include "lib.i"

spc_ptr                 = $00
spc_sourcelist_ptr      = $03
spc_ptr_copy            = $06
spc_v                   = $09
spc_bank                = $0a


        .segment "code"

        .global spc_upload
        .global spc_set_bank
        .global spc_upload_module
        .global spc_play

spc_driver_start:
        .incbin "../res/driver.spc"
spc_driver_end:

        .macro spc_wait
      	:
        cmp     reg_apuiox + 0
        bne :-
        .endmacro

        counter = $00

spc_upload:

        ;; wait for ready signal

        :
        cmp2    reg_apuiox + 0, #$bbaa
        bne :-

        ;; init transfer

        stx     reg_apuiox + 1
        mov2    reg_apuiox + 2, #$0400 ; transfer address
        mov     reg_apuiox + 0, #$cc

        spc_wait

        ;; transfer

        ldx     #$0000

_transfer:

        txa
        sta     reg_apuiox + 0
        mov     reg_apuiox + 1, {spc_driver_start, x}

        txa
        spc_wait

        inx
        cpx     #(spc_driver_end - spc_driver_start)
        bne     _transfer

        inx
        inx

        stz     reg_apuiox + 1
        mov2    reg_apuiox + 2, #$0400 ; entry point
        txa
        sta     reg_apuiox + 0

        spc_wait

        stz     spc_v

        rts



        .macro spc_wait_vv byte
        .ifnblank byte
        lda     byte
	sta     reg_apuiox + 1
	sta     spc_v
        .else
        lda     spc_v
        .endif
        :
        cmp     reg_apuiox + 1
        bne     :-
        .endmacro



        ;; a : bank

spc_set_bank:

        sta     spc_bank
        rts



        ;; a : index

spc_upload_module:

        soundbank_samplecount   = $0
        soundbank_modcount      = $2
        soundbank_modtable      = $4
        soundbank_sourcetable   = $184

        ldx     #soundbank_modtable
        jsr     get_address

        .a16
        rep     #$20

        lda     [spc_ptr]       ; x = module size
        tax

        ldy     #2
        lda     [spc_ptr], y    ; a = source list size

        pha

        asl
        adc     #4
        tay                     ; [spc_ptr], y = module data start

        .a8
        sep     #$20

        spc_wait_vv

        stz     reg_apuiox + 0  ; send load module message

        jsr     transfer

        mov3    spc_sourcelist_ptr, spc_ptr, spc_ptr + 2
        plx
        ldy     #4

_source_loop:
        phx                     ; x = remaining sources
        phy                     ; y = source list index

        lda     [spc_sourcelist_ptr], y         ; a = source index
        ldx     #soundbank_sourcetable
        jsr     get_address

        mov     reg_apuiox + 0, #1              ; send load source

        .a16
        rep     #$20

        lda     [spc_ptr]
        ina
        lsr
        tax                     	        ; x = source size

        ldy     #2
        lda     [spc_ptr], y
        sta     reg_apuiox + 2

        .a8
        sep     #$20

        ldy     #4
        jsr     transfer

        ply
        plx

        iny
        iny
        dex

        bne     _source_loop

        stz     reg_apuiox + 0   ; end transfer

        spc_wait_vv #$20

        rts



        ;; [spc_ptr], y : data pointer
        ;; x : data length

transfer:
        lda     spc_v
        eor     #$80
        ora     #$1

_transfer_loop:
     	sta     reg_apuiox + 1
        sta     spc_v

        spc_wait_vv

        mov     reg_apuiox + 2, {[spc_ptr], y}
        iny

     	mov     reg_apuiox + 3, {[spc_ptr], y}
	iny

     	lda     spc_v
        eor     #$80

        dex
        bne     _transfer_loop

        stz     reg_apuiox + 1
        stz     spc_v

        spc_wait_vv

        rts



        ;; a : index
        ;; x : table (soundbank_modtable or soundbank_sourcetable)
        ;;
        ;; returns spc_ptr : address

get_address:

        mul     a, #3

        stx     spc_ptr_copy
        mov     spc_ptr_copy + 2, spc_bank

        ldy     reg_rdmpy

        mov     spc_ptr, {[spc_ptr_copy], y}
        iny
        mov     spc_ptr + 1, {[spc_ptr_copy], y}
        iny

        clc
        lda     [spc_ptr_copy], y
        adc     spc_bank
        sta     spc_ptr + 2

        rts



spc_play:

        ;; mov     reg_apuiox + 0, #2
	;; mov     reg_apuiox + 2, #$7f

        ;; spc_wait_vv #$84

     	;; mov     reg_apuiox + 0, #5
	;; mov     reg_apuiox + 2, #$7f

        ;; spc_wait_vv #$86

        mov     reg_apuiox + 0, #3
        stz     reg_apuiox + 3

        spc_wait_vv #$82



        rts
