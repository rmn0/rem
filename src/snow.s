

        ;; snow.s

        ;; pseudo-3d snow effect


        .include "rem.i"

        .export snow_init, snow_init_2, snow_update, snow_clear

        .struct flake
        posxx   .word
        velxx   .word
        posyy   .word
        velyy   .word
        poszz   .word
        velzz   .word
        .endstruct


        ;; zero page

scroll_xx_88 = $0
scroll_yy_88 = $2
poszz_copy = $4



        .segment "bss"

rng_state:
        .res    4


        .define nflakes $40
        .define nflakes_2 $10

flake_table_size:       .res 2
flake_acceleration:     .res 2

flakes:
        .res    .sizeof(flake) * nflakes


        .segment "code"


        ;; init random number generator
        ;; 24-bit seed shoud be in a16:x8

        .macro  rng_init

        eor     rng_state + $0
        xba
        eor     rng_state + $1
        txa
        eor     rng_state + $2

        rng

        .endmacro


        ;; get random byte in accumulator

        .macro  rng

        lda     rng_state + $3
        inc
        sta     rng_state + $3

        eor     rng_state + $0
        eor     rng_state + $2
        sta     rng_state + $0

        eor     rng_state + $1
        sta     rng_state + $0

        lsr
        eor     rng_state + $0
        clc
        adc     rng_state + $2
        sta     rng_state + $2

        .endmacro


        .macro flake_update pos, vel, acc

        ;; brownian motion

        sa8
        rng
        sa16
        and     #$3f
        sec
        sbc     #$20
        clc
        adc     flakes + flake::vel, x
        tay

        ;; friction

        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror

        sta     flakes + flake::vel, x
        tya
        sec
        sbc     flakes + flake::vel, x

        .ifnblank acc
        clc
        adc     flake_acceleration
        .endif

        sta     flakes + flake::vel, x

        ;; velocity to position

        clc
        adc     flakes + flake::pos, x
        sta     flakes + flake::pos, x

        .endmacro


        ;; perspective divide

        .macro flake_divide pos, scroll
        lda     flakes + flake::pos, x
        sec
        sbc     scroll
        sta     reg_wrdiv

        sa8
        lda     poszz_copy + $1
        sta     reg_wrdivb
        sa16
        .endmacro


        ;; clear snow sprites

snow_clear:
        sa16

        lda     #$e0e0
        ldx     #oam::snow

        :
        sta     f:oam_mirror, x
        inx
        inx
        cpx     #oam::snow + $4 * nflakes
        bne     :-

        sa8
        rts


        ;; initialize snow

snow_init:

        ;; random seed

        lda     #$12
        xba
        lda     #$34
        ldx     #$56

        rng_init

        ;; set flake start position

        ldx     #$0

        :
        rng
        sta     flakes, x
        inx
        rng
        sta     flakes, x
        inx
        inx
        inx

        cpx     #.sizeof(flake) * nflakes
        bne     :-

        stx     flake_table_size

        ldx     #$2
        stx     flake_acceleration

        rts


snow_init_2:

        ldx     #.sizeof(flake) * nflakes_2
        stx     flake_table_size

        ldx     #$0
        stx     flake_acceleration

        rts

        ;; update snow

snow_update:

        lda     scroll_xx
        eor     #$80
        sta     scroll_xx_88 + $1

        lda     scroll_yy
        eor     #$80
        sta     scroll_yy_88 + $1
        
        stz     reg_wmadd + $2

        sa16

        ldx     #$0

        lda     #.loword(oam_mirror) + oam::snow
        sta     reg_wmadd

_loop:  
        lda     flakes + flake::poszz, x
        bmi     :+
        eor     #$ffff
        :
        sta     poszz_copy

        flake_update    posxx, velxx, acc

        flake_divide    posxx, scroll_xx_88

        flake_update    posyy, velyy

        lda     reg_rddiv
        clc
        adc     #$80

        sa8
        sta     reg_wmdata
        sa16

        flake_divide    posyy, scroll_yy_88

        flake_update    poszz, velzz

        lda     reg_rddiv
        clc
        adc     #$80

        sa8
        sta     reg_wmdata

        lda     poszz_copy + $1
        lsr
        lsr
        lsr
        lsr
        and     #$7
        inc

        sta     reg_wmdata

        lda     #$2a
        sta     reg_wmdata

        sa16

        txa
        clc
        adc     #.sizeof(flake)
        tax
        cpx     flake_table_size
        beq     :+
        jmp     _loop
        :

        sa8

        rts






