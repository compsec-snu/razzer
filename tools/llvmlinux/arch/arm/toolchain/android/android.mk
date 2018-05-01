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

# Note: use CROSS_ARM_TOOLCHAIN=android to include this file

TARGETS_TOOLCHAIN	+= android-gcc

ANDROID_SDK_BRANCH 	= jb_rel_rb6.1
ANDROID_SDK_GIT 	= git://codeaurora.org/platform/prebuilts/gcc/linux-x86/arm/${ANDROID_CC_VERSION}.git

ANDROID_DIR		= ${ARCH_ARM_TOOLCHAIN}/android
ANDROID_CC_VERSION	= arm-linux-androideabi-4.6
ANDROID_CC_DIR		= ${ANDROID_DIR}/${ANDROID_CC_VERSION}
ANDROID_CC_BINDIR	= ${ANDROID_CC_DIR}/bin

HOST		= arm-linux-androideabi
HOST_TRIPLE	= arm-linux-androideabi
COMPILER_PATH	= ${ANDROID_CC_DIR}
ANDROID_GCC	= ${ANDROID_CC_BINDIR}/${CROSS_COMPILE}gcc
CROSS_GCC	= ${ANDROID_GCC}

ARM_CROSS_GCC_TOOLCHAIN = ${ANDROID_CC_DIR}
CFLAGS		= -isystem ${ANDROID_DIR}/arm-linux-androideabi-4.6/lib/gcc/arm-linux-androideabi/4.6.x-google/include

# Add path so that ${CROSS_COMPILE}${CC} is resolved
PATH		:= ${ANDROID_CC_BINDIR}:${PATH}

# The Android toolchain supports only ARM cross compilation
${ANDROID_DIR}:
	@mkdir -p $@

android-gcc arm-cc: ${ARCH_ARM_TOOLCHAIN_STATE}/android-gcc
${ARCH_ARM_TOOLCHAIN_STATE}/android-gcc: ${ANDROID_DIR}
	$(call assert,`uname -i | grep -v i386`,"Android compiler only supported on x86_64\n" \
		"set CROSS_ARM_TOOLCHAIN=codesourcery for i386")
	@$(call banner,Installing Android compiler...)
	@$(call gitclone,${ANDROID_SDK_GIT},${ANDROID_CC_DIR},-b ${ANDROID_SDK_BRANCH})
	$(call state,$@)

android-gcc-sync: ${ARCH_ARM_TOOLCHAIN_STATE}/android-gcc
	@$(call banner,Updating Android compiler...)
	(cd ${ANDROID_CC_DIR} && git pull && git checkout ${ANDROID_SDK_BRANCH})

state/arm-cc: ${ARCH_ARM_TOOLCHAIN_STATE}/android-gcc
	$(call state,$@)

android-gcc-clean arm-cc-clean:
	@$(call banner,Removing Android compiler...)
	@rm -f state/arm-cc ${ARCH_ARM_TOOLCHAIN_STATE}/android-gcc
	@rm -rf ${LINARO_CC_DIR}

arm-cc-version: ${ARCH_ARM_TOOLCHAIN_STATE}/android-gcc
	@echo -e "ANDROID_GCC\t= `${ANDROID_GCC} --version | head -1`"

