#!/bin/bash

# BASE is defined in Makefile and exported

TESTDIR=${BASE}/test/unit/mergedglobal/old/clang

# Prebuilt Clang
#CLANGDIR=${BASE}/toolchain/clang/clang+llvm-3.3-Ubuntu-13.04-x86_64-linux-gnu/bin
#VERSION=3.3

# Src Clang
CLANGDIR=${BASE}/toolchain/clang/install/bin
VERSION=3.4

VEXPRESSSRC=${BASE}/targets/vexpress/src/linux

rm -f foo.o foo-gcc.o

# .o
${CLANGDIR}/clang -gcc-toolchain ${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05 -nostdinc -isystem ${CLANGDIR}/../lib/clang/${VERSION}/include -I. -include ${TESTDIR}/kconfig.h -D__KERNEL__ -Qunused-arguments -target arm-none-linux-gnueabi -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -no-integrated-as -O2 -fno-builtin -Wno-asm-operand-widths -fno-dwarf2-cfi-asm -funwind-tables -D__LINUX_ARM_ARCH__=7 -march=armv7-a -msoft-float -Wframe-larger-than=1024 -fno-stack-protector -Wno-unused-variable -Wno-format-invalid-specifier -Wno-gnu -Wno-tautological-compare -fomit-frame-pointer -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -D"KBUILD_STR(s)=#s" -D"KBUILD_BASENAME=KBUILD_STR(rtnetlink)"  -D"KBUILD_MODNAME=KBUILD_STR(rtnetlink)" -c -o foo.o foo.c 

${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05/bin/arm-none-linux-gnueabi-gcc -nostdinc -I. -include ${TESTDIR}/kconfig.h -D__KERNEL__ -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -O2 -fno-builtin -fno-dwarf2-cfi-asm -funwind-tables -D__LINUX_ARM_ARCH__=7 -march=armv7-a -msoft-float -Wframe-larger-than=1024 -fno-stack-protector -Wno-unused-variable -fomit-frame-pointer -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -D"KBUILD_STR(s)=#s" -D"KBUILD_BASENAME=KBUILD_STR(rtnetlink)"  -D"KBUILD_MODNAME=KBUILD_STR(rtnetlink)" -c -o foo-gcc.o foo.c 2>/dev/null

[ -e foo.o ] && ${TESTDIR}/modpost ./foo.o > outfile 2>&1 && grep "Section mismatch in reference from the variable _MergedGlobals to the function .init.text:rtnetlink_net_init" outfile && \
[ -e foo-gcc.o ] && ${TESTDIR}/modpost ./foo-gcc.o > outfile-gcc 2>&1 && ! grep "Section mismatch in reference from the variable" outfile-gcc
