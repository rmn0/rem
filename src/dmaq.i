        
        .struct dmaq_entry
        dst_address .res 2
        length      .res 2
        src_address .res 2
        src_bank    .res 1
        .endstruct

        ;; returns current queue entry address in x and increments queue length
        ;; .a16 mode expected

        .macro dmaq_insert queue
        .a16
        lda     dmaq_length + queue * 2
        tax
        inx
        inx
        stx     dmaq_length + queue * 2
        asl
        asl
        tax
        .endmacro