#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define ASCII_HEXLEN 3


static void defaultHexOut(char *text) {
  int i;
  size_t len;

  for (i = 0; i < (len = strlen(text)); i++) {
    printf("0x%X%c", text[i], (i == len-1 ? '\n' : ' '));
  }
}

static void dwordHexOut(char *text) {
  int i;
  size_t len;

  for (i = 0; i < (len = strlen(text)); i++) {
    printf("%s%X%s", (i % 4 == 0 ? (i == 0 ? "0x" : " 0x") : ""), text[i], (i == len-1 ? "\n" : ""));
  }
}

static void strHexOut(char *text) {
  int i;
  size_t len;
 
  for (i = 0; i < (len = strlen(text)); i++) {
    printf("%s%X%s", (i == 0 ? "0x" : ""), text[i], (i == len-1 ? "\n" : ""));
  }
}

int main(int argc, char **argv)
{
  if (argc != 2) {
    fprintf(stderr, "usage: %s [TEXT]\n", argv[0]);
    return 1;
  }

  defaultHexOut(argv[1]);
  dwordHexOut(argv[1]);
  strHexOut(argv[1]);
  return 0;
}
