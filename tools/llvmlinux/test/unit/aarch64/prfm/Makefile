TARGETDIR	= ${CURDIR}
TOPDIR		= $(realpath ${TARGETDIR}/../../../..)
#include	${TOPDIR}/common.mk

all: x-clang.s x-gcc.s z-clang.s z-gcc.s y-clang.s y-gcc.s

list-var:
	@echo ${TARGETDIR}
	@echo ${TOPDIR}

# GCC build command
# aarch64-linux-gnu-gcc -Wp,-MD,mm/.slub.o.d  -nostdinc -isystem ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/../lib/gcc/aarch64-linux-gnu/4.8.2/include -I${TOPDIR}/targets/vexpress64/src/linux/arch/arm64/include -Iarch/arm64/include/generated  -I${TOPDIR}/targets/vexpress64/src/linux/include -Iinclude -I${TOPDIR}/targets/vexpress64/src/linux/arch/arm64/include/uapi -Iarch/arm64/include/generated/uapi -I${TOPDIR}/targets/vexpress64/src/linux/include/uapi -Iinclude/generated/uapi -include ${TOPDIR}/targets/vexpress64/src/linux/include/linux/kconfig.h  -I${TOPDIR}/targets/vexpress64/src/linux/mm -Imm -D__KERNEL__ -mlittle-endian -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -mgeneral-regs-only -fno-delete-null-pointer-checks -O2 --param=allow-store-data-races=0 -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-but-set-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -fno-var-tracking-assignments -g -fno-inline-functions-called-once -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -Werror=implicit-int -Werror=strict-prototypes    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(slub)"  -D"KBUILD_MODNAME=KBUILD_STR(slub)" -c -o mm/slub.o ${TOPDIR}/targets/vexpress64/src/linux/mm/slub.c

# Clang build command
# ${TOPDIR}/toolchain/clang/head/install/bin/clang -gcc-toolchain ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux -target aarch64-linux-gnu -target aarch64-linux-gnu -Wp,-MD,mm/.slub.o.d  -nostdinc -isystem ${TOPDIR}/toolchain/clang/head/install/bin/../lib/clang/3.6.0/include -I${TOPDIR}/targets/vexpress64/src/linux/arch/arm64/include -Iarch/arm64/include/generated  -I${TOPDIR}/targets/vexpress64/src/linux/include -Iinclude -I${TOPDIR}/targets/vexpress64/src/linux/arch/arm64/include/uapi -Iarch/arm64/include/generated/uapi -I${TOPDIR}/targets/vexpress64/src/linux/include/uapi -Iinclude/generated/uapi -include ${TOPDIR}/targets/vexpress64/src/linux/include/linux/kconfig.h  -I${TOPDIR}/targets/vexpress64/src/linux/mm -Imm -D__KERNEL__ -target aarch64-linux-gnu -mlittle-endian -Qunused-arguments -Wno-unknown-warning-option -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -no-integrated-as -Wno-format-security -fno-builtin -Wno-asm-operand-widths -Wno-initializer-overrides -mgeneral-regs-only -O2 --param=allow-store-data-races=0 -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-variable -Wno-format-invalid-specifier -Wno-gnu -Wno-tautological-compare -mno-global-merge -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -Werror=implicit-int -Werror=strict-prototypes -Werror=date-time -Wno-initializer-overrides -Wno-unused-value -Wno-format -Wno-unknown-warning-option -Wno-sign-compare -Wno-format-zero-length -Wno-uninitialized    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(slub)"  -D"KBUILD_MODNAME=KBUILD_STR(slub)" -c -o mm/slub.o ${TOPDIR}/targets/vexpress64/src/linux/mm/slub.c

x-clang.s: x.c
	${TOPDIR}/toolchain/clang/head/install/bin/clang -gcc-toolchain ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux -target aarch64-linux-gnu -target aarch64-linux-gnu -nostdinc -isystem ${TOPDIR}/toolchain/clang/head/install/bin/../lib/clang/3.6.0/include -D__KERNEL__ -target aarch64-linux-gnu -mlittle-endian -Qunused-arguments -Wno-unknown-warning-option -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -no-integrated-as -Wno-format-security -fno-builtin -Wno-asm-operand-widths -Wno-initializer-overrides -mgeneral-regs-only -O2 --param=allow-store-data-races=0 -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-variable -Wno-format-invalid-specifier -Wno-gnu -Wno-tautological-compare -mno-global-merge -fno-omit-frame-pointer -fno-optimize-sibling-calls -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -Werror=implicit-int -Werror=strict-prototypes -Werror=date-time -Wno-initializer-overrides -Wno-unused-value -Wno-format -Wno-unknown-warning-option -Wno-sign-compare -Wno-format-zero-length -Wno-uninitialized    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(slub)"  -D"KBUILD_MODNAME=KBUILD_STR(slub)" -S -o $@ $<

CC=/usr/bin/aarch64-linux-gnu-gcc
CC=${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/aarch64-linux-gnu-gcc
x-gcc.s: x.c 
	${CC} -nostdinc -isystem ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/../lib/gcc/aarch64-linux-gnu/4.8.2/include -D__KERNEL__ -mlittle-endian -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -mgeneral-regs-only -fno-delete-null-pointer-checks -O2 --param=allow-store-data-races=0 -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-but-set-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -fno-var-tracking-assignments -fno-inline-functions-called-once -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -fconserve-stack -Werror=implicit-int -Werror=strict-prototypes    -D"KBUILD_STR(s)=\#s" -D"KBUILD_BASENAME=KBUILD_STR(slub)"  -D"KBUILD_MODNAME=KBUILD_STR(slub)" -S -o $@ $< 

z-gcc.s: z.c 
	${CC} -nostdinc -mlittle-endian -O2 -S -o $@ $< 

z-clang.s: z.c 
	${TOPDIR}/toolchain/clang/head/install/bin/clang -gcc-toolchain ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux -target aarch64-linux-gnu -target aarch64-linux-gnu -nostdinc -isystem ${TOPDIR}/toolchain/clang/head/install/bin/../lib/clang/3.6.0/include -D__KERNEL__ -target aarch64-linux-gnu -mlittle-endian -Qunused-arguments -O2 -S -o $@ $<

y-clang.s: y.c
	${TOPDIR}/toolchain/clang/head/install/bin/clang -gcc-toolchain ${TOPDIR}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux -target aarch64-linux-gnu -target aarch64-linux-gnu -nostdinc -isystem ${TOPDIR}/toolchain/clang/head/install/bin/../lib/clang/3.6.0/include -target aarch64-linux-gnu -mlittle-endian -Qunused-arguments -Wno-unknown-warning-option -O2 -S -o $@ $<


y-gcc.s: y.c 
	${CC} -nostdinc -mlittle-endian -O2 -S -o $@ $< 
