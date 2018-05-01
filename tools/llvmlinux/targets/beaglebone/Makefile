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

ARCH		= arm
BOARD		= beaglebone

# Kernel settings
KERNEL_CFG		= ${KERNELDIR}/arch/arm/configs/multi_v7_defconfig
KERNEL_IMAGES		= arch/arm/boot/*Image
KERNEL_DTBS		= arch/arm/boot/dts/am335x-bone*.dtb
#KERNEL_MAKE_TARGETS	= LOADADDR=0x80008000 uImage dtbs
KERNEL_MAKE_TARGETS	= zImage dtbs

DEBDEP			+= u-boot-tools

.PHONY:			${BOARD_TARGETS} clean mrproper

all all-clang: prep kernel-build
	@$(call ls,$(wildcard ${KERNEL_BUILD}/${KERNEL_IMAGES}) $(wildcard ${KERNEL_BUILD}/${KERNEL_DTBS}))

all-gcc: prep kernel-gcc-build
	@$(call ls,$(wildcard ${KERNELGCC_BUILD}/${KERNEL_IMAGES}) $(wildcard ${KERNELGCC_BUILD}/${KERNEL_DTBS}))

include ${TOPDIR}/common.mk
include ${ARCHDIR}/${ARCH}/${ARCH}.mk

KERNEL_PATCH_DIR	+= ${TARGETDIR}/patches
KERNEL_PATCH_DIR	+= ${PATCHDIR} ${PATCHDIR}/${KERNEL_REPO_PATCHES}

include ${CONFIG}

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
