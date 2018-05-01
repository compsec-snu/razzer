/* Copyright (c) 2013, The Linux Foundation. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 *       copyright notice, this list of conditions and the following
 *       disclaimer in the documentation and/or other materials provided
 *       with the distribution.
 *     * Neither the name of The Linux Foundation nor the names of its
 *       contributors may be used to endorse or promote products derived
 *       from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE
 * OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN
 * IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
/* Fixup the atags for dragonboard (and possibly other targets). */
/*
 * The bootloader on some targets passes an ATAG in that sets the
 * first memory region to be 2MB after the actual start of memory.
 * With newer upstream kernels, the PHYS_OFFSET must be a multiple of
 * a large boundary (currently 128MB).  Without devicetree, we work
 * around this with an early init hook, and a fixup that adds a
 * reservation.  These hooks don't run in time to fix it in Device
 * tree.
 *
 * The following code can be prepended to the zImage.  It adjusts the
 * memory atag back down to the actual start of memory.  The
 * assumption is that the device tree will describe the necessary
 * memory reservation.  The zImage is relocatable, so it is easy to
 * prepend this code.
 */

	/* Figure out what the broken mem tag would be */
	mov	r8, pc
	and	r8, r8, #0xf8000000
	add	r8, r8, #0x00200000

	/* R2 is where the atags are passed.  r5 on are scratch. */
	mov	r5, r2
	ldr	r7, .tag_mem

.next:
	/* Load the tag, and check. */
	ldr	r6, [r5, #4]
	cmp	r6, #0
	beq	.done

	/* Is the a 'mem' tag. */
	cmp	r6, r7
	bne	.not_mem

	/* Is this memory base what we want? */
	ldr	r6, [r5, #12]
	cmp	r6, r8

	subeq	r6, r6, #0x200000
	streq	r6, [r5, #12]
	ldreq	r6, [r5, #8]
	addeq	r6, r6, #0x200000
	streq	r6, [r5, #8]

.not_mem:
	/* Move r5 to the next tag. */
	ldr	r6, [r5, #0]
	add	r5, r5, r6, asl #2
	b	.next

.tag_mem:
	.word	0x54410002

.done:
