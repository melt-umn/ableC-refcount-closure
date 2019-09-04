#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <pthread.h>

#ifndef __REFCOUNT_H
#define __REFCOUNT_H

/**
 * Tag structure placed at beginning of allocated memory that contains reference-
 * counting information for a pointer.
 */
typedef struct refcount_tag_s *refcount_tag_t;
struct refcount_tag_s {
  void *data;
  //const char *name;
  void (*finalize)(void *);
  pthread_mutex_t mutex;
  size_t ref_count;
  size_t refs_len;
  refcount_tag_t refs[];
};

/**
 * Add a reference to a reference-counted piece of memory.
 *
 * @param rt The tag for which to add a reference.
 */
static inline void add_ref(const refcount_tag_t rt) {
  pthread_mutex_lock(&rt->mutex);
  //fprintf(stderr, "Adding ref to %s (has %lu ref(s))\n", rt->name, rt->ref_count);
  if (rt == NULL) {
    fprintf(stderr, "Fatal error: Adding ref to invalid refcount tag\n");
    abort();
  }
  rt->ref_count++;
  pthread_mutex_unlock(&rt->mutex);
}

/**
 * Remove a reference to a reference-counted piece of memory, possibly freeing
 * it, and recursively removing outgoing references.
 *
 * @param rt The tag for which to remove a reference.
 */
static inline void remove_ref(const refcount_tag_t rt) {
  pthread_mutex_lock(&rt->mutex);
  //fprintf(stderr, "Removing ref to %s (has %lu ref(s))\n", rt->name, rt->ref_count);
  if (rt == NULL || rt->ref_count == 0) {
    fprintf(stderr, "Fatal error: Removing ref to invalid refcount tag\n");
    abort();
  }
  if (--rt->ref_count == 0) {
    for (size_t i = 0; i < rt->refs_len; i++) {
      remove_ref(rt->refs[i]);
    }
    //fprintf(stderr, "Freed %s\n", rt->name);
    if (rt->finalize != NULL) {
      rt->finalize(rt->data);
    }
    pthread_mutex_unlock(&rt->mutex);
    pthread_mutex_destroy(&rt->mutex);
    free(rt);
  } else {
    pthread_mutex_unlock(&rt->mutex);
  }
}

/**
 * Allocate reference-counted memory with an array of outgoing references to be
 * made by the data and a finalization function to be called when freed.
 *
 * @param size The number of bytes to allocate.
 * @param p_rt A pointer to a refcount tag to initialize.
 * @param refs_len The number of outgoing references to be made from the
 * allocated memory.
 * @param refs A pointer to an array of outgoing references to be made from the
 * allocated memory.
 * @return A pointer to the allocated memory.
 */
static inline void *refcount_final_malloc(const size_t size,
                                          refcount_tag_t *const p_rt,
                                          const size_t refs_len,
                                          const refcount_tag_t refs[const],
                                          void (*finalize)(void *)) {
  size_t refs_size = sizeof(refcount_tag_t) * refs_len;
  size_t rt_size = sizeof(struct refcount_tag_s) + refs_size;
  void *mem = malloc(rt_size + size);
  void *data = mem + rt_size;
  refcount_tag_t rt = mem;
  rt->data = data;
  rt->ref_count = 1;
  rt->refs_len = refs_len;
  rt->finalize = finalize;
  pthread_mutex_init(&rt->mutex, NULL);
  if (refs_len) {
    memcpy(rt->refs, refs, refs_size);
  }
  *p_rt = rt;

  for (size_t i = 0; i < rt->refs_len; i++) {
    add_ref(rt->refs[i]);
  }
  
  return data;
}

/**
 * Allocate reference-counted memory with an array of outgoing references to be
 * made by the data, and no finalization.
 *
 * @param size The number of bytes to allocate.
 * @param p_rt A pointer to a refcount tag to initialize.
 * @param refs_len The number of outgoing references to be made from the
 * allocated memory.
 * @param refs A pointer to an array of outgoing references to be made from the
 * allocated memory.
 * @return A pointer to the allocated memory.
 */
static inline void *refcount_refs_malloc(const size_t size,
                                         refcount_tag_t *const p_rt,
                                         const size_t refs_len,
                                         const refcount_tag_t refs[const]) {
  return refcount_final_malloc(size, p_rt, refs_len, refs, NULL);
}

/**
 * Allocate reference-counted memory with no outgoing references or finalization.
 *
 * @param size The number of bytes to allocate.
 * @param p_rt A pointer to a refcount tag to initialize.
 * @return A pointer to the allocated memory.
 */
static inline void *refcount_malloc(const size_t size,
                                    refcount_tag_t *const p_rt) {
  return refcount_refs_malloc(size, p_rt, 0, NULL);
}

/**
 * Create a refcount tag wrapping multiple other tags into a single reference.
 * This effectively makes the new tag "responsible" for a given number of
 * references to each wrapped tag; Note that this does not add references to the
 * existing tags.
 *
 * @param ref_count The number of refrences for which this tag is responsible.
 * @param refs_len The number of references to be wrapped.
 * @param refs A pointer to an array of references to be wrapped.
 * @return A refcount tag wrapping the provided references.
 */
static inline refcount_tag_t refcount_wrap(const size_t ref_count,
                                           const size_t refs_len,
                                           const refcount_tag_t refs[const]) {
  size_t refs_size = sizeof(refcount_tag_t) * refs_len;
  size_t rt_size = sizeof(struct refcount_tag_s) + refs_size;
  refcount_tag_t rt = malloc(rt_size);
  rt->data = NULL;
  rt->ref_count = ref_count;
  rt->refs_len = refs_len;
  rt->finalize = NULL;
  pthread_mutex_init(&rt->mutex, NULL);
  if (refs_len) {
    memcpy(rt->refs, refs, refs_size);
  }

#ifndef NDEBUG
  for (size_t i = 0; i < rt->refs_len; i++) {
    if (refs[i]->ref_count < ref_count) {
      fprintf(stderr, "Fatal error: Wrapped reference has fewer refs than expected\n");
      abort();
    }
  }
#endif
  
  return rt;
}

#endif
