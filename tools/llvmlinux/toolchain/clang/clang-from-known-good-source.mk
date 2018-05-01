##############################################################################
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

# Assumes has been included from clang.mk
TOOLCHAINTOP		= ${LLVMTOP}/known_good

CLANG_TMPDIR		= ${TOOLCHAINTOP}/tmp
TMPDIRS			+= ${CLANG_TMPDIR}
CLEAN_TARGETS		+= clang-config-clean
CONFIG_CLEAN_TARGETS	+= clang-config-clean

include ${LLVMTOP}/clang-from-source.mk
STATE_CLANG_TOOLCHAIN = ${LLVMSTATE}/clang-build-known-good

##############################################################################
KNOWN_GOOD_CLANG_CONFIG_URL = http://buildbot.llvm.linuxfoundation.org/configs/clang-${ARCH}.cfg
CLANG_CONFIG	= ${CLANG_TMPDIR}/clang.cfg
ifndef NOCONFIG
-include ${CLANG_CONFIG}
endif

##############################################################################
# Get known good config from continue integration buildbot
#${CLANG_CONFIG}: # Can't be this or will auto-download with the above include
clang-config:
	-@$(call getlink,${KNOWN_GOOD_CLANG_CONFIG_URL},${CLANG_CONFIG})
clang-config-clean:
	@$(call leavestate,${STATEDIR},clang-build-known-goof)
	@rm -f ${CLANG_CONFIG}

##############################################################################
clang-build-known-good: ${LLVMSTATE}/clang-build-known-good
${LLVMSTATE}/clang-build-known-good:
	@$(MAKE) llvm-resync clang-resync
	@$(call banner,Build known good clang)
	@$(call leavestate,${LLVMSTATE},llvm-configure llvm-build clang-configure clang-build)
	@$(MAKE) ${LLVMSTATE}/clang-build
	$(call state,$@)

##############################################################################
clang-rebuild-known-good:
	@$(call leavestate,${LLVMSTATE},clang-build-known-good)
	@$(MAKE) ${LLVMSTATE}/clang-build-known-good

##############################################################################
llvm-resync: ${LLVMSTATE}/llvm-fetch clang-config
	@$(call banner,Sync known good LLVM)
	-@grep LLVM ${CLANG_CONFIG}
	@$(call leavestate,${LLVMSTATE},llvm-patch)
	@$(call llvmsync,LLVM,${LLVMDIR},${LLVM_BRANCH},${LLVM_COMMIT})

##############################################################################
clang-resync: ${LLVMSTATE}/clang-fetch clang-config
	@$(call banner,Sync known good clang)
	-@grep CLANG ${CLANG_CONFIG}
	@$(call leavestate,${LLVMSTATE},clang-patch)
	@$(call llvmsync,Clang,${CLANGDIR},${CLANG_BRANCH},${CLANG_COMMIT})

##############################################################################
llvm-sync-latest clang-sync-latest: %-sync-latest: clang-config-clean
	@$(call banner,Sync latest $*)
	@$(MAKE) $*-sync

##############################################################################
clang-clean clang-mrproper clang-raze::
	@rm -rf ${LLVMSTATE}/clang-build-known-good ${CLANG_CONFIG}
