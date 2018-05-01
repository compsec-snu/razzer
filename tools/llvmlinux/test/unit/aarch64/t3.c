#include "common.h"

#define MT_NORMAL 4

int main()
{
	u64 foo, tmp;

	// This works for both clang and gcc
	asm volatile(
	"	mrs	%0, mair_el1\n"
	"	bfi	%0, %1, %2, #8\n"
	"	msr	mair_el1, %0\n"
	"	isb\n"
	: "=&r" (tmp)
	: "r" (foo), "i" (MT_NORMAL * 8));

	// This fails for clang but not gcc
	asm volatile(
	"	mrs	%0, mair_el1\n"
	"	bfi	%0, %1, #%2, #8\n"
	"	msr	mair_el1, %0\n"
	"	isb\n"
	: "=&r" (tmp)
	: "r" (foo), "i" (MT_NORMAL * 8));
}
