/*
 * aes-ce-cipher.c - core AES cipher using ARMv8 Crypto Extensions
 *
 * Copyright (C) 2013 - 2014 Linaro Ltd <ard.biesheuvel@linaro.org>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * Mark Charlebois: Modified for debugging
 */

struct aes_block {
	unsigned char b[16];
};

void aes_cipher_decrypt(unsigned int *key_dec, struct aes_block *out, struct aes_block const *in)
{
	void *dummy0;
	int dummy1;
	int num_rounds = 10;

	__asm__("	ld1	{v0.16b}, %[in]			;"
		"	ld1	{v1.2d}, [%[key]], #16		;"
		"	cmp	%w[rounds], #10			;"
		"	bmi	0f				;"
		"	bne	3f				;"
		"	mov	v3.16b, v1.16b			;"
		"	b	2f				;"
		"0:	mov	v2.16b, v1.16b			;"
		"	ld1	{v3.2d}, [%[key]], #16		;"
		"1:	aesd	v0.16b, v2.16b			;"
		"	aesimc	v0.16b, v0.16b			;"
		"2:	ld1	{v1.2d}, [%[key]], #16		;"
		"	aesd	v0.16b, v3.16b			;"
		"	aesimc	v0.16b, v0.16b			;"
		"3:	ld1	{v2.2d}, [%[key]], #16		;"
		"	subs	%w[rounds], %w[rounds], #3	;"
		"	aesd	v0.16b, v1.16b			;"
		"	aesimc	v0.16b, v0.16b			;"
		"	ld1	{v3.2d}, [%[key]], #16		;"
		"	bpl	1b				;"
		"	aesd	v0.16b, v2.16b			;"
		"	eor	v0.16b, v0.16b, v3.16b		;"
		"	st1	{v0.16b}, %[out]		;"

	:	[out]		"=Q"(*out),
		[key]		"=r"(dummy0),
		[rounds]	"=r"(dummy1)
	:	[in]		"Q"(*in),
				"1"(key_dec),
				"2"(num_rounds)
	:	"cc");

}
