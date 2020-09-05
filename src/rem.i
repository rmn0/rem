

        ;; rem.i

        ;; main include file

        
        .p816
        .a8
        .i16
        
        .include "snes.i"
        .include "macro.i"
        .include "map.i"
        .include "dmaq.i"
        .include "debug.i"
        .include "sprite.i"
        .include "room.i"


        ;; constants

        .scope setup
master_brightness_bit = $0f
bgmode = $01
mainscreen_bit = $13
subscreen_bit = $04
        .endscope

        .scope button_bit
bb      = $8000
yy      = $4000
select	= $2000
start	= $1000
up	= $0800
down	= $0400
left	= $0200
right	= $0100
aa	= $80
xx	= $40
ll	= $20
rr	= $10
        .endscope

        .scope const
pixels_in_room = $100
pixels_in_tile = $8
tiles_in_room = $20

        map_bits = $4
        rooms_in_map = $10

room_table_size = .sizeof(room_entry) * rooms_in_map * rooms_in_map
        .endscope


        .scope transform_bit
hh = $2
vv = $4
tt = $8
        .endscope


        ;; structure definitions

        .struct entity
        pos_xx_frac     .res 1
        pos_xx          .res 2
        pos_yy_frac     .res 1
        pos_yy          .res 2
        vel_xx          .res 2
        vel_yy          .res 2
        box_ww          .res 1
        box_hh          .res 1
        flags           .res 2
        animation_index .res 1
        padding         .res 1
        .endstruct

        .scope entity_flag_bit
ground =      $1
slope =       $2
air = $4
crouched = $8
left_wall = $10
right_wall = $20
ledge = $40
ledge_b = $80
all_wall_flags = $f0
facing = $8000
        .endscope



        ;; scale a coordinate from pixel-space to tile-space and/or room-space

        ;; xx : pixel-space coordinate

        ;; txx : returns the tile-space coordinate
        ;; rxx : returns the pixel-space coordinate
        ;; pxx : returns the pixel offset within a tile

        ;; pre : if not blank, pre-multiply the tile-space coordinate
        ;; nt  : optional, floor the tile coordinate to a multipe of this value (must be power of two)

        .macro scale_pixel_coord xx, txx, rxx, pxx, pre, nt
        lda     xx
        tax
        .ifnblank pxx
        and     #(const::pixels_in_tile - $1)
        sta     pxx
        txa
        .endif
        .ifnblank txx
        .ifnblank pre
        asl
        asl
        .ifnblank nt
        and     #((const::tiles_in_room - nt) * (const::tiles_in_room))
        .else
        and     #((const::tiles_in_room - $1) * (const::tiles_in_room))
        .endif
        .else
        lsr
        lsr
        lsr
        .ifnblank nt
        and     #(const::tiles_in_room - nt)
        .else
        and     #(const::tiles_in_room - $1)
        .endif
        .endif
        sta     txx
        txa
        .endif
        .ifnblank rxx
        xba
        and     #(const::rooms_in_map - $1)
        sta     rxx
        .endif
        .endmacro


        ;; get the room table address from the room coordinates

        ;; room_xx : room x-coordinate
        ;; room_yy : room y-coordinate

        ;; the room index is returned in ii (default = room_ii)

        .macro room_index ii
        lda     room_yy
        .repeat const::map_bits
        asl
        .endrepeat
        ora     room_xx
        eor     tform_room_mask
        asl
        asl
        .if .xmatch(ii, x)
        tax
        .elseif .xmatch(ii, a)
        .else
        sta     room_ii
        .endif
        .endmacro


        ;; get address offset for tile coordinates

        ;; xx : tile-space horizontal coordinate
        ;; yy : tile-space vertical coordinate (premultiplied)

        ;; index is returned in accumulator

        .macro tile_index xx, yy
        lda     yy
        ora     xx
        .endmacro

