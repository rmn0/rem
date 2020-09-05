
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>

#include <gif_lib.h>

#include "imgheader.h"

void writeframe(GifFileType *gif, SavedImage *img, unsigned char *canvas, FILE *fo, int verbose)
{
  static int t = 0;

  struct imgframeheader fh;
  fh.w = gif->SWidth;
  fh.h = gif->SHeight;

  for(int ii = 0; ii < img->ExtensionBlockCount; ++ii) {
    if(img->ExtensionBlocks[ii].Function == GRAPHICS_EXT_FUNC_CODE) {
      t = *(unsigned short*)(img->ExtensionBlocks[ii].Bytes + 1);
      if (verbose) fprintf(stderr, "DelayTime = %i\n", t);
      break;
    }
  }

  fh.t = t / 2;

  fwrite(&fh,  1, sizeof(fh), fo);

  int yy, xx;


  for(yy = 0; yy < img->ImageDesc.Height; ++yy) {
    for(xx = 0; xx < img->ImageDesc.Width; ++xx) {
      int c = img->RasterBits[yy * img->ImageDesc.Width + xx];
      canvas[(xx + img->ImageDesc.Left) + (yy + img->ImageDesc.Top) * gif->SWidth] = c;
      /* if(verbose) fprintf(stderr, c ? "." : " "); */
    }
    /* if(verbose) fprintf(stderr, "\n"); */
  }

  fwrite(canvas, 1, fh.w * fh.h, fo);
}

int main(int argc, char *argv[])
{
  GifFileType *gif = NULL;

  int opt;
  int frame = -1;
  int verbose = 0;

  while ((opt = getopt(argc, argv, "n:f:v")) != -1) {
    switch (opt) {
    case 'v':
      verbose = 1;
      break;
    case 'f':
      gif = DGifOpenFileName(optarg, NULL);
      break;
    case 'n':
      frame = atoi(optarg);
      break;
    default:
      fprintf(stderr, "usage: %s [-n frame number] [-f filename]\n",
              argv[0]);
      return 1;
    }
  }

  if(!gif) {
    fprintf(stderr, "error in DGifOpenFileName()\n");
    return 1;
  }

  if(GIF_OK != DGifSlurp(gif)) {
    fprintf(stderr, "error in DGifSlurp()\n");
  }

  FILE *fo = freopen(NULL, "wb", stdout);

  struct imgheader h;

  h.magic = IMGMAGIC;

  memcpy(h.palette, gif->SColorMap->Colors, gif->SColorMap->ColorCount * 3);

  unsigned char *canvas = malloc(gif->SWidth * gif->SHeight);

  memset(canvas, 0, gif->SWidth * gif->SHeight);

  if(frame >= 0) {
    h.frames = 1;
    fwrite(&h, 1, sizeof(h), fo);

    if(frame >= gif->ImageCount) {
      fprintf(stderr, "requested frame %i, gif has %i frames\n", frame, gif->ImageCount);
    }

    writeframe(gif, &gif->SavedImages[frame], canvas, fo, verbose);

  } else {
    h.frames = gif->ImageCount;
    fwrite(&h, 1, sizeof(h), fo);

    for(int ii = 0; ii < gif->ImageCount; ++ii) {
      writeframe(gif, &gif->SavedImages[ii], canvas, fo, verbose);
    }
  }

  free(canvas);

  DGifCloseFile(gif, NULL);

  return 0;
}
