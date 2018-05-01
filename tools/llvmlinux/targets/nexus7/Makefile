##############################################################################
# Copyright (c) 2013 Mark Charlebois
#               2012 Jan-Simon Möller
#               2012 Behan Webster
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

TARGETDIR	= ${CURDIR}
TOPDIR		= $(realpath ${TARGETDIR}/../..)
CROSS_ARM_TOOLCHAIN = linaro
LLVM_COMMIT = master
CLANG_COMMIT = master

KERNEL_BRANCH	= cm-10.2
KERNEL_GIT	= git://github.com/CyanogenMod/android_kernel_asus_grouper
KERNELDIR	= ${SRCDIR}/android_kernel_nexus7
KERNEL_CFG	= ${KERNELDIR}/arch/arm/configs/cyanogenmod_grouper_defconfig

#Use the branch name for the dir containing target specific patch overrides
KERNEL_REPO_PATCHES=${KERNEL_BRANCH}

EXTRAFLAGS	=

all: prep kernel-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/arm/arm.mk
include ${CONFIG}

KERNEL_PATCH_DIR	+= ${TOPDIR}/arch/all/patches/v3.14
KERNEL_PATCH_DIR	+= ${TARGETDIR}/patches-overlay
KERNEL_PATCH_DIR	+= ${TARGETDIR}/patches 

TARGETS+= check-dups kernel-autopatch clean mrproper
.PHONY: kernel-copy clean mrproper

prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR} ${TARGETDIR}/patches
	$(call state,$@)

check-dups:
	${TOOLSDIR}/checkduplicates.py $(shell ${MAKE} list-kernel-patches)

clean: kernel-clean kernel-gcc-clean
	@$(call banner,Clean)

mrproper: clean kernel-mrproper kernel-gcc-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}/*
	@$(call banner,Very Clean)

