##############################################################################
# Copyright (c) 2014 Behan Webster
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
# Build and test alternatives to VLAIS

GCC	= gcc
CLANG_TOOLCHAIN=prebuilt
CFLAGS	= -g -O2

.PHONY: all test clean

TARGS		= test
GCC_TARGET	= $(addsuffix -gcc,$(TARGS))
CLANG_TARGET	= $(addsuffix -clang,$(TARGS))
TARGET		= $(GCC_TARGET) $(CLANG_TARGET)

all: $(TARGET)

foo:
	@echo $(TARGET)

TOPDIR		= $(realpath ../../..)
TARGETDIR	= $(TOPDIR)/targets/vexpress

include ${TOPDIR}/common.mk
include ${ARCHDIR}/x86_64/x86_64.mk

GCC	= $(CROSS)-gcc

### BUILD ######################################################################

test: test.c
	$(CLANG) -Wall $< -static -o $@

${GCC_TARGET}: %-gcc: %.c
	$(GCC) ${CFLAGS} -c $< -o $@.o
	-g++ ${CFLAGS} -c $<pp -o $@-cpp.o
	objdump -d -S $@.o

${CLANG_TARGET}: %-clang: %.c
	-$(CLANG) ${EXTRAFLAGS} ${CFLAGS} -c $< -o $@.o
	-$(CLANG) ${EXTRAFLAGS} ${CFLAGS} -c $<pp -o $@-cpp.o
	objdump -d -S $@.o

clean:
	rm -f $(TARGET) *.o
