
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <libgen.h>

#include "getext.h"

#define ROOM_WIDTH 32
#define ROOM_HEIGHT 32

#define BG_PRIORITY_BIT 0x2000
#define BG_LIGHT_PALETTE_BIT (2 * 0x400)
#define BG_DARK_PALETTE_BIT (5 * 0x400)

#define COLDATALAYER 8
#define VISLAYER 7
#define LIGHTLAYER 6

#define LAYERMAX 9

#define TILESETDEFMAX 4

union mapdata
{
  struct {
    unsigned char tile;
    unsigned char set;
    unsigned char active;
    unsigned char flags;
  } t;

  unsigned int r;
};

struct mapheader
{
  unsigned int magic;

  unsigned short w, h;
  unsigned short nl;

  unsigned short unused;

  struct tileset {
    unsigned short c, id;
  } t[TILESETDEFMAX];
};

struct portal
{
  int a, u, l, r, t, b, x, y;
  int f, key, lock, entry, key_xx, key_yy;
  int padding[2];
};

unsigned int is_pot(unsigned int x)
{
  return (x & (x - 1)) == 0;
}

unsigned int ilog2(unsigned int x)
{
  int r = 0;
  while (x >>= 1) ++r;
  return r;
}

unsigned char rearrange_collision_bits(unsigned char b)
{
  return ((b & 0xf) << 4) | ((b & 0x30) >> 3);
}

