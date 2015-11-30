/*
 * compile with: gcc -Wall -fgnu-tm -O2 -s stm.c -o stm
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <immintrin.h>


#include <assert.h>


struct thread_data {
  pthread_t thrd;
  int id;
  int result;
};
  

#define NTHREADS 8
static const unsigned int nthreads = NTHREADS;
static const unsigned int iterations = 4000;
static struct thread_data thrds[NTHREADS];

/* r/w by threads */
static int sum = 0;


void *
thread_func(void *arg)
{
  int i;
  struct thread_data *td = (struct thread_data *) arg;

  printf("Thread %d started ..\n", td->id);

  /* critical section - stm */
  for (i = 0; i < iterations; i++) {
    __transaction_atomic { sum++; }
  }

  return NULL;
}

int
main(int argc, char *argv[])
{
  int i;

  for (i = 0; i < nthreads; i++) {
    thrds[i].id = i;
    thrds[i].result = 0;
    assert( pthread_create( &(thrds[i].thrd), NULL, thread_func, (void*)&thrds[i] ) == 0 );
  }

  for (i = 0; i < nthreads; i++) {
    assert( pthread_join(thrds[i].thrd, NULL) == 0 );
  }

  printf("Expected result: sum == %d\n", iterations*nthreads);
  if (sum == iterations*nthreads) {
    printf("STM worked! sum == %d\n", sum);
  } else {
    printf("Wrong result? Maybe your GNU-STM does not work. (sum == %d)\n", sum);
  }

  return 0;
}
