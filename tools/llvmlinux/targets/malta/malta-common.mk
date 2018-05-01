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

# This is a template file with the kinds of settings and make targets filled in.
TARGETDIR	?= ${CURDIR}
BASETARGETDIR	?= ${CURDIR}
TOPDIR		?= $(realpath ${TARGETDIR}/../..)
CLANG_TOOLCHAIN ?= from-source
CROSS_MIPS_TOOLCHAIN ?= codescape-sdk

ARCH	?= mips
BOARD	?= malta
CORE_BOARD ?= default
MIPS_ENDIAN ?= big

COREBOARDDIR            = ${TARGETDIR}/build-${CORE_BOARD}-${MIPS_ENDIAN}

# Kernel settings
#KERNEL_GIT		= git://git.le.imgtec.org/mips-linux.git
KERNEL_BRANCH		= master
#KERNEL_TAG		=
KERNELDIR		= ${TARGETDIR}/src/linux
KERNELGCC		= ${TARGETDIR}/src/linux-gcc
KERNEL_CFG		?= ${TARGETDIR}/configs/${CORE_BOARD}/${MIPS_ENDIAN}-endian
#KERNEL_REPO_PATCHES	= master
#EXTRAFLAGS		=

# MIPS specific
BOARD_TARGETS		= ${BOARD}-clean ${BOARD}-mrproper ${BOARD}-raze \
			  clean mrproper test-gcc
TARGETS			+= ${BOARD_TARGETS}
CLEAN_TARGETS		+= ${BOARD}-clean
MRPROPER_TARGETS	+= ${BOARD}-mrproper
RAZE_TARGETS		+= ${BOARD}-raze
.PHONY:			${BOARD_TARGETS} clean mrproper test-gcc

all: prep kernel-build

all-gcc: prep kernel-gcc-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/${ARCH}/${ARCH}.mk
include ${CONFIG}

KERNEL_PATCH_DIR	+= ${PATCHDIR} ${PATCHDIR}/${KERNEL_REPO_PATCHES}
prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR}
	$(call state,$@)

${BOARD}-build: kernel-build

${BOARD}-clean:
	@$(call banner,Cleaning ${BOARD})

${BOARD}-mrproper:
	@$(call banner,Really cleaning ${BOARD})

${BOARD}-raze:
	@$(call banner,Getting rid of all downloaded files for ${BOARD})

initramfs-unpacked::
	tar -C ${BASETARGETDIR}/initramfs-overlay -c -z -f ${BASETARGETDIR}/initramfs-overlay.tar.gz .
	tar -C ${INITBUILDFSDIR} -x -z -f ${BASETARGETDIR}/initramfs-overlay.tar.gz

test-gcc: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}
	$(call qemu_mips,${BOARD},${KERNELGCC_BUILD}/vmlinux,256,/dev/ram0,rw,-initrd ${INITRAMFS} -net none ${QEMU_FLAGS})

test: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}
	$(call qemu_mips,${BOARD},${KERNEL_BUILD}/vmlinux,256,/dev/ram0,rw,-initrd ${INITRAMFS} -net none ${QEMU_FLAGS})

test-gdb: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}
	( $(call qemu_mips,${BOARD},${KERNEL_BUILD}/vmlinux,256,/dev/ram0,rw console=ttyS0 debug user_debug=-1 earlyprintk initcall.debug,-initrd ${INITRAMFS} -net none -s -S ${QEMU_FLAGS}) &)
	@(echo "set output-radix 16" > .gdbinit ; echo "target remote localhost:1234" >> .gdbinit )
	(${CROSS_GDB} ${KERNEL_BUILD}/vmlinux)
	(killall -s 9 qemu-system-mips)

test-qemu-debug: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}
	( $(call qemu_mips,${BOARD},${KERNEL_BUILD}/vmlinux,256,/dev/ram0,rw console=ttyS0 earlyprintk initcall.debug ,-initrd ${INITRAMFS} -net none -D qemulog.log -d in_asm,op,int,exec,cpu, ${QEMU_FLAGS}) & )
	( sleep 20 && killall -s 9 qemu-system-mips ) || exit 0
	grep ^0x qemulog.log > debugaddr.log
	tail -n 2000 debugaddr.log | cut -d":" -f1 > addresses.log
	rm -f a2l.log
	for i in `tac addresses.log` ; do addr2line -f -p -e ${KERNEL_BUILD}/vmlinux $$i >> a2l.log ; done

kernel-gcc-test:: test-gcc-boot-poweroff
test-gcc-boot-poweroff: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}
	$(call qemu_mips,${BOARD},${KERNELGCC_BUILD}/vmlinux,256,/dev/ram0,rw POWEROFF,-initrd ${INITRAMFS} -net none ${QEMU_FLAGS})

kernel-test:: test-boot-poweroff
test-boot-poweroff: ${STATEDIR}/prep ${QEMUSTATE}/qemu-build ${INITRAMFS}
	$(call qemu_mips,${BOARD},${KERNEL_BUILD}/vmlinux,256,/dev/ram0,rw POWEROFF,-initrd ${INITRAMFS} -net none ${QEMU_FLAGS})

clean: kernel-clean kernel-gcc-clean ${BOARD}-clean
	@$(call banner,Clean)

mrproper: clean kernel-mrproper kernel-gcc-mrproper ${BOARD}-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}/*
	@$(call banner,Very Clean)

myenv:
	env
