
#ifndef GETEXT_H
#define GETEXT_H

#include <string.h>

char* getext(char *fname)
{
  char *end = fname + strlen(fname);

  while (end > fname && *end != '.' && *end != '\\' && *end != '/') {
    --end;
  }
  if ((end > fname && *end == '.') &&
      (*(end - 1) != '\\' && *(end - 1) != '/')) {
    *end = 0;
    return end + 1;
  }
  return fname + strlen(fname);
}

#endif
