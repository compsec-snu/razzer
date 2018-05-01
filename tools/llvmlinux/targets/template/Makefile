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
# Those settings with defaults are commented out.
# Delete make targets you don't need.

TARGETDIR	= ${CURDIR}
TOPDIR		= $(realpath ${TARGETDIR}/../..)

ARCH	= arm
BOARD	= template

# Kernel settings
#KERNEL_GIT		= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
#KERNEL_BRANCH		= master
#KERNEL_TAG		= 
#KERNELDIR		= ${TARGETDIR}/src/linux
#KERNELGCC		= ${TARGETDIR}/src/linux-gcc
KERNEL_CFG		= ${TARGETDIR}/config_${BOARD}
#KERNEL_REPO_PATCHES	= master
#EXTRAFLAGS		=

# Arm specific
#MARCH			= armv7-a

BOARD_TARGETS		= board-clean board-help board-fetch board-mrproper board-raze board-settings clean mrproper
TARGETS			+= ${BOARD_TARGETS}
CLEAN_TARGETS		+= board-clean
HELP_TARGETS		+= board-help
FETCH_TARGETS		+= board-fetch
MRPROPER_TARGETS	+= board-mrproper
RAZE_TARGETS		+= board-raze
SETTINGS_TARGETS	+= board-settings
.PHONY:			${BOARD_TARGETS} clean mrproper

all: remove_me_when_configured prep kernel-build

# Remove me when you want this makefile to do something useful
remove_me_when_configured:
	@echo "Not configured yet"
	@exit 1

include ${TOPDIR}/common.mk
include ${ARCHDIR}/${ARCH}/${ARCH}.mk
include ${CONFIG}

KERNEL_PATCH_DIR	+= ${PATCHDIR} ${PATCHDIR}/${KERNEL_REPO_PATCHES}
prep: ${STATEDIR}/prep
${STATEDIR}/prep:
	$(MAKE) ${TMPDIR}
	@mkdir -p ${LOGDIR}
	$(call state,$@)

board-help:
	@echo "targets/${BOARD} has these options:"
	@echo
	@echo "* make <your make target here>	- Description"

board-settings:
	@$(call prsetting,FOO,${FOO})

board-fetch:
	@$(call banner,Fetching foo)

board-clean:
	@$(call banner,Cleaning foo)

board-mrproper:
	@$(call banner,Really cleaning foo)

board-raze:
	@$(call banner,Getting rid of all downloaded files for foo)

clean: kernel-clean kernel-gcc-clean board-clean
	@$(call banner,Clean)

mrproper: clean kernel-mrproper kernel-gcc-mrproper board-mrproper tmp-mrproper
	@rm -rf ${LOGDIR}/*
	@$(call banner,Very Clean)
