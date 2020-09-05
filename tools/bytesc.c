
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>

#include "imgheader.h"

int main(int argc, char *argv[])
{
  int layerwidth = 128;
  int layerheight = 128;

  int opt;

  int verbose = 0;

  int tilebase = 0;

  FILE *ft = NULL;

  while ((opt = getopt(argc, argv, "h:w:t:b:v")) != -1) {
    switch (opt) {
    case 'v':
      verbose = 1;
      break;
    case 'h':
      layerheight = atoi(optarg);
      if(layerheight <= 0) {
        fprintf(stderr, "invalid layer height");
        return 1;
      }
      break;
    case 'w':
      layerwidth = atoi(optarg);
      if(layerheight <= 0) {
        fprintf(stderr, "invalid layer width");
        return 1;
      }
      break;
    case 't':
      ft = fopen(optarg, "wb");
      break;
    case 'b':
      tilebase = atoi(optarg);
      break;
    default:
      fprintf(stderr, "usage: %s [-w layer width] [-h layer height] [-t tilemap file] [-b tile base]\n",
              argv[0]);
      return 1;
    }
  }

  FILE *fi = freopen(NULL, "rb", stdin);
  FILE *fo = freopen(NULL, "wb", stdout);

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



  if((fh.w % layerwidth) != 0) {
    fprintf(stderr, "image width=%i is not a multiple of tile width = %i\n", fh.w, layerwidth);
    return 1;
  }

  int layersx = (fh.w / layerwidth);
  int layersy = (fh.h / layerheight);

  int layers = layersx * layersy;


  unsigned char* buffer = malloc(layers * layerwidth * layerheight);
  fread(buffer, 1, layers * layerwidth * layerheight, fi);

  unsigned short* tilemap = malloc(layers * 2);
  unsigned int* tiles = malloc(layers * 4);

  if(ft) {
    int nt = 0;

    for(int i = 0; i < layers; ++i) {
      int isunique = 1;
      for(int j = 0; j < nt; ++j) {
        int tile1x = (i % layersx) * layerwidth;
        int tile1y = (i / layersx) * layerheight;
        int tile2x = (tiles[j] % layersx) * layerwidth;
        int tile2y = (tiles[j] / layersx) * layerheight;
        int issame = 1;
        for(int y = 0; y < layerheight; ++y)
          for(int x = 0; x < layerwidth; ++x)
            if(buffer[(tile1y + y) * layersx * layerwidth + tile1x + x]
               != buffer[(tile2y + y) * layersx * layerwidth + tile2x + x])
              issame = 0;
        if(issame) {
          tilemap[i] = j + tilebase;
          isunique = 0;
          break;
        }
      }
      if(isunique) {
        tilemap[i] = nt + tilebase;
        tiles[nt] = i;
        ++nt;
      }
    }

    if(verbose) fprintf(stderr, "%i of %i tiles are unique\n", nt, layers);

    fwrite(tilemap, 1, 2 * layers, ft);

    layers = nt;

  } else {
    for(int i = 0; i < layers; ++i) tiles[i] = i;
  }

  h.frames = layers;

  fh.w = layerwidth;
  fh.h = layerheight;

  fwrite(&h, 1, sizeof(h), fo);

  for(int i = 0; i < layers; ++i) {
    fwrite(&fh, 1, sizeof(fh), fo);

    int tilex = (tiles[i] % layersx) * layerwidth;
    int tiley = (tiles[i] / layersx) * layerheight;

    for(int y = 0; y < layerheight; ++y)
      fwrite(buffer + (tiley + y) * layersx * layerwidth + tilex, 1, layerwidth, fo);
  }

  free(tiles);
  free(tilemap);
  free(buffer);

  if(ft) fclose(ft);

  return 0;
}
