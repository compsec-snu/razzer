#############################################################################
# Copyright (c) 2014 Behan Webster
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

##############################################################################
KNOWN_GOOD_KERNEL_CONFIG_URL = http://buildbot.llvm.linuxfoundation.org/configs/kernel-${TARGET}.cfg
KERNEL_CONFIG	= ${TMPDIR}/kernel.cfg

ifndef NOCONFIG
-include ${KERNEL_CONFIG}
endif

CLEAN_TARGETS		+= kernel-config-clean
CLEAN_CONFIG_TARGETS	+= kernel-config-clean

##############################################################################
# Get known good config from continue integration buildbot
# ${KERNEL_CONFIG}: # Can't be this or will autodownload on above include
kernel-config:
	-@$(call getlink,${KNOWN_GOOD_KERNEL_CONFIG_URL},${KERNEL_CONFIG})
kernel-config-clean:
	@$(call leavestate,${STATEDIR},kernel-build-known-good kernel-gcc-build-known-good)
	@rm -f ${KERNEL_CONFIG}

##############################################################################
kernel-build-known-good kernel-gcc-build-known-good: %: ${STATEDIR}/%
${STATEDIR}/kernel-build-known-good ${STATEDIR}/kernel-gcc-build-known-good: ${STATEDIR}/%-build-known-good:
	@$(MAKE) GIT_HARD_RESET=1 kernel-resync
	@$(MAKE) GIT_HARD_RESET=1 refresh
	@$(call banner,Build known good kernel)
	@$(call leavestate,${STATEDIR},$*-configure $*-build)
	@$(MAKE) state/$*-build
	@$(call state,$@)

##############################################################################
kernel-rebuild-known-good kernel-gcc-rebuild-known-good: %-rebuild-known-good:
	@$(call leavestate,${STATEDIR},$*-build-known-good)
	@$(MAKE) ${STATEDIR}/$*-build-known-good

##############################################################################
kernel-resync: state/kernel-fetch kernel-config
	@$(call banner,Sync known good kernel)
	@cat ${KERNEL_CONFIG}
	@$(call unpatch,${KERNELDIR})
	@$(call leavestate,${STATEDIR},kernel-patch)
	@$(call optional_gitreset,${KERNELDIR})
	@$(call gitref,${KERNELDIR},${SHARED_KERNEL})
	@$(call gitsync,${KERNELDIR},${KERNEL_COMMIT},${KERNEL_BRANCH},${KERNEL_TAG})

##############################################################################
kernel-sync-latest: kernel-config-clean
	@$(call banner,Sync latest kernel)
	@$(MAKE) kernel-sync

##############################################################################
kernel-raze::
	@$(call leavestate,${STATEDIR},*-build-known-good)
	@rm -rf ${KERNEL_CONFIG}
