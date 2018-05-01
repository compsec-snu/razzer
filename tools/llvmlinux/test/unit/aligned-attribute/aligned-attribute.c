#include <stdio.h>

typedef unsigned char u8;
typedef __attribute__ ((aligned)) u8 u8_align;
typedef __attribute__ ((aligned(1))) u8 u8_align1;
typedef __attribute__ ((aligned(2))) u8 u8_align2;
typedef __attribute__ ((aligned(4))) u8 u8_align4;
typedef __attribute__ ((aligned(8))) u8 u8_align8;
typedef __attribute__ ((aligned(16))) u8 u8_align16;
typedef __attribute__ ((aligned(32))) u8 u8_align32;

#define test_aligned_default(mask) (unsigned int)(mask & ~(__alignof__(u8_align) - 1))
#define test_aligned(mask, val)    (unsigned int)(mask & ~(__alignof__(u8_align##val) - 1))

#define test_aligned_default_gcc(mask) (unsigned int)(mask & ~(__alignof__(u8 __attribute__ ((aligned))) - 1))
#define test_aligned_gcc(mask, val)    (unsigned int)(mask & ~(__alignof__(u8 __attribute__ ((aligned(val)))) - 1))

void test_mask(unsigned mask)
{
	printf("----------------------------------\n");
	printf("Mask value: 0x%x\n", mask);
	printf("test_aligned_default    : 0x%x\n", test_aligned_default(mask));
	printf("test_aligned(1)         : 0x%x\n", test_aligned(mask, 1));
	printf("test_aligned(2)         : 0x%x\n", test_aligned(mask, 2));
	printf("test_aligned(4)         : 0x%x\n", test_aligned(mask, 4));
	printf("test_aligned(8)         : 0x%x\n", test_aligned(mask, 8));
	printf("test_aligned(16)        : 0x%x\n", test_aligned(mask, 16));
	printf("test_aligned(32)        : 0x%x\n", test_aligned(mask, 32));

	printf("test_aligned_default-gcc: 0x%x\n", test_aligned_default(mask));
	printf("test_aligned_gcc(1)     : 0x%x\n", test_aligned(mask, 1));
	printf("test_aligned_gcc(2)     : 0x%x\n", test_aligned(mask, 2));
	printf("test_aligned_gcc(4)     : 0x%x\n", test_aligned(mask, 4));
	printf("test_aligned_gcc(8)     : 0x%x\n", test_aligned(mask, 8));
	printf("test_aligned_gcc(16)    : 0x%x\n", test_aligned(mask, 16));
	printf("test_aligned_gcc(32)    : 0x%x\n", test_aligned(mask, 32));
}

int main()
{
	printf("__alignof__(u8)         : 0x%lx\n", __alignof__(u8));
	printf("__alignof__(u8_align)   : 0x%lx\n", __alignof__(u8_align));
	test_mask(0x0000000f);
	test_mask(0x0000ffff);
	test_mask(0x00ffffff);

	return 0;
}

