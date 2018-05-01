	.arch armv5te
	.fpu softvfp
	.eabi_attribute 20, 1
	.eabi_attribute 21, 1
	.eabi_attribute 23, 3
	.eabi_attribute 24, 1
	.eabi_attribute 25, 1
	.eabi_attribute 26, 2
	.eabi_attribute 30, 2
	.eabi_attribute 34, 0
	.eabi_attribute 18, 4
	.file	"percpu.c"
	.section	.text.startup,"ax",%progbits
	.align	2
	.global	main
	.type	main, %function
main:
	.fnstart
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 0, uses_anonymous_args = 0
	@ link register save eliminated.
#APP
@ 29 "percpu.c" 1
	mrc p15, 0, r1, c13, c0, 4
@ 0 "" 2
	ldr	r0, .L2
	b	printf
.L3:
	.align	2
.L2:
	.word	.LC0
	.fnend
	.size	main, .-main
	.section	.rodata.str1.4,"aMS",%progbits,1
	.align	2
.LC0:
	.ascii	"Offset = %lu\012\000"
	.ident	"GCC: (Sourcery CodeBench Lite 2013.05-24) 4.7.3"
	.section	.note.GNU-stack,"",%progbits
