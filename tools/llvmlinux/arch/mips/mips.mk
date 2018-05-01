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

# Note: This file must be included after ${TOPDIR}/common.mk

# ARCH must be defined before all.mk
ARCH		= mips
MARCH           ?= mips32r2
HOST		= mips-unknown-linux-gnu
HOST_TRIPLE	= mips-unknown-linux-gnu

FETCH_TARGETS	+= mips-cc
RAZE_TARGETS	+= mips-cc-clean

STATE_TOOLCHAIN = state/mips-cc

ARCH_MIPS_DIR     = ${ARCHDIR}/mips
ARCH_MIPS_BINDIR  = ${ARCH_MIPS_DIR}/bin
ARCH_MIPS_PATCHES = ${ARCH_MIPS_DIR}/patches

ARCH_MIPS_TOOLCHAIN      = ${ARCH_MIPS_DIR}/toolchain
ARCH_MIPS_TOOLCHAIN_STATE= ${ARCH_MIPS_TOOLCHAIN}/state

PATH := ${ARCH_MIPS_BINDIR}:${PATH}

include ${ARCH_MIPS_TOOLCHAIN}/toolchain.mk
include ${ARCHDIR}/all/all.mk

KERNEL_PATCH_DIR+= ${ARCH_MIPS_PATCHES} ${ARCH_MIPS_PATCHES}/${KERNEL_REPO_PATCHES}

HELP_TARGETS	+= mips-help
SETTINGS_TARGETS+= mips-settings
VERSION_TARGETS	+= mips-cc-version

KERNEL_SIZE_ARTIFACTS	= vmlinux*

# Set sensible defaults according to the architecture
ifeq ($(findstring mips32,${MARCH}),mips32)
  MIPS_NBITS ?= 32
endif
ifeq ($(findstring mips64,${MARCH}),mips64)
  MIPS_NBITS ?= 64
endif
ifndef MIPS_NBITS
  $(error Could not determine MIPS_NBITS setting from $${MARCH}. You will need to set it manually)
endif

MIPS_ENDIAN ?= little
ifeq (${MIPS_ENDIAN},little)
  MIPS_QEMU_ENDIAN = el
else
  ifeq (${MIPS_ENDIAN},big)
    MIPS_QEMU_ENDIAN =
  else
    $(error Invalid value for MIPS_ENDIAN, expected 'big' or 'little')
  endif
endif

ifeq (${MIPS_NBITS},32)
  MIPS_QEMU_NBITS =
else
  ifeq (${MIPS_NBITS},64)
    MIPS_QEMU_NBITS = 64
  else
    $(error Invalid value for MIPS_NBITS, expected '32' or '64')
  endif
endif

MIPS_QEMU_BIN=${QEMUBINDIR}/qemu-system-mips${MIPS_QEMU_NBITS}${MIPS_QEMU_ENDIAN}

MIPS_BUSYBOX_ENDIAN=${MIPS_QEMU_ENDIAN}

# ${1}=Machine_type ${2}=path_to_zImage ${3}=RAM ${4}=rootfs ${5}=Kernel_opts ${6}=QEMU_opts
qemu_mips = $(call runqemu,${MIPS_QEMU_BIN},${1},${2},${3},${4},${KERNELOPTS} ${5},${6})

mips-help:
	@echo
	@echo "These options are specific to building a Linux Kernel for MIPS:"
	@echo "* make CROSS_MIPS_TOOLCHAIN=[codesourcery] ..."
	@echo "			- Choose the gcc cross toolchain you want to use"
	@echo "* make MIPS_ENDIAN=[big,little] ..."
	@echo "			- Select the endianness of the target"
	@echo "* make MIPS_NBITS=[32,64] ..."
	@echo "			- Select the size of the general purpose registers"
	@echo "			  This will be inferred from the value of MARCH when possible"

mips-settings:
	@echo "# MIPS settings"
	@$(call prsetting,CROSS_MIPS_TOOLCHAIN,${CROSS_MIPS_TOOLCHAIN})
	@$(call prsetting,MIPS_ENDIAN,${MIPS_ENDIAN})
	@$(call prsetting,MIPS_NBITS,${MIPS_NBITS})
	@$(call prsetting,EXTRAFLAGS,${EXTRAFLAGS})
	@$(call prsetting,KERNEL_MAKE_TARGETS,${KERNEL_MAKE_TARGETS})
