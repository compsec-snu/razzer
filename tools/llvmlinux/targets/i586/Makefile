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

# pin to stable version
#CONFIG ?= checkpoints/v3.14/config.mk
KERNEL_CFG	= ${TARGETDIR}/config_i586
KERNEL_BRANCH	= master
# override KERNEL_TAG to v3.3
#KERNEL_TAG = v3.3
# around 3.10-rc7
#KERNEL_COMMIT = "4300a0f8bdcce5a03b88bfa16fc9827e15c52dc4"
#LLVM_COMMIT = release_34
#CLANG_COMMIT = release_34

#GDB_OPTS	= -gdb tcp::1234 -s -S
GDB_OPTS	=

all: prep kernel-build

include ${TOPDIR}/common.mk
include ${ARCHDIR}/i586/i586.mk

# we overlay the patches with even newer versions of it 
PATCHDIR = ${TARGETDIR}/patches
BKERNEL_REPO_PATCHES = master
KERNEL_PATCH_DIR += ${PATCHDIR}/${KERNEL_REPO_PATCHES}

# no, use CONFIG !
#include ${CONFIG}

TARGETS+= clean mrproper test test2
.PHONY: test test2 fetch-initrd prep clean mrproper

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

test: ${QEMUSTATE}/qemu-build initramfs ${STATEDIR}/kernel-build
	@$(call qemu,${BOARD},${KERNELDIR},768,/dev/ram0,init=/init,-initrd initramfs.img)

