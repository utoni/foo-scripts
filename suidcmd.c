/*
 * build with: gcc -std=c99 -D_GNU_SOURCE=1 -Wall -O2 -ffunction-sections -fdata-sections -fomit-frame-pointer ./suidcmd.c -o ./suidcmd
 * strip -s ./suidcmd
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/wait.h>


#ifndef CMD
#define CMD "/usr/sbin/ether-wake"
#endif


int safe_exec(const char* cmdWithArgs)
{
  pid_t child;
  if ( (child = fork()) == 0 ) {
    size_t szCur = 0, szMax = 10;
    char** args = calloc(szMax, sizeof(char**));
    const char* cmd = NULL;

    const char* prv = cmdWithArgs;
    const char* cur = NULL;
    while ( (cur = strchr(prv, ' ')) ) {
      if (cmd == NULL)
        cmd = strndup(prv, cur-prv);

      args[szCur++] = strndup(prv, cur-prv);
      if (szCur >= szMax) {
        szMax *= 2;
        args = realloc(args, sizeof(char**)*szMax);
      }

      cur++;
      prv = cur;
    }
    if (cmd == NULL) {
      cmd = cmdWithArgs;
    } else {
      args[szCur++] = strndup(prv, cur-prv);
    }
    args[szCur] = NULL;
    execv(cmd, args);
  } else {
    int retval = 0;
    waitpid(child, &retval, 0);
    return retval;
  }
  return -1;
}

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

  int retval = -1;
  switch ( (retval = safe_exec(cmd)) ) {
    case -1: fprintf(stderr, "%s: could not create child process..\n", argv[0]); return 1;
    case 127: fprintf(stderr, "%s: could not execute shell (child process)..\n", argv[0]); return 1;
    default:
      printf("%s: child process returned with: %d\n", argv[0], retval);
  }
  free(cmd);
  return 0;
}
