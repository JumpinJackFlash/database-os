#include <stdlib.h>
#ifndef __APPLE__
#include <malloc.h>
#endif
#include <string.h>
#include <stdio.h>

#include "commonDefs.h"

static long mallocCount = 0, freeCount = 0;									// Track memory allocation/deallocation count...
static long long bytesAllocated = 0;

#ifdef TRACK_MEMORY             // This shit is not thread safe. Use for brief testing only.....
typedef struct memoryStackStruct
{
  void *allocatedArea;
  long mallocCount;
  size_t size;
  struct memoryStackStruct *nextEntry;
}MEMORY_STACK;

static MEMORY_STACK *memoryStack = NULL;

void pushMemoryStack(void *var, size_t nbytes)
{
MEMORY_STACK *memoryStackEntry = NULL;

  memoryStackEntry = (MEMORY_STACK *)malloc(sizeof(MEMORY_STACK));
  if (!memoryStackEntry) return;
  
  mallocCount++;
  bzero(memoryStackEntry, sizeof(MEMORY_STACK));
  memoryStackEntry->allocatedArea = var;
  memoryStackEntry->size = nbytes;
  memoryStackEntry->mallocCount = mallocCount - 1;
  memoryStackEntry->nextEntry = memoryStack;
  memoryStack = memoryStackEntry;
  
  return;
}

void pullMemoryStackEntry(void *memory)
{
MEMORY_STACK *memoryStackEntry = NULL, *prevEntry = NULL;

  if (memoryStack->allocatedArea == memory)
  {
    memoryStackEntry = memoryStack;
    memoryStack = memoryStack->nextEntry;
    freeCount++;
    free(memoryStackEntry);
    return;
  }
  
  memoryStackEntry = memoryStack;									// By definition of logic, we'll go through this loop at
  while (memoryStackEntry)											// twice thus setting the value of prevEntry...
  {
    if (memoryStackEntry->allocatedArea == memory)
    {
      prevEntry->nextEntry = memoryStackEntry->nextEntry;			// Maintain the links....
      freeCount++;
      free(memoryStackEntry);
      return;
    }
    prevEntry = memoryStackEntry;
    memoryStackEntry = memoryStackEntry->nextEntry;
  }
  
  return;
}
#endif

void *allocateMemory(size_t nbytes)		/* Local memory allocation.   */
{
void *var = NULL;				/* The allocated area.	      */

  var = (void *)malloc(nbytes);
  if (!var) return(NULL);

#ifdef MEMORY_COUNT
  mallocCount++;
#endif
  
#ifdef TRACK_MEMORY
  
  pushMemoryStack(var, nbytes);
  
#endif

  bzero(var, nbytes);

  bytesAllocated += nbytes;
  return(var);
}

void *reallocateMemory(void *location, size_t oldSize, size_t newSize)
{
void *var = NULL;
char *x = NULL;

#ifdef TRACK_MEMORY

  if (location) pullMemoryStackEntry(location);

#endif

  var = realloc(location, newSize);
  if (!var) return var;

  x = (char *)var + oldSize;
  bzero(x, newSize - oldSize);

#ifdef MEMORY_COUNT
  if (!location) mallocCount++;
#endif

#ifdef TRACK_MEMORY

  pushMemoryStack(var, newSize);

#endif

  return var;
}

void freeMemory(void *memory)
{
  if (!memory) return;
  
#ifdef TRACK_MEMORY

  pullMemoryStackEntry(memory);
  
#endif

#ifdef MEMORY_COUNT
  freeCount++;
#endif
  
  free(memory);

  return;
}

int checkMemoryCount(void)
{
  return (int) (mallocCount - freeCount);
}

long getMallocCount(void)
{
  return mallocCount;
}

long getFreeCount(void)
{
  return freeCount;
}
