##############################################################################
# Copyright (c) 2013 Behan Webster
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

# Assumes has been included from clang.mk

STATE_CLANG_TOOLCHAIN	= clang-check-version
CLANG			= clang
LLC			= llc

CLANG_MAJOR		= 4
CLANG_MINOR		= 0

clang-check-version:
	@${LLC} -version | grep -q ${ARCH} || $(call error1,Your native clang does not have ${ARCH} support)
	@$(call assert, \
		`echo __clang_major__ | ${CLANG} -E -x c - | tail -1` -ge ${CLANG_MAJOR} -a \
		`echo __clang_minor__ | ${CLANG} -E -x c - | tail -1` -ge ${CLANG_MINOR}, \
		Your native clang must be at least version ${CLANG_MAJOR}.${CLANG_MINOR} to work with the Linux kernel)
