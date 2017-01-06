/*
 * build with: gcc -Wall -O2 -D_GNU_SOURCE=1 -D_HAS_CMD=1 -D_HAS_MSG=1 -D_HAS_HOSTENT=1 -D_HAS_SIGNAL=1 -D_HAS_UTMP=1 -D_HAS_SYSINFO -ffunction-sections -fdata-sections -ffast-math -fomit-frame-pointer dummyshell.c -o dummyshell
 * strip -s dummyshell
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <time.h>
#include <ctype.h>       /* isprint(...) */
#include <sys/ioctl.h>   /* ioctl(...) */
#include <stdint.h>      /* UINT8_MAX */
#include <string.h>      /* memset(...) */
#include <sys/types.h>
#include <pwd.h>         /* getpwuid(...) */
#ifdef _HAS_CMD
#include <sys/wait.h>
#else
#warning "COMMANDS(_HAS_CMD) disabled!"
#endif
#ifdef _HAS_MSG
#include <errno.h>
#include <string.h>
#else
#warning "MESSAGE(_HAS_MSG) disabled!"
#endif
#ifdef _HAS_HOSTENT
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#else
#warning "HOSTENT(_HAS_HOSTENT) disabled!"
#endif
#ifdef _HAS_SIGNAL
#include <signal.h>      /* signal(...) */
#else
#warning "SIGNAL(_HAS_SIGNAL) disabled!"
#endif
#ifdef _HAS_UTMP
#include <utmp.h>        /* utmp structure */
#else
#warning "UTMP(_HAS_UTMP) disabled!"
#endif
#ifdef _HAS_SYSINFO
#include "sys/types.h"   /* sysinfo structture */
#include "sys/sysinfo.h" /* sysinfo(...) */
#else
#warning "SYSINFO(_HAS_SYSINFO) disabled!"
#endif

/* for print_memusage() and print cpuusage() see: http://stackoverflow.com/questions/63166/how-to-determine-cpu-and-memory-consumption-from-inside-a-process */


static const char keymsg[] = " ['q'-EXIT | 'm'-MESSAGE | 'c'-CMDS] ";
static const char txtheader[] =
  "**************\n"
  "* dummyshell *\n"
  "**************\n"
  "!(C) by Toni Uhlig\n"
  "@see: https://raw.githubusercontent.com/lnslbrty/foo-scripts/master/dummyshell.c\n";

static volatile unsigned char doLoop = 1;


static void printQuitLoop(void) {
  printf("quit in 3 .. ");
  fflush(stdout);
  sleep(1);
  printf("2 .. ");
  fflush(stdout);
  sleep(1);
  printf("1 .. ");
  fflush(stdout);
  sleep(1);
  printf("\n");
  doLoop = 0;
}

#define I_CLEARBUF 0x1
static char readInput(char* buf, size_t* siz, size_t szMax, char key, int flags) {
  if (flags & I_CLEARBUF) {
    memset(&buf[0], '\0', szMax);
    *siz = 0;
  } else switch (key) {
    case '\n':
      break;
    case 127:
      if (*siz > 0)
        buf[--(*siz)] = '\0';
      break;
    case EOF: break;
    default:
      if (isprint(key) && *siz < szMax)
        buf[(*siz)++] = key;
        break;
  }
  return key;
}

#ifdef _HAS_CMD
struct __attribute__((__packed__)) cmd {
  char* name;
  char* path;
};

static struct cmd cmds[] = {
  { "ether-wake", "/usr/sbin/ether-wake" },
  { "echo", "/bin/echo" },
  { NULL, NULL }
};

static void print_cmds(void)
{
  size_t idx = 0;
  printf("\33[2K\r[COMMANDS]\n");
  while ( cmds[idx++].path != NULL ) {
    printf("  [%lu] %s\n", (unsigned long int)idx-1, ( cmds[idx-1].name != NULL ? cmds[idx-1].name : "unknown" ));
  }
}

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
    exit(-5);
  } else if (child != -1) {
    int retval = 0;
    waitpid(child, &retval, 0);
    return retval;
  }
  return -6;
}

