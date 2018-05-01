#include "common.h"

static inline void prefetch(const void *ptr)
{
	asm volatile("prfm pldl1keep, [%x0]\n" : : "p" (ptr));
}
 
static inline void prefetchw(const void *ptr)
{
	asm volatile("prfm pstl1keep, [%x0]\n" : : "p" (ptr));
}

int main()
{
	u64 tmp;

	const void *ptr = (const void *)&tmp;

	// The following give the error when built with clang
	// Error: bad instruction
	prefetch(ptr);
	prefetchw(ptr);
}
