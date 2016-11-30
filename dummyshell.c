#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <termios.h>
#include <fcntl.h>
#include <time.h>


static const char txtheader[] =
  "**************\n"
  "* dummyshell *\n"
  "**************\n";


int main(int argc, char** argv)
{
  struct timeval tv;
  tv.tv_sec = 1;
  tv.tv_usec = 0;

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
    printf("\r( %0.fs ) [PRESS ANY KEY TO QUIT] ", diff);
    fflush(stdout);
    fflush(stdin);
    FD_ZERO(&fds);
    FD_SET(STDIN_FILENO, &fds);
    int ret = select(FD_SETSIZE, &fds, NULL, NULL, &tv);
    if (ret == 0) {
      tv.tv_sec = 1;
      tv.tv_usec = 0;
    } else {
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
