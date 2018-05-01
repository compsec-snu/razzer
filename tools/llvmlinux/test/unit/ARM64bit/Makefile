#
# Unit test framwork for Kbuild
#

all: testcase1

TOPDIR         = $(realpath ../../..)
TARGETDIR      = $(TOPDIR)/targets/vexpress

include ${TOPDIR}/common.mk
# We need one arch, this is as good as any
include ${ARCHDIR}/arm/arm.mk

#================================================================================

testcase: context-parsed.c
	${CLANG} -gcc-toolchain ${COMPILER_PATH}/bin -target arm-linux-gnueabi -include ./include/kconfig.h -D __KERNEL__ -D __LINUX_ARM_ARCH__=7 -I ./include -O2 -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -Werror-implicit-function-declaration -Wno-format-security -Wno-asm-operand-widths -Wno-unused-variable -Wno-tautological-compare -Wdeclaration-after-statement -Wno-pointer-sign -fno-dwarf2-cfi-asm -fno-dwarf-directory-asm -fdebug-compilation-dir -fwrapv -mstackrealign -fno-builtin -fobjc-runtime=gcc -fno-common -fdiagnostics-show-option -fcolor-diagnostics -c -o context.o $? -static

testcase1: context-reduced.c
	-${CLANG} -target arm-linux-gnueabi -O2 -c $^ -w -o context-reduced.o
	@echo '--------------------------------------------------------'
	arm-linux-gnueabi-gcc -O2 -c $^ -w -o context-reduced.o
