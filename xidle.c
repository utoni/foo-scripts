#include <stdio.h>
#include <X11/Xlib.h>
#include <X11/extensions/scrnsaver.h>


/* Report amount of X server idle time. */
/* gcc xidle.c -o xidle -lX11 -lXext -lXss */

int main(int argc, char *argv[])
{
  Display *display;
  int event_base, error_base;
  XScreenSaverInfo info;
  float seconds;
  unsigned int d_seconds = 0;

  if (argc == 2) {
    d_seconds = atoi(argv[1]);
  }

  display = XOpenDisplay("");

  if (XScreenSaverQueryExtension(display, &event_base, &error_base)) {
    if (XScreenSaverQueryInfo(display, DefaultRootWindow(display), &info) != True) {
      fprintf(stderr, "Error: XScreenSaver QueryInfo failed\n");
      return -1;
    }
    seconds = (float)info.idle/1000.0f;
    if ( d_seconds > 0 ) {
      if (d_seconds <= (unsigned int) seconds) {
        return 1;
      }
    } else {
      printf("%f\n",seconds);
    }
    return 0;
  } else {
    fprintf(stderr,"Error: XScreenSaver Extension not present\n");
    return -1;
  }
}

