#include <stdio.h>
#include <string.h>
#include "util.h"

#define paddedsize(offset,name,type,n) \
	type *name; \
	size_t pad_##name = (~__alignof__(type)) & (offset % __alignof__(type)); \
	size_t offset_##name = offset + pad_##name; \
	size_t sz_##name = n * sizeof(type); \
	size_t next_##name = offset + pad_##name + sz_##name; 
	
#define paddedstart(ptr,name) name = (__typeof__(name))&ptr[offset_##name]

TESTFUNC(NOVLAIS)
{
	paddedsize(0,          var_a, TYPEA, a);
	paddedsize(next_var_a, var_b, TYPEB, b);
	paddedsize(next_var_b, var_c, TYPEC, c);
	paddedsize(next_var_c, var_d, TYPED, d);
	ptr->size = next_var_d;

	paddedstart(ptr->buffer, var_a);
	paddedstart(ptr->buffer, var_b);
	paddedstart(ptr->buffer, var_c);
	paddedstart(ptr->buffer, var_d);

	ptr->offsets = offsets(0, offset_var_b, offset_var_c, offset_var_d);

	memset(ptr->buffer, 0, ptr->size);
	memset(var_d, 4, sz_var_d);
	memset(var_c, 3, sz_var_c);
	memset(var_b, 2, sz_var_b);
	memset(var_a, 1, sz_var_a);
}
