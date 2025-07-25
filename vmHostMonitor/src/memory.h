void *allocateMemory(size_t nbytes);
void freeMemory(void *memory);
void *reallocateMemory(void *location, size_t oldSize, size_t newSize);
int checkMemoryCount(void);
long getMallocCount(void);
long getFreeCount(void);
