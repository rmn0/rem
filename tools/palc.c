
#include "stdio.h"

int main()
{
  char id[256];
  int version;
  int entrys;

  scanf("%s %i %i", id, &version, &entrys);

  printf(".word ");

  for(int ii = 0; ii < 32; ++ii) {
    int r, g, b;
    scanf("%i %i %i", &r, &g, &b);
    unsigned short p = (r / 8) + ((g / 8) << 5) + ((b / 8) << 10);
    printf("$%04x", p);
    if(ii < 31) printf(", ");
  }

}