static int exec_cmd(size_t i, char* args, size_t szArgs)
{
  size_t idx = (size_t)-1;
  while ( cmds[++idx].path != NULL ) {
    if (idx == i) {
      size_t siz = strlen(cmds[idx].path)+szArgs+1;
      char execbuf[siz+1];
      memset(&execbuf[0], '\0', siz+1);
      snprintf(&execbuf[0], siz+1, "%s %s", cmds[idx].path, args);
      return safe_exec(&execbuf[0]);
    }
  }
  return -7;
}
#endif

#ifdef _HAS_MSG
#define MSGFILE "/tmp/dummyshell.msg"
#define STRLEN(str) (sizeof(str)/sizeof(str[0]))
static FILE* msgfile = NULL;
static void init_msg(void)
{
  msgfile = fopen(MSGFILE, "a+");
  if (!msgfile) {
    fprintf(stderr, "fopen(\"%s\"): %s\n", MSGFILE, strerror(errno));
  }
}

struct __attribute__((__packed__)) msgHdr {
  uint8_t szFrom;
  uint8_t szMsg;
  time_t timestamp;
};

struct __attribute__((__packed__)) msg {
  char* from;
  char* msg;
};

static int read_msg(struct msgHdr* hdr, struct msg* msg)
{
  if (!msgfile) return -1;
  int ok = 1;
  size_t rb = 0;
  if ( (rb = fread(hdr, sizeof(struct msgHdr), 1, msgfile)) == 1 ) {
    msg->from = calloc(hdr->szFrom+1, sizeof(char));
    msg->msg = calloc(hdr->szMsg+1, sizeof(char));
    if ( (rb = fread(&(msg->from[0]), sizeof(char), hdr->szFrom, msgfile)) != hdr->szFrom )
      ok = 0;
    if ( (rb = fread(&(msg->msg[0]), sizeof(char), hdr->szMsg, msgfile)) != hdr->szMsg )
      ok = 0;
    char newline = 0;
    if ( (rb = fread(&newline, sizeof(char), 1, msgfile)) != 1 )
      ok = 0;
    if (!ok || newline != '\n') {
      free(msg->from);
      free(msg->msg);
      msg->from = NULL;
      msg->msg = NULL;
      return -1;
    }
    return 0;
  }
  return -1;
}

static int print_msg(void) {
  struct msgHdr hdr;
  struct msg msg;
  memset(&hdr, '\0', sizeof(struct msgHdr));
  memset(&msg, '\0', sizeof(struct msg));
  if (read_msg(&hdr, &msg) == 0) {
    struct tm localtime;
    struct passwd* pwd = NULL;
    unsigned long int uid = strtoul(msg.from, NULL, 10);
    if ( (pwd = getpwuid((uid_t)uid)) ) {
      free(msg.from);
      msg.from = strdup(pwd->pw_name);
    }
    if (localtime_r(&hdr.timestamp, &localtime) != NULL) {
      printf("\33[2K\r[%02d-%02d-%04d %02d:%02d:%02d] Message from %s: %s\n", localtime.tm_mday, localtime.tm_mon+1, 1900+localtime.tm_year, localtime.tm_hour, localtime.tm_min, localtime.tm_sec, msg.from, msg.msg);
    } else {
      printf("\33[2K\r\aMessage from %s: %s\n", msg.from, msg.msg);
    }
    free(msg.from);
    free(msg.msg);
    return 0;
  }
  return -1;
}

static int write_msg(char* msg) {
  char from[6];
  memset(&from[0], '\0', STRLEN(from));
  if (snprintf(&from[0], STRLEN(from), "%u", getuid()) > 0) {
    struct msgHdr hdr;
    hdr.szFrom = strnlen(from, STRLEN(from));
    hdr.szMsg = strnlen(msg, UINT8_MAX);
    hdr.timestamp = time(NULL);
    char* buf = calloc(sizeof(hdr) + hdr.szFrom + hdr.szMsg + 2, sizeof(char));
    if (buf) {
      memcpy(buf, &hdr, sizeof(hdr));
      memcpy(buf+sizeof(hdr), from, hdr.szFrom);
      memcpy(buf+sizeof(hdr)+hdr.szFrom, msg, hdr.szMsg);
      *(buf + sizeof(hdr) + hdr.szFrom + hdr.szMsg) = '\n';
      int failed = 1;
      if ( fwrite(buf, sizeof(char), sizeof(hdr)+hdr.szFrom+hdr.szMsg+1, msgfile) == sizeof(hdr)+hdr.szFrom+hdr.szMsg+1)
        failed = 0;
      free(buf);
      return failed;
    }
  }
  return -1;
}
#endif

