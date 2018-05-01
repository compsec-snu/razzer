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

MASTER_BRANCH	?= master
MAINLINE_BRANCH	?= mainline
PUSH_BRANCH	?= $(shell date +llvmlinux-%Y.%m.%d)

REMOTE_REPO	?= ssh://git-lf@git.linuxfoundation.org/llvmlinux/kernel.git

#############################################################################
HELP_TARGETS	+= kernel-git-push-help

include ${ARCHDIR}/all/git-request-pull.mk

#############################################################################
kernel-git-push-help:
	@echo
	@echo "These are the kernel git push make targets:"
	@echo "* make kernel-git-for-linus"
	@echo "* make kernel-git-for-next"
	@echo "* make kernel-git-for-arm"
	@echo "* make kernel-git-for-aarch64"
	@echo "		Build branches based on bug triage spreadsheet"
	@echo "* make kernel-git-push-latest"
	@echo "* make kernel-git-push-mainline"
	@echo "* make kernel-git-push-for-linus"
	@echo "* make kernel-git-push-for-next"
	@echo "* make kernel-git-push-for-arm"
	@echo "* make kernel-git-push-for-aarch64"
	@echo "		Push branches to remote llvmlinux/kernel.git"

#############################################################################
kernel-git-latest: kernel-git-import-quilt-patches
kernel-git-for-linus kernel-git-for-next kernel-git-for-arm kernel-git-for-aarch64 kernel-git-for-test: kernel-git-for-%: kernel-fetch
	@$(call banner,Building for-$*)
	@$(call importprepare,for-$*)
	@${PATCHSTATUS} --for-$* -o ${TARGET_PATCH_SERIES}.for-$*
	@rm -f ${TARGET_PATCH_SERIES}.tmp
	@for PATCH in `$(call catuniq,${ALL_PATCH_SERIES})`; do \
		grep $$PATCH ${TARGET_PATCH_SERIES}.for-$* >> ${TARGET_PATCH_SERIES}.tmp || true; \
	done
	@mv ${TARGET_PATCH_SERIES}.tmp ${TARGET_PATCH_SERIES}
	@$(call git,${KERNELDIR}, quiltimport for-$*)
	@$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH})
	@$(MAKE) kernel-quilt-link-patches >/dev/null 2>&1
	
#############################################################################
ASSEMBLE_BRANCHES	= latest for-linus for-next for-arm for-aarch64
kernel-git-all:
	@$(foreach B,${ASSEMBLE_BRANCHES},$(MAKE) -j1 kernel-git-${B};)

#############################################################################
kernel-git-push-mainline:
	@$(call banner,Pushing ${TMP_BRANCH} to ${MAINLINE_BRANCH})
	@$(call gitprepare,${KERNEL_BRANCH})
	@$(call git,${KERNELDIR}, push ${REMOTE_REPO} ${KERNEL_BRANCH}:${MAINLINE_BRANCH})

#############################################################################
LLVMLINUX_BRANCHES = ${PUSH_BRANCH} ${LATEST_BRANCH} ${MASTER_BRANCH}
kernel-git-push-latest:
	@$(call banner,Pushing ${TMP_BRANCH} to ${PUSH_BRANCH})
	@$(call gitprepare,${TMP_BRANCH})
	@$(foreach B,${LLVMLINUX_BRANCHES},$(call git,${KERNELDIR}, push -f ${REMOTE_REPO} ${TMP_BRANCH}:${B});)
	@$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH})

#############################################################################
kernel-git-push-for-linus kernel-git-push-for-next kernel-git-push-for-arm kernel-git-push-for-aarch64: kernel-git-push-for-%:
	@$(call banner,Pushing for-$* to llvmlinux/for-$*)
	@$(call gitprepare,for-$*)
	$(call git,${KERNELDIR}, push -f ${REMOTE_REPO} for-$*:for-$*)
	@$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH})

#############################################################################
kernel-git-push: kernel-git-push-mainline kernel-git-push-latest

#############################################################################
ALLBRANCHES	= mainline ${ASSEMBLE_BRANCHES}
kernel-git-push-all:
	@$(foreach B,${ALLBRANCHES},$(MAKE) -j1 kernel-git-${B} kernel-git-push-${B};)
