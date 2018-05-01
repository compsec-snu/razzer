##############################################################################
# Copyright (c) 2013 Mark Charlebois
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
##############################################################################
# Build and test __builtin_stack_address

BASE	= $(realpath ../../..)
CLANG	= ${BASE}/toolchain/clang/install/bin/clang

.PHONY: all clean

# The following seems to be needed on i686 machine but not on x86_64
ARM_SYSROOT=${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05/arm-none-linux-gnueabi/libc
ARM_FLAGS=-isysroot ${ARM_SYSROOT} -iwithsysroot /usr/include

AARCH64_SYSROOT=${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/aarch64-linux-gnu/libc
AARCH64_FLAGS=-isysroot ${AARCH64_SYSROOT} -iwithsysroot /usr/include


### BUILD ######################################################################
all: arm_test.s aarch64_test.s x86_test.s arm_testgcc.s aarch64_testgcc.s x86_testgcc.s

arm_test.s: test.c Makefile
	$(CLANG) -target arm-none-linux-gnueabi ${ARM_FLAGS} -S -O2 $< -o $@

x86_test.s: test.c Makefile
	$(CLANG) -S -O2 $< -o $@

aarch64_test.s: testgcc.c Makefile
	$(CLANG) -target aarch64-none-linux-gnueabi ${AARCH64_FLAGS} -S -O2 $< -o $@

arm_testgcc.s: testgcc.c Makefile
	${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05/bin/arm-none-linux-gnueabi-gcc -S -O2 $< -o $@

aarch64_testgcc.s: testgcc.c Makefile
	${BASE}/arch/aarch64/toolchain/linaro/gcc-linaro-aarch64-linux-gnu-4.8-2013.06_linux/bin/aarch64-linux-gnu-gcc -S -O2 $< -o $@

x86_testgcc.s: testgcc.c Makefile
	gcc -S -O2 $< -o $@

clean:
	@rm -f *test*.s
