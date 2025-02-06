#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "scribe.h"

#define LIMIT 41

struct writer_t {
  char buffer[LIMIT];
};

int writer_at(void* ctx, uint32_t c, size_t row, size_t col) {
  const size_t index = (row*10) + col;
  if (index >= LIMIT) return 0;
  struct writer_t* w = (struct writer_t*)ctx;
  w->buffer[index] = c;
  return 1;
}

int deleter_at(void *ctx, size_t row, size_t col) {
  const size_t index = (row*10) + col;
  if (index >= LIMIT) return 0;
  struct writer_t* w = (struct writer_t*)ctx;
  w->buffer[index] = 0;
  return 1;
}

struct number_state {
  size_t start_index;
  uint32_t character;
  struct Scribe_t *scribe;
};

void* add_numbers(void* ctx) {
  struct number_state *state = (struct number_state*)ctx;
  const size_t start_index = state->start_index;
  size_t count = 1;
  for (size_t i = start_index; i < (start_index + 10); ++i, ++count) {
    struct Edit e = {
      .row = start_index,
      .col = count,
      .event = SCRIBE_ADD,
      .character = state->character,
    };
    const size_t index = (e.row*10)+e.col;
    if (index >= LIMIT) continue;
    if (scribe_write(state->scribe, e) != SCRIBE_SUCCESS) {
      printf("writer encountered a problem when writing\n");
      break;
    }
    sleep(1);
  }
  return NULL;
}

int main () {
  struct Scribe_t scribe;
  struct writer_t buffer;
  struct ScribeWriter writer = {
    .ptr = &buffer,
    .write_at = writer_at,
    .delete_at = deleter_at,
  };

  if (!scribe_init(&scribe, writer)) {
    printf("failed to initialize writer.\n");
    exit(1);
  }

  pthread_t th1, th2;
  struct number_state state1, state2;
  state1.character = 'A';
  state1.scribe = &scribe;
  state1.start_index = 1;
  pthread_create(&th1, NULL, add_numbers, &state1);
  state2.character = 'B';
  state2.scribe = &scribe;
  state2.start_index = 3;
  pthread_create(&th2, NULL, add_numbers, &state2);

  pthread_join(th1, NULL);
  pthread_join(th2, NULL);

  for (int i = 1; i < LIMIT; ++i) {
    printf("%c", (char)buffer.buffer[i]);
    if ((i % 10) == 0) {
      printf("\n");
    }
  }

  scribe_free(&scribe);

  return 0;
}
