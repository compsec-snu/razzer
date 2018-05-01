#include <stdio.h>

int main()
{
	int a;
	register unsigned long sp asm("sp");

	printf("a = %p sp = %p\n", &a, sp);

	return 0;
}
