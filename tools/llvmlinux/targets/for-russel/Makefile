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
LLVM_BRANCH	= master
CLANG_BRANCH	= master
CLANG_TOOLCHAIN	= from-source

KERNEL_CFG	= ${KERNELDIR}/arch/arm/configs/multi_v7_defconfig
KERNEL_GIT	= http://ftp.arm.linux.org.uk/pub/linux/arm/kernel/git-cur/linux-arm.git

GDB_OPTS	=

all: prep kernel-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/arm/arm.mk
include ${ARCHDIR}/all/git-submit-russel.mk

include ${CONFIG}

#KERNEL_PATCH_DIR+= ${TARGETDIR}/patches-overlay
KERNEL_PATCH_DIR+= ${TARGETDIR}/patches

TARGETS+= clean mrproper
.PHONY: prep clean mrproper

#############################################################################
prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR}
	$(call state,$@)

#############################################################################
clean: kernel-clean kernel-gcc-clean
	@$(call banner,Clean)

#############################################################################
mrproper: clean kernel-mrproper kernel-gcc-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}
	@$(call banner,Very Clean)

#############################################################################
kernel-patch-required:
	@$(call banner,Patch status for the kernel)
	@$(call patch_status_extract,required,Y.*,${PATCHDIR})

#############################################################################
kernel-patch-required-series:
	@$(call banner,Patch status for the kernel)
	@$(call patch_status_extract,required,Y.*,${PATCHDIR}) | tee ${PATCHDIR}/series

#############################################################################
kernel-patch-for-russel:
	@$(call banner,Patch status for the kernel)
	@$(call patch_status_extract,finalpatchforrussel,Y.*,${PATCHDIR})

#############################################################################
kernel-patch-for-russel-series:
	@$(call banner,Patch status for the kernel)
	@$(call patch_status_extract,finalpatchforrussel,Y.*,${PATCHDIR}) | tee ${PATCHDIR}/series

#############################################################################
# Create the generic initramfs, add in the kernel modules, then create the cpio
test: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build initramfs-unpacked
	@rm -rf ${INITBUILDFSDIR}/lib/modules
	(cd ${KERNEL_BUILD} && make V=0 INSTALL_MOD_PATH=${INITBUILDFSDIR} modules_install 2>&1 > /dev/null)
	mkdir -p ${INITBUILDFSDIR}/usr/lib
	@rm -f ${INITRAMFS}
	@make ${INITRAMFS}
	mv ${INITRAMFS} ${INITRAMFS}.clang
#	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/x86/boot/bzImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-initrd ${INITRAMFS}.clang -curses)
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/arm/boot/zImage,512,/dev/ram0,rw console=ttyS0 earlyprintk ,-initrd ${INITRAMFS}.clang -net none )

test-qemu:
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/arm/boot/zImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-M q35 -cpu SandyBridge -initrd ${INITRAMFS}.clang)

test-qemu-smp:
	$(call qemu,${BOARD},${KERNEL_BUILD}/arch/arm/boot/zImage,2048,/dev/ram0,ramdisk_size=512000 rdinit=/init console=ttyS0 earlyprintk,-M q35 -cpu SandyBridge -smp 4 -initrd ${INITRAMFS}.clang)
