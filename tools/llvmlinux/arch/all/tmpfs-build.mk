##############################################################################
# Copyright (c) 2012 Behan Webster
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

TMPFS_BUILD_STATE	= ${TOPDIR}/build/tmpfs-build-dir

# Look to see if we have a tmpfs mounted. If so use it. Use default if provided
ifeq (${BUILDROOT},)
BUILDROOT	:= $(shell (mount | egrep "tmpfs on ${TOPDIR}.*/build .* tmpfs" \
			|| echo . . ${TOPDIR}) | head -1 | awk '{print $$3}')
endif

ifneq (${TMPFS_REQUIRED_FOR_BUILD},)
TMPFS_MOUNT	= ${TMPFS_BUILD_STATE}
endif

HELP_TARGETS		+= tmpfs-build-help

##############################################################################
# Convenience macro
buildroot	= $(subst ${TOPDIR},${BUILDROOT},${1})

##############################################################################
list-buildroot:
	@$(call echovar,BUILDROOT)

##############################################################################
tmpfs-build-help:
	@echo
	@echo "These are the make targets for the tmpfs build directory:"
	@echo "* make tmpfs-build-setup     - Mount tmpfs for use with build system"
	@echo "* make tmpfs-build-teardown  - Unmount tmpfs build directory"
	@echo "* make tmpfs-build-clean     - Remount tmpfs build directory"
	@echo
	@echo "Set TMPFS_REQUIRED_FOR_BUILD=1 in your local.mk if you want to always use this"

#############################################################################
check-tmpfs = if [ "${1}" = "${2}" ] ; then \
		[ -f ${1}/.config ] || ${MAKE} ${3} ; \
	else \
		[ -d ${2} ] || ${MAKE} ${3} ; \
	fi

##############################################################################
${TMPFS_BUILD_STATE}:
	$(MAKE) tmpfs-build-setup

##############################################################################
tmpfs-build-setup:
	@$(call banner,setting up tmpfs-build)
	@mkdir -p ${TOPDIR}/build
	@mount | egrep -q "tmpfs on ${TOPDIR}/build .* tmpfs" \
		&& echo "${TOPDIR}/build already mounted" \
		|| ( sudo mount -o uid=`id -u`,gid=`id -g`,mode=775 -t tmpfs -o size=16G tmpfs ${TOPDIR}/build ; \
			echo "The build will automatically look for this build directory." ; \
			echo "However, if you want to force the use of this directory," ; \
			echo "run the following once before building:" ; \
			echo ; \
			echo "export BUILDROOT=${TOPDIR}/build" )
	@touch ${TMPFS_BUILD_STATE}

##############################################################################
tmpfs-build-teardown:
	-@[ ! -d ${TOPDIR}/build ] || sudo umount ${TOPDIR}/build
	@[ ! -d ${TOPDIR}/build ] || rmdir ${TOPDIR}/build

##############################################################################
tmpfs-build-remount tmpfs-build-clean tmpfs-clean : tmpfs-build-teardown tmpfs-build-setup

##############################################################################
tmpfs-size:
	@du -sk ${BUILDROOT}/*/*

##############################################################################
shared-size:
	@du -sk ${SHARED_ROOT}/*/*
	@du -sk ${SHARED_ROOT}
