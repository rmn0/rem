
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include "imgheader.h"

#define NSPANS 5
#define BOUNDING_BOX_HEIGHT 16

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
  unsigned char boxtable[(256 / BOUNDING_BOX_HEIGHT) * 2];
  unsigned char spanmax[256];

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
        //spantable[yy * NSPANS + span] = xx; // 16-bit version
        spantable[yy * NSPANS + span] = xx - lastxx; // 8-bit version
        lastxx = xx;
        ++span;
      }
      lastc = c;
    }

    if(span == 2) {
      // setup up the unneeded span so that it will clip early
      //spantable[yy * NSPANS + 2] = 0x7f; //spantable[yy * NSPANS + 0];
      //spantable[yy * NSPANS + 3] = 0x7f; //spantable[yy * NSPANS + 1];

      spantable[yy * NSPANS + 2] = 0;
      spantable[yy * NSPANS + 3] = 0;
    }

    spanmax[yy] = lastxx;

    if(firstline == 0xff && span > 0) firstline = yy;
    if(span > 0) linecount = yy + 1 - firstline;
  }

  for(int yy = 0; yy < fh.h / BOUNDING_BOX_HEIGHT; ++yy) {
    int lmax = 0, rmax = 0;
    for(int yy2 = 0; yy2 < BOUNDING_BOX_HEIGHT; ++yy2) {
      int llyy = (yy * BOUNDING_BOX_HEIGHT) + yy2 + firstline;
      if(llyy >= firstline + linecount) llyy = firstline + linecount - 1;

      int l = spantable[llyy * NSPANS + 0] + spantable[llyy * NSPANS + 1];
      int r = spanmax[llyy];

      if(l > lmax) lmax = l;
      if(r > rmax) rmax = r;
    }
    boxtable[yy] = lmax;
    boxtable[yy + 256 / BOUNDING_BOX_HEIGHT] = rmax;
  }


  FILE *fo = fo = fopen(outfile, "wb");

  if(verbose) printf("start line = %i, line count = %i\n", firstline, linecount);

  linecount *= NSPANS;

  fwrite(&firstline, 1, 2, fo);
  fwrite(&linecount, 1, 2, fo);

  fwrite(boxtable, 1, (256 / BOUNDING_BOX_HEIGHT) * 2, fo);

  fwrite(&spantable[firstline * NSPANS], 1, linecount, fo);

  fclose(fo);

  free(spantable);
  free(buffer);

  return 0;
}
