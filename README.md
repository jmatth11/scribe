# Scribe

Simple library to handle writes of Edit operations from multiple sources to one output.

This library is meant for text files or text buffers but could be applied to other things.

`pipe2` is used to deliver the messages between writers and readers.


## C Usage

A C header file is included. You can check out `examples` for working examples
used in the C interface, but here is a simple example only using the ADD operation.

```c
/**
 * Writer structure to hold our character buffer.
 */
struct writer_t {
  char buffer[LIMIT];
};

/**
 * Define our writer function to populate our buffer for ADD commands.
 */
int writer_at(void* ctx, uint32_t c, size_t row, size_t col) {
  const size_t index = (row*10) + col;
  if (index >= LIMIT) return 0;
  struct writer_t* w = (struct writer_t*)ctx;
  // we aren't dealing with unicode so we can assume ASCII
  w->buffer[index] = c;
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
      .row = start_index,
      .col = count,
      .event = SCRIBE_ADD,
      .character = state->character,
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
    // write
    .write_at = writer_at,
    // we do not use delete in our example
    .delete_at = NULL,
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
    if ((i % 10) == 0) {
      printf("\n");
    }
  }
  return 0;
}
```
