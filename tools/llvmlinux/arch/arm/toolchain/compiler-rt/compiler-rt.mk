##############################################################################
# Copyright (c) 2012 Mark Charlebois
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

# This makefile must be included after common.mk which includes toolchain.mk

COMPILERRT_LOCALGIT  = "${COMPILERRTDIR}/.git"

ARMCOMPILERRTDIR	= ${ARCH_ARM_TOOLCHAIN}/compiler-rt
ARMCOMPILERRTSTATE	= ${ARMCOMPILERRTDIR}/state

ARMCOMPILERRTPATCHES	= ${ARMCOMPILERRTDIR}/patches
ARMCOMPILERRTBUILDDIR	= ${ARMCOMPILERRTDIR}/build
ARMCOMPILERRTSRCDIR	= ${ARMCOMPILERRTBUILDDIR}/compiler-rt
ARMCOMPILERRTINSTALLDIR	= ${ARMCOMPILERRTDIR}/install
TARGETS_TOOLCHAIN	+= compilerrt-arm-[clone,patch,configure,build,clean,sync]

compilerrt-arm-clone: ${ARMCOMPILERRTSTATE}/compilerrt-arm-clone
${ARMCOMPILERRTSTATE}/compilerrt-arm-clone: ${LLVMSTATE}/compilerrt-fetch
	@$(call banner,Cloning Compiler-rt for ARM build...)
	@mkdir -p ${ARMCOMPILERRTBUILDDIR}
	$(call gitclone,${COMPILERRT_LOCALGIT} -b ${COMPILERRT_BRANCH},${ARMCOMPILERRTSRCDIR})
	[ -z "${COMPILERRT_COMMIT}" ] || $(call gitcheckout,${ARMCOMPILERRTSRCDIR},${COMPILERRT_BRANCH},${COMPILERRT_COMMIT})
	$(call state,$@)

compilerrt-arm-patch: ${ARMCOMPILERRTSTATE}/compilerrt-arm-patch
${ARMCOMPILERRTSTATE}/compilerrt-arm-patch: ${ARMCOMPILERRTSTATE}/compilerrt-arm-clone
	@$(call banner,Patching Compiler-rt...)
#	@ln -sf ${ARMCOMPILERRTPATCHES} ${ARMCOMPILERRTSRCDIR}/patches
	@$(call patches_dir,${ARMCOMPILERRTPATCHES},${ARMCOMPILERRTSRCDIR}/patches)
	@$(call patch,${ARMCOMPILERRTSRCDIR})
	$(call state,$@)

compilerrt-arm-build: ${ARMCOMPILERRTSTATE}/compilerrt-arm-build
${ARMCOMPILERRTSTATE}/compilerrt-arm-build: ${ARMCOMPILERRTSTATE}/compilerrt-arm-patch
	@$(call banner,Building Compiler-rt...)
	@mkdir -p ${ARMCOMPILERRTINSTALLDIR}
	(cd ${ARMCOMPILERRTSRCDIR} && make ARMGCCHOME=${ARCH_ARM_TOOLCHAIN}/codesourcery/arm-2011.03 linux_armv7)
	@cp -r ${ARMCOMPILERRTSRCDIR}/linux_armv7/full-arm/* ${ARMCOMPILERRTINSTALLDIR}
	$(call state,$@)

compilerrt-arm-clean:
	@$(call banner,Reseting Compiler-rt...)
	@rm -rf ${ARMCOMPILERRTSRCDIR}/*
	@rm -rf ${ARMCOMPILERRTINSTALLDIR}/*
	@rm -f ${ARMCOMPILERRTSTATE}/compilerrt-arm-*

compilerrt-arm-sync: ${LLVMSTATE}/compilerrt-sync compilerrt-arm-clean compilerrt-arm-clone
	@$(call banner,Updated Compiler-rt for ARM...)
