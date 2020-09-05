
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <libgen.h>

#include "imgheader.h"

#define MAXDEPTH 32

#define TILESIZE 7

#define MARKERBIT 0x10

struct sprite
{
  int nobjects;

  struct object {
    int x, y;
  } object[MAXDEPTH];

} sprite_current, sprite_best;

struct boundingrect {
  int l, r, t, b;
} bounds[MAXDEPTH];


int max(int a, int b) { return a > b ? a : b; }
int min(int a, int b) { return a < b ? a : b; }

int searchmode;

void assemble_sprite(int w, int h, unsigned char *data, unsigned char *mask, int depth);

void getbounds(unsigned char *data, int w, int h, int depth)
{
  bounds[depth].l = w; bounds[depth].r = 0;
  bounds[depth].t = h; bounds[depth].b = 0;

  for(int yo = bounds[depth - 1].t; yo <= bounds[depth - 1].b; ++yo)
    for(int xo = bounds[depth - 1].l; xo <= bounds[depth - 1].r; ++xo)
      if(data[yo * w + xo]) {
        bounds[depth].l = min(bounds[depth].l, xo);
        bounds[depth].r = max(bounds[depth].r, xo);
        bounds[depth].t = min(bounds[depth].t, yo);
        bounds[depth].b = max(bounds[depth].b, yo);
      }
}

void make_object(int x, int y, int w, int h, unsigned char *data, unsigned char *mask, int depth)
{
  if(depth + 1 == sprite_best.nobjects) return;

  sprite_current.object[depth].x = min(x, w - TILESIZE - 1);
  sprite_current.object[depth].y = min(y, h - TILESIZE - 1);
  sprite_current.nobjects = depth + 1;

  unsigned char* datacopy = &data[w * h];

  for(int yo = bounds[depth].t; yo <= bounds[depth].b; ++yo)
    for(int xo = bounds[depth].l; xo <= bounds[depth].r; ++xo)
      datacopy[yo * w + xo] = data[yo * w + xo];

  for(int yo = max(y, bounds[depth].t); yo <= min(y + TILESIZE, bounds[depth].b); ++yo)
    for(int xo = max(x, bounds[depth].l); xo <= min(x + TILESIZE, bounds[depth].r); ++xo)
      datacopy[yo * w + xo] = 0;

  assemble_sprite(w, h, datacopy, &mask[w * h], depth + 1);
}

