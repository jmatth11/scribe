#ifndef JM_SCRIBE_H
#define JM_SCRIBE_H

#include <stddef.h>
#include <stdint.h>
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
  /* Edit operation. */
  enum EditEvent event;
  /* Row location. */
  size_t row;
  /* Column location. */
  size_t col;
  /* Character (If ADD operation). */
  uint32_t character;
};

/**
 * Scribe writer write at function.
 */
typedef int(*scribe_write_at_fn)(void*, uint32_t, size_t, size_t);
/**
 * Scribe writer delete at function.
 */
typedef int(*scribe_delete_at_fn)(void*, size_t, size_t);

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
bool scribe_init(Scribe_t *s, ScribeWriter writer) __THROWNL __nonnull((1));
/**
 * Write an event to the scribe.
 *
 * @param[in] The scribe structure.
 * @param[in] The Edit info to write out.
 * @return SCRIBE_SUCCESS on success, SCRIBE_CLOSED if the scribe was closed,
 *  or SCRIBE_ERROR for any errors.
 */
enum ScribeErrors scribe_write(Scribe_t *s, Edit e) __THROWNL __nonnull((1));
/**
 * Initialize scribe internals.
 *
 * @param[in/out] The scribe structure.
 */
void scribe_free(Scribe_t *s) __THROWNL __nonnull((1));

__END_DECLS

#endif
