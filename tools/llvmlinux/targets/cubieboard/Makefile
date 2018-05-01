##############################################################################
# Copyright (c) 2014 Mark Charlebois
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
LLVM_COMMIT	= master
CLANG_COMMIT	= master
CLANG_TOOLCHAIN	= source

#KERNEL_CFG	= ${KERNELDIR}/arch/arm/configs/sunxi_defconfig
KERNEL_CFG	= ${TARGETDIR}/config_initrd
KERNEL_DTB	= arch/arm/boot/dts/sun4i-a10-cubieboard.dtb
ZIMAGE		= arch/arm/boot/zImage
KERNEL_MAKE_TARGETS	= zImage dtbs


BUILDROOT_ARCH	= qemu_arm_allwinner
BUILDROOT_CONFIG= config_allwinner_buildroot
TOOLCHAINDIR	= $(ARM_CROSS_GCC_TOOLCHAIN)

ifeq ('${GDBON}','1')
GDB_OPTS=-gdb tcp::4321 -S
else
GDB_OPTS=
endif

all: prep kernel-build test-boot-poweroff
all-gcc: prep kernel-gcc-build test-boot-poweroff

BOARD	= cubieboard

NET	= -net nic,macaddr=52:54:00:12:34:57

BUILDBOT_PREBUILT_URL	= http://buildbot.llvm.linuxfoundation.org/prebuilt/arm/${NAME}
get_prebuilt		= mkdir -p $(dir ${1}) && wget -P $(dir ${1}) -c ${BUILDBOT_PREBUILT_URL}/$(notdir ${1})

CUBIEBOARD_TARGETS	= test2 test2-gcc clean mrproper
TARGETS_BUILD		+= test2 test2-gcc clean mrproper
HELP_TARGETS		+= cubieboard-help
FETCH_TARGETS		+= ${INITRAMIMG} ${VEXPRESS_IMG_GZ}
RAZE_TARGETS		+= cubieboard-raze
.PHONY:			${VEXPRESS_TARGETS}

include ${TOPDIR}/common.mk
include ${ARCHDIR}/arm/arm.mk

# Must use master branch for Allwinner support
QEMU_BRANCH	= "master"
QEMU_COMMIT	= 

#KERNEL_PATCH_DIR+= ${TARGETDIR}/patches-overlay
KERNEL_PATCH_DIR+= ${TARGETDIR}/patches

# See http://linux-sunxi.org/Mainline_Kernel_Howto
KERNEL_ENV += LOADADDR=0x40008000
KERNELGCC_ENV += LOADADDR=0x40008000

include ${CONFIG}

cubieboard-help:
	@echo "targets/cubieboard has these options:"
	@echo
	@echo "* make test2		- busybox based initramfs"
	@echo "* make test2-gcc		- busybox based initramfs"
	@echo
	@echo " Note: You currently have to do a 'killall qemu-system-arm' from another terminal"
	@echo "       to exit from the above tests."
	@echo
	@echo "* make patch-update"
	@echo
	@echo "* make clean		- Remove most built files"
	@echo "* make mrproper		- Remove all downloaded and built files"

${KERNEL_CFG}: initramfs
	cp ${KERNELDIR}/arch/arm/configs/sunxi_defconfig $@
	sed -i -e 's#CONFIG_BLK_DEV_INITRD=y#CONFIG_BLK_DEV_INITRD=y\nCONFIG_INITRAMFS_SOURCE="${TARGETDIR}/initramfs.cpio.gz"#' $@
	sed -i -e 's/CONFIG_DEVTMPFS/#CONFIG_DEVTMPFS/' $@
	sed -i -e 's/CONFIG_DEVTMPFS_MOUNT/#CONFIG_DEVTMPFS_MOUNT/' $@


prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR}
	$(call state,$@)

INITRAMIMG	= ${TMPDIR}/initramfs.img
${INITRAMIMG}:
	$(call get_prebuilt, $@)

parse-qemulog:
	( rm a2llog ; for i in `cat qemulog.log | tail -n 500 | grep ^0x | cut -d":" -f1` ; do echo -n "$$i " >> a2llog ; addr2line -f -p -e src/linux/vmlinux $$i >> a2llog ; done )
	( cat a2llog | more )

# Create the generic initramfs, add in the kernel modules, then create the cpio
# Allwinner config does not have module support enabled
test2: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${STATEDIR}/kernel-build initramfs-unpacked
	@rm -rf ${INITBUILDFSDIR}/lib
	mkdir -p ${INITBUILDFSDIR}/usr/lib
	@rm -f ${INITRAMFS}
	@make ${INITRAMFS}
	../../test/qemu/install/bin/qemu-system-arm -M ${BOARD} -kernel ${KERNEL_BUILD}/${ZIMAGE} -serial stdio -append "console=ttyS0 rw root=/dev/ram0 rdinit=/init" -dtb ${KERNEL_BUILD}/${KERNEL_DTB} -display none

# Allwinner config does not have module support enabled
test2-gcc: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${KERNELGCCDTB_IMG} initramfs-unpacked
	@rm -rf ${INITBUILDFSDIR}/lib
	mkdir -p ${INITBUILDFSDIR}/usr/lib
	@rm -f ${INITRAMFS}
	@make ${INITRAMFS}
	../../test/qemu/install/bin/qemu-system-arm -M ${BOARD} -kernel ${KERNELGCC_BUILD}/${ZIMAGE} -serial stdio -append "console=ttyS0 root=/dev/ram0 rw rdinit=/init" -dtb ${KERNELGCC_BUILD}/${KERNEL_DTB} -display none
	
cubieboard-raze raze: kernel-raze
	@$(call banner,Razed Vexpress)

clean: 
	@$(call banner,Clean)
	rm -f ${KERNEL_CFG}
	make kernel-clean kernel-gcc-clean 

rproper: clean tmp-mrproper
	@$(call banner,Very Clean)
