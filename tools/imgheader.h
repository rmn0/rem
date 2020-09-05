
// all the tools dealing with graphics use this raw image data format with a minimal header
// to make passing around intermediate representations between the different components of the tool chain easier.

#ifndef IMGHEADER_H
#define IMGHEADER_H

#define IMGMAGIC (*(unsigned int*)"rri")

struct imgheader
{
  unsigned int magic;
  unsigned int frames;
  unsigned char palette[256 * 3];
};

struct imgframeheader
{
  unsigned int w, h, t;
};

#endif
