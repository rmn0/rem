
#include <stdio.h>
#include <math.h>

#define LIGHT_RADIUS 23
// assembly snippets for putting together an unrolled
// visibility computation loop

#define LIGHT_ASM                               \
  "lda a:light_origin + $%04x\n"                \
  "%s\n"                                        \
  "adc a:visibility_origin + $%04x\n"           \
  "%s\n"                                        \
  "bmi :+\n"                                    \
  "jmp _end_tile_%04x\n"                        \
  ":\n"                                         \
  "sta a:light_origin + $%04x\n\n"

#define SHORT_LIGHT_ASM                         \
  "lda a:light_origin + $%04x\n"                \
  "%s\n"                                        \
  "adc a:visibility_origin + $%04x\n"           \
  "%s\n"                                        \
  "bpl _end_tile_%04x\n"                        \
  "sta a:light_origin + $%04x\n\n"


int short_tile_count, long_tile_count;

// get address of a lightel in the buffer

int bufferpos(int xx, int yy)
{
  return (xx + yy * 32 + 32 * 30) & 0xffff;
}


void tile(int xx, int yy);
int offset_to_end_label(int xx, int yy);

int end_loop(int xx, int yy, int from_xx, int from_yy)
{
  if(xx == 0 && yy == 0) return 1;

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

  if(xxs != from_xx || yys != from_yy) return 1;

  // get distance from orgin

  float rr = sqrtf(xx * xx + yy * yy);
  float rrs = sqrtf(xxs * xxs + yys * yys);

  if(rr > LIGHT_RADIUS) return 1;

  return 0;
}

// generate the assembly for a single lightel

void light(int xx, int yy, int from_xx, int from_yy)
{
  if(end_loop(xx, yy, from_xx, from_yy)) return;

  int jump_length = offset_to_end_label(xx, yy);

  float rr = sqrtf(xx * xx + yy * yy);
  float rrs = sqrtf(from_xx * from_xx + from_yy * from_yy);

  int tiledif = (int)(rr * 0.8f) - (int)(rrs * 0.8f);

  // just for debugging
  if(jump_length > 127) long_tile_count++; else short_tile_count++;

  printf(jump_length > 127 ? LIGHT_ASM : SHORT_LIGHT_ASM,
        bufferpos(from_xx, from_yy),
        tiledif == 0 ? "clc" : "sec",
        bufferpos(from_xx, from_yy),
        tiledif > 1 ? "inc" : "",
        yy * 256 + xx,
        bufferpos(xx, yy));

  tile(xx, yy); // recursively build the shadow cone

  printf("_end_tile_%04x:\n", yy * 256 + xx);
}

int light_length(int xx, int yy, int from_xx, int from_yy)
{
  if(end_loop(xx, yy, from_xx, from_yy)) return 0;

  int jump_length = offset_to_end_label(xx, yy);

  if(jump_length > 127) jump_length += 15; else jump_length += 12;

  return jump_length;
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

int offset_to_end_label(int xx, int yy)
{
  int offset = 0;

  offset += light_length(xx - 1, yy - 1, xx, yy);
  offset += light_length(xx    , yy - 1, xx, yy);
  offset += light_length(xx + 1, yy - 1, xx, yy);
  offset += light_length(xx - 1, yy    , xx, yy);
  offset += light_length(xx + 1, yy    , xx, yy);
  offset += light_length(xx - 1, yy + 1, xx, yy);
  offset += light_length(xx    , yy + 1, xx, yy);
  offset += light_length(xx + 1, yy + 1, xx, yy);

  return offset;
}

// make a fence around the visibile area
// for aborting the loop
void fence()
{
  printf("sa16\n");
  printf("lda #$2020\n");
  for(int ii = 0; ii < 32; ii += 2) {
    printf("sta a:visibility_origin + $%04x, x\n", ii);
    printf("sta a:visibility_origin + $%04x, x\n", ii + 32 * 28);
  }
  for(int ii = 0; ii < 28; ++ii) {
    printf("sta a:visibility_origin + $%04x, x\n", ii * 32 + 31);
  }
  printf("sa8\n");
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

  short_tile_count = 0;
  long_tile_count = 0;

  tile(0, 0);

  fprintf(stderr, "generated %i short tiles and %i long tiles (%i total).\n",
          short_tile_count, long_tile_count, short_tile_count + long_tile_count);

  printf("_end:\n\n");
  printf("lda #$80\npha\nplb\n\n");
  printf("rtl\n\n");

  return 0;
};
