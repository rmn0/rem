
#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <dirent.h>

#include <sys/stat.h>
#include <sys/types.h>

#include "getext.h"

off_t fsize(const char *filename) {
  struct stat st;

  if (stat(filename, &st) == 0)
    return st.st_size;

  return -1;
}

#define MAXFILE 0x10000

#define BANK 0x10000

#define MAXBANK 0x100


struct file
{
  char filename[256];
  char path[256];
  char basename[256];
  char *extension;
  int size;
  int is_bank;
} files[MAXFILE];

int main(int argc, char *argv[])
{
  int opt;
  int palette = 0;
  int frame = -1;
  int verbose = 0;
  int bank = 0;
  int include = 0;

  FILE *fo = NULL;
  DIR *dp;
  struct dirent *ep;
  char directory[1024];
  char filename[1024] = "";

  while ((opt = getopt(argc, argv, "d:o:b:iv")) != -1) {
    switch (opt) {
    case 'b':
      bank = atoi(optarg);
      break;
    case 'd':
      strcpy(directory, optarg);
      dp = opendir (optarg);
      if(!dp) {
        fprintf(stderr, "directory '%s' not found\n", optarg);
        return 1;
      }
      break;
    case 'o':
      strcpy(filename, optarg);
      break;
    case 'i':
      include = 1;
      break;
    case 'v':
      verbose = 1;
      break;
    default:
      fprintf(stderr, "usage: %s [-d resource directory] [-o output file] [-b starting bank no] [-i] [-v]\n",
              argv[0]);
      return 1;
    }
  }

  if(!dp) {
    fprintf(stderr, "directory name missing\n");
    return 1;
  }

  remove(filename);


  int filecount = 0;

  if (dp != NULL) {
    while ((ep = readdir (dp))) {
      strcpy(files[filecount].filename, ep->d_name);
      strcpy(files[filecount].basename, files[filecount].filename);
      sprintf(files[filecount].path, "%s%s", directory, ep->d_name);
      files[filecount].extension = getext(files[filecount].basename);

      if((files[filecount].extension[0] == (include ? 'i' : 'r')
          || files[filecount].extension[0] == (include ? 'i' : 'b'))
         && files[filecount].extension[1] == 0) {
        char *c = files[filecount].basename;
        while(*c) { if (*c == '.') *c = '_'; ++c; }

        files[filecount].size = fsize(files[filecount].path);

        if(verbose) fprintf(stderr, "- %s %s %i\n",
                            files[filecount].filename, files[filecount].basename, files[filecount].size);

        if(files[filecount].size > BANK && !include) {
          fprintf(stderr, "resource %s does not fit in a rom bank (%i bytes)\n",
                  files[filecount].filename, files[filecount].size);
        }

        files[filecount].is_bank = files[filecount].extension[0] == 'b';

        ++filecount;
      }
    }
    closedir (dp);
  }

  if(filecount == 0) {
    fprintf(stderr, "no resource files found\n");
    return 1;
  }

  fo = fopen(filename, "w");
  if(!fo) {
    fprintf(stderr, "could not open file '%s'\n", optarg);
    return 1;
  }

  if(!include) {

    int bankbytes[MAXBANK];

    int bank_assign[MAXFILE];

    for(int i = 0; i < MAXBANK; ++i) bankbytes[i] = 0;

    for(int i = 0; i < filecount; ++i) {
      for(int j = 0; j < MAXBANK; ++j) {
        if(files[i].is_bank) {
          if(bankbytes[j] == 0) {
            bank_assign[i] = j;
            bankbytes[j] += files[i].size;
            break;
          }
        }
        else {
          if(bankbytes[j] + files[i].size <= BANK) {
            bank_assign[i] = j;
            bankbytes[j] += files[i].size;
            break;
          }
        }
      }
    }

    for(int i = 0; i < filecount; ++i) {
      fprintf(fo, "\n.segment \"res%i\"\n\n", bank + bank_assign[i]);
      fprintf(fo, "\t.export data_%s\n", files[i].basename);
      fprintf(fo, "\t.export data_%s_end\n\n", files[i].basename);
      fprintf(fo, "\tdata_%s:\n", files[i].basename);
      fprintf(fo, "\t.incbin \"%s\"\n", files[i].filename);
      fprintf(fo, "\tdata_%s_end:\n\n", files[i].basename);
    }

    for(int i = 0; i < MAXBANK; ++i) {
      if(bankbytes[i] == 0) break;
      printf("bank %i : %i bytes\n", i + bank, bankbytes[i]);
    }


  } else {
    for(int i = 0; i < filecount; ++i)
      fprintf(fo, "\t.include \"%s\"\n", files[i].filename);
  }

  fclose(fo);

  return 0;
}
