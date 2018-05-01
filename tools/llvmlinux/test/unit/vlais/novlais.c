#include <stdio.h>
#include <string.h>
#include "util.h"
#include "valign.h"

TESTFUNC(NOVLAIS)
{
	size_t sa = paddedsize(0, a, TYPEA, TYPEB);
	size_t sb = paddedsize(sa, b, TYPEB, TYPEC);
	size_t sc = paddedsize(sa+sb, c, TYPEC, TYPED);
	size_t sd = paddedsize(sa+sb+sc, d, TYPED, TYPED);
	ptr->size = sa+sb+sc+sd;

	char *aa = paddedstart(ptr->buffer, 0, TYPEA);
	short *bb = paddedstart(aa, sa, TYPEB);
	int *cc = paddedstart(bb, sb, TYPEC);
	long *dd = paddedstart(cc, sc, TYPED);
	long long *ee = paddedstart(dd, sd, long long);

	ptr->offsets = offsets(0, sa, sa+sb, sa+sb+sc);

	memset(ptr->buffer, 0, ptr->size);
	memset(dd, 4, sd);
	memset(cc, 3, sc);
	memset(bb, 2, sb);
	memset(aa, 1, sa);
}
