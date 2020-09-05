
        ;; dmaq.s

        ;; dma queues


        .include "rem.i"

        .scope  dmaq

        .export dmaq_flush = flush
        .export dmaq_table_rblock = table_rblock
        .export dmaq_table_vblock = table_vblock
        .export dmaq_table_hblock = table_hblock
        .export dmaq_length = length
        
        .define entry dmaq_entry

        .segment "bss"

        .define queue_length $10
        .define queue_address $8 * (index + queue * queue_length)


table:
table_rblock:   
        .res $8 * queue_length
table_vblock:
        .res $8 * queue_length
table_hblock:
        .res $8 * queue_length


length: .res $2 * $3
        
        .segment "code"
                
        .macro  dma_entry_block index, queue
        ldx     a:table + entry::src_address + queue_address
        stx     reg_a1tx

        ldx     a:table + entry::dst_address + queue_address
        stx     reg_vmadd

        ldx     a:table + entry::length + queue_address
        stx     reg_dasx

        sta     reg_mdmaen
        .endmacro
        
        .macro  dma_entry_rblock index, queue
        ldy     a:table + entry::src_address + queue_address
        sty     reg_a1tx
        
        ldy     a:table + entry::length + queue_address
        sty     reg_dasx
        
        ldy     a:table + entry::dst_address + queue_address
        sty     reg_vmadd
        
        lda     a:table + entry::src_bank + queue_address
        sta     reg_a1bx
        
        lda     #$01
        sta     reg_mdmaen
        .endmacro
        
        
        .macro  queue_flush dma_entry, queue
        .scope
        
        ldx     length + queue * $2

        jmp     (_jumptable, x)
        
_jumptable:
        .word    _ls, _l0, _l1, _l2, _l3, _l4, _l5, _l6, _l7, _l8, _l9, _l10, _l11, _l12, _l13, _l14, _l15
_l15:

        dma_entry $f, queue
_l14:
        dma_entry $e, queue
_l13:
        dma_entry $d, queue
_l12:
        dma_entry $c, queue
_l11:
        dma_entry $b, queue
_l10:
        dma_entry $a, queue
_l9:
        dma_entry $9, queue
_l8:
        dma_entry $8, queue
_l7:
        dma_entry $7, queue
_l6:
        dma_entry $6, queue
_l5:
        dma_entry $5, queue
_l4:
        dma_entry $4, queue
_l3:
        dma_entry $3, queue
_l2:
        dma_entry $2, queue
_l1:
        dma_entry $1, queue
_l0:
        dma_entry $0, queue
_ls:
        
        .endscope
        .endmacro
        
flush:
        .a8
        lda     #$80
        sta     reg_vmainc

        ldy     #$1801
        sty     reg_dmapx
        
        queue_flush dma_entry_rblock, $0

        lda     #$7e
        sta     reg_a1bx

        lda     #$01
        
        queue_flush dma_entry_block, $1
        
        lda     #$81
        sta     reg_vmainc
        lda     #$01
                
        queue_flush dma_entry_block, $2
                
        rts
        
        .endscope
        
        
        