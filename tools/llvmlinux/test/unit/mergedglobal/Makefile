BASE=$(realpath ../../..)

# Prebuilt Clang
CLANGDIR=${BASE}/toolchain/clang/clang+llvm-3.4-x86_64-linux-gnu-ubuntu-13.10/bin
VERSION=3.4

# Src Clang
#CLANGDIR=${BASE}/toolchain/clang/install/bin
#VERSION=3.4

VEXPRESSDIR=${BASE}/targets/vexpress

all: test

foo.o: foo.c
	${CLANGDIR}/clang -gcc-toolchain ${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05 -mno-global-merge -nostdinc -isystem ${CLANGDIR}/../lib/clang/${VERSION}/include -I. -include kconfig.h -D__KERNEL__ -Qunused-arguments -target arm-none-linux-gnueabi -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -no-integrated-as -O2 -fno-builtin -Wno-asm-operand-widths -fno-dwarf2-cfi-asm -funwind-tables -D__LINUX_ARM_ARCH__=7 -march=armv7-a -msoft-float -Wframe-larger-than=1024 -fno-stack-protector -Wno-unused-variable -Wno-format-invalid-specifier -Wno-gnu -Wno-tautological-compare -fomit-frame-pointer -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -D"KBUILD_STR(s)=#s" -D"KBUILD_BASENAME=KBUILD_STR(rtnetlink)"  -D"KBUILD_MODNAME=KBUILD_STR(rtnetlink)" -c -o $@ $? #2>/dev/null

foo-gcc.c: foo.c
	cp foo.c foo-gcc.c

foo-gcc.o: foo-gcc.c
	${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05/bin/arm-none-linux-gnueabi-gcc -nostdinc -I. -include kconfig.h -D__KERNEL__ -Wall -Wundef -Wstrict-prototypes -Wno-trigraphs -fno-strict-aliasing -fno-common -Werror-implicit-function-declaration -Wno-format-security -O2 -fno-builtin -fno-dwarf2-cfi-asm -funwind-tables -D__LINUX_ARM_ARCH__=7 -march=armv7-a -msoft-float -Wframe-larger-than=1024 -fno-stack-protector -Wno-unused-variable -fomit-frame-pointer -g -Wdeclaration-after-statement -Wno-pointer-sign -fno-strict-overflow -D"KBUILD_STR(s)=#s" -D"KBUILD_BASENAME=KBUILD_STR(rtnetlink)"  -D"KBUILD_MODNAME=KBUILD_STR(rtnetlink)" -c -o $@ $< 2>/dev/null

objdump: foo.o
	../../../arch/arm/toolchain/codesourcery/arm-2013.05/bin/arm-none-linux-gnueabi-objdump -x $? > $@

objdump-gcc: foo-gcc.o
	../../../arch/arm/toolchain/codesourcery/arm-2013.05/bin/arm-none-linux-gnueabi-objdump -x $? > $@

outfile: ${VEXPRESSDIR}/src/linux/scripts/mod/modpost foo.o
	@echo "# This file should not be empty" > $@ 
	${VEXPRESSDIR}/src/linux/scripts/mod/modpost foo.o >> $@ 2>&1 
	-grep "Section mismatch in reference from the variable _MergedGlobals to the function .init.text:rtnetlink_net_init" $@

outfile-gcc: ${VEXPRESSDIR}/src/linux/scripts/mod/modpost foo-gcc.o
	@echo "# This file should be empty" > $@
	${VEXPRESSDIR}/src/linux/scripts/mod/modpost foo-gcc.o >> $@ 2>&1 

${VEXPRESSDIR}/src/linux/scripts/mod/modpost: 
	(cd ${VEXPRESSDIR} && make kernel-configure)
	(cd ${VEXPRESSDIR}/src/linux &&  time  make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- CONFIG_DEBUG_INFO=1 CONFIG_DEBUG_SECTION_MISMATCH=y CONFIG_NO_ERROR_ON_MISMATCH=y   CC="${CLANGDIR}/clang -gcc-toolchain ${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05" init/main.o )
	
test: outfile outfile-gcc objdump objdump-gcc
	@echo
	@echo "Compare objdump and objdump-gcc"

clean:
	rm -f outfile foo.o foo.mod.c outfile-gcc foo-gcc.o foo-gcc.c foo-gcc.mod.c objdump objdump-gcc
