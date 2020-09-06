#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include "getext.h"
#include "imgheader.h"

int brighten(int i)
{
  i = i + i / 2;
  if (i > 255) i = 255;
  return i;
}

int main(int argc, char *argv[])
{
  int tilewidth = 8;
  int tileheight = 8;
  int planes = 4;
  int split = 0;
  int palette = 0;
  int verbose = 0;
  int noempty = 0;

  int opt;

  char outfile[1024] = "", out;
  char *outfileext;

  while ((opt = getopt(argc, argv, "h:w:b:o:spev")) != -1) {
    switch (opt) {
    case 'h':
      tileheight = atoi(optarg);
      if(tileheight <= 0) {
        fprintf(stderr, "invalid tile height");
        return 1;
      }
      break;
    case 'w':
      tilewidth = atoi(optarg);
      if ((tilewidth & 7) || tilewidth > 32 || tilewidth <= 0) {
        fprintf(stderr, "tile width must be 8, 16, 24 or 32\n");
        return 1;
      }
      break;
    case 'b':
      planes = atoi(optarg);
      if(planes != 1 && planes != 2 && planes != 4 && planes != 8) {
        fprintf(stderr, "bit planes must be 1, 2, 4, or 8\n");
        return 1;
      }
      break;
    case 'o':
      strcpy(outfile, optarg);
      break;
    case 's':
      split = 1;
      break;
    case 'p':
      palette = 1;
      break;
    case 'e':
      noempty = 1;
      break;
    case 'v':
      verbose = 1;
      break;
    default:
      fprintf(stderr, "usage: %s [-w tile width] [-h tile height] [-b bit planes] [-c tiles per line] [-o output file] [-s] [-p] [-e] [-v]\n",
              argv[0]);
      return 1;
    }
  }

  if(!outfile[0]) {
    fprintf(stderr, "output file name missing\n");
    return 1;
  }

  FILE *fi = freopen(NULL, "rb", stdin);
  FILE *fo;
  if(!split) {
    fo = fopen(outfile, "wb");
    if(!fo) {
      fprintf(stderr, "could not open file '%s'\n", outfile);
      return 1;
    }
  } else outfileext = getext(outfile);


  struct imgheader h;
  fread(&h, 1, sizeof(h), fi);

  if(h.magic != IMGMAGIC) {
    fprintf(stderr, "not an rri file\n");
    return 1;
  }

  for(int i = 0; i < h.frames; ++i) {
    struct imgframeheader fh;
    fread(&fh, 1, sizeof(fh), fi);

    if(fh.w & (tilewidth - 1)) {
      fprintf(stderr, "image width=%i is not a multiple of tile width = %i in frame %i\n", fh.w, tilewidth, i);
      return 1;
    }

    if(fh.h & (tileheight - 1)) {
      fprintf(stderr, "image height=%i is not a multiple of tile height = %i in frame %i\n", fh.h, tileheight, i);
      return 1;
    }

    int tiles = fh.w / tilewidth;
    int lines = fh.h / tileheight;
    int y = 0;

    if(verbose == 2) fprintf(stderr, "frame %i: tiles = %i lines = %i\n", i, tiles, lines);

    unsigned char* buffer = malloc(fh.w * fh.h);

    fread(buffer, 1, fh.w * fh.h, fi);

    if(noempty) {
      int found = 0;
      for(int j = 0; j < fh.w * fh.h; ++j) if (buffer[j]) { found = 1; break; }
      if(!found) continue;
    }

    if(split) {
      char fn[256]; sprintf(fn, "%s.%i.%s", outfile, i, outfileext);
      fo = fopen(fn, "wb");

      if(!fo) {
        fprintf(stderr, "could not open file '%s'\n", fn);
        return 1;
      }
    }

    for(int ln = 0; ln < lines; ++ln)
      for(int i = 0; i < tiles; ++i)
        for(int m = 0; m < planes; m += 2)
          for(int l = 0; l < tileheight; ++l)
            for(int k = 0; k < (planes < 2 ? planes : 2); ++k) {
              unsigned int byte = 0;

              for(int j = 0; j < tilewidth; ++j) {
                if(buffer[i * tilewidth + l * tilewidth * tiles + j + ln * fh.w * tileheight] & (1 << (k + m)))
                  byte |= 1 << (tilewidth - j - 1);
              }

              for(int n = 0; n < tilewidth; n += 8) {
                fputc(byte, fo);
                byte >>= 8;
              }
            }

    if(palette) {
      unsigned char p = 0;
      for(int n = 0; n < fh.w * fh.h; ++n)
        if(buffer[n] & ((1 << planes) - 1)) { p = buffer[n] >> planes; break; }

      for(int n = 0; n < fh.w * fh.h; ++n)
        if((buffer[n] & ((1 << planes) - 1)) && (buffer[n] >> planes != p) )
          fprintf(stderr, "warning: more than one palette used in frame %i: %i != %i\n", i, p, buffer[n] >> planes);

      for(int n = 0; n < (1 << planes); ++n) {
        unsigned short w =
          (brighten(h.palette[n * 3 + (p << planes) * 3 + 0]) / 8)
          | ((brighten(h.palette[n * 3 + (p << planes) * 3 + 1]) / 8) << 5)
          | ((brighten(h.palette[n * 3 + (p << planes) * 3 + 2]) / 8) << 10);
        fputc(w, fo);
        fputc(w >> 8, fo);
      }

      for(int n = 0; n < (1 << planes); ++n) {
        unsigned short w =
          (h.palette[n * 3 + (p << planes) * 3 + 0] / 8)
          | ((h.palette[n * 3 + (p << planes) * 3 + 1] / 8) << 5)
          | ((h.palette[n * 3 + (p << planes) * 3 + 2] / 8) << 10);
        fputc(w, fo);
        fputc(w >> 8, fo);
      }

      /* for(int n = 0; n < (1 << planes); ++n) { */
      /*   unsigned short w = */
      /*     (h.palette[n * 3 + (p << planes) * 3 + 0] * 3 / 55) */
      /*     | ((h.palette[n * 3 + (p << planes) * 3 + 1] * 3 / 55) << 5) */
      /*     | ((h.palette[n * 3 + (p << planes) * 3 + 2] * 3 / 55) << 10); */
      /*   fputc(w, fo); */
      /*   fputc(w >> 8, fo); */
      /* } */

    }

    free(buffer);

    if(split) fclose(fo);
  }

  if(!split) fclose(fo);

  return 0;
}
