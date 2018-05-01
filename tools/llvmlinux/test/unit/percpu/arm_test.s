	.syntax unified
	.cpu	arm7tdmi
	.eabi_attribute	6, 2
	.eabi_attribute	8, 1
	.eabi_attribute	20, 1
	.eabi_attribute	21, 1
	.eabi_attribute	23, 3
	.eabi_attribute	24, 1
	.eabi_attribute	25, 1
	.file	"percpu.c"
	.text
	.globl	main
	.align	2
	.type	main,%function
main:
	push	{r11, lr}
	@APP
	mrc p15, 0, r1, c13, c0, 4
	@NO_APP
	ldr	r0, .LCPI0_0
	mov	r11, sp
	bl	printf
	mov	r0, #0
	pop	{r11, lr}
	bx	lr
	.align	2
.LCPI0_0:
	.long	.L.str
.Ltmp0:
	.size	main, .Ltmp0-main

	.type	.L.str,%object
	.section	.rodata.str1.1,"aMS",%progbits,1
.L.str:
	.asciz	"Offset = %lu\n"
	.size	.L.str, 14


	.ident	"clang version 3.4 "
