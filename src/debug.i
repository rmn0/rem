
        ;; read the scanline counter into xx

        .macro read_vcounter xx

        lda     reg_stat78
        lda     reg_slhv
        lda     reg_opvct
        xba
        lda     reg_opvct
        and     #$1
        xba
        tax
        stx     xx

        .endmacro


        .macro read_vcounter_far

        lda     f:reg_stat78
        lda     f:reg_slhv
        lda     f:reg_opvct
        xba
        lda     f:reg_opvct
        and     #$1
        xba

        .endmacro

