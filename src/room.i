
        
        ;; room.i

        ;; room data layout


        .struct room_entry
        data_addr       .res 2
        data_bank       .res 2
        .endstruct

        .struct room_info_entry
        tileset         .res 4
        portal_type     .res 1
        portal_ll       .res 1
        portal_rr       .res 1
        portal_tt       .res 1
        portal_bb       .res 1
        portal_xx       .res 2
        portal_yy       .res 2
        flags           .res 1
        key             .res 1
        lock            .res 1
        lock_entry      .res 1
        key_xx          .res 1
        key_yy          .res 1
                        .res $d
        .endstruct

        .scope room_info_flag_bit
barrier_ll = $1
barrier_rr = $2
barrier_tt = $4
barrier_bb = $8
        .endscope

        .struct room_data
        bg1             .word $400
        bg2             .word $400
        vis             .byte $400
        collision       .byte $400
        .endstruct