#include <stdio.h>

int main()
{
char a[1];
char b[1]; 
char c[1];
char d[1]; 

char *offset = a;

printf("size %lu location: %p offset: %lu\n", sizeof(a), a, a-offset);
printf("size %lu location: %p offset: %lu\n", sizeof(b), b, b-offset);
printf("size %lu location: %p offset: %lu\n", sizeof(c), c, c-offset);
printf("size %lu location: %p offset: %lu\n", sizeof(d), d, d-offset);
}

