

        ;; sprite.i

        ;; sprite and sprite animation definitions


        .struct sprite_entry
        index                   .byte           
        frame_counter           .byte   
        xx                      .byte
        yy                      .byte
        oam_attribute_2         .byte
        oam_attribute_3         .byte
        animation_table         .word
        animation_table_bank    .byte
        oam_buffer_address      .word
        oam_buffer_length       .byte
        oam_index               .byte
        vram_address            .word
        flags                   .byte
        .endstruct
        
        .struct ani_frame
        object_pointer       .word
        object_table_length  .word
        data_pointer         .word
        data_bank            .byte
        frame_delay          .byte
        .endstruct

        .scope sprite_entry_flag_bit
stop = $1
update = $2
        .endscope
        
        
