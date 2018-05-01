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

# Note: This file must be included after ${TOPDIR}/common.mk

#export MARCH
#export MFLOAT

STATE_TOOLCHAIN	= state/aarch64-cc

# ARCH must be defined before all.mk
ARCH		= arm64
CROSS_COMPILE	= ${HOST}-
MARCH		?= armv8
MFLOAT		?= 

FETCH_TARGETS	+= aarch64-cc
RAZE_TARGETS	+= aarch64-cc-clean

ARCH_AARCH64_DIR	= ${ARCHDIR}/aarch64
ARCH_AARCH64_BINDIR	= ${ARCH_AARCH64_DIR}/bin
ARCH_AARCH64_PATCHES	= ${ARCH_AARCH64_DIR}/patches

ARCH_AARCH64_TOOLCHAIN	= ${ARCH_AARCH64_DIR}/toolchain
ARCH_AARCH64_TOOLCHAIN_STATE= ${ARCH_AARCH64_TOOLCHAIN}/state

PATH			:= ${ARCH_AARCH64_BINDIR}:${PATH}

include ${ARCH_AARCH64_TOOLCHAIN}/toolchain.mk
include ${ARCHDIR}/all/all.mk

KERNEL_PATCH_DIR+= ${ARCH_AARCH64_PATCHES} ${ARCH_AARCH64_PATCHES}/${KERNEL_REPO_PATCHES}

HELP_TARGETS	+= aarch64-help
SETTINGS_TARGETS+= aarch64-settings
VERSION_TARGETS	+= aarch64-cc-version

KERNEL_SIZE_ARTIFACTS   = arch/arm64/boot/Image* vmlinux*

#KERNELOPTS	= console=earlycon console=ttyAMA0,38400n8 earlyprintk
KERNELOPTS	= console=ttyAMA0

aarch64-help:
	@echo
	@echo "These options are specific to building a Linux Kernel for ARM:"
	@echo "* make CROSS_AARCH64_TOOLCHAIN=[linaro,native] ..."
	@echo "			- Choose the gcc cross toolchain you want to use"

aarch64-settings:
	@echo "# AARCH64 settings"
	@$(call prsetting,CROSS_AARCH64_TOOLCHAIN,${CROSS_AARCH64_TOOLCHAIN})
	@$(call prsetting,EXTRAFLAGS,${EXTRAFLAGS})
	@$(call prsetting,KERNEL_MAKE_TARGETS,${KERNEL_MAKE_TARGETS})

