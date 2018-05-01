BASE=../../..

# Prebuilt Clang
#CLANGDIR=${BASE}/toolchain/clang/clang+llvm-3.4-x86_64-linux-gnu-ubuntu-13.10/bin
#VERSION=3.4
#CLANG=clang

# Src Clang
CLANGDIR=${BASE}/toolchain/clang/head/install/bin
VERSION=3.5.0
CLANG=clang

#Native Clang
#CLANGDIR=/usr/bin
#VERSION=3.5.0
#CLANG=clang-3.5

VEXPRESSDIR=${BASE}/targets/vexpress

ARMCC=${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/aarch64-linux-gnu-gcc
ARMLIBC=${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/aarch64-linux-gnu/libc

OPTIONS=-O2

OPTIONS1=-cc1 -triple aarch64--linux-gnu -S -disable-free -disable-llvm-verifier -mrelocation-model static -mdisable-fp-elim -relaxed-aliasing -mdisable-tail-calls -fmath-errno -masm-verbose -mconstructor-aliases -fuse-init-array -g -nostdsysteminc -nobuiltininc -resource-dir ${CLANGDIR}/../lib/clang/${VERSION} -sys-header-deps -isystem ${CLANGDIR}/../lib/clang/${VERSION}/include -fcolor-diagnostics -vectorize-loops -vectorize-slp -fobjc-runtime=gcc -fno-dwarf-directory-asm -fdebug-compilation-dir /local2/mnt/workspace/llvmlinux/targets/vexpress64/src/linaro-aarch64 -ferror-limit 19 -fmessage-length 127 -mstackrealign -Wno-gnu -Wno-tautological-compare -Wno-format-invalid-specifier -Wno-asm-operand-widths 


OPTIONS2=-D __KERNEL__ -D CC_HAVE_ASM_GOTO -I /local2/mnt/workspace/llvmlinux/targets/vexpress64/src/linaro-aarch64/arch/arm64/include -I /local2/mnt/workspace/llvmlinux/targets/vexpress64/src/linaro-aarch64/arch/arm64/include/uapi -I /local2/mnt/workspace/llvmlinux/targets/vexpress64/src/linaro-aarch64/include/uapi -O2 -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -Werror-implicit-function-declaration -Wno-format-security -Wno-unused-variable -Wdeclaration-after-statement -Wno-pointer-sign -fwrapv -fno-builtin -fno-signed-char -fno-common -fdiagnostics-show-option 

all: 
	make clean
	@echo
	@echo "=========== Building with GCC ============"
	@echo
	make t1-gcc
	make t2-gcc
	make t3-gcc
	make t4-gcc
	make t5-gcc
	make x1-gcc
	@echo
	@echo "=========== building with Clang  ========="
	@echo
	-make t1
	-make t2
	-make t3
	-make t4
	-make t5
	-make x1

export PATH:=${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin:${PATH}

t%: t%.c
	@echo
	(export PATH=${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin:${PATH}; ${CLANGDIR}/${CLANG} -no-integrated-as -I. -target aarch64-none-linux-gnueabi --sysroot=${ARMLIBC} ${OPTIONS} -o $@ $? )
	@echo "+++ $@ built successfully +++"

v%: t%.c
	@echo
	(${CLANGDIR}/${CLANG} -gcc-toolchain ${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux -no-integrated-as -I. -target aarch64-none-linux-gnueabi --sysroot=${ARMLIBC} ${OPTIONS} -o $@ $? )
	@echo "+++ $@ built successfully +++"

t5: t5.c
	@echo
	(CROSS_COMPILE=aarch64-linux-gnu- ${CLANGDIR}/${CLANG} ${OPTIONS1} ${OPTIONS2} -o $@ $?)
	@echo "+++ $@ built successfully +++"


t%-gcc:  t%.c
	@echo
	${ARMCC} -o $@ $< 
	@echo "+++ $@ built successfully +++"

t5-gcc:  t5.c
	@echo
	${ARMCC} ${OPTIONS2} -o $@ $< 
	@echo "+++ $@ built successfully +++"

x1-gcc:  x1.c
	@echo
	${ARMCC} ${OPTIONS2} -o $@ $< 
	@echo "+++ $@ built successfully +++"

x1:  x1.c
	@echo
	(CROSS_COMPILE=aarch64-linux-gnu- ${CLANGDIR}/${CLANG} ${OPTIONS1} ${OPTIONS2} -o $@ $?)
	@echo "+++ $@ built successfully +++"

x2-gcc:  x2.c
	@echo
	${ARMCC} ${OPTIONS2} -o $@ $< 
	@echo "+++ $@ built successfully +++"

x2:  x2.c
	@echo
	(CROSS_COMPILE=aarch64-linux-gnu- ${CLANGDIR}/${CLANG} ${OPTIONS1} ${OPTIONS2} -o $@ $?)
	@echo "+++ $@ built successfully +++"

OPTIONS6 = -march=armv8-a+crypto -mlittle-endian -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -O2 -fno-builtin -mgeneral-regs-only -Wframe-larger-than=2048 -fno-stack-protector -Wno-unused-variable -fno-omit-frame-pointer -fno-optimize-sibling-calls -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -Werror=implicit-int -Werror=strict-prototypes 

y1-clang.o: y1.c
	@echo
	(CROSS_COMPILE=aarch64-linux-gnu- ${CLANGDIR}/${CLANG} ${OPTIONS5} -c -o $@ $?)
	@echo "+++ $@ built successfully +++"
	
y1-gcc.o: y1.c
	@echo
	${ARMCC} ${OPTIONS6} -c -o $@ $< 
	@echo "+++ $@ built successfully +++"

clean:
	rm -f t? t?-gcc x? x?-gcc x3.s
