
        ;; map.i

        ;; vram memory layout (word addresses)


        .struct vram

        ;; 0k

        tileset0        .res $1000
        tileset1        .res $1000

        ;; 8k

        tileset2        .res $1000
        tileset3        .res $1000

        ;; 16k

        bg0             .res $400
        bg1             .res $400
        bg2             .res $400
        debugbg         .res $400
        lighttiles      .res $1000

        ;; 24k

        spritetiles     .res $1000

        debugtiles      .res $280

        bogus           .res $800 - $280

        ;; 32k

        .endstruct


        ;; oam memory layout

        .struct oam
        border          .res $1c * $4
        snow            .res $10 * $4
        rem             .res $18 * $4
        key             .res $1 * $4
        .endstruct