#include <stdio.h>
#include <string.h>
#include "util.h"

#define vla_group(groupname) size_t groupname##__##next = 0
#define vla_group_size(groupname) groupname##__##next

#define vla_item(groupname, type, name, n) \
       size_t groupname##_##name##__##offset = \
               (groupname##__##next + __alignof__(type) - 1) & \
               ~(__alignof__(type) - 1); \
       size_t groupname##_##name##__##sz = (n) * sizeof(type); \
       type * groupname##_##name = ({ \
       groupname##__##next = groupname##_##name##__##offset + \
               groupname##_##name##__##sz; NULL;})

#define vla_ptr(ptr,groupname,name) groupname##_##name = \
       (__typeof__(groupname##_##name))&ptr[groupname##_##name##__##offset]


TESTFUNC(NOVLAIS)
{
	vla_group(foo);
	vla_item(foo, TYPEA, vara, a-1+1);
	vla_item(foo, TYPEB, varb, b-1+1);
	vla_item(foo, TYPEC, varc, c-1+1);
	vla_item(foo, TYPED, vard, d-1+1);

	ptr->size = vla_group_size(foo);

	vla_ptr(ptr->buffer, foo, vara);
	vla_ptr(ptr->buffer, foo, varb);
	vla_ptr(ptr->buffer, foo, varc);
	vla_ptr(ptr->buffer, foo, vard);

	ptr->offsets = offsets(0, foo_varb__offset, foo_varc__offset, foo_vard__offset);

	memset(ptr->buffer, 0, ptr->size);
	memset(foo_vard, 4, foo_vard__sz);
	memset(foo_varc, 3, foo_varc__sz);
	memset(foo_varb, 2, foo_varb__sz);
	memset(foo_vara, 1, foo_vara__sz);
}