void assemble_sprite(int w, int h, unsigned char *data, unsigned char *mask, int depth)
{
  getbounds(data, w, h, depth);

  if(bounds[depth].l > bounds[depth].r) {
    //printf("current = %i, best = %i\n", sprite_current.nobjects, sprite_best.nobjects);
    if(sprite_current.nobjects < sprite_best.nobjects)
      sprite_best = sprite_current;
    return;
  }

  memset(mask, 0, w * h);

  for(int y = bounds[depth].t; y <= bounds[depth].b; ++y)
    for(int x = bounds[depth].l; x <= bounds[depth].r; ++x)
      if(data[y * w + x]) {
        for(int xo = max(x - TILESIZE, bounds[depth].l); xo <= x; ++xo) mask[y * w + xo] |= 1;
        for(int xo = x; xo <= min( x + TILESIZE, bounds[depth].r); ++xo) mask[y * w + xo] |= 2;
        for(int yo = max(y - TILESIZE, bounds[depth].t); yo <= y; ++yo) mask[yo * w + x] |= 4;
        for(int yo = y; yo <= min( y + TILESIZE, bounds[depth].b); ++yo) mask[yo * w + x] |= 8;
      }

  for(int y = bounds[depth].t; y <= bounds[depth].b; ++y)
    for(int x = bounds[depth].l; x <= bounds[depth].r; ++x) {
      int i = y * w + x;
      mask[i] |= ((mask[i] | (mask[i] >> 1)) & ((mask[i] >> 2) | (mask[i] >> 3)) & 1) << 4;
    }

  /* for(int y = bounds[depth].t; y <= bounds[depth].b; ++y) */
  /*   for(int x = bounds[depth].l; x <= bounds[depth].r; ++x) */
  /*     if(mask[y * w + x] & 16) { */
  /*       int t = y > bounds[depth].t ? (mask[(y - 1) * w + x] & 16) : 0; */
  /*       int b = y < bounds[depth].b ? (mask[(y + 1) * w + x] & 16) : 0; */
  /*       int l = x > bounds[depth].l ? (mask[y * w + x - 1] & 16) : 0; */
  /*       int r = x < bounds[depth].r ? (mask[y * w + x + 1] & 16) : 0; */
  /*       if((r || b) && !(l || t)) make_object(x, y, w, h, data, mask, depth); */
  /*       if((l || b) && !(r || t)) make_object(x - TILESIZE, y, w, h, data, mask, depth); */
  /*       if((r || t) && !(l || b)) make_object(x, y - TILESIZE, w, h, data, mask, depth); */
  /*       if((l || t) && !(r || b)) make_object(x - TILESIZE, y - TILESIZE, w, h, data, mask, depth); */
  /*       if(!(l || r || t || b)) make_object(x, y, w, h, data, mask, depth); */
  /*     } */

  searchmode = (rand() & 3) + 1;

  switch(searchmode) {
  case 1:
    for(int x = bounds[depth].l; x <= max(bounds[depth].l, bounds[depth].r - TILESIZE); ++x)
      if(mask[bounds[depth].t * w + x] & 16) {
        make_object(x, bounds[depth].t, w, h, data, mask, depth);
        break;
      }

    for(int x = max(bounds[depth].l, bounds[depth].r - TILESIZE); x >= bounds[depth].l; --x)
      if(mask[bounds[depth].t * w + (x + TILESIZE)] & 16) {
        make_object(x, bounds[depth].t, w, h, data, mask, depth);
        break;
      }
    break;

  case 2:
    for(int x = bounds[depth].l; x <= max(bounds[depth].l, bounds[depth].r - TILESIZE); ++x)
      if(mask[bounds[depth].b * w + x] & 16) {
        make_object(x, bounds[depth].b - TILESIZE, w, h, data, mask, depth);
        break;
      }

    for(int x = max(bounds[depth].l, bounds[depth].r - TILESIZE); x >= bounds[depth].l; --x)
      if(mask[bounds[depth].b * w + (x + TILESIZE)] & 16) {
        make_object(x, bounds[depth].b - TILESIZE, w, h, data, mask, depth);
        break;
      }
    break;

  case 3:
    for(int y = bounds[depth].t; y <= max(bounds[depth].t, bounds[depth].b - TILESIZE); ++y)
      if(mask[y * w + bounds[depth].l] & 16) {
        make_object(bounds[depth].l, y, w, h, data, mask, depth);
        break;
      }

    for(int y = max(bounds[depth].t, bounds[depth].b - TILESIZE); y >= bounds[depth].t; --y)
      if(mask[(y + TILESIZE) * w + bounds[depth].l] & 16) {
        make_object(bounds[depth].l, y, w, h, data, mask, depth);
        break;
      }
    break;

  case 4:
    for(int y = bounds[depth].t; y <= max(bounds[depth].t, bounds[depth].b - TILESIZE); ++y)
      if(mask[y * w + bounds[depth].r] & 16) {
        make_object(bounds[depth].r - TILESIZE, y, w, h, data, mask, depth);
        break;
      }

    for(int y = max(bounds[depth].t, bounds[depth].b - TILESIZE); y >= bounds[depth].t; --y)
      if(mask[(y + TILESIZE) * w + bounds[depth].r] & 16) {
        make_object(bounds[depth].r - TILESIZE, y, w, h, data, mask, depth);
        break;
      }
    break;
  }


}

