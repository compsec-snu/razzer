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

LATEST_BRANCH	?= llvmlinux-latest
TMP_BRANCH	?= ${LATEST_BRANCH}

#############################################################################
HELP_TARGETS   += kernel-git-quilt-help

#############################################################################
kernel-git-quilt-help:
	@echo
	@echo "These are the kernel git/quilt make targets:"
	@echo "* make kernel-git-import-quilt-patches  Import quilt patches into kernel git"
	@echo "* make kernel-quilt-import-git-patches  Export kernel git patches back into quilt"
	@echo "* make kernel-git-quilt-roundtrip       Send patches to git, then back to quilt (formatting)"

importprepare	= ($(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH}) ; \
		$(call git,${KERNELDIR}, pull) ; \
		$(call unpatch,${KERNELDIR}) ; \
		$(call leavestate,${STATEDIR},kernel-patch) ; \
		$(call gitabort,${KERNELDIR}) || true ; \
		$(call git,${KERNELDIR}, branch -D ${1}) || true ; \
		$(call gitcheckout,${KERNELDIR},-b ${1}) ; \
		$(call gitabort,${KERNELDIR}) || true ; \
		${MAKE} kernel-quilt-link-patches ; \
		) >/dev/null 2>&1

gitprepare	= ($(call unpatch,${KERNELDIR}); \
		$(call leavestate,${STATEDIR},kernel-patch) ; \
		$(call gitcheckout,${KERNELDIR},${1})) >/dev/null 2>&1

#############################################################################
kernel-git-import-quilt-patches: kernel-fetch
	@$(call banner,Importing quilt patch series into git branch: ${TMP_BRANCH}...)
	@$(call importprepare,${TMP_BRANCH})
	@$(call git,${KERNELDIR}, quiltimport ${TMP_BRANCH})
	@$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH})

#############################################################################
kernel-git-export-patches:
	@$(call banner,Exporting quilt patch series from git branch: ${TMP_BRANCH}...)
	@$(call gitprepare,${TMP_BRANCH})
	@$(call git,${KERNELDIR}, format-patch --find-renames --find-copies --no-numbered ${KERNEL_BRANCH})
	@$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH})

#############################################################################
kernel-quilt-rename-patches:
	@$(call banner,Renaming quilt patch series from git back to original patch names...)
	@(cd $(KERNELDIR); \
	for NEWPATCH in 0*.patch; do \
		[ "$$NEWPATCH" = '0*.patch' ] && exit 0; \
		FILE=""; SAMENESS=99999; \
		for OLDPATCH in `cat patches/series` ; do \
			SCORE=`diff --suppress-common-lines $$NEWPATCH patches/$$OLDPATCH | wc -l`; \
			if [ $$SCORE -lt $$SAMENESS ] ; then \
				FILE=patches/$$OLDPATCH; SAMENESS=$$SCORE; \
			fi ; \
		done ; \
		if [ -n "$$FILE" ] ; then \
			mv $$NEWPATCH $$FILE; \
		else \
			echo "$$NEWPATCH is a new patch, and needs to be added to quilt manually"; \
		fi ; \
	done)

#############################################################################
kernel-quilt-fix-unchanged-patches:
	@for PATCH in `git status | sed -e 's/^#//' | awk '/modified:.*\.patch/ {print $$2}'`; do \
		CHANGED=`GIT_EXTERNAL_DIFF=${TOOLSDIR}/patchdiff git diff $$PATCH 2>/dev/null | wc -l`; \
		if [ $$CHANGED -eq 0 ] ; then \
			git checkout $$PATCH; \
		else \
			echo "modified: $$PATCH"; \
		fi ; \
	done

#############################################################################
kernel-quilt-import-git-patches: kernel-git-export-patches
	@$(MAKE) kernel-quilt-rename-patches
	@$(MAKE) kernel-quilt-link-patches >/dev/null 2>&1
	@$(MAKE) kernel-quilt-fix-unchanged-patches
	@$(call banner,Patches successfully sent through git back to quilt series)

#############################################################################
kernel-git-quilt-roundtrip: kernel-git-import-quilt-patches kernel-quilt-import-git-patches

#############################################################################
kernel-git-quilt-delete-branch:
	@$(call banner,Deleting git branch: ${TMP_BRANCH}...)
	@$(call git,${KERNELDIR}, branch -D ${TMP_BRANCH})

