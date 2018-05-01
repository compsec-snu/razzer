#include <stdio.h>
#include <stdlib.h>
#include <stddef.h>
 
double do_log2(double a)
{
	return __builtin_log2(a);
}

int main()
{
	printf("%lf\n", do_log2(16.0));
}


