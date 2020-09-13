
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include "imgheader.h"

#define NSPANS 4

#define INDEX_ROWS 32

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

  unsigned short* spantable = malloc(fh.h * NSPANS * 2);

  for(int yy = 0; yy < fh.h; ++yy) {
    spantable[yy * NSPANS + 0] = 0xff;
    spantable[yy * NSPANS + 1] = 0;
    spantable[yy * NSPANS + 2] = 0xff;
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
        spantable[yy * NSPANS + span] = xx - ((span & 1) ? 1 : 0);
        lastxx = xx;
        ++span;
      }
      lastc = c;
    }
  }


  FILE *fo = fo = fopen(outfile, "wb");

  unsigned short dma_table_start[4];
  unsigned short dma_table_length[4];
  int total_length = 0;
  unsigned char dma_tables[4][256 * 3];

  unsigned char index_tables[4][256 / INDEX_ROWS * 2];

  for(int xx = 0; xx < NSPANS; xx++) {
    int table_ofs = 0;
    int c, lc, lyy, ayy = 0;
    lc = spantable[xx];
    lyy = 0;


    // extra entry for skipping ahead

    dma_tables[xx][table_ofs + 0] = 0x78;
    dma_tables[xx][table_ofs + 1] = spantable[xx];
    dma_tables[xx][table_ofs + 2] = 1;
    table_ofs += 3;


    // table entries

    int index = 0;


    for(int yy = 0; yy < fh.h; yy++) {

      if((yy % INDEX_ROWS) == 0) {
        index_tables[xx][index * 2 + 0] = table_ofs / 3;
        index_tables[xx][index * 2 + 1] = lyy;
        ++index;
      }

      c = spantable[yy * NSPANS + xx];
      if(c != lc) {
        /* printf("%i, %i\n", yy - lyy, lc); */
        dma_tables[xx][table_ofs + 0] = yy - lyy;
        dma_tables[xx][table_ofs + 1] = lc;
        dma_tables[xx][table_ofs + 2] = 1;
        table_ofs += 3;
        lc = c;
        ayy = lyy;
        lyy = yy;
      }


    }

    /* printf("----\n"); */

    // disable window

    for(; index < 256 / INDEX_ROWS; ++index) {
      index_tables[xx][index * 2 + 0] = table_ofs / 3;
      index_tables[xx][index * 2 + 1] = 0xff;
    }

    dma_tables[xx][table_ofs + 0] = 0x7f;
    dma_tables[xx][table_ofs + 1] = spantable[xx];
    dma_tables[xx][table_ofs + 2] = 1;
    table_ofs += 3;

    // end of table

    dma_tables[xx][table_ofs] = 0;
    dma_table_length[xx] = table_ofs + 1;
    total_length += dma_table_length[xx];
  }

  dma_table_start[0] = 8 + sizeof(index_tables);
  dma_table_start[1] = dma_table_start[0] + dma_table_length[0];
  dma_table_start[2] = dma_table_start[1] + dma_table_length[1];
  dma_table_start[3] = dma_table_start[2] + dma_table_length[2];

  /* for(int xx = 0; xx < 4; ++xx) */
  /*   for(int yy = 0; yy < 16; ++yy) */
  /*     index_tables[xx][yy * 2] += dma_table_start[xx]; */

  fwrite(dma_table_start, 2, 4, fo);

  fwrite(index_tables, 1, sizeof(index_tables), fo);

  fwrite(dma_tables[0], 1, dma_table_length[0], fo);
  fwrite(dma_tables[1], 1, dma_table_length[1], fo);
  fwrite(dma_tables[2], 1, dma_table_length[2], fo);
  fwrite(dma_tables[3], 1, dma_table_length[3], fo);

  fclose(fo);

  free(spantable);
  free(buffer);

  return 0;
}
