#include <assert.h>
#include <pthread.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include "scribe.h"

// arbitrary limit
#define LIMIT 41

#define expected_add_id 1
#define expected_delete_id 2

// Expected buffer to assert against.
char expected_addition[LIMIT] = {
  0,0,0,0,0,0,0,0,0,0,0,
  'B','C','D','E','F','G','H','I','J','K',
  0,0,0,0,0,0,0,0,0,0,
  'C','D','E','F','G','H','I','J','K','L',
};
// Expected buffer to assert against.
char expected_deletion[LIMIT] = {
  0,0,0,0,0,0,0,0,0,0,0,
  'B','C','D',0,0,'G','H','I','J','K',
  0,0,0,0,0,0,0,0,0,0,
  'C','D','E',0,0,'H','I','J','K','L',
};

static long expected_time;

/**
 * Writer structure to hold our character buffer.
 */
struct writer_t {
  char buffer[LIMIT];
};

/**
 * Define our writer function to populate our buffer for ADD commands.
 */
int writer_at(void* ctx, struct Edit e) {
  const size_t index = (e.row*10) + e.col;
  if (index >= LIMIT) return 0;
  struct writer_t* w = (struct writer_t*)ctx;
  w->buffer[index] = e.character;
  assert(e.id == expected_add_id);
  assert(e.timestamp == expected_time);
  return 1;
}

/**
 * Define our deleter function to handle deleting from our buffer for DELETE commands.
 */
int deleter_at(void *ctx, struct Edit e) {
  const size_t index = (e.row*10) + e.col;
  if (index >= LIMIT) return 0;
  struct writer_t* w = (struct writer_t*)ctx;
  w->buffer[index] = 0;
  assert(e.id == expected_delete_id);
  assert(e.timestamp == expected_time);
  return 1;
}

/**
 * Structure to hold number states for scribe operations.
 */
struct number_state {
  size_t start_index;
  uint32_t character;
  struct Scribe_t *scribe;
};

/**
 * Thread function to operate on our writer buffer.
 */
void* add_numbers(void* ctx) {
  struct number_state *state = (struct number_state*)ctx;
  const size_t start_index = state->start_index;
  size_t count = 1;
  // change the next 10 entries
  for (size_t i = start_index; i < (start_index + 10); ++i, ++count) {
    // create an edit command
    struct Edit e = {
      .id = expected_add_id,
      .row = start_index,
      .col = count,
      .event = SCRIBE_ADD,
      .character = state->character + count,
      .timestamp = expected_time,
    };
    // calculate index
    const size_t index = (e.row*10)+e.col;
    if (index >= LIMIT) continue;
    // write edit operation to scribe
    if (scribe_write(state->scribe, e) != SCRIBE_SUCCESS) {
      printf("writer encountered a problem when writing\n");
      break;
    }
  }
  return NULL;
}

/**
 * Thread function to operate on our writer buffer.
 */
void* delete_numbers(void* ctx) {
  struct number_state *state = (struct number_state*)ctx;
  const size_t start_index = state->start_index;
  size_t count = 4;
  // change the next 2 entries
  for (size_t i = start_index; i < (start_index + 2); ++i, ++count) {
    // create an edit command
    struct Edit e = {
      .id = expected_delete_id,
      .row = start_index,
      .col = count,
      .event = SCRIBE_DELETE,
      .character = state->character,
      .timestamp = expected_time,
    };
    // calculate index
    const size_t index = (e.row*10)+e.col;
    if (index >= LIMIT) continue;
    // write edit operation to scribe
    if (scribe_write(state->scribe, e) != SCRIBE_SUCCESS) {
      printf("writer encountered a problem when writing\n");
      break;
    }
  }
  return NULL;
}

int main () {
  expected_time = clock();
  // create scribe
  struct Scribe_t scribe;
  // create our writer buffer
  struct writer_t buffer;
  // zero out our buffer struct
  memset(&buffer, 0, sizeof(buffer));
  // create our scribe writer structure
  struct ScribeWriter writer = {
    // pointer to our buffer
    .ptr = &buffer,
    // write and delete functions
    .write_at = writer_at,
    .delete_at = deleter_at,
  };

  // initialize our scribe
  if (!scribe_init(&scribe, writer)) {
    printf("failed to initialize writer.\n");
    exit(1);
  }

  // define our threads
  pthread_t th1, th2;
  // number state objects for our threads
  struct number_state state1, state2;

  // define our data and kick off our threads.
  state1.character = 'A';
  state1.scribe = &scribe;
  state1.start_index = 1;
  pthread_create(&th1, NULL, add_numbers, &state1);
  state2.character = 'B';
  state2.scribe = &scribe;
  state2.start_index = 3;
  pthread_create(&th2, NULL, add_numbers, &state2);

  // force the join of our threads
  pthread_join(th1, NULL);
  pthread_join(th2, NULL);

  // print out and assert result
  for (int i = 1; i < LIMIT; ++i) {
    printf("%c,", (char)buffer.buffer[i]);
    assert(buffer.buffer[i] == expected_addition[i]);
    if ((i % 10) == 0) {
      printf("\n");
    }
  }

  // define our data for delete and kick off
  state1.character = 0;
  state1.start_index = 1;
  pthread_create(&th1, NULL, delete_numbers, &state1);
  state2.character = 0;
  state2.start_index = 3;
  pthread_create(&th2, NULL, delete_numbers, &state2);

  // force the join of our threads
  pthread_join(th1, NULL);
  pthread_join(th2, NULL);

  // print out and assert result
  for (int i = 1; i < LIMIT; ++i) {
    printf("%c,", (char)buffer.buffer[i]);
    assert(buffer.buffer[i] == expected_deletion[i]);
    if ((i % 10) == 0) {
      printf("\n");
    }
  }

  // free scribe
  scribe_free(&scribe);

  return 0;
}
