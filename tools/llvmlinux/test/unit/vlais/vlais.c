#include <stdio.h>
#include <stddef.h>
#include <string.h>
#include "util.h"

TESTFUNC(vlais)
{
	struct vlais {
		TYPEA a[a];
		TYPEB b[b];
		TYPEC c[c];
		TYPED d[d];
	};
	struct vlais *v = (struct vlais*)&(ptr->buffer[0]);

	ptr->size = sizeof(struct vlais);
	ptr->offsets = offsets(
		offsetof(struct vlais, a),
		offsetof(struct vlais, b),
		offsetof(struct vlais, c),
		offsetof(struct vlais, d)
	);

	memset(v, 0, ptr->size);
	memset(v->d, 4, sizeof(v->d));
	memset(v->c, 3, sizeof(v->c));
	memset(v->b, 2, sizeof(v->b));
	memset(v->a, 1, sizeof(v->a));
}
