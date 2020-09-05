
#include "stdio.h"

#define BLIT_MAIN                                                                             \
    ".export blit\n\n"                                                                        \
    ".export blit_shader_table\n\n"                                                           \
                                                                                              \
    ".importzp blit_temp    \n"          \
    ".importzp blit_xx        ; screen x-coordinate 0..31\n"                               \
    ".importzp blit_yy        ; screen y-coordinate 0..31\n"                               \
    ".importzp blit_length    ; blit length 0..31 (0 is 32)\n"                             \
    ".importzp blit_room_addr ; room data address\n"                                          \
    ".importzp blit_room_bank ; room data bank\n"                                             \
    ".importzp blit_transform ; 1 bit unused, 3 bits transform flags, 4 bits unused\n"        \
    ".importzp blit_shader    ; xor-ed with data\n"                                           \
    "                         ; stack : wram address of target buffer\n\n"                    \
                                                                                              \
    "blit:\n"                                                                                 \
    "lda     blit_room_bank\n"                                                                \
    "pha\n"                                                                                   \
    "plb\n\n"                                                                                 \
                                                                                                \
    ".a16\n"                                                                                  \
    "rep     #$20\n\n"                                                                        \
                                                                                              \
    "ldx     blit_transform\n"                                                                \
    "jmp     (.loword(offset_jumptable), x)\n\n"                                                         \
    "_blit_l1:\n"                                                                             \
    "asl\n"                                                             \
    "clc\n"                                                                                   \
    "adc     blit_room_addr\n"                                                                \
    "pha\n\n"                                                                                   \
                                                                                              \
    "lda     blit_length\n"                                                                   \
    "asl\n"                                                                                   \
    "asl\n"                                                                                   \
    "asl\n"                                                             \
    "asl\n"                                                             \
    "ora     blit_transform\n"                                                                \
    "tax\n\n"                                                                                 \
                                                                                              \
    "lda     blit_shader\n\n"                                           \
    "xba\n\n"                                           \
    "tay\n\n"                                           \
                                                                        \
    "lda     #$2100\n"                                                                        \
    "tcd\n\n"                                                                                 \
                                                                                              \
\
"jmp     (.loword(loop_jumptable), x)\n\n"                              \
                                                                                              \
"_blit_l2:\n\n"                                                                                 \
    ".a8\n"                                                            \
                                                                                              \
    "lda     #$00\n"                                                                          \
    "xba\n"                                                                          \
    "lda     #$00\n"                                                                          \
    "tcd\n\n"                                                                                 \
                                                                                              \
    "lda     #$80\n"                                                                          \
    "pha\n"                                                                                   \
    "plb\n\n"                                                                                 \
                                                                                              \
    "rtl\n\n\n"

#define BLIT_OFFSET          \
    "offset_%i:\n"           \
    "lda     %s\n"           \
    "eor     #$%02x\n"       \
    "%s"           \
    "asl\n"                  \
    "asl\n"                  \
    "asl\n"                  \
    "asl\n"                  \
    "asl\n"                  \
    "sta     blit_temp\n" \
    "lda     %s\n"           \
    "eor     #$%02x\n"               \
    "%s"                             \
    "ora     blit_temp\n"            \
    "jmp     _blit_l1\n\n"


#define BLIT_ADDRESS         \
    ".a16\n"                   \
    "rep     #$20\n\n"         \
    "lda     $04, s\n"       \
    "clc\n"                  \
    "adc     #$%04x\n"       \
    "sta     $81\n\n" \
    ".a8\n"                                                             \
    "sep     #$20\n\n"                                                    

#define BLIT_EL                                 \
  "lda     a:%i, x\n"                           \
  "sta     $80\n"                               \
  "tya\n"                                       \
  "eor     a:%i + 1, x\n"                       \
  "sta     $80\n\n"                               

/* #define BLIT_EL              \ */
/*     "tya\n"                  \ */
/*     "eor     a:%i, x\n"      \ */
/*     ".a8\n"                  \ */
/*     "sep     #$20\n"         \ */
/*     "sta     $80\n"          \ */
/*     "xba\n"                  \ */
/*     "sta     $80\n"          \ */
/*     ".a16\n"                 \ */
/*     "rep     #$20\n\n" */

void blit_offset(int transform)
{
    const char* xx = (transform & 4) ? "blit_yy" : "blit_xx";
    const char* yy = (transform & 4) ? "blit_xx" : "blit_yy";
    const char* inxx;
    const char* inyy;
    unsigned short bitmask;
    if(transform & 4)  {
      bitmask = ((transform & 2) ? 31 : 0) | ((transform & 1) ? 31 * 32 : 0);
      if(transform & 2) inxx = ""; else inxx = "";
      if(transform & 1) inyy = "inc\nclc\nadc blit_length\nand #$1f\n"; else inyy = "";
    } else {
      bitmask = ((transform & 1) ? 31 : 0) | ((transform & 2) ? 31 * 32 : 0);
      if(transform & 1) inxx = "inc\nclc\nadc blit_length\nand #$1f\n"; else inxx = "";
      if(transform & 2) inyy = ""; else inyy = "";
    }

    printf(BLIT_OFFSET, transform, yy, bitmask >> 5, inyy, xx, bitmask & 31, inxx);
}

void blit_loop(int length, int transform)
{
    printf("loop_%i_%i:\n\nplx\n\n", length, transform);

    for(int i = 0; i < 1; ++i) {
        printf(BLIT_ADDRESS, i * 64);
        int l = (32 - length);
        for(int j = 0; j < l; ++j) {
            int xx = (transform & 1) ? (l - 1 - j) : j;
            int yy = (transform & 2) ? (0 - i) : i;
            int addr = (unsigned short)(((transform & 4) ? (yy * 2 + xx * 64) : (xx * 2 + yy * 64)));
            printf(BLIT_EL, addr, addr);
        }
    }

    printf("jmp _blit_l2\n\n");
}

int main()
{
    printf(".segment \"code2\"\n\n");

    printf(BLIT_MAIN);
    printf("\n\n");

    printf("offset_jumptable:\n");
    for(int i = 0; i < 8; ++i)
      printf("\t.word .loword(offset_%i)\n", i);
    printf("\n\n");

    printf("loop_jumptable:\n");
    for(int i = 0; i < 32 * 8; ++i)
      printf("\t.word .loword(loop_%i_%i)\n", i / 8, i % 8);
    printf("\n\n");

    printf(".a16\n\n\n");

    printf("blit_shader_table:\n");
    for(int i = 0; i < 8; ++i)
      printf("\t.word $%04x\n", ((i & 3) << 13) | ((i & 4) << 10));
    printf("\n\n");

    for(int i = 0; i < 8; ++i) blit_offset(i);
    printf("\n\n");

    for(int i = 0; i < 32 * 8; ++i) blit_loop(i / 8, i % 8);
    printf("\n\n");

    return 0;
}
