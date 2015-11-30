#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <immintrin.h>

#include <assert.h>


enum thrd_ids {
  AGENT_A = 0,
  AGENT_B,
  AGENT_C,
  SMOKER_T,
  SMOKER_P,
  SMOKER_M,
  THRD_MAX
};

static pthread_t thrds[THRD_MAX];

/* memory shared by all threads */
/* only atomic operations are allowed */
static unsigned int agent_tasks = 0;
static unsigned int tobacco = 0;
static unsigned int paper = 0;
static unsigned int match = 0;


static void *agenta_thread(void *args)
{
  while (1) {
    __transaction_atomic {
      if (agent_tasks > 0) {
        agent_tasks--;
        tobacco++; paper++;
      }
    }
    printf("AGENT_A: +1 TOBACCO , +1 PAPER\n");
    sleep( random() % 5 );
  }
  return NULL;
}

static void *agentb_thread(void *args)
{
  while (1) {
    __transaction_atomic {
      if (agent_tasks > 0) {
        agent_tasks--;
        paper++; match++;
      }
    }
    printf("AGENT_B: +1 PAPER, +1 MATCH\n");
    sleep( random() % 5 );
  }
  return NULL;
}

static void *agentc_thread(void *args)
{
  while (1) {
    __transaction_atomic {
      if (agent_tasks > 0) {
        agent_tasks--;
        tobacco++; match++;
      }
    }
    printf("AGENT_C: +1 TOBACCO, +1 MATCH\n");
    sleep( random() % 5 );
  }
  return NULL;
}

static void *smokerm_thread(void *args)
{
  while (1) {
    __transaction_atomic {
      if (tobacco > 0 && paper > 0) {
        agent_tasks++;
        tobacco--; paper--;
      }
    }
    printf("SMOKER_M: -1 TOBACCO, -1 PAPER\n");
    sleep( random() % 5 );
  }
  return NULL;
}

static void *smokert_thread(void *args)
{
  while (1) {
    __transaction_atomic {
      if (paper > 0 && match > 0) {
        agent_tasks++;
        paper--; match--;
      }
    }
    printf("SMOKER_T: -1 PAPER, -1 MATCH\n");
    sleep( random() % 5 );
  }
  return NULL;
}

static void *smokerp_thread(void *args)
{
  while (1) {
    __transaction_atomic {
      if (tobacco > 0 && match > 0) {
        agent_tasks++;
        tobacco--; match--;
      }
    }
    printf("SMOKER_P: -1 TOBACCO, -1 MATCH\n");
    sleep( random() % 5 );
  }
  return NULL;
}

int
main(int argc, char *argv[])
{
  assert( pthread_create(&thrds[AGENT_A], NULL, agenta_thread, NULL) == 0 );
  assert( pthread_create(&thrds[AGENT_B], NULL, agentb_thread, NULL) == 0 );
  assert( pthread_create(&thrds[AGENT_C], NULL, agentc_thread, NULL) == 0 );
  assert( pthread_create(&thrds[SMOKER_M], NULL, smokerm_thread, NULL) == 0 );
  assert( pthread_create(&thrds[SMOKER_T], NULL, smokert_thread, NULL) == 0 );
  assert( pthread_create(&thrds[SMOKER_P], NULL, smokerp_thread, NULL) == 0 );

  while (1) {
    unsigned char succ = 0;
    unsigned int t_tasks, t_tobacco, t_paper, t_match;
    sleep(1);
    __transaction_atomic {
      t_tasks = agent_tasks;
      t_tobacco = tobacco;
      t_paper = paper;
      t_match = match;
      succ = 1;
    }
    if (succ == 1) {
      printf("*** STATUS: %u agent_tasks , %u tobacco , %u paper , %u matches\n", t_tasks, t_tobacco, t_paper, t_match);
    } else {
      printf("*** ATOMIC OPERATIONS NOT EXECUTED ***\n");
    }
  }
  return 0;
}


