/*
 * build with: gcc -std=c99 -D_GNU_SOURCE=1 -Wall -O2 -ffunction-sections -fdata-sections -fomit-frame-pointer ./suidcmd.c -o ./suidcmd
 * strip -s ./suidcmd
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>


#ifndef CMD
#define CMD "/usr/sbin/ether-wake"
#endif

int main(int argc, char** argv)
{
  uid_t ruid, euid, suid;

  if (getresuid(&ruid, &euid, &suid) != 0) {
    perror("getresuid()");
  } else {
    printf("%s: RUID:%u , EUID:%u , SUID:%u\n", argv[0], ruid, euid, suid);
  }

  if (setuid(0) != 0) {
    perror("setuid(0)");
  } else printf("%s: setuid(0)\n", argv[0]);

  char* cmd = NULL;
  if (asprintf(&cmd, "%s", CMD) <= 0) {
    fprintf(stderr, "%s: asprintf(\"%s\") error\n", argv[0], CMD);
    return 1;
  }

  char* prev_cmd = NULL;
  for (int i = 1; i < argc; ++i) {
    prev_cmd = cmd;
    if (asprintf(&cmd, "%s %s", prev_cmd, argv[i]) < 0) {
      fprintf(stderr, "%s: asprintf(\"%s\") error\n", argv[0], argv[i]);
      return 1;
    }
    free(prev_cmd);
  }

  printf("system(\"%s\")\n", cmd);
  int retval = -1;
  switch ( (retval = system(cmd)) ) {
    case -1: fprintf(stderr, "%s: could not create child process..\n", argv[0]); return 1;
    case 127: fprintf(stderr, "%s: could not execute shell (child process)..\n", argv[0]); return 1;
    default:
      printf("%s: child process returned with: %d\n", argv[0], retval);
  }
  return 0;
}