#ifdef _HAS_HOSTENT
#define ARP_STRING_LEN 1024
#define ARP_IP_LEN 32
#define XSTR(s) STR(s)
#define STR(s) #s
static void print_nethost(void)
{
  FILE *arpCache = fopen("/proc/net/arp", "r");
  if (arpCache != NULL) {
    char arpline[ARP_STRING_LEN+1];
    memset(&arpline[0], '\0', ARP_STRING_LEN+1);
    if (fgets(arpline, ARP_STRING_LEN, arpCache)) {
      char arpip[ARP_IP_LEN+1];
      memset(&arpip[0], '\0', ARP_IP_LEN);
      const char nonline[] = "\33[2K\rhost online...: ";
      size_t i = 0;
      while (1 == fscanf(arpCache, "%" XSTR(ARP_IP_LEN) "s %*s %*s %*s %*s %*s", &arpip[0])) {
        struct in_addr ip;
        struct hostent *hp = NULL;
        if (inet_aton(&arpip[0], &ip)) {
          hp = gethostbyaddr((const void *)&ip, sizeof ip, AF_INET);
        }
        char *herrmsg = NULL;
        if (hp == NULL) {
          switch (h_errno) {
            case HOST_NOT_FOUND: herrmsg = "HOST UNKNOWN"; break;
            case NO_ADDRESS:     herrmsg = "IP UNKNOWN"; break;
            case NO_RECOVERY:    herrmsg = "SERVER ERROR"; break;
            case TRY_AGAIN:      herrmsg = "TEMPORARY ERROR"; break;
          }
        }
        printf("%s[%lu] %.*s aka %s\n", nonline, (long unsigned int)++i, ARP_IP_LEN, arpip, (hp != NULL ? hp->h_name : herrmsg));
        memset(&arpip[0], '\0', ARP_IP_LEN);
      }
    }
    fclose(arpCache);
  }
}
#endif

#ifdef _HAS_UTMP
#ifndef _GNU_SOURCE
size_t
strnlen(const char *str, size_t maxlen)
{
  const char *cp;
  for (cp = str; maxlen != 0 && *cp != '\0'; cp++, maxlen--);
  return (size_t)(cp - str);
}
#endif

static void print_utmp(void)
{
  int utmpfd = open("/var/run/utmp", O_RDONLY);
  if (utmpfd >= 0) {
    struct utmp ut;
    memset(&ut, '\0', sizeof(struct utmp));
    const char uonline[] = "\33[2K\ruser online...: ";
    size_t i = 0;
    while ( read(utmpfd, &ut, sizeof(struct utmp)) == sizeof(struct utmp) && strnlen(ut.ut_user, UT_NAMESIZE) > 0 ) {
      if (strnlen(ut.ut_host, UT_HOSTSIZE) > 0) {
        printf("%s[%lu] %.*s from %.*s\n", uonline, (long unsigned int)++i, UT_NAMESIZE, ut.ut_user, UT_HOSTSIZE, ut.ut_host);
      } else {
        printf("%s[%lu] %.*s\n", uonline, (long unsigned int)++i, UT_NAMESIZE, ut.ut_user);
      }
    }
  }
}
#endif

#ifdef _HAS_SYSINFO
static unsigned long long lastTotalUser, lastTotalUserLow, lastTotalSys, lastTotalIdle;

static void init_cpuusage(){
  FILE* file = fopen("/proc/stat", "r");
  if (file) {
    fscanf(file, "cpu %llu %llu %llu %llu", &lastTotalUser, &lastTotalUserLow,
      &lastTotalSys, &lastTotalIdle);
    fclose(file);
  }
}

