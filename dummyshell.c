/*
 * build with: gcc -Wall -O2 -D_HAS_HOSTENT=1 -D_HAS_SIGNAL=1 -D_HAS_UTMP=1 -D_HAS_SYSINFO -ffunction-sections -fdata-sections -ffast-math -fomit-frame-pointer dummyshell.c -o dummyshell
 * strip -s dummyshell
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <time.h>
#ifdef _HAS_HOSTENT
#include <netdb.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#else
#warn "HOSTENT(_HAS_HOSTENT) disabled!"
#endif
#ifdef _HAS_SIGNAL
#include <signal.h>      /* signal(...) */
#else
#warn "SIGNAL(_HAS_SIGNAL) disabled!"
#endif
#if defined(_HAS_UTMP) || defined(_HAS_SYSINFO)
#include <string.h>      /* memset */
#endif
#ifdef _HAS_UTMP
#include <utmp.h>        /* utmp structure */
#else
#warn "UTMP(_HAS_UTMP) disabled!"
#endif
#ifdef _HAS_SYSINFO
#include "sys/types.h"   /* sysinfo structture */
#include "sys/sysinfo.h" /* sysinfo(...) */
#else
#warn "SYSINFO(_HAS_SYSINFO) disabled!"
#endif

/* for print_memusage() and print cpuusage() see: http://stackoverflow.com/questions/63166/how-to-determine-cpu-and-memory-consumption-from-inside-a-process */


static const char keymsg[] = " [PRESS ANY KEY TO QUIT] ";
static const char txtheader[] =
  "**************\n"
  "* dummyshell *\n"
  "**************\n";

static volatile unsigned char doLoop = 1;


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
  }
}
#endif

#ifdef _HAS_UTMP
#ifndef _GNU_SOURCE
static size_t
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
      printf("%s[%lu] %.*s from %.*s\n", uonline, (long unsigned int)++i, UT_NAMESIZE, ut.ut_user, UT_HOSTSIZE, ut.ut_host);
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

int main(int argc, char** argv)
{
  struct timeval tv;
  tv.tv_sec = 1;
  tv.tv_usec = 0;

#ifdef _HAS_SIGNAL
  signal(SIGINT, SigIntHandler);
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
  while (1) {
    cur = time(NULL);
    double diff = difftime(cur, start);
#if defined(_HAS_UTMP) || defined(_HAS_SYSINFO)
    if ((unsigned int)diff % 60 == 0) {
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
    printf("\r( %0.fs )%s", diff, keymsg);
    fflush(stdout);
    fflush(stdin);
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    int ret = select(FD_SETSIZE, &fds, NULL, NULL, &tv);
    if (doLoop == 1 && ret == 0) {
      tv.tv_sec = 1;
      tv.tv_usec = 0;
    } else {
#ifdef _HAS_SIGNAL
      signal(SIGINT, SIG_IGN);
#endif
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
      break;
    }
    if (FD_ISSET(STDIN_FILENO,&fds)) break;
  }
  while (getchar() != EOF) {}

  tcsetattr( STDIN_FILENO, TCSANOW, &oldt);

  return 0;
}
