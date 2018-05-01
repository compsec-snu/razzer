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

.PHONY: ${BB_ARTIFACT_MANIFEST} ${BB_LLVMLINUX_CFG} ${BB_TARGET_CFG} ${BB_KERNEL_CFG}
BB_ARTIFACT_MANIFEST	= ${BUILDBOTDIR}/manifest.ini
BB_LLVMLINUX_CFG	= ${BUILDBOTDIR}/llvmlinux-${ARCH}.cfg
BB_TARGET_CFG		= ${BUILDBOTDIR}/target-${TARGET}.cfg
BB_KERNEL_CFG		= ${BUILDBOTDIR}/kernel-${TARGET}.cfg
# Date in ISO 8601 UTC format for easy sorting
BB_UTC_DATE		:= $(shell date --utc '+%Y-%m-%dT%H%M%SZ')
BB_KERNEL_PATCHES_DATE	:= ${BUILDBOTDIR}/kernel-patches-${BB_UTC_DATE}.tar.bz2
BB_KERNEL_PATCHES_PAT	= ${BUILDBOTDIR}/kernel-patches-*.tar.bz2
BB_KERNEL_PATCHES	= ${BUILDBOTDIR}/kernel-patches.tar.bz2

#############################################################################
.PHONY: ${BB_ARTIFACT_MANIFEST} ${BB_TARGET_CFG} ${BB_KERNEL_CFG}
bb_manifest: ${BB_ARTIFACT_MANIFEST}
${BB_ARTIFACT_MANIFEST}:
	@$(call banner,Building $@)
	@mkdir -p $(dir $@)
	@echo "# Buildbot manifest for ${TARGET} built on `date`" > $@
	@$(call ini_section,$@,[Versions],list-versions)
	@$(call ini_section,$@,[Config],list-settings)
	@$(call ini_section,$@,[Artifacts],list-buildbot-artifacts)

#############################################################################
list-buildbot-artifacts::
	@$(call ini_file_entry,LLVMLINUX\t\t,${BB_LLVMLINUX_CFG})
	@$(call ini_file_entry,TARGET\t\t,${BB_TARGET_CFG})
	@$(call ini_file_entry,KERNEL\t\t,${BB_KERNEL_CFG})
	@$(call ini_link_entry,KERNEL_PATCHES,${BB_KERNEL_PATCHES})
	@$(call ini_file_entry,WARNINGS\t,${KERNEL_CLANG_LOG})
	@$(call ini_file_entry,ERROR_ZIP\t,${ERROR_ZIP})

#############################################################################
BB_ALL	= bb_llvmlinux bb_clang bb_kernel bb_kernel_patches bb_target bb_manifest
.PHONY: ${BB_ALL}
bb_all: ${BB_ALL}

#############################################################################
bb_llvmlinux: ${BB_LLVMLINUX_CFG}
${BB_LLVMLINUX_CFG}:
	@$(call banner,Building $@)
	@mkdir -p $(dir $@)
	@$(call makequiet,common-settings) > $@

#############################################################################
bb_target: ${BB_TARGET_CFG}
${BB_TARGET_CFG}:
	@$(call banner,Building $@)
	@mkdir -p $(dir $@)
	@$(call makequiet,list-settings) > $@

#############################################################################
bb_kernel: ${BB_KERNEL_CFG}
${BB_KERNEL_CFG}:
	@$(call banner,Building $@)
	@mkdir -p $(dir $@)
	@$(call makequiet,kernel-settings) > $@

#############################################################################
bb_kernel_patches:
	@$(call banner,Building ${BB_KERNEL_PATCHES_DATE})
	@rm -f ${BB_KERNEL_PATCHES_PAT}
	@$(call tar_patches,${BB_KERNEL_PATCHES_DATE})
	@$(call link_files,${BB_KERNEL_PATCHES},$(notdir ${BB_KERNEL_PATCHES_DATE}))

#############################################################################
# Defined in toolchain/clang/buildbot.mk
#BB_CI_CLANG_MAKE	= $(MAKE) ${BB_CI_CLANGOPT}
#BB_CI_KERNEL_MAKE	= $(MAKE) ${BB_CI_KERNEL_CLANGOPT}
bb_check	= $(call assert,-n "${1}",Must run buildbot target with CLANG_TOOLCHAIN=from-known-good-source)

#############################################################################
# Updated in toolchain/clang/buildbot.mk
bb_clang::

############################################################################
# Clang is already built before this
buildbot-llvm-ci-build buildbot-clang-ci-build::
	@$(call bb_check,${BB_CI_CLANG_MAKE})
	${BB_CI_CLANG_MAKE} GIT_HARD_RESET=1 kernel-rebuild-known-good \
		|| $(MAKE) ${BB_CI_CLANGOPT} GIT_HARD_RESET=1 kernel-sync-latest refresh kernel-rebuild
	${BB_CI_CLANG_MAKE} kernel-test
	${BB_CI_CLANG_MAKE} bb_clang bb_manifest

############################################################################
# Clang is already built before this
buildbot-llvmlinux-ci-build buildbot-kernel-ci-build::
	@$(call bb_check,${BB_CI_KERNEL_MAKE})
	${BB_CI_KERNEL_MAKE} GIT_HARD_RESET=1 refresh
# Do it with gcc first (because we can't break gcc)
	@$(call banner,Build/test kernel with gcc)
	${BB_CI_KERNEL_MAKE} GIT_HARD_RESET=1 kernel-gcc-clean
# If it fails with current kernel source, resync to tip and try again
	${BB_CI_KERNEL_MAKE} kernel-gcc-build \
		|| ${BB_CI_KERNEL_MAKE} kernel-sync-latest kernel-gcc-rebuild
	${BB_CI_KERNEL_MAKE} kernel-gcc-test
# Now redo it all with clang
	@$(call banner,Build/test kernel with clang)
	${BB_CI_KERNEL_MAKE} GIT_HARD_RESET=1 kernel-clean
	${BB_CI_KERNEL_MAKE} kernel-build
	${BB_CI_KERNEL_MAKE} kernel-test

############################################################################
# Kernel is already built before this
buildbot-llvmlinux-ci-build::
	${BB_CI_KERNEL_MAKE} bb_llvmlinux bb_manifest

############################################################################
# Kernel is already built before this
buildbot-kernel-ci-build::
	${BB_CI_KERNEL_MAKE} bb_target bb_kernel bb_kernel_patches bb_manifest