int main(int argc, char *argv[])
{
  int tilesetwidth = 16;
  int tilesetheight = 16;

  FILE *fi = freopen(NULL, "rb", stdin);
  FILE *fo = NULL;
  FILE *finfo = NULL;

  int opt;

  char outfile[1024] = "", out;
  char *outfileext;
  char name[256];

  int verbose = 0;

  while ((opt = getopt(argc, argv, "o:i:v")) != -1) {
    switch (opt) {
    case 'i':
      finfo = fopen(optarg, "w");
      break;
    case 'o':
      strcpy(outfile, optarg);
      strcpy(name, basename(optarg));
      char *c = name;
      while(*c) { if (*c == '.') *c = 0; ++c; }
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

  if(!finfo) {
    fprintf(stderr, "need info file name\n");
    return 1;
  }

  outfileext = getext(outfile);

  // load header

  struct mapheader header;
  fread(&header, 1, sizeof(header), fi);

  // sanity checks

  if(header.w & (ROOM_WIDTH - 1)) {
    fprintf(stderr, "map width = %i not a multiple of room width = %i \n", header.w, ROOM_WIDTH);
    return 1;
  }

  if(header.h & (ROOM_HEIGHT - 1)) {
    fprintf(stderr, "map height = %i not a multiple of room height = %i\n", header.h, ROOM_HEIGHT);
    return 1;
  }

  if(!is_pot(header.w)) {
    fprintf(stderr, "map width must be power of two\n");
    return 1;
  }

  if(!is_pot(header.h)) {
    fprintf(stderr, "map height must be power of two\n");
    return 1;
  }

  if(header.w != header.h) {
    fprintf(stderr, "map width and map height must be euqal\n");
    return 1;
  }

  if(header.nl < LAYERMAX) {
    fprintf(stderr, "not enough layers in map\n");
    return 1;
  }


  // load data

  union mapdata* buffer = malloc(header.w * header.h * header.nl * 4);
  fread(buffer, 1, header.w * header.h * header.nl * 4, fi);

  struct portal* portals = malloc(header.w * header.h / (ROOM_WIDTH * ROOM_HEIGHT) * 64);
  fread(portals, 1, header.w * header.h / (ROOM_WIDTH * ROOM_HEIGHT) * 64, fi);

  // recode tile data

  int i = 0;
  for(int layer = 0; layer < LAYERMAX; ++layer)
    for(int y = 0; y < header.h; ++y) {
      for(int x = 0; x < header.w; ++x, ++i)
  {
    unsigned int r = buffer[i].r;

    buffer[i].t.active = r > 0;

    if(!buffer[i].t.active) {
      continue;
    }

    int tid = r & 0xffff;

    buffer[i].t.flags = r >> 24;
    buffer[i].t.flags =
      ((buffer[i].t.flags & 0x40) ? 0x80 : 0x00)
      | ((buffer[i].t.flags & 0x80) ? 0x40 : 0x00);

    int ts = 0;
    int tsid = -1;

    for(int t = 0; t < TILESETDEFMAX; ++t)
      if(header.t[t].id <= tid && header.t[t].id > tsid) { ts = t; tsid = header.t[t].id; }

    int tlayer = layer < LIGHTLAYER ? 0 : (layer - LIGHTLAYER + 1);

    if (ts != tlayer) {
      const char *layernames[] = {"tileset", "light", "vis", "collsion"};

      if(verbose)
        fprintf(stderr, "warning: wrong tile in %s layer at %i:[%i, %i]\n", layernames[tlayer], layer, x, y);
      buffer[i].t.active = 0;
    }

    tid -= header.t[ts].id;

    unsigned short tx = tid % header.t[ts].c;
    unsigned short ty = tid / header.t[ts].c;

    buffer[i].t.tile = (tx & (tilesetwidth - 1)) | ((ty & (tilesetheight - 1)) * tilesetwidth);
    buffer[i].t.set = (tx / tilesetwidth) | ((ty / tilesetheight) * (header.t[ts].c / tilesetwidth));

  }
    }


  printf(".segment \"rodata\"\n\n");
  /* printf("rooms_in_map = $%04x\n\n", header.w / ROOM_WIDTH); */
  printf("roomtable:\n\n");

  fprintf(finfo, ".segment \"rodata\"\n\n");
  fprintf(finfo, "roominfotable:\n\n");

  unsigned short roomdata[ROOM_WIDTH * ROOM_HEIGHT * LAYERMAX];

  int rn = 0;

  int roomcount = 0;

  for(int ry = 0; ry < header.h; ry += ROOM_HEIGHT)
    for(int rx = 0; rx < header.w; rx += ROOM_WIDTH, ++rn) {

      // find tilesets used in room and create bidirectional mapping

      unsigned char setmap[256];

      unsigned char set[4] = {0, 0, 0, 0};
      int nsets = 0;

      for(int l = 0; l < LIGHTLAYER; ++l)
        for(int y = 0; y < ROOM_HEIGHT; ++y)
          for(int x = 0; x < ROOM_WIDTH; ++x)
            if (buffer[(ry + y) * header.w + (rx + x) + l * header.w * header.h].t.active)
              {
                unsigned char s = buffer[(ry + y) * header.w + (rx + x) + l * header.w * header.h].t.set;
                if(nsets >= 1 && set[0] == s) continue;
                if(nsets >= 2 && set[1] == s) continue;
                if(nsets >= 3 && set[2] == s) continue;
                if(nsets >= 4 && set[3] == s) continue;
                if(nsets >= 4) {
                  fprintf(stderr, "too many tilesets used in room [%i, %i]\n", rx, ry);
                  return 1;
                }
                set[nsets] = s;
                // TODO: implement tileset mapping
                setmap[s] = /*nsets*/ s;
                ++nsets;
              }

      if(nsets == 0) {
        printf("\t.word .loword(data_%s_room_0)\n", name);
        printf("\t.word ^data_%s_room_0\n", name);


        fprintf(finfo, "\t.res $20\n\n");
        continue;
      }

      ++roomcount;

      char fn[256]; sprintf(fn, "%s.%i.%s", outfile, rn, outfileext);
      fo = fopen(fn, "wb");

      if(!fo) {
        fprintf(stderr, "could not open file '%s'\n", fn);
        return 1;
      }

      for(i = nsets; i < 4; ++i) set[i] = 0xff;

      printf("\t.word .loword(data_%s_room_%i)\n", name, rn);
      printf("\t.word ^data_%s_room_%i\n", name, rn);

      fprintf(finfo, "\t.byte $%02x, $%02x, $%02x, $%02x\n",
              set[0], set[1], set[2], set[3]);

      fprintf(finfo, "\t.byte $%02x, $%02x, $%02x, $%02x, $%02x\n",
              portals[rn].a, portals[rn].l, portals[rn].r, portals[rn].t, portals[rn].b);

      fprintf(finfo, "\t.word $%04x, $%04x\n",
              (unsigned short)portals[rn].x, (unsigned short)portals[rn].y);

      fprintf(finfo, "\t.byte $%02x\n",
              (unsigned short)portals[rn].f);

      fprintf(finfo, "\t.byte $%02x, $%02x, $%02x, $%02x, $%02x\n",
              portals[rn].key, portals[rn].lock, portals[rn].entry, portals[rn].key_xx, portals[rn].key_yy);

      fprintf(finfo, "\t.res 13\n\n");

      i = 0;

      for(int y = 0; y < ROOM_HEIGHT; ++y)
        for(int x = 0; x < ROOM_WIDTH; ++x, ++i) {
          union mapdata tile[LAYERMAX];
          unsigned short stile[LAYERMAX];
          for(int l = 0; l < LAYERMAX; ++l) {
            tile[l] = buffer[(ry + y) * header.w + (rx + x) + l * header.w * header.h];

            if(tile[l].t.active) {
              stile[l] = (unsigned short)tile[l].t.tile;

              if(l >= LIGHTLAYER) {
                //stile[l] = ( (stile[l] % 3) + 1) | ((stile[l] / 3) << 10);
              }

              else stile[l]  |= ((unsigned short)( (setmap[tile[l].t.set] << 2)
                                                   | setmap[tile[l].t.set]
                                                   | (tile[l].t.flags)) << 8);
            } else {
                stile[l] = l < LIGHTLAYER ? 0xff : 0x00;
            }
          }

          unsigned char *lroomdata = (unsigned char*)roomdata;

          int firsttile, secondtile, light;

          for(firsttile = 5; firsttile >= 0; --firsttile) if(tile[firsttile].t.active) break;
          if(firsttile > 0) {
            for(secondtile = firsttile - 1; secondtile >= 0; --secondtile) if(tile[secondtile].t.active) break;
          } else {
            secondtile = 0;
          }


          //light = stile[LIGHTLAYER] + 4 - 2 * (firsttile < 2 ? firsttile : 2);
          //if(light > 15) light = 15;

          light = stile[LIGHTLAYER];

          // collision layer
          lroomdata[i + 5 * ROOM_WIDTH * ROOM_HEIGHT] = rearrange_collision_bits(stile[COLDATALAYER]);

          // light layer
          lroomdata[i + 4 * ROOM_WIDTH * ROOM_HEIGHT] = stile[VISLAYER] * 4;

          // foreground layer
          roomdata[i]
            = (firsttile >= 4 ? BG_PRIORITY_BIT : 0)
            + (firsttile >= 2 ? BG_LIGHT_PALETTE_BIT : BG_DARK_PALETTE_BIT)
            + stile[firsttile];

          // background layer
          roomdata[i + 1 * ROOM_WIDTH * ROOM_HEIGHT]
            = (secondtile >= 4 ? BG_PRIORITY_BIT : 0)
            + (secondtile >= 2 ? BG_LIGHT_PALETTE_BIT : BG_DARK_PALETTE_BIT)
            + stile[secondtile];
        }

      fwrite(roomdata, 1, ROOM_WIDTH * ROOM_HEIGHT * 6, fo);

      fclose(fo);

    }

  fprintf(stderr, "%i rooms total\n", roomcount);

  return 0;
}
