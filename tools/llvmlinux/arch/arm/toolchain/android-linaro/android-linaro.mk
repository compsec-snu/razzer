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

# Note: use CROSS_ARM_TOOLCHAIN=android-linaro to include this file

TARGETS				+= android-linaro-gcc

ANDROID_LINARO_VERSION		?= 13.11
ANDROID_LINARO_GCC_VERSION	?= 4.8
ANDROID_LINARO_CC_NAME		?= android-toolchain-eabi
ANDROID_LINARO_CC_URL		?= http://releases.linaro.org/${ANDROID_LINARO_VERSION}/components/android/toolchain/${ANDROID_LINARO_GCC_VERSION}/${ANDROID_LINARO_CC_NAME}-${ANDROID_LINARO_GCC_VERSION}-20${ANDROID_LINARO_VERSION}-x86.tar.bz2
ANDROID_LINARO_DIR		?= ${ARCH_ARM_TOOLCHAIN}/android-linaro
ANDROID_LINARO_TMPDIR		= $(call shared,${ANDROID_LINARO_DIR}/tmp)
TMPDIRS				+= ${ANDROID_LINARO_TMPDIR}

ANDROID_LINARO_CC_TAR		= ${notdir ${ANDROID_LINARO_CC_URL}}
ANDROID_LINARO_CC_DIR		= ${ANDROID_LINARO_DIR}/${ANDROID_LINARO_CC_NAME}
ANDROID_LINARO_CC_BINDIR	= ${ANDROID_LINARO_CC_DIR}/bin

HOST				?= arm-linux-androideabi
HOST_TRIPLE			?= ${HOST}
COMPILER_PATH			= ${ANDROID_LINARO_CC_DIR}
ANDROID_LINARO_GCC		= ${ANDROID_LINARO_CC_BINDIR}/${CROSS_COMPILE}gcc
CROSS_GCC			= ${ANDROID_LINARO_GCC}

ARM_CROSS_GCC_TOOLCHAIN 	= ${ANDROID_LINARO_CC_DIR}

# Add path so that ${CROSS_COMPILE}${CC} is resolved
PATH				:= ${ANDROID_LINARO_CC_BINDIR}:${PATH}

# Get Linaro cross compiler
${ANDROID_LINARO_TMPDIR}/${ANDROID_LINARO_CC_TAR}:
	@$(call wget,${ANDROID_LINARO_CC_URL},${ANDROID_LINARO_TMPDIR})

android-linaro-gcc arm-cc: ${ARCH_ARM_TOOLCHAIN_STATE}/android-linaro-gcc
${ARCH_ARM_TOOLCHAIN_STATE}/android-linaro-gcc: ${ANDROID_LINARO_TMPDIR}/${ANDROID_LINARO_CC_TAR}
	rm -rf ${ANDROID_LINARO_CC_DIR}
	tar -x -j -C ${ANDROID_LINARO_DIR} -f $<
	$(call state,$@)

state/arm-cc: ${ARCH_ARM_TOOLCHAIN_STATE}/android-linaro-gcc
	$(call state,$@)

android-linaro-gcc-clean arm-cc-clean:
	@$(call banner,Removing Linaro compiler...)
	@rm -f state/arm-cc ${ARCH_ARM_TOOLCHAIN_STATE}/android-linaro-gcc
	@rm -rf ${ANDROID_LINARO_CC_DIR}

arm-cc-version: ${ARCH_ARM_TOOLCHAIN_STATE}/android-linaro-gcc
	@echo -e "ANDROID_LINARO_GCC\t= `${ANDROID_LINARO_GCC} --version | head -1`"

