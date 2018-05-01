##############################################################################
# Copyright (c) 2013 Mark Charlebois
#               2012 Jan-Simon Möller
#               2012 Behan Webster
#               2014 Vinícius Tinti
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

KERNEL_BRANCH	= linux-linaro
KERNELDIR	= ${SRCDIR}/panda-linaro
KERNEL_GIT	= http://git.linaro.org/git/kernel/linux-linaro-tracking.git
KERNEL_CFG	= ${TMPDIR}/kernel_config
KERNEL_CFG_DIR = ${TMPDIR}/config
KERNEL_DTB	= arch/arm/boot/dts/omap4-panda.dtb
ZIMAGE		= arch/arm/boot/zImage

#Use the branch name for the dir containing target specific patch overrides
KERNEL_REPO_PATCHES=${KERNEL_BRANCH}

EXTRAFLAGS	=

all: prep kernel-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/arm/arm.mk
include ${CONFIG}

KERNEL_PATCH_DIR+= ${TARGETDIR}/patches/panda-linaro-overlay
KERNEL_PATCH_DIR+= ${TARGETDIR}/patches

TARGETS+= check-dups kernel-autopatch clean mrproper
.PHONY: kernel-copy clean mrproper

prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR} ${TARGETDIR}/patches
	$(call state,$@)

check-dups:
	${TOOLSDIR}/checkduplicates.py $(shell ${MAKE} list-kernel-patches)

clean: kernel-clean kernel-gcc-clean ${KERNEL_CFG}-clean
	@$(call banner,Clean)

mrproper: clean kernel-mrproper kernel-gcc-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}/*
	@$(call banner,Very Clean)

${KERNEL_CFG}:
	@mkdir -p ${KERNEL_CFG_DIR}
	@(cd ${KERNELDIR}; \
		scripts/kconfig/merge_config.sh \
		-O ${KERNEL_CFG_DIR} \
		linaro/configs/linaro-base.conf \
		linaro/configs/distribution.conf \
		linaro/configs/omap2plus.conf \
		linaro/configs/panda.conf; \
	 cd -)
	@cp ${KERNEL_CFG_DIR}/.config $@

${KERNEL_CFG}-clean:
	@rm -rf ${KERNEL_CFG_DIR}

INITRAMIMG	= ${TMPDIR}/initramfs.img
${INITRAMIMG}:
	$(call get_prebuilt, $@)

KERNELDTB_IMG = ${TMPDIR}/kernel_dtb.img
KERNELGCCDTB_IMG = ${TMPDIR}/kernelgcc_dtb.img
${KERNELDTB_IMG}: ${STATEDIR}/kernel-build
	@$(call check-tmpfs,${KERNELDIR},${KERNEL_BUILD},kernel-mrproper $^)
	cat ${KERNEL_BUILD}/${ZIMAGE} ${KERNEL_BUILD}/${KERNEL_DTB} > $@
${KERNELGCCDTB_IMG}: ${STATEDIR}/kernel-gcc-build
	@$(call check-tmpfs,${KERNELGCC},${KERNELGCC_BUILD},kernel-gcc-mrproper $^)
	cat ${KERNELGCC_BUILD}/${ZIMAGE} ${KERNELGCC_BUILD}/${KERNEL_DTB} > $@

linaro-pack: kernel-build ${KERNELDTB_IMG} ${INITRAMIMG}
	@echo cp ${INITRAMIMG} ${KERNELDTB_IMG} /tmp
