all: test test_gcc

TOPDIR		= $(realpath ../../..)
TARGETDIR	= $(TOPDIR)/targets/vexpress
CROSS_ARM_TOOLCHAIN = codesourcery
ARMGCCSYSROOT=`arm-none-linux-gnueabi-gcc -print-sysroot`

include ${TOPDIR}/common.mk
# We need one arch, this is as good as any
include ${ARCHDIR}/arm/arm.mk

#================================================================================

test: test.c
	${CLANGCC} -Wall --sysroot=${ARMGCCSYSROOT} $< -static -o $@

test_gcc: test.c
	${CROSS_COMPILE}gcc -Wall $< -static -o $@

debug:
	gdb -tui -x gdbcmds /local2/mnt/workspace/llvmlinux/toolchain/clang/install/bin/clang-3.5
hexdump:
	cat test.c | hexdump -v  -e '/1  "%_ad#  "' -e '/1 " _%_u\_\n"'
clean:
	rm -f test test_gcc
