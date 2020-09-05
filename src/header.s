

        ;; header.s

        ;; rom header


        .segment "header"

        .include "header.i"

        .import start_
        .import nmi_

        ;; header

        .byte "DD"                      ; maker code
        .byte "DEAD"                    ; game code
        .byte $0, $0, $0, $0, $0, $0, $0  ; reserved
        .byte xram_none                 ; expansion ram size
        .byte $00                       ; special version
        .byte $00                       ; cartridge sub-number
        .byte "DEADER DEADER DEADER "   ; game title
        .byte mode_21_fast              ; map mode
        .byte cart_rom                  ; cartridge type
        .byte $00                       ; rom size placeholder
        .byte xram_none                 ; ram size
        .byte dest_german               ; destination code
        .byte $33                       ; extended header
        .byte $00                       ; mask rom version
        .word $0000                     ; check sum complement placeholder
        .word $0000                     ; check sum placeholder

        ;; native mode vectors

        .word $0                         ; -
        .word $0                         ; -
        .word $0                         ; -
        .word $0                         ; brk
        .word $0                         ; abort
        .word nmi_                      ; nmi
        .word $0                         ; reset
        .word $0                         ; irq

        ;; emulation mode vectors

        .word $0                         ; -
        .word $0                         ; -
        .word $0                         ; cop
        .word $0                         ; -
        .word $0                         ; abort
        .word $0                         ; nmi
        .word start_                    ; res
        .word $0                         ; irq/brk
