
#include <stdio.h>
#include <math.h>

// clamp the value x to the range of 0..r

int clamp(int x, int r)
{
  if (x < 0) return 0;
  if (x > r) return r;
  return x;
}

// generate assembly for the vis table
// the vistable is a 64 kbyte table which stores a precomputed visibility
// info byte for each combination of source and target lightel.

void vistable()
{
  for(unsigned int i = 0; i < 256 * 256; ++i) {
    if((i & 15) == 0) printf("\n.byte ");
    if((i & 15) != 0) printf (", ");
    int
      from_vis = ((i >> 8) & 31) - 4,
      to_vis = (i >> 4) & 15;

    int new_vis;

    new_vis = clamp(from_vis + to_vis * 2, 28) + 4;

    printf("$%02x", new_vis);

  }
  printf("\n\n");
}

// assembly snippets for putting together an unrolled
// visibility computation loop

#define LIGHT_ASM                               \
  "lda a:light_origin + $%04x\n"                \
  "xba\n"                                       \
  "lda a:light_origin + $%04x\n"                \
  "tax\n"                                       \
  "lda f:vistable + $%04x, x\n"                 \
  "sta a:light_origin + $%04x\n\n"              \

#define SHORT_LIGHT_ASM                         \
  ";lda a:light_origin + $%04x\n"               \
  ";xba\n"                                      \
  "lda a:light_origin + $%04x\n"                \
  "tax\n"                                       \
  "lda f:vistable + $%04x, x\n"                 \
  "sta a:light_origin + $%04x\n\n"              \

#define COLUMN_ASM                              \
  "cpy  #$%02x\n"                                \
  "%s  :+\n"                                    \
  "jmp %s\n"                                   \
  ":\n\n"

// radius of the light

#define RADIUS 23

// number of unrolled loops = BUFFERMAX + 1

#define BUFFERMAX 1

// get address of a lightel in the bufferpos

int bufferpos(int xx, int yy)
{
   int p = xx + yy * 32 + 30 * 32;

   // sanity check
   if(p < 0) { printf("warning: buffer size check failed.\n"); }
   if(p >= 32 * 64) { printf("warning : buffer size check failed.\n"); }

   return p;
}


// table for the maximum vertical extent
// of each visibility loop variation

int maxtable[] = { -16, 24, -24, 16 };


// generate the assembly for a single lightel

void light(int xx, int yy, int overflow)
{
  if(xx == 0 && yy == 0) return;

  // hand-made table defines how to select the source lightel
  // could probably created algorithmically, but result  won't look as good

  int stable[] = { 0, 1, 1, 3, 1, 4, 3, 7, 1, 7, 4, 11, 3, 10, 7, 15, 1, 13, 9, 19, 5, 17, 11, 23 };

  static int prevxxs = 255, prevyys = 255;

  int xxabs = xx < 0 ? -xx : xx;
  int yyabs = yy < 0 ? -yy : yy;

  int xxs, yys;

  if(xxabs > yyabs) {
    if(xx < 0) xxs = xx + 1; else xxs = xx - 1;
    if(yyabs >= stable[xxabs]) {
      if(yy < 0) yys = yy + 1; else yys = yy - 1;
    } else yys = yy;
  } else {
    if(yy < 0) yys = yy + 1; else yys = yy - 1;
    if(xxabs >= stable[yyabs]) {
      if(xx < 0) xxs = xx + 1; else xxs = xx - 1;
    } else xxs = xx;
  }

  // get distance from orgin

  float rr = sqrtf(xx * xx + yy * yy);
  float rrs = sqrtf(xxs * xxs + yys * yys);

  int dest = bufferpos(xx, yy);

  if(rr > RADIUS + 0.8f) {
    if(!overflow) return;
    else {
      printf("lda #$ff\n");
      printf("sta a:light_origin + $%04x\n", dest);
      return;
    }
  }


 printf((prevxxs == xxs && prevyys == yys) ? SHORT_LIGHT_ASM : LIGHT_ASM,
        bufferpos(xxs, yys),
        dest,
        (int)(rr * 0.8f) == (int)(rrs * 0.8f) ? 0x0 : 0x100,
        dest);

  prevxxs = xxs;
  prevyys = yys;
}


// generate a visibility computation loop

void cast(int ii)
{
  printf("viscast_%i:\n", ii);

  for(int xx = 0; xx >= -RADIUS; --xx) {
    for(int yy = 0; yy >= -RADIUS; --yy)
      if(yy >= maxtable[(BUFFERMAX - ii) * 2 + 0]) light(xx, yy, 0);
    for(int yy = 1; yy <= RADIUS; ++yy)
      if(yy < maxtable[(BUFFERMAX - ii) * 2 + 1]) light(xx, yy, 0);
    if (xx > -RADIUS) printf(COLUMN_ASM, (32 + xx) * 2, "bmi", "@skip_1");
  }

  printf("@skip_1:\n\n");

  for(int xx = 1; xx <= RADIUS; ++xx) {
    for(int yy = 0; yy >= -RADIUS; --yy)
      if(yy >= maxtable[(BUFFERMAX - ii) * 2 + 0]) light(xx, yy, 0);
    for(int yy = 1; yy <= RADIUS; ++yy)
      if(yy < maxtable[(BUFFERMAX - ii) * 2 + 1]) light(xx, yy, 0);
    if (xx < RADIUS) printf(COLUMN_ASM, (xx + 2) * 2, "bpl", "_end");
  }

  printf("jmp _end\n\n");
}



int main()
{
  printf(".export viscast\n");
  printf(".import light_origin \n\n");

  printf(".segment \"code3\"\n\n");

  printf("jumptable:\n\n");
  printf(".word .loword(viscast_0)\n");
  printf(".word .loword(viscast_1)\n");

  printf("\nviscast:\n\n");
  printf("lda #$7e\npha\nplb\n\n");
  printf("jmp (.loword(jumptable), x)\n\n");
  printf("_end:\n\n");
  printf("lda #$80\npha\nplb\n\n");
  printf("rtl\n\n");

  for(int ii = 0; ii <= BUFFERMAX; ++ii) {
    cast(ii);
  }

  printf("\n\n.segment \"vistable\"\n\n");

  printf("\nvistable:\n");

  vistable();


  return 0;
};
