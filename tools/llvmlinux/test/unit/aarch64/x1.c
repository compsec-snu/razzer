static inline void prefetchw(const void *ptr)
{
        asm volatile("prfm pstl1keep, %a0\n" : : "p" (ptr));
}

int main(int argv, char *argc[])
{
	int foo = 10;
	prefetchw(&foo);

	return 0;
}

