/* Common VLAIS header */

#ifndef __COMMON_VLAIS_H__
#define __COMMON_VLAIS_H__

#include <sys/time.h>

extern void printHex(char *buffer, size_t size);

struct testdata {
	long size, offsets, usecs;
	struct timeval before, after;
	char buffer[64];
};

#define TYPEA char
#define TYPEB short
#define TYPEC int
#define TYPED long

#define offsets(a, b, c, d) ((a) << 24 | (b) << 16 | (c) << 8 | (d))

typedef void (*testfunc)(struct testdata *ptr, int a, int b, int c, int d);
#define TESTFUNC(name) void name(struct testdata *ptr, int a, int b, int c, int d)

#endif /* __COMMON_VLAIS_H__ */
