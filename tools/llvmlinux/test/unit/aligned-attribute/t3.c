#include <stdio.h>

int main()
{
char a[1];
char b[1] __attribute__ ((__aligned__(__alignof__(unsigned long long))));; 
char c[1];
char d[1]; 

char *offset = a;

printf("size %lu location: %p offset: %ld\n", sizeof(a), a, a-offset);
printf("size %lu location: %p offset: %ld\n", sizeof(b), b, b-offset);
printf("size %lu location: %p offset: %ld\n", sizeof(c), c, c-offset);
printf("size %lu location: %p offset: %ld\n", sizeof(d), d, d-offset);
}

