#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "util.h"

#define vlais_args 1, 2, 3, 3

#ifdef TIMING
long vlais_timing_count = 100000000L;
#else
long vlais_timing_count = 1;
#endif

#define QUOTEME(x) #x

unsigned long tvdiff(const struct timeval *before, const struct timeval *after)
{
	unsigned long usecs;
	usecs = (after->tv_sec - before->tv_sec) * 1000 * 1000;
	usecs += after->tv_usec - before->tv_usec;

	return usecs;
}

void results(const char* fmt, const char* name, const char* cc, struct testdata *data, long diff)
{
	printf(fmt, name, cc);
	printf("\t0x%08X size:%ld usecs:%lu diff:%ld\n", (unsigned int)data->offsets, data->size, data->usecs, diff);
}

/* Time runtime of func */
void runtime(testfunc func, struct testdata *data)
{
	gettimeofday(&data->before, NULL);
	unsigned long i;
	for(i=vlais_timing_count; i; i--)
		func(data, vlais_args);
	gettimeofday(&data->after, NULL);
	data->usecs = tvdiff(&data->before, &data->after);
}

/* Run the test with a particular compiled routine */
void runtest(testfunc func, const char *name, const char *cc, struct testdata *soln)
{
	struct testdata data;
	memset(&data, 0, sizeof(data));
	runtime(func, &data);
	if(memcmp(data.buffer, soln->buffer, soln->size))
		printHex(data.buffer, sizeof(data.buffer));
	char* fmt = "PASS: %s works with %s  ";
	if (data.offsets != soln->offsets)
		fmt = "FAIL: %s doesn't work with %s  ";
	results(fmt, name, cc, &data, data.usecs - soln->usecs);
}
#define RUNTEST(name, cc, soln) runtest(name##_##cc, QUOTEME(name##_##cc), QUOTEME(cc), soln)

/* Run the test with a all compiled routines */
#define NO_VLAIS_TEST(name) \
	extern TESTFUNC(name ## _gcc); \
	extern TESTFUNC(name ## _clang); \
	void test_ ## name (struct testdata *soln) { \
		RUNTEST(name, gcc, soln); \
		RUNTEST(name, clang, soln); \
	}

/* Define all test routines */
extern TESTFUNC(vlais);
NO_VLAIS_TEST(novlais)
NO_VLAIS_TEST(novlais1)
NO_VLAIS_TEST(novlais2)
NO_VLAIS_TEST(novlais3)
NO_VLAIS_TEST(novlais4)

int main(void)
{
	struct testdata test1;
	memset(&test1, 0, sizeof(test1));
	runtime(vlais, &test1);
	printHex(test1.buffer, sizeof(test1.buffer));
	results("PASS: %s works with %s       ", "vlais", "gcc", &test1, 0);

	test_novlais(&test1);
	test_novlais1(&test1);
	test_novlais2(&test1);
	printHex(test1.buffer, sizeof(test1.buffer));
	test_novlais3(&test1);
	test_novlais4(&test1);

	return 0;
}
