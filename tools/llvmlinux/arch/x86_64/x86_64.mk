##############################################################################
# Copyright (c) 2012 Mark Charlebois
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

# ARCH must be defined before all.mk
ARCH	= x86_64

include ${ARCHDIR}/all/all.mk

ARCH_X86_64_DIR		= ${ARCHDIR}/x86_64
ARCH_X86_64_BINDIR	= ${ARCH_X86_64_DIR}/bin
ARCH_X86_64_PATCHES	= ${ARCH_X86_64_DIR}/patches

KERNEL_PATCH_DIR	+= ${ARCH_X86_64_PATCHES} ${ARCH_X86_64_PATCHES}/${KERNEL_REPO_PATCHES}

KERNEL_SIZE_ARTIFACTS	= arch/x86_64/boot/bzImage vmlinux*
BOARD		= pc

# Add path so that ${CROSS_COMPILE}${CC} is resolved
PATH		:= ${PATH}:${ARCH_X86_64_BINDIR}

gcc x86_64-cc: state/cross-gcc
state/cross-gcc:
	$(call state,$@)

# ${1}=Machine_type ${2}=bzImage ${3}=RAM ${4}=rootfs ${5}=Kernel_opts ${6}=QEMU_opts
qemu = $(call runqemu,${QEMUBINDIR}/qemu-system-x86_64,${1},${2},${3},${4},${KERNELOPTS} ${5},${6})