static void print_cpuusage(){
  double percent;
  FILE* file;
  unsigned long long totalUser, totalUserLow, totalSys, totalIdle, total;

  file = fopen("/proc/stat", "r");
  fscanf(file, "cpu %llu %llu %llu %llu", &totalUser, &totalUserLow,
    &totalSys, &totalIdle);
  fclose(file);

  if (totalUser < lastTotalUser || totalUserLow < lastTotalUserLow ||
    totalSys < lastTotalSys || totalIdle < lastTotalIdle){
    //Overflow detection. Just skip this value.
    percent = -1.0;
  } else{
    total = (totalUser - lastTotalUser) + (totalUserLow - lastTotalUserLow) +
      (totalSys - lastTotalSys);
    percent = total;
    total += (totalIdle - lastTotalIdle);
    percent /= total;
    percent *= 100;
  }

  lastTotalUser = totalUser;
  lastTotalUserLow = totalUserLow;
  lastTotalSys = totalSys;
  lastTotalIdle = totalIdle;

  printf("CPU...........: %.02f%%\n", percent);
}

static void print_memusage(void)
{
  struct sysinfo meminfo;
  memset(&meminfo, '\0', sizeof(struct sysinfo));
  if (sysinfo(&meminfo) == 0) {
    unsigned long long totalvmem = meminfo.totalram;
    totalvmem += meminfo.totalswap;
    totalvmem *= meminfo.mem_unit;
    unsigned long long usedvmem = meminfo.totalram - meminfo.freeram;
    usedvmem += meminfo.totalswap - meminfo.freeswap;
    usedvmem *= meminfo.mem_unit;
    printf("VMEM(used/max): %llu/%lld (Mb)\n", (usedvmem/(1024*1024)), (totalvmem/(1024*1024)));
  }
}
#endif

#ifdef _HAS_SIGNAL
void SigIntHandler(int signum)
{
  if (signum == SIGINT) {
    doLoop = 0;
  }
}
#endif

enum mainState { MS_DEFAULT, MS_MESSAGE, MS_COMMAND };

