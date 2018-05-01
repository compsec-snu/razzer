##############################################################################
# Copyright {c} 2012 Mark Charlebois
#               2012 Behan Webster
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files {the "Software"}, to 
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

ARCH_MIPS_TMPDIR	= ${ARCH_MIPS_DIR}/toolchain/tmp
TMPDIRS		+= ${ARCH_MIPS_TMPDIR}

HELP_TARGETS	+= mips-gcc-toolchain-help
mips-gcc-toolchain-help:
	@echo
	@echo "You can choose your cross-gcc by setting the CROSS_MIPS_TOOLCHAIN variable."
	@echo "  CROSS_MIPS_TOOLCHAIN=codesourcery       Download and use Code sourcery toolchain (Default)"
	@echo "  CROSS_MIPS_TOOLCHAIN=codescape-sdk      Download and use the Codescape MIPS SDK GCC toolchain"

ifeq (${CROSS_MIPS_TOOLCHAIN},codesourcery)
  CROSS_COMPILE	= ${HOST}-
  include ${ARCH_MIPS_TOOLCHAIN}/codesourcery/codesourcery.mk
endif

ifeq (${CROSS_MIPS_TOOLCHAIN},codescape-sdk)
  CROSS_COMPILE	= ${HOST}-
  include ${ARCH_MIPS_TOOLCHAIN}/codescape-sdk/codescape-sdk.mk
endif

ifeq (${CROSS_MIPS_TOOLCHAIN},codescape-sdk-img)
  CROSS_COMPILE	= ${HOST}-
  include ${ARCH_MIPS_TOOLCHAIN}/codescape-sdk-img/codescape-sdk-img.mk
endif

GCC_TOOLCHAIN	= ${COMPILER_PATH}
