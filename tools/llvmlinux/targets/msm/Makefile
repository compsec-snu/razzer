##############################################################################
# Copyright (c) 2012 Mark Charlebois
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
CLANG_TOOLCHAIN	= from-source

KERNELDIR	= ${SRCDIR}/msm
KERNEL_CFG	= ${KERNELDIR}/arch/arm/configs/msm_defconfig
KERNEL_DTB	= arch/arm/boot/dts/qcom-apq8074-dragonboard.dts

#Use the branch name for the dir containing MSM specific patch overrides
KERNEL_REPO_PATCHES=${KERNEL_BRANCH}

EXTRAFLAGS	= 
#EXTRAFLAGS	= -Iarch/arm/mach-msm
#EXTRAFLAGS = CFLAGS_KERNEL=" -mllvm -print-call-graph"

all: prep kernel-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/arm/arm.mk

KERNEL_PATCH_DIR	+= ${TARGETDIR}/patches-overlay
KERNEL_PATCH_DIR	+= ${TARGETDIR}/patches

include ${CONFIG}

TARGETS+= kernel-autopatch clean mrproper
.PHONY: kernel-copy clean mrproper

prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR}
	$(call state,$@)

clean: kernel-clean kernel-gcc-clean
	@$(call banner,Clean)

mrproper: clean kernel-mrproper kernel-gcc-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}/*
	@$(call banner,Very Clean)

get-msm-tags:
