#include <stdio.h>
#include <ctype.h>

void printHex(char *buffer, size_t size)
{
	int i, j;
	int stride = 16;

	for (i=0; i<size; i+=stride) {
		printf("0x%04X  ", i);
		for (j=i; j<i+stride; j++) {
			printf("%02X ", buffer[j] & 0XFF);
			if (j%4 == 3) printf(" ");
		}
		for (j=i; j<i+stride; j++) {
			printf("%c", isprint(buffer[j]) ? buffer[j] : '.');
			if (j%4 == 3) printf(" ");
		}
		printf("\n");
	}
}

void NOVLAIS(char *buffer, size_t size)
{
	printHex(buffer, size);
}

