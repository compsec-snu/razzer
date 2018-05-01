#!/bin/bash

TOPDIR=/local2/mnt/workspace/llvmlinux

rm -f x.s elog

${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/aarch64-linux-gnu-gcc -nostdinc -isystem ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/../lib/gcc/aarch64-linux-gnu/4.8.2/include -D__KERNEL__ -mlittle-endian -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -mgeneral-regs-only -fno-delete-null-pointer-checks -O2 --param=allow-store-data-races=0 -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-but-set-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -fno-var-tracking-assignments -fno-inline-functions-called-once -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -Werror=implicit-int -Werror=strict-prototypes    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(slub)"  -D"KBUILD_MODNAME=KBUILD_STR(slub)" -S -o x.s x.c 2>elog || true

[ ! -e x.s ] && grep "prfm pldl1keep, \[%x0\]" elog && grep "error: invalid 'asm': invalid operand" elog

