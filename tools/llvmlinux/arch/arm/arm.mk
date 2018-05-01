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

STATE_TOOLCHAIN	= state/arm-cc

# ARCH must be defined before all.mk
ARCH		= arm
MARCH		?= armv7-a
MFLOAT		?= -mfloat-abi=softfp -mfpu=neon

FETCH_TARGETS	+= arm-cc
RAZE_TARGETS	+= arm-cc-clean

ARCH_ARM_DIR	= ${ARCHDIR}/arm
ARCH_ARM_BINDIR	= ${ARCH_ARM_DIR}/bin
ARCH_ARM_PATCHES= ${ARCH_ARM_DIR}/patches

ARCH_ARM_TOOLCHAIN	= ${ARCH_ARM_DIR}/toolchain
ARCH_ARM_TOOLCHAIN_STATE= ${ARCH_ARM_TOOLCHAIN}/state

PATH		:= ${ARCH_ARM_BINDIR}:${PATH}

include ${ARCH_ARM_TOOLCHAIN}/toolchain.mk
include ${ARCHDIR}/all/all.mk

KERNEL_PATCH_DIR+= ${ARCH_ARM_PATCHES} ${ARCH_ARM_PATCHES}/${KERNEL_REPO_PATCHES}

HELP_TARGETS	+= arm-help
SETTINGS_TARGETS+= arm-settings
VERSION_TARGETS	+= arm-cc-version

KERNEL_SIZE_ARTIFACTS	= arch/arm/boot/zImage vmlinux*

#KERNELOPTS	= console=earlycon console=ttyAMA0,38400n8 earlyprintk
KERNELOPTS	= console=ttyAMA0

# ${1}=Machine_type ${2}=path_zImage ${3}=RAM ${4}=rootfs ${5}=Kernel_opts ${6}=QEMU_opts
qemu_arm = $(call runqemu,${QEMUBINDIR}/qemu-system-arm,${1},${2},${3},${4},${KERNELOPTS} ${5},${6})

# ${1}=Machine_type ${2}=path_zImage ${3}=path_dtb ${4}=RAM ${5}=rootfs ${6}=Kernel_opts ${7}=QEMU_opts
qemu_arm_dtb = $(call runqemudtb,${QEMUBINDIR}/qemu-system-arm,${1},${2},${3},${4},${5},${KERNELOPTS} ${6},${7})

arm-help:
	@echo
	@echo "These options are specific to building a Linux Kernel for ARM:"
	@echo "* make CROSS_ARM_TOOLCHAIN=[codesourcery,linaro,android] ..."
	@echo "			- Choose the gcc cross toolchain you want to use"

arm-settings:
	@echo "# ARM settings"
	@$(call prsetting,CROSS_ARM_TOOLCHAIN,${CROSS_ARM_TOOLCHAIN})
	@$(call prsetting,EXTRAFLAGS,${EXTRAFLAGS})
	@$(call prsetting,KERNEL_MAKE_TARGETS,${KERNEL_MAKE_TARGETS})

