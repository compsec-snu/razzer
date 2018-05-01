typedef struct {
        int counter;
} atomic_t;

/*
 * AArch64 UP and SMP safe atomic ops.  We use load exclusive and
 * store exclusive to ensure that these are atomic.  We may loop
 * to ensure that the update happens.
 */
static inline void atomic_add(int i, atomic_t *v)
{
	unsigned long tmp;
	int result;

	__asm__ __volatile__("// atomic_add\n"
"1:	ldxr	%w0, [%3]\n"
"	add	%w0, %w0, %w4\n"
"	stxr	%w1, %w0, [%3]\n"
"	cbnz	%w1, 1b"
	: "=&r" (result), "=&r" (tmp), "+o" (v->counter)
	: "r" (&v->counter), "Ir" (i)
	: "cc");
}

static inline void atomic_sub(int i, atomic_t *v)
{
	unsigned long tmp;
	int result;

	asm volatile("// atomic_sub\n"
"1:	ldxr	%w0, [%3]\n"
"	sub	%w0, %w0, %w4\n"
"	stxr	%w1, %w0, [%3]\n"
"	cbnz	%w1, 1b"
	: "=&r" (result), "=&r" (tmp), "+o" (v->counter)
	: "r" (&v->counter), "Ir" (i)
	: "cc");
}

#define atomic_inc(v)		atomic_add(1, v)
#define atomic_dec(v)		atomic_sub(1, v)

int main()
{
	atomic_t foo = { .counter=0 };

	atomic_inc(&foo);
	atomic_dec(&foo);
}
