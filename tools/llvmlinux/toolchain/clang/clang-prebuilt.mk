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

LLVMSTATE	= ${LLVMTOP}/state
CLANG_TMPDIR	= ${LLVMTOP}/tmp
TMPDIRS		+= ${CLANG_TMPDIR}
FETCH_TARGETS	+= clang-fetch
RAZE_TARGETS	+= clang-raze

# Overall clang release (used in URL and tar filename)
CLANG_RELEASE	= 4.0.0
# Tar file pkg name (used in URL and tar filename)
# The tar files *should* work on most distros regardless of what is listed here
CLANG_32_PKG	= opensuse13.1
CLANG_64_PKG	= linux-gnu-ubuntu-16.04

ifeq ($(shell uname -i), x86_64)
CLANG_DIR	= clang+llvm-${CLANG_RELEASE}-x86_64-${CLANG_64_PKG}
CLANG_TAR	= clang+llvm-${CLANG_RELEASE}-x86_64-${CLANG_64_PKG}.tar.xz
else
CLANG_DIR	= clang+llvm-${CLANG_RELEASE}-i586-${CLANG_32_PKG}
CLANG_TAR	= clang+llvm-${CLANG_RELEASE}-i586-${CLANG_32_PKG}.tar.xz
endif
CLANG_UNPACK 	= unxz
CLANG_TAR_FILE	= $(call shared,${CLANG_TMPDIR}/${CLANG_TAR})

CLANG_PATH	= ${LLVMTOP}/${CLANG_DIR}
CLANG_BINDIR	= ${CLANG_PATH}/bin
CLANG_URL	= http://llvm.org/releases/${CLANG_RELEASE}/${CLANG_TAR}

CLANG			= ${CLANG_BINDIR}/clang
STATE_CLANG_TOOLCHAIN	= ${CLANG}

# Add clang to the path
PATH		:= ${CLANG_BINDIR}:${PATH}

${CLANG}: ${LLVMSTATE}/clang-prebuilt

clang-get clang-fetch: ${CLANG_TAR_FILE}
${CLANG_TAR_FILE}:
	@$(call wget,${CLANG_URL},$(dir $@))

clang-unpack: ${LLVMSTATE}/clang-prebuilt
${LLVMSTATE}/clang-prebuilt: ${CLANG_TAR_FILE}
	@$(call ${CLANG_UNPACK},$<,${LLVMTOP})
	$(call state,$@)

clang-raze:
	@rm -rf ${LLVMSTATE}/clang-prebuilt ${CLANG_PATH} ${CLANG_TAR_FILE}
