#include <stdio.h>

int main()
{
	int a;

	printf("a = %p sp = %p\n", &a, __builtin_stack_pointer());

	return 0;
}
