
#include <stdio.h>
#include <math.h>

#define LIGHT_RADIUS 21

// assembly snippets for putting together an unrolled
// visibility computation loop

#define LIGHT_ASM                               \
  "lda a:light_origin + $%04x\n"                \
  "%s\n"                                        \
  "adc a:visibility_origin + $%04x\n"           \
  "bmi :+\n"                                    \
  "jmp _end_tile_%04x\n"                        \
  ":\n"                                         \
  "sta a:light_origin + $%04x\n\n"

// get address of a lightel in the bufferpos

int bufferpos(int xx, int yy)
{
   int p = xx + yy * 32 + 30 * 32;

   // sanity check
   if(p < 0) { fprintf(stderr, "warning: buffer size check failed.\n"); }
   if(p >= 32 * 64) { fprintf(stderr, "warning : buffer size check failed.\n"); }

   return p;
}


void tile(int xx, int yy);


// generate the assembly for a single lightel

void light(int xx, int yy, int from_xx, int from_yy)
{
  if(xx == 0 && yy == 0) return;

  // hand-made table defines how to select the source lightel
  // could probably created algorithmically, but result  won't look as good

  int stable[] = { 0, 1, 1, 3, 1, 4, 3, 7, 1, 7, 4, 11, 3, 10, 7, 15, 1, 13, 9, 19, 5, 17, 11, 23 };

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

  if(xxs != from_xx || yys != from_yy) return;

  // get distance from orgin

  float rr = sqrtf(xx * xx + yy * yy);
  float rrs = sqrtf(xxs * xxs + yys * yys);

  int dest = bufferpos(xx, yy);

  if(rr > LIGHT_RADIUS) return;

  printf(LIGHT_ASM,
        bufferpos(xxs, yys),
        (int)(rr * 0.8f) == (int)(rrs * 0.8f) ? "clc" : "sec",
        bufferpos(xxs, yys), yy * 256 + xx, dest);

  tile(xx, yy); // recursively build the shadow cone

  printf("_end_tile_%04x:\n", yy * 256 + xx);
}

void tile(int xx, int yy)
{
  light(xx - 1, yy - 1, xx, yy);
  light(xx    , yy - 1, xx, yy);
  light(xx + 1, yy - 1, xx, yy);
  light(xx - 1, yy    , xx, yy);
  light(xx + 1, yy    , xx, yy);
  light(xx - 1, yy + 1, xx, yy);
  light(xx    , yy + 1, xx, yy);
  light(xx + 1, yy + 1, xx, yy);
}


// make a fence around the visibile area
// for aborting the loop
void fence()
{
  printf("lda #31\n");
  for(int ii = 0; ii < 32; ++ii) {
    printf("sta a:visibility_origin + $%04x, x\n", ii);
    printf("sta a:visibility_origin + $%04x, x\n", ii + 32 * 29);
  }
  for(int ii = 0; ii < 30; ++ii) {
    printf("sta a:visibility_origin + $%04x, x\n", ii * 32);
    printf("sta a:visibility_origin + $%04x, x\n", ii * 32 + 31);
  }
}


// generate the visibility computation loop

int main()
{
  printf(".export viscast\n");
  printf(".import light_origin \n\n");
  printf(".import visibility_origin \n\n");

  printf(".segment \"code3\"\n\n");

  printf("\nviscast:\n\n");
  printf("lda #$7e\npha\nplb\n\n");

  fence();

  tile(0, 0);

  printf("_end:\n\n");
  printf("lda #$80\npha\nplb\n\n");
  printf("rtl\n\n");

  return 0;
};
