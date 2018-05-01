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

# Note: use CROSS_ARM_TOOLCHAIN=linaro to include this file

TARGETS			+= linaro-gcc

DEBDEP_32		+= libstdc++6:i386 zlib1g:i386

# http://releases.linaro.org/14.09/components/toolchain/binaries/gcc-linaro-arm-linux-gnueabihf-4.9-2014.09_linux.tar.bz2
LINARO_VERSION		?= 14.09
LINARO_GCC_VERSION	?= 4.9
LINARO_CC_NAME		?= arm-linux-gnueabihf
LINARO_CC_FILENAME	= gcc-linaro-${LINARO_CC_NAME}-${LINARO_GCC_VERSION}-20${LINARO_VERSION}_linux
LINARO_CC_DIR_NAME	= ${LINARO_CC_FILENAME}
LINARO_CC_URL		?= http://releases.linaro.org/${LINARO_VERSION}/components/toolchain/binaries/${LINARO_CC_FILENAME}.tar.bz2
LINARO_DIR		?= $(call shared,${ARCH_ARM_TOOLCHAIN}/linaro)
LINARO_TMPDIR		= ${LINARO_DIR}/tmp
TMPDIRS			+= ${LINARO_TMPDIR}

LINARO_CC_TAR_BZ2	= ${LINARO_TMPDIR}/${LINARO_CC_FILENAME}.tar.bz2
LINARO_CC_DIR		= ${LINARO_DIR}/${LINARO_CC_DIR_NAME}
LINARO_CC_BINDIR	= ${LINARO_CC_DIR}/bin

HOST			?= ${LINARO_CC_NAME}
HOST_TRIPLE		?= ${HOST}
COMPILER_PATH		= ${LINARO_CC_DIR}
LINARO_GCC		= ${LINARO_CC_BINDIR}/${CROSS_COMPILE}gcc
CROSS_GCC		= ${LINARO_GCC}

DEBDEP			+= 

ARM_CROSS_GCC_TOOLCHAIN = ${LINARO_CC_DIR}

# Add path so that ${CROSS_COMPILE}${CC} is resolved
PATH			:= ${LINARO_CC_BINDIR}:${PATH}

# Get Linaro cross compiler
${LINARO_CC_TAR_BZ2}:
	mkdir -p ${LINARO_TMPDIR}
	@$(call wget,${LINARO_CC_URL},${LINARO_TMPDIR})

LINARO_CC_STAMP	= ${ARCH_ARM_TOOLCHAIN_STATE}/linaro-gcc-${LINARO_VERSION}
linaro-gcc arm-cc: ${LINARO_CC_STAMP}
${LINARO_CC_STAMP}: ${LINARO_CC_TAR_BZ2}
	@${MAKE} arm-cc-clean
	@$(call unbz2,${LINARO_CC_TAR_BZ2},${LINARO_DIR})
	$(call state,$@)

state/arm-cc: ${LINARO_CC_STAMP}
	$(call state,$@)

linaro-gcc-clean arm-cc-clean:
	@$(call banner,Removing Linaro compiler...)
	@rm -rf ${LINARO_CC_DIR} ${LINARO_CC_TAR_BZ2:.bz2=}
	@$(call leavestate,arm-cc) ${LINARO_CC_STAMP}

arm-cc-version: ${LINARO_CC_STAMP}
	@echo -e "LINARO_GCC\t= `${LINARO_GCC} --version | head -1`"

arm-cc-env:
	@$(call prsetting,LINARO_CC_URL,${LINARO_CC_URL})
	@$(call prsetting,LINARO_CC_FILENAME,${LINARO_CC_FILENAME})
	@$(call prsetting,LINARO_CC_DIR_NAME,${LINARO_CC_DIR_NAME})
	@$(call prsetting,LINARO_TMPDIR,${LINARO_TMPDIR})
	@$(call prsetting,LINARO_CC_TAR_BZ2,${LINARO_CC_TAR_BZ2})
	@$(call prsetting,LINARO_DIR,${LINARO_DIR})
	@$(call prsetting,LINARO_CC_DIR,${LINARO_CC_DIR})
	@$(call prsetting,LINARO_CC_BINDIR,${LINARO_CC_BINDIR})
	@$(call prsetting,LINARO_GCC,${LINARO_GCC})
