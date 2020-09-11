
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include "imgheader.h"

#define NSPANS 4
#define BOUNDING_BOX_HEIGHT 8
#define BOUNDING_BOX_ENTRIES 4

void flip(unsigned char* a, unsigned char* b)
{
  unsigned char t;
  t = *a;
  *a = *b;
  *b = t;
}

int main(int argc, char *argv[])
{
  int opt;
  int verbose = 0;

  char outfile[1024] = "";

  while ((opt = getopt(argc, argv, "o:v")) != -1) {
    switch (opt) {
    case 'o':
      strcpy(outfile, optarg);
      break;
    case 'v':
      verbose = 1;
      break;
    default:
      fprintf(stderr, "usage: %s [-o output file] [-v]\n",
              argv[0]);
      return 1;
    }
  }

  if(!outfile[0]) {
    fprintf(stderr, "output file name missing\n");
    return 1;
  }

  FILE *fi = freopen(NULL, "rb", stdin);

  struct imgheader h;
  fread(&h, 1, sizeof(h), fi);

  if(h.magic != IMGMAGIC) {
    fprintf(stderr, "not an rri file\n");
    return 1;
  }

  if(h.frames != 1) {
    fprintf(stderr, "too many frames in input file\n");
  }

  struct imgframeheader fh;
  fread(&fh, 1, sizeof(fh), fi);

  unsigned char* buffer = malloc(fh.w * fh.h);
  fread(buffer, 1, fh.w * fh.h, fi);

  unsigned char* spantable = malloc(fh.h * NSPANS);
  unsigned char boxtable[(256 / BOUNDING_BOX_HEIGHT) * BOUNDING_BOX_ENTRIES];

  unsigned short firstline = 0xff;
  unsigned short linecount = 0xff;

  for(int yy = 0; yy < fh.h; ++yy) {
    spantable[yy * NSPANS + 0] = 0;
    spantable[yy * NSPANS + 1] = 0;
    spantable[yy * NSPANS + 2] = 0;
    spantable[yy * NSPANS + 3] = 0;

    int span = 0;
    int lastc = -1;
    int lastxx = 0;
    for(int xx = 0; xx < fh.w; ++xx) {
      int c = buffer[yy * fh.w + xx];
      if(c != lastc && xx > 0) {
        if(span > 4) {
          fprintf(stderr, "too many spans in scanline %i", yy);
          return 1;
        }
        spantable[yy * NSPANS + span] = xx;
        lastxx = xx;
        ++span;
      }
      lastc = c;
    }

    if(span == 2) {
      spantable[yy * NSPANS + 2] = 0;
      spantable[yy * NSPANS + 3] = 0;
    }

    if(firstline == 0xff && span > 0) firstline = yy;
    if(span > 0) linecount = yy + 1 - firstline;
  }

  for(int yy = firstline + linecount; yy < firstline + linecount + BOUNDING_BOX_HEIGHT; ++yy) {
    spantable[yy * NSPANS + 0] = spantable[(yy - 1) * NSPANS + 0];
    spantable[yy * NSPANS + 1] = spantable[(yy - 1) * NSPANS + 1];
    spantable[yy * NSPANS + 2] = spantable[(yy - 1) * NSPANS + 2];
    spantable[yy * NSPANS + 3] = spantable[(yy - 1) * NSPANS + 3];
  }


  unsigned char right = 0;

  for(int yy = 0; yy < fh.h / BOUNDING_BOX_HEIGHT; ++yy) {
    int l1min = 255, l2max = 0, r1min = 255, r2max = 0;
    int hasright = 0;
    for(int yy2 = 0; yy2 < BOUNDING_BOX_HEIGHT; ++yy2) {
      int llyy = (yy * BOUNDING_BOX_HEIGHT) + yy2 + firstline;
      if(llyy >= firstline + linecount) llyy = firstline + linecount - 1;

      int l1 = spantable[llyy * NSPANS + 0];
      int l2 = spantable[llyy * NSPANS + 1];
      int r1 = spantable[llyy * NSPANS + 2];
      int r2 = spantable[llyy * NSPANS + 3];

      if(l1 < l1min) l1min = l1;
      if(l2 > l2max) l2max = l2;

      if(r1 > 0 && r1 < r1min) r1min = r1;
      if(r2 > 0 && r2 > r2max) r2max = r2;
    }

    if(l2max > r2max) r2max = l2max;

    boxtable[yy * BOUNDING_BOX_ENTRIES + 0] = l1min;
    boxtable[yy * BOUNDING_BOX_ENTRIES + 1] = l2max;
    boxtable[yy * BOUNDING_BOX_ENTRIES + 2] = r1min;
    boxtable[yy * BOUNDING_BOX_ENTRIES + 3] = r2max;

    if(l2max > right) right = l2max;
    if(r2max > right) right = r2max;

    if(verbose) printf("%i, %i, %i, %i\n", l1min, l2max, r1min, r2max);
  }

  // make relative offsets
  for(int yy = firstline; yy < firstline + linecount + BOUNDING_BOX_HEIGHT; ++yy) {
    if(spantable[yy * NSPANS + 2] == 0) {
      spantable[yy * NSPANS + 3] = spantable[yy * NSPANS + 1];
      spantable[yy * NSPANS + 2] = spantable[yy * NSPANS + 0];
    }

    spantable[yy * NSPANS + 3] -= spantable[yy * NSPANS + 2];
    spantable[yy * NSPANS + 1] -= spantable[yy * NSPANS + 0];
  }


  FILE *fo = fo = fopen(outfile, "wb");

  if(verbose) printf("start line = %i, line count = %i, groups = %i\n",
                     firstline, linecount,  linecount / BOUNDING_BOX_HEIGHT + 1);

  fwrite(&firstline, 1, 2, fo);
  fwrite(&linecount, 1, 2, fo);
  fwrite(&right, 1, 2, fo);
  fwrite(&right, 1, 2, fo);

  for(int yy = 0; yy <= linecount / BOUNDING_BOX_HEIGHT; ++yy) {
    fwrite(&boxtable[yy * BOUNDING_BOX_ENTRIES], 1, BOUNDING_BOX_ENTRIES, fo);
    fwrite(&spantable[(firstline + yy * BOUNDING_BOX_HEIGHT) * NSPANS], 1, BOUNDING_BOX_HEIGHT * NSPANS, fo);
  }

  fclose(fo);

  free(spantable);
  free(buffer);

  return 0;
}
