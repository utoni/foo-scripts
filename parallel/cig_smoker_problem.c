#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <pthread.h>
#include <semaphore.h>

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

enum sem_ids {
  AGENTSEM = 0,
  TOBACCO,
  PAPER,
  MATCH,
  SEM_MAX
};

static sem_t sems[SEM_MAX];


static void *agenta_thread(void *args)
{
  while (1) {
    sem_wait(&sems[AGENTSEM]);
    sem_post(&sems[TOBACCO]);
    sem_post(&sems[PAPER]);
    printf("AGENT_A: +1 TOBACCO , +1 PAPER\n");
  }
  return NULL;
}

static void *agentb_thread(void *args)
{
  while (1) {
    sem_wait(&sems[AGENTSEM]);
    sem_post(&sems[PAPER]);
    sem_post(&sems[MATCH]);
    printf("AGENT_B: +1 PAPER, +1 MATCH\n");
  }
  return NULL;
}

static void *agentc_thread(void *args)
{
  while (1) {
    sem_wait(&sems[AGENTSEM]);
    sem_post(&sems[TOBACCO]);
    sem_post(&sems[MATCH]);
    printf("AGENT_C: +1 TOBACCO, +1 MATCH\n");
  }
  return NULL;
}

static void *smokerm_thread(void *args)
{
  while (1) {
    sem_wait(&sems[TOBACCO]);
    sem_wait(&sems[PAPER]);
    sem_post(&sems[AGENTSEM]);
    printf("SMOKER_M: +1 PAPER , \n");
  }
  return NULL;
}

static void *smokert_thread(void *args)
{
  while (1) {
    sem_wait(&sems[PAPER]);
    sem_wait(&sems[MATCH]);
    sem_post(&sems[AGENTSEM]);
    printf("SMOKER_T\n");
  }
  return NULL;
}

static void *smokerp_thread(void *args)
{
  while (1) {
    sem_wait(&sems[TOBACCO]);
    sem_wait(&sems[MATCH]);
    sem_post(&sems[AGENTSEM]);
    printf("SMOKER_P\n");
  }
  return NULL;
}

int
main(int argc, char *argv[])
{
  int i;

  for (i = 0; i < SEM_MAX; i++) {
    assert( sem_init(&sems[i], 0, 0) == 0 );
  }

  assert( pthread_create(&thrds[AGENT_A], NULL, agenta_thread, NULL) == 0 );
  assert( pthread_create(&thrds[AGENT_B], NULL, agentb_thread, NULL) == 0 );
  assert( pthread_create(&thrds[AGENT_C], NULL, agentc_thread, NULL) == 0 );
  assert( pthread_create(&thrds[SMOKER_M], NULL, smokerm_thread, NULL) == 0 );
  assert( pthread_create(&thrds[SMOKER_T], NULL, smokert_thread, NULL) == 0 );
  assert( pthread_create(&thrds[SMOKER_P], NULL, smokerp_thread, NULL) == 0 );

  while (1) {
    sleep( random() % 5 );
    sem_post(&sems[AGENTSEM]);
  }
  return 0;
}


