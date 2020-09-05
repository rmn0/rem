
MEMORY {
       ZP:         start = $0000, size = $0100;
       RAM:        start = $0100, size = $ff00;
}

SEGMENTS {
         ZEROPAGE:   load = ZP,  type = zp;
         CODE:       load = RAM, type = rw, define = yes;
}
