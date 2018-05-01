unsigned long addr_limit = 0xffffff;

/*
 * Test whether a block of memory is a valid user space address.
 * Returns 1 if the range is valid, 0 otherwise.
 *
 * This is equivalent to the following test:
 * (u65)addr + (u65)size < (u65)current->addr_limit
 *
 * This needs 65-bit arithmetic.
 */
#define __range_ok(addr, size)						\
({									\
	unsigned long flag, roksum;					\
	asm("adds %1, %1, %3; ccmp %1, %4, #2, cc; cset %0, cc"		\
		: "=&r" (flag), "=&r" (roksum)				\
		: "1" (addr), "Ir" (size),				\
		  "r" (addr_limit)		\
		: "cc");						\
	flag;								\
})

int main()
{
	unsigned long int a = 100;
	unsigned long  b = 100;
	__range_ok(a,b);
}


