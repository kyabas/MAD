/*
 o----------------------------------------------------------------------------o
 |
 | Memory module implementation
 |
 | Methodical Accelerator Design - Copyright CERN 2015
 | Support: http://cern.ch/mad  - mad at cern.ch
 | Authors: L. Deniau, laurent.deniau at cern.ch
 | Contrib: -
 |
 o----------------------------------------------------------------------------o
 | You can redistribute this file and/or modify it under the terms of the GNU
 | General Public License GPLv3 (or later), as published by the Free Software
 | Foundation. This file is distributed in the hope that it will be useful, but
 | WITHOUT ANY WARRANTY OF ANY KIND. See http://gnu.org/licenses for details.
 o----------------------------------------------------------------------------o
*/

#include <stdio.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

#include "mad_log.h"
#include "mad_mem_nodef.h"

// --- macros ----------------------------------------------------------------o

/*
Note about auto collect:
  If MAD_MEM_AUTOCOLLECT != 0, the memory allocator will bound the amount
  of cached memory to pool_max. Default is to bound the memory cached for
  OPENMP only. -DMAD_MEM_AUTOCOLLECT sets it to 1.
*/

#ifdef _OPENMP
#define MAD_MEM_AUTOCOLLECT 1
#endif

#if     MAD_MEM_AUTOCOLLECT != 0
#define MAC(...) __VA_ARGS__
#define CAM(...) 
#else
#define MAC(...)
#define CAM(...) __VA_ARGS__
#endif

// --- types & constants -----------------------------------------------------o

// memory block
union mblk {
  struct { // free mblk
    union mblk *next;
  } free;

  struct { // used mblk
    unsigned slot;
    union { // alignment of data
      ptrdiff_t s, *sp;
      size_t    u, *up;
      double    d, *dp;
      void         *vp;
      void        (*fp)(void);
    } data[1];
  } used;
};

// pool slots (list of mblk)
struct slot {
  union mblk *list;
};

// sizes & offsets
enum {
  mblk_stp = 1<< 4, // step size is 16 bytes
  mblk_max = 1<<11, // max object size is 2kB
  pool_max = 1<<24, // max cached size is 16MB

  slot_max = mblk_max/mblk_stp, // 128 slots
  cach_max = pool_max/mblk_stp, // 16MB in slots unit
  mblk_off = offsetof(union mblk, used.data),

  // sanity checks
  static_assert__mblk_stp_must_be_a_power_of_2 = 1/!(mblk_stp & (mblk_stp-1)),
  static_assert__mblk_max_must_be_a_power_of_2 = 1/!(mblk_max & (mblk_max-1)),
  static_assert__pool_max_must_be_a_power_of_2 = 1/!(pool_max & (pool_max-1))
};

// memory pool
struct pool {
MAC(
  size_t cached; )
  struct slot slot[slot_max];
};

// --- locals ----------------------------------------------------------------o

static struct pool pool[1];

#ifdef _OPENMP
#pragma omp threadprivate(pool)
#endif

// --- implementation --------------------------------------------------------o

static inline union mblk*
get_base (void *ptr)
{
  return (union mblk*)((char*)ptr - mblk_off);
}

static inline size_t
get_slot (size_t size)
{
  // size=0 gives highest slot (special case)
  return (size-1) / mblk_stp;
}

static inline size_t
get_size (size_t slot)
{
  return (slot+1) * mblk_stp + mblk_off;
}

static inline void*
init_node (union mblk *ptr, size_t slot)
{
    ptr->used.slot = slot;
    return ptr->used.data;
}

// -- allocator

void*
(mad_malloc) (size_t size)
{
  size_t slot = get_slot(size);
  struct pool *ppool = pool;
  struct slot *pptr = ppool->slot+slot;
  union  mblk *ptr;

  if (slot < slot_max && pptr->list) {
    ptr = pptr->list, pptr->list = ptr->free.next;
MAC(ppool->cached -= slot+1; )
  } else {
MAC(if (ppool->cached > cach_max) mad_mem_collect(); )
    ptr = malloc(size ? get_size(slot) : 0);
    if (!ptr) {
      mad_mem_collect();
      ptr = malloc(size ? get_size(slot) : 0);
      if (!ptr) mad_fatalf("out of memory");
    }
  }

  return init_node(ptr, slot);
}

void*
(mad_realloc) (void *ptr_, size_t size)
{
  if (!size) return (mad_free)  (ptr_), NULL;
  if (!ptr_) return (mad_malloc)(size);

  union mblk *ptr = get_base(ptr_);
  size_t slot = get_slot(size);
MAC(
  struct pool *ppool = pool;
  if (ppool->cached > cach_max) mad_mem_collect(); )

  ptr = realloc(ptr, size ? get_size(slot) : 0);
  if (!ptr) {
    mad_mem_collect();
    ptr = realloc(ptr, size ? get_size(slot) : 0);
    if (!ptr) mad_fatalf("out of memory");
  }

  return init_node(ptr, slot);
}

void
(mad_free) (void *ptr_)
{
  if (ptr_) {
    union mblk *ptr = get_base(ptr_);
    size_t slot = ptr->used.slot;
  
    if (slot < slot_max) {
      struct pool *ppool = pool;
      struct slot *pptr = ppool->slot+slot;
      ptr->free.next = pptr->list, pptr->list = ptr;
MAC(  ppool->cached += slot+1;
      if (ppool->cached > cach_max) mad_mem_collect(); )
    }
    else free(ptr);
  }
}

// -- utils

size_t
mad_mem_size (void* ptr_)
{
  if (!ptr_) return 0;
  size_t slot = get_base(ptr_)->used.slot;
  return slot != get_slot(0) ? (slot+1) * mblk_stp : 0;
}

size_t __attribute__((noinline))
mad_mem_cached (void)
{
  struct pool *ppool = pool;
  size_t cached = 0;
CAM(
  union mblk *ptr;

  for (int slot=0; slot < slot_max; slot++) {
    struct slot *pptr = ppool->slot+slot;
    for (ptr=pptr->list; ptr; ptr=ptr->free.next)
      cached += slot+1;
  })
MAC(
  cached = ppool->cached; )

  return cached * mblk_stp;
}

// note: noinline improves speed of malloc and realloc for GCC 4.8 to 5.2
size_t __attribute__((noinline))
mad_mem_collect (void)
{
  struct pool *ppool = pool;
  union mblk *ptr, *nxt;
  size_t cached = 0;

  for (int slot=0; slot < slot_max; slot++) {
    struct slot *pptr = ppool->slot+slot;
    for (ptr=pptr->list; ptr; ptr=nxt) {
      nxt = ptr->free.next;
      free(ptr);
CAM(  cached += slot+1; )
    }
    pptr->list = 0;
  }
MAC(
  cached = ppool->cached;
  ppool->cached = 0; )

  return cached * mblk_stp;
}