int main(int argc, char *argv[])
{
  FILE *fi = freopen(NULL, "rb", stdin);
  FILE *fo = freopen(NULL, "wb", stdout);
  FILE *fa = NULL;

  char name[256] = "data_";

  int opt;
  int verbose = 0;

  while ((opt = getopt(argc, argv, "va:")) != -1) {
    switch (opt) {
    case 'v':
      verbose = 1;
      break;
    case 'a':
      fa = fopen(optarg, "wb");

      strcat(name, basename(optarg));
      char *c = name;
      while(*c) { if (*c == '.') *c = 0; ++c; }

      if(!fa) {
        fprintf(stderr, "could not open annotation file\n");
        return 1;
      }
      break;
    default:
      fprintf(stderr, "usage: %s [-v] [-a annotation file]\n",
              argv[0]);
      return 1;
    }
  }

  struct imgheader h;
  fread(&h, 1, sizeof(h), fi);

  if(h.magic != IMGMAGIC) {
    fprintf(stderr, "not an rri file\n");
    return 1;
  }

  fwrite(&h, 1, sizeof(h), fo);

  if (fa)
    fprintf(fa, ".segment \"rodata\"\n\n.export %s_frame_table\n\n%s_frame_table:\n\n\t.word\t$%x\t; frame count\n\n",
            name, name, h.frames);

  int datal = 0;
  char db[0x10000] = "";

  for(int f = 0; f < h.frames; ++f) {
    struct imgframeheader fh;
    fread(&fh, 1, sizeof(fh), fi);

    unsigned char *data = malloc(fh.w * fh.h * MAXDEPTH);
    unsigned char *mask = malloc(fh.w * fh.h * MAXDEPTH);

    fread(data, 1, fh.w * fh.h, fi);
    memcpy(&data[fh.w * fh.h], data, fh.w * fh.h);

    int marker_xx = -1, marker_yy = -1, have_marker = 0;
    for(int yy = 0; yy < fh.h; ++yy)
      for(int xx = 0; xx < fh.w; ++xx)
        if(data[xx + yy * fh.w] & MARKERBIT) {
          marker_xx = xx;
          marker_yy = yy;
          if(have_marker != 0) {
            fprintf(stderr, "frame %i contains multiple positioning markers\n", f);
            return 1;
          }
          ++have_marker;
        }

    if(have_marker != 1) {
      fprintf(stderr, "frame %i doesn't contain a positioning marker\n", f);
      return 1;
    }

    if(verbose) fprintf(stderr, "frame %i: positioning marker at %i, %i\n", f, marker_xx, marker_yy);

    sprite_best.nobjects = MAXDEPTH - 1;
    sprite_current.nobjects = 0;

    bounds[0].l = 0;
    bounds[0].r = fh.w - 1;
    bounds[0].t = 0;
    bounds[0].b = fh.h - 1;

    for(int i = 0; i < 2; ++i)
      assemble_sprite(fh.w, fh.h, data, mask, 1);

    int w = fh.w;
    int h = fh.h;

    fh.w = TILESIZE + 1;
    fh.h = (TILESIZE + 1) * (sprite_best.nobjects - 1);

    fwrite(&fh, 1, sizeof(fh), fo);

    if(fa) {
      fprintf(fa, "\t.word\t.loword(%s_frame_objects) + $%x\n", name, datal * 2);
      fprintf(fa, "\t.word\t$%x\t; object table length\n", (sprite_best.nobjects - 1) * 2);
      fprintf(fa, "\t.word\t.loword(%s_frame_%i)\n\t.byte\t^%s_frame_%i\n", name, f, name, f);
      fprintf(fa, "\t.byte\t$%x\t; frame delay\n\n", fh.t < 0x80 ? fh.t : 0x0);
      for(int i = 1; i < sprite_best.nobjects; ++i) {
        sprintf(db + strlen(db),
                "\t.byte\t$%x,$%x\n",
                (unsigned char)(sprite_best.object[i].x - marker_xx + 3),
                (unsigned char)(sprite_best.object[i].y - marker_yy - 1));
      }
      sprintf(db + strlen(db), "\n");
      datal += sprite_best.nobjects - 1;
    }

    for(int i = 1; i < sprite_best.nobjects; ++i)
      for(int y = 0; y <= TILESIZE; ++y)
        fwrite(&data[(sprite_best.object[i].y + y) * w + sprite_best.object[i].x], 1, TILESIZE + 1, fo);

    if(verbose == 2) {
      memset(mask, 0, w * h);
      for(int i = 1; i < sprite_best.nobjects; ++i) {
        for(int y = 0; y <= TILESIZE; ++y)
          for(int x = 0; x <= TILESIZE; ++x)
            mask[(y + sprite_best.object[i].y) * w + (x + sprite_best.object[i].x)] = i;
      }


      for(int y = 0; y < h; ++y) {
        for(int x = 0; x < w; ++x)
          if(data[y * w + x] > 0) fprintf(stderr, "*");
          else if(mask[y * w + x] > 0) fprintf(stderr, ".");
          else fprintf(stderr, " ");
        fprintf(stderr, "\n");
      }
    }

    free(data);
    free(mask);
  }

  if(fa) {
    fprintf(fa, "%s_frame_objects:\n\n%s", name, db);
    fclose(fa);
  }

  return 0;
}
