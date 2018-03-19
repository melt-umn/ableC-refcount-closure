#include <stdlib.h>
#include <string.h>
//#include <stdio.h>

#ifndef __REFCOUNT_H
#define __REFCOUNT_H

/**
 * Tag structure placed at beginning of allocated memory that contains reference-
 * counting information for a pointer.
 */
typedef struct refcount_tag_s *refcount_tag;
struct refcount_tag_s {
  const char *fn_name;
  size_t ref_count;
  size_t refs_len;
  refcount_tag refs[];
};

/**
 * Add a reference to a reference-counted piece of memory.
 *
 * @param rt The tag for which to add a reference.
 */
static inline void add_ref(const refcount_tag rt) {
  //fprintf(stderr, "Adding ref to %s\n", rt->fn_name);
  rt->ref_count++;
}

/**
 * Remove a reference to a reference-counted piece of memory, possibly freeing
 * it, and recursively removing outgoing references.
 *
 * @param rt The tag for which to remove a reference.
 */
static void remove_ref(const refcount_tag rt) {
  //fprintf(stderr, "Removing ref to %s\n", rt->fn_name);
  if (--rt->ref_count == 0) {
    for (size_t i = 0; i < rt->refs_len; i++) {
      remove_ref(rt->refs[i]);
    }
    //fprintf(stderr, "Freed %s\n", rt->fn_name);
    free(rt);
  }
}

/**
 * Allocate reference-counted memory with an array of outgoing references to be
 * made by the data.
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
                                         refcount_tag *const p_rt,
                                         const size_t refs_len,
                                         const refcount_tag refs[const]) {
  size_t refs_size = sizeof(refcount_tag) * refs_len;
  size_t rt_size = sizeof(struct refcount_tag_s) + refs_size;
  void *mem = malloc(rt_size + size);
  refcount_tag rt = mem;
  rt->ref_count = 1;
  rt->refs_len = refs_len;
  if (refs_len) {
    memcpy(rt->refs, refs, refs_size);
  }
  *p_rt = rt;

  for (size_t i = 0; i < rt->refs_len; i++) {
    add_ref(rt->refs[i]);
  }
  
  return mem + rt_size;
}

/**
 * Allocate reference-counted memory with no outgoing references.
 *
 * @param size The number of bytes to allocate.
 * @param p_rt A pointer to a refcount tag to initialize.
 * @return A pointer to the allocated memory.
 */
static inline void *refcount_malloc(const size_t size, refcount_tag *const p_rt) {
  return refcount_refs_malloc(size, p_rt, 0, NULL);
}

#endif
