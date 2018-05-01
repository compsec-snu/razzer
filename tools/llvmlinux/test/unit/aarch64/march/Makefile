BASE=../../../..

# Src Clang
CLANGDIR=${BASE}/toolchain/clang/install/bin
#VERSION=3.5.0

ARM64CC=${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/aarch64-linux-gnu-gcc

CLANG_OPTIONS = -gcc-toolchain ${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux -target aarch64-linux-gnu -nostdinc -isystem ${CLANGDIR}/../lib/clang/3.5.0/include -march=armv8-a+crypto -mlittle-endian -Qunused-arguments -Wno-unknown-warning-option -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -no-integrated-as -O2 -fno-builtin -Wno-asm-operand-widths -Wno-initializer-overrides -mgeneral-regs-only -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-variable -Wno-format-invalid-specifier -Wno-gnu -Wno-tautological-compare -mno-global-merge -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -Werror=implicit-int -Werror=strict-prototypes -Werror=date-time

GCC_OPTIONS = -march=armv8-a+crypto -mlittle-endian -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -O2 -fno-builtin -mgeneral-regs-only -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -Werror=implicit-int -Werror=strict-prototypes 

all: y1-gcc.o y1-clang.o y1-gcc-test.o y1-clang-test.o

y1-clang.o: y1.c
	@echo
	@echo "Compiling with Clang"
	-(CROSS_COMPILE=aarch64-linux-gnu- ${CLANGDIR}/clang ${CLANG_OPTIONS} -c -o $@ $?)
	
y1-gcc.o: y1.c
	@echo
	@echo "Compiling with GCC"
	${ARM64CC} ${GCC_OPTIONS} -c -o $@ $< 
	@echo "+++ $@ built successfully +++"

y1-clang-test.o: y1.c
	@echo
	@echo "Compiling with Clang and -###"
	(CROSS_COMPILE=aarch64-linux-gnu- ${CLANGDIR}/clang -\#\#\# ${CLANG_OPTIONS} -c -o $@ $?)
	@echo "+++ $@ built successfully +++"
	
y1-gcc-test.o: y1.c
	@echo
	@echo "Compiling with GCC and -###"
	${ARM64CC} -\#\#\# ${GCC_OPTIONS} -c -o $@ $< 
	@echo "+++ $@ built successfully +++"
clean:
	rm -f *.o
