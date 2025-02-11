#ifndef JM_SCRIBE_H
#define JM_SCRIBE_H

#include <stddef.h>
#include <stdint.h>
#include <stdbool.h>
#include <sys/cdefs.h>

__BEGIN_DECLS

/**
 * Event enums for edit operations.
 */
enum EditEvent {
  SCRIBE_ADD,
  SCRIBE_DELETE,
};

/**
 * Scribe error enums.
 */
enum ScribeErrors {
  /* Everything was successful. */
  SCRIBE_SUCCESS,
  /* Internals were closed. */
  SCRIBE_CLOSED,
  /* Internal Error. */
  SCRIBE_ERROR,
};

/**
 * An edit operation.
 */
struct Edit {
  /* ID for edit operation. */
  size_t id;
  /* Edit operation. */
  enum EditEvent event;
  /* Row location. */
  size_t row;
  /* Column location. */
  size_t col;
  /* Character (If ADD operation). */
  uint32_t character;
  /* Timestamp of edit operation. */
  long timestamp;
};

/**
 * Scribe writer write at function.
 *
 * @param[in] ptr The pointed object you attach to the ScribeWriter.
 * @param[in] e The edit operation.
 * @return The number of bytes written, 0 for error or none.
 */
typedef int(*scribe_write_at_fn)(void* ptr, struct Edit e);
/**
 * Scribe writer delete at function.
 * @param[in] ptr The pointed object you attach to the ScribeWriter.
 * @param[in] e The edit operation.
 * @return The number of bytes deleted, 0 for error or none.
 */
typedef int(*scribe_delete_at_fn)(void* ptr, struct Edit e);

/**
 * ScribeWriter interface for the Scribe to push events to.
 */
struct ScribeWriter {
  /* internal base ptr to be used with the interface functions. */
  void* ptr;
  /* Write at function pointer. */
  scribe_write_at_fn write_at;
  /* Delete at function pointer. */
  scribe_delete_at_fn delete_at;
};

/**
 * Scribe structure.
 */
struct Scribe_t {
  void *__internal;
};

/**
 * Initialize scribe internals.
 *
 * @param[out] The scribe structure.
 * @param[in] The writer for the scribe.
 * @return True for success, false otherwise.
 */
bool scribe_init(struct Scribe_t *s, struct ScribeWriter writer) __THROWNL __nonnull((1));
/**
 * Write an event to the scribe.
 *
 * @param[in] The scribe structure.
 * @param[in] The Edit info to write out.
 * @return SCRIBE_SUCCESS on success, SCRIBE_CLOSED if the scribe was closed,
 *  or SCRIBE_ERROR for any errors.
 */
enum ScribeErrors scribe_write(struct Scribe_t *s, struct Edit e) __THROWNL __nonnull((1));
/**
 * Initialize scribe internals.
 *
 * @param[in/out] The scribe structure.
 */
void scribe_free(struct Scribe_t *s) __THROWNL __nonnull((1));

__END_DECLS

#endif
