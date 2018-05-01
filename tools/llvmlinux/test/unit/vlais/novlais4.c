#include <stdio.h>
#include <string.h>
#include "util.h"

#define vlaoffset(next, x) (next + __alignof__(__typeof__(*x)) - 1) & ~(__alignof__(__typeof__(*x)) - 1)
#define vlasz(x, n) n * sizeof(__typeof__(*x))
#define vlastart int __vla_next = 0
#define vlai(type, name, num) type *name; \
				size_t name##__offset = vlaoffset(__vla_next, name); \
				__vla_next = name##__offset + vlasz(name, num)
#define vlap(name, data) name = (__typeof__(name))&data[name##__offset]
#define vlatotal __vla_next
#define vlareset __vla_next = 0

TESTFUNC(NOVLAIS)
{
	vlastart;
	vlai(char, foo_a, a);
	vlai(short, foo_b, b);
	vlai(int, foo_c, c);
	vlai(long, foo_d, d);
	ptr->size = vlatotal;

        char *foo_data = (char *)&(ptr->buffer[0]);
	vlap(foo_a, foo_data);
	vlap(foo_b, foo_data);
	vlap(foo_c, foo_data);
	vlap(foo_d, foo_data);
	
	ptr->offsets = offsets(foo_a__offset, foo_b__offset, foo_c__offset, foo_d__offset);

	memset(ptr->buffer, 0, ptr->size);
	memset(foo_d, 4, vlasz(foo_d, d));
	memset(foo_c, 3, vlasz(foo_c, c));
	memset(foo_b, 2, vlasz(foo_b, b));
	memset(foo_a, 1, vlasz(foo_a, a));
}
