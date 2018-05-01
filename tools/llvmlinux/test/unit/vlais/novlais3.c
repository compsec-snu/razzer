#include <stdio.h>
#include <string.h>
#include "util.h"

#define vlaoffset(next, x) (next + __alignof__(__typeof__(*x)) - 1) & ~(__alignof__(__typeof__(*x)) - 1)
#define vlasz(x, n) n * sizeof(__typeof__(*x))
#define vlastart int __vla_next = 0
#define vla_data(type, name) type *name; size_t name##__offset
#define vlai(name, num) name##__offset = vlaoffset(__vla_next, name); \
                               __vla_next = name##__offset + vlasz(name, num)
#define vlap(name, data) name = (__typeof__(name))&data[name##__offset]
#define vlatotal __vla_next
#define vlareset __vla_next = 0

TESTFUNC(NOVLAIS)
{
	struct {
		vla_data(TYPEA, a);
		vla_data(TYPEB, b);
		vla_data(TYPEC, c);
		vla_data(TYPED, d);
		char *data;
	} foo;

	vlastart;
        vlai(foo.a, a);
	vlai(foo.b, b);
	vlai(foo.c, c);
	vlai(foo.d, d);
	ptr->size = vlatotal;
	ptr->offsets = offsets(foo.a__offset, foo.b__offset, foo.c__offset, foo.d__offset);

        foo.data = (char *)&(ptr->buffer[0]);
	vlap(foo.a, foo.data);
	vlap(foo.b, foo.data);
	vlap(foo.c, foo.data);
	vlap(foo.d, foo.data);

	memset(ptr->buffer, 0, ptr->size);
	memset(foo.d, 4, vlasz(foo.d, d));
	memset(foo.c, 3, vlasz(foo.c, c));
	memset(foo.b, 2, vlasz(foo.b, b));
	memset(foo.a, 1, vlasz(foo.a, a));
}