int main(int argc, char** argv)
{
  enum mainState state = MS_DEFAULT;
  struct timeval tv;
  tv.tv_sec = 1;
  tv.tv_usec = 0;

#ifdef _HAS_SIGNAL
  signal(SIGINT, SigIntHandler);
#endif
  size_t inputsiz = 0, absiz = UINT8_MAX;
  struct winsize wsiz;
  ioctl(0, TIOCGWINSZ, &wsiz);
  if (wsiz.ws_col < absiz)
    absiz = wsiz.ws_col - 3;
  char inputbuf[absiz+1];
  memset(&inputbuf[0], '\0', absiz+1);
#ifdef _HAS_MSG
  init_msg();
  if (argc > 1) {
    const char optRmsg[] = "readmsg";
    const char optWmsg[] = "writemsg";
    const char optNofollow[] = "-n";
    if (strncmp(argv[1], optRmsg, STRLEN(optRmsg)) == 0) {
      if (argc == 2) while (doLoop) {
        if (print_msg() != 0)
          sleep(1);
      } else if (argc == 3) {
        if (strncmp(argv[2], optNofollow, STRLEN(optNofollow)) == 0) {
          while (print_msg() == 0) {}
        } else {
          fprintf(stderr, "%s readmsg [-n]\n", argv[0]);
          return 1;
        }
      }
      return 0;
    } else if (strncmp(argv[1], optWmsg, STRLEN(optWmsg)) == 0) {
      if (argc == 3) {
        return write_msg(argv[2]);
      } else {
        fprintf(stderr, "%s writemsg msg\n", argv[0]);
      }
      return 0;
    } else {
      fprintf(stderr, "usage: %s [readmsg [-n] | writemsg msg]\n", argv[0]);
      return 1;
    }
  }
#endif
#ifdef _HAS_SYSINFO
  init_cpuusage();
#endif
  int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
  fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);

  static struct termios oldt, newt;
  tcgetattr(STDIN_FILENO, &oldt);
  newt = oldt;
  newt.c_lflag &= ~(ICANON | ECHO);
  tcsetattr(STDIN_FILENO, TCSANOW, &newt);

  printf("%s\n", txtheader);
  fd_set fds;
  time_t start = time(NULL);
  time_t cur;
  unsigned char mins = 0, hrs = 0;
  while (doLoop > 0) {
    cur = time(NULL);
    double diff = difftime(cur, start);
#if defined(_HAS_UTMP) || defined(_HAS_SYSINFO)
    if ((unsigned int)diff % 60 == 0) {
      if (diff != 0 && ++mins == 60) {
        mins = 0;
        hrs++;
      }
      struct tm localtime;
      if (localtime_r(&cur, &localtime) != NULL) {
        printf("\33[2K\r--- %02d:%02d:%02d ---\n", localtime.tm_hour, localtime.tm_min, localtime.tm_sec);
      }
#ifdef _HAS_UTMP
      print_utmp();
#endif
#ifdef _HAS_HOSTENT
      print_nethost();
#endif
#ifdef _HAS_SYSINFO
      print_memusage();
      print_cpuusage();
#endif
    }
#endif
#ifdef _HAS_MSG
    while (print_msg() == 0) {}
#endif
    switch (state) {
      case MS_DEFAULT:
        printf("\r--- %02d:%02d:%02d ---%s", hrs, mins, ((unsigned int)diff % 60), keymsg);
        break;
      case MS_MESSAGE:
      case MS_COMMAND:
#if defined(_HAS_MSG) || defined(_HAS_CMD)
        printf("\33[2K\r> %s", inputbuf);
#endif
        break;
    }
    fflush(stdout);

    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    int ret = select(FD_SETSIZE, &fds, NULL, NULL, &tv);
    if (doLoop == 1 && ret == 0) {
      tv.tv_sec = 1;
      tv.tv_usec = 0;
    } else if (FD_ISSET(STDIN_FILENO, &fds)) {
      char key = getchar();
      switch (state) {
        case MS_DEFAULT:
          switch ( key ) {
            case 'q':
#ifdef _HAS_SIGNAL
              signal(SIGINT, SIG_IGN);
#endif
              printQuitLoop();
              break;
            case 'm':
#ifdef _HAS_MSG
              state = MS_MESSAGE;
#else
              printf("<feature disabled>\n");
#endif
              break;
            case 'c':
#ifdef _HAS_CMD
              print_cmds();
              state = MS_COMMAND;
#else
              printf("<feature disabled>\n");
#endif
              break;
            default: printf("unknown key: %c\n", key); break;
          }
          break;
        case MS_COMMAND:
        case MS_MESSAGE:
          switch (readInput(&inputbuf[0], &inputsiz, absiz, key, 0)) {
            case '\n':
              if (state == MS_MESSAGE) {
#ifdef _HAS_MSG
                printf("\33[2K\rSending message(%lu): %s\n", (long unsigned int)inputsiz, inputbuf);
                if (write_msg(inputbuf) != 0)
                  printf("Sending failed.\n");
#endif
              } else if (state == MS_COMMAND) {
#ifdef _HAS_CMD
                int inputFail = 0;
                if (inputsiz < 3) {
                  inputFail++;
                } else {
                  char* endptr = NULL;
                  unsigned long int tmpi = strtoul(inputbuf, &endptr, 10);
                  if (*endptr == ' ') {
                    endptr++;
                    printf("\33[2K\rExec CMD #%lu with args: %s\n", tmpi, endptr);
                    int retval;
                    switch ( (retval = exec_cmd(tmpi, endptr, strlen(endptr))) ) {
                      case -7: printf("unknown cmd #%lu\n", tmpi); break;
                      case -6: printf("fork error cmd #%lu\n", tmpi); break;
                      case -5: printf("execute cmd #%lu\n", tmpi); break;

                      case 0: break;
                      default: printf("Something went wrong, child returned: %d\n", retval); break;
                    }
                  } else inputFail++;
                }
                if (inputFail > 0)
                  printf("\33[2K\rFORMAT: [cmd#] [params]\n");
#endif
              }
              state = MS_DEFAULT;
              readInput(&inputbuf[0], &inputsiz, absiz, 0, I_CLEARBUF);
              break;
          }
          fflush(stdout);
          break;
      }
    }
  }
  while (getchar() != EOF) {}

  tcsetattr( STDIN_FILENO, TCSANOW, &oldt);
  return 0;
}
