#include "common.h"

static u32 mdscr_read_fails_for_clang(void)
{
        u32 mdscr;
        asm volatile("mrs %0, mdscr_el1" : "=r" (mdscr));
        return mdscr;
}

static u32 mdscr_read_ok_for_clang(void)
{
	// mdscr_read requires a workaround for clang to pass a 64bit type
	// to the asm statement
        u64 mdscr;
        asm volatile("mrs %0, mdscr_el1" : "=r" (mdscr));
        return (u32)mdscr;
}

int main()
{
	printf("mdsr = %d\n", mdscr_read_fails_for_clang());
	printf("mdsr = %d\n", mdscr_read_ok_for_clang());
}
