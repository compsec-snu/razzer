##############################################################################
# Copyright (c) 2013 Mark Charlebois
#               2013 Behan Webster
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

CLANG	= ../../../toolchain/clang/clang+llvm-3.3-Ubuntu-13.04-x86_64-linux-gnu/bin/clang
GCC	= gcc -std=c11 -lm
CFLAGS	= -g -Wall

.PHONY: all test clean

### BUILD ######################################################################
all: test

clean:
	rm -f test_clang test_gcc

test: test_clang test_gcc
test_clang: test.c
	${CLANG} ${CFLAGS} $< -o $@

# GCC requires -lm at the end
test_gcc: test.c
	${GCC} ${CFLAGS} $< -o $@ -lm

