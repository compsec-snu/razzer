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

# Should be included from clang-from-source.mk

.PHONY: ${BB_CLANG_CFG}
BB_CLANG_CFG		= ${BUILDBOTDIR}/clang-${ARCH}.cfg

BB_CI_CLANGOPT		= CLANG_TOOLCHAIN=from-source
BB_CI_CLANG_MAKE	= $(MAKE) ${BB_CI_CLANGOPT}
BB_CI_KERNEL_CLANGOPT	= CLANG_TOOLCHAIN=from-known-good-source
BB_CI_KERNEL_MAKE	= $(MAKE) ${BB_CI_KERNEL_CLANGOPT}

#############################################################################
list-buildbot-artifacts::
	@$(call ini_file_entry,TOOLCHAIN\t,${BB_CLANG_CFG})

#############################################################################
bb_clang::
	@$(call banner,Building ${BB_CLANG_CFG})
	@mkdir -p $(dir ${BB_CLANG_CFG})
	@$(call makequiet,llvm-settings clang-settings) > ${BB_CLANG_CFG}

############################################################################
# Kernel is tested after this
buildbot-llvm-ci-build::
	${BB_CI_CLANG_MAKE} GIT_HARD_RESET=1 llvm-mrproper
	${BB_CI_CLANG_MAKE} clang
buildbot-clang-ci-build::
	${BB_CI_CLANG_MAKE} GIT_HARD_RESET=1 clang-mrproper
	${BB_CI_CLANG_MAKE} ${BB_CI_CLANGOPT} clang

############################################################################
# Kernel is tested after this
buildbot-llvmlinux-ci-build buildbot-kernel-ci-build::
	${BB_CI_KERNEL_MAKE} clang-rebuild-known-good
