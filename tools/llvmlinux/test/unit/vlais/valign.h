/*
 * Variable alignment macros used to break up a larger chunk of memory into
 * smaller variables. Meant to be used to replace the use of Variable Length
 * Arrays In Structures (VLAIS)
 *
 *  Copyright (C) 2012 Behan Webster <behanw@conversincode.com>
 */

#ifndef _VALIGN_H_
#define _VALIGN_H_

/**
 * truncalign() - Align a memory address by truncation
 * @num:	Address or size to align
 * @padwidth:	Number of byte upon which to align
 *
 * Truncate an address or size to a particular memory alignment.
 * Used by truncalign().
 */
#define truncalign(num, padwidth) ((long)(num) & ~((padwidth)-1))

/**
 * padalign() - Align a memory address by padding
 * @num:	Address or size to align
 * @padwidth:	Number of byte upon which to align
 *
 * Pad out an address or size to a particular memory alignment
 * Used by paddedsize() and paddedstart().
 */
#define padalign(num, padwidth) \
	truncalign((long)(num) + ((padwidth)-1), padwidth)

/**
 * paddedsize() - Calculate the size of an chunk of aligned memory
 * @offset:	Unaligned offset to the start of the chunk size being calculated
 * @num:	The number of variables in the array of "type" (can be 1)
 * @type:	The type of variables in the array
 * @nexttype:	The type of the next variable in the large piece of memory
 *
 * Calculate the size that a variable (or array) will take as a part of a
 * larger piece of memory.  Takes into account a potentially unaligned offset
 * into the larger piece of allocated memory, the alignment of the variable
 * type, and the alignement of the type of the variable to be used after that.
 *
 * Example: size_t l = paddedsize(1, 2, short, int);
 *
 * The example above would give you a padded size of 6 bytes: 2x 16-bit shorts,
 * starting at 2 bytes into the buffer (the offset of 1 byte being padded out
 * to 2 bytes) followed by 2 bytes of padding so that the next type (a 32-bit
 * int) would be 32-bit aligned. looking like this:
 *
 *   0: O.SS SS.. iiii
 *        \-----/ <-- 2 shorts + 2 bytes of padding = size of 6 bytes
 *
 * O = The offset
 * . = Padding bytes
 * S = 2 shorts
 * i = int which will theoretically be next
 */
#define paddedsize(offset, num, type, nexttype) (padalign((offset) \
	+ (num) * sizeof(type), __alignof__(nexttype)) - (offset))

/**
 * paddedstart() - Calculate the start of a chunk of aligned memory
 * @ptr:	Pointer from which to calculate the start of the chunk
 * @offset:	Offset from the ptr to the start of the chunk being calculated
 * @type:	The type of variable in the chunk of memory
 *
 * Calculate the start address of a variable based on the offset from an
 * address, aligned based on the type of the variable specified.
 *
 * Example: char *data = kmalloc(size, GFP_KERNEL);
 *          long *var = paddedstart(data, 12, long);
 *
 * The example above on a 64-bit machine would return the equivalent of
 * &buffer[16] since a long needs to be 8 byte aligned.
 *
 *   0: OOOO OOOO OOOO .... LLLL LLLL
 *                          ^ <-- The start address of the long
 * O = The offset
 * . = Padding bytes
 * L = The long
 */
#define paddedstart(ptr, offset, type) \
	(type *)padalign((long)(ptr)+(offset), __alignof__(type))

#endif
