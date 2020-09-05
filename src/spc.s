

        ;; spc.s

        ;; cpu-side sound code


        .include "rem.i"

spc_ptr                 = $00
spc_sourcelist_ptr      = $03
spc_ptr_copy            = $06
;; spc_v                   = $09
spc_bank                = $0a

        .segment "bss"

spc_v:
        .res 1


        .segment "code"

        .export spc_upload, spc_set_bank, spc_upload_module, spc_play, spc_stop, spc_fade, spc_reset
        .export spc_play_sample

spc_driver_start:
        .incbin "../res/driver.spc"
spc_driver_end:

        .macro spc_wait
      	:
        cmp     reg_apuiox + $0
        bne :-
        .endmacro

        counter = $00

spc_upload:

        ;; wait for ready signal

        :
        cmp2    reg_apuiox + $0, #$bbaa
        bne :-

        ;; init transfer

        stx     reg_apuiox + $1
        mov2    reg_apuiox + $2, #$0400 ; transfer address
        mov     reg_apuiox + $0, #$cc

        spc_wait

        ;; transfer

        ldx     #$0000

_transfer:

        txa
        sta     reg_apuiox + $0
        mov     reg_apuiox + $1, {spc_driver_start, x}

        txa
        spc_wait

        inx
        cpx     #(spc_driver_end - spc_driver_start)
        bne     _transfer

        inx
        inx

        stz     reg_apuiox + $1
        mov2    reg_apuiox + $2, #$0400 ; entry point
        txa
        sta     reg_apuiox + $0

        spc_wait

        stz     spc_v

        rts



        .macro spc_wait_vv byte
        .ifnblank byte
        lda     byte
	sta     reg_apuiox + $1
	sta     spc_v
        .else
        lda     spc_v
        .endif
        :
        cmp     reg_apuiox + $1
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

        sa16

        lda     [spc_ptr]       ; x = module size
        tax

        ldy     #$2
        lda     [spc_ptr], y    ; a = source list size

        pha

        asl
        adc     #$4
        tay                     ; [spc_ptr], y = module data start

        sa8

        ;; spc_wait_vv #$2c

        stz     reg_apuiox + $0  ; send load module message

        jsr     transfer

        mov3    spc_sourcelist_ptr, spc_ptr, spc_ptr + $2
        plx
        ldy     #$4

_source_loop:
        phx                     ; x = remaining sources
        phy                     ; y = source list index

        lda     [spc_sourcelist_ptr], y         ; a = source index
        ldx     #soundbank_sourcetable
        jsr     get_address

        lda     #$1
        sta     reg_apuiox + $0                 ; send load source

        sa16

        lda     [spc_ptr]
        ina
        lsr
        tax                     	        ; x = source size

        ldy     #$2
        lda     [spc_ptr], y
        sta     reg_apuiox + $2

        sa8

        ldy     #$4
        jsr     transfer

        ply
        plx

        iny
        iny
        dex

        bne     _source_loop

        stz     reg_apuiox + $0   ; end transfer

        spc_wait_vv #$21

        rts



        ;; [spc_ptr], y : data pointer
        ;; x : data length

transfer:
        lda     spc_v
        eor     #$80
        ora     #$1
        sta     spc_v

        cpx     #$0
        bne     _transfer_loop

        ;; driver expects one word to be transfered even there is no data

     	sta     reg_apuiox + $1
        sta     spc_v

        spc_wait_vv

        bra     _transfer_end


_transfer_loop:
     	sta     reg_apuiox + $1

        spc_wait_vv

        mov     reg_apuiox + $2, {[spc_ptr], y}
        iny

     	mov     reg_apuiox + $3, {[spc_ptr], y}
	iny

     	lda     spc_v
        eor     #$80
        sta     spc_v

        dex
        bne     _transfer_loop

_transfer_end:  
        spc_wait_vv #$00

        rts



        ;; a : index
        ;; x : table (soundbank_modtable or soundbank_sourcetable)
        ;;
        ;; returns spc_ptr : address

get_address:

        mul     a, #$3

        stx     spc_ptr_copy
        mov     spc_ptr_copy + $2, spc_bank

        ldy     reg_rdmpy

        mov     spc_ptr, {[spc_ptr_copy], y}
        iny
        mov     spc_ptr + $1, {[spc_ptr_copy], y}
        iny

        clc
        lda     [spc_ptr_copy], y
        adc     spc_bank
        sta     spc_ptr + $2

        rts


spc_stop:
        mov     reg_apuiox + $0, #$4

        spc_wait_vv #$86

        rts


spc_reset:
        ;; set master volume

        mov     reg_apuiox + 0, #$2
	mov     reg_apuiox + 2, #$00

        spc_wait_vv #$22
        
        rts

        ;; play module

spc_play:

        ;; set master volume

        mov     reg_apuiox + 0, #$2
	mov     reg_apuiox + 2, #$7f
        
        spc_wait_vv #$22

        ;; set module volume

     	mov     reg_apuiox + 0, #$5
        mov     reg_apuiox + 3, #$00

        spc_wait_vv #$24

        ;; play module

        mov     reg_apuiox + $0, #$3
        stz     reg_apuiox + $3

        spc_wait_vv #$26

        ;; fade in

        mov     reg_apuiox + $0, #$6
        mov     reg_apuiox + $2, #$1
        mov     reg_apuiox + $3, #$ff
        spc_wait_vv #$28

        rts


        ;; fade out module

spc_fade:
        mov     reg_apuiox + $0, #$6
        mov     reg_apuiox + $2, #$10
        stz     reg_apuiox + $3
        spc_wait_vv #$2a

        rts


        ;; play sample

        ;; x : sssshhhhvvvvpppp
        ;;     s = sample
        ;;     h = pitch
        ;;     v = volume
        ;;     p = panning

spc_play_sample:        
        lda     spc_v
        eor     #$40
        ora     #$4
        sta     spc_v
        sta     reg_apuiox + $1

        mov     reg_apuiox + $0, #$8
        stx     reg_apuiox + $2

        ;; spc_wait_vv

        rts
