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


#############################################################################
HELP_TARGETS	+= kernel-git-request-pull-help

#############################################################################
kernel-git-request-pull-help:
	@echo
	@echo "These are the kernel git request pull make targets:"
	@echo "* make kernel-git-request-pull"
	@echo "   options:"
	@echo "    REQUEST_BRANCH=for-linus  Branch from which git pull request will be made"

#############################################################################
REQUEST_BRANCH	= for-linus
REQUEST_VER	=
REQUEST_TEXT	= LLVMLinux patches for ${REQUEST_VER}
REQUEST_TAG	= llvmlinux-for-${REQUEST_VER}
REQUEST_REMOTE  = lfgit
REQUEST_REPO_URI= git://git.linuxfoundation.org/llvmlinux/kernel.git
REQUEST_FILE	= msg.txt

REQUEST_PATCHES	= ALL_PATCH_SERIES=${TARGET_PATCH_SERIES}.${REQUEST_BRANCH}

#############################################################################
#email_addresses2 = (cd ${KERNELDIR} ; \
#	./scripts/get_maintainer.pl ${1}; \
#	./scripts/get_maintainer.pl ${1} | while read ENTRY; do \
#		case "$$ENTRY" in \
#			*maintainer*) echo "--to-maintainer $$ENTRY";; \
#			*authored*) echo "--to-author $$ENTRY";; \
#			*list*) echo "--cc-list $$ENTRY";; \
#			*) echo --bcc $$ENTRY;; \
#		esac; \
#	done \
#	| sed -e 's/ .*</ /g; s/>.*//g; s/ (.*)//g' | sort)

#############################################################################
#kernel-git-request-pull-get_maintainers: kernel-fetch
#	@[ -n "$$PATCH_LIST" ] || PATCH_LIST=`$(call catuniq,${ALL_PATCH_SERIES}) | grep "${PATCH_FILTER_REGEX}"`; \
#	PATCH_LIST=`for PATCH in $$PATCH_LIST; do echo patches/$$PATCH; done`; \
#	$(call email_addresses2,$$PATCH_LIST)

#############################################################################
kernel-git-request-pull:
	@$(call assert,-n "${REQUEST_VER}",Need to set REQUEST_VER=v3.x\\n Example: make REQUEST_VER=v3.16 $@)
	@$(call banner,Generating Kernel Git Pull Request)
# Build request branch
	-@$(call makequiet,kernel-git-${REQUEST_BRANCH})
# Check patches to be sure
	@$(call makequiet,${REQUEST_PATCHES} kernel-git-submit-patch-check)
# Checkout request branch
	@$(call banner,Checkout git request branch)
	@$(call unpatch,${KERNELDIR})
	@$(call leavestate,${STATEDIR},kernel-patch)
	@$(call gitcheckout,${KERNELDIR},${REQUEST_BRANCH})
# Create signed tag for REUQEST_BRANCH
	@$(call banner,Signing request branch)
	@$(call git,${KERNELDIR},tag --sign ${GPG_OPTS} --force --message="${REQUEST_TEXT}" ${REQUEST_TAG} ${REUQEST_BRANCH})
# Push tag to remote repo
	@$(call banner,Push request branch)
	@if [ -z "${DRYRUN}" ] ; then \
		$(call makequiet,kernel-git-push-for-linus); \
		$(call git,${KERNELDIR},push ${REQUEST_REMOTE} +${REQUEST_TAG}); \
	else \
		echo "$(call git,${KERNELDIR},push ${REQUEST_REMOTE} +${REQUEST_TAG})"; \
	fi
# Build To/Cc list
	@$(call banner,Build git pull request email)
	@$(call makequiet,${REQUEST_PATCHES} kernel-git-submit-patch-get_maintainers) > ${TMPDIR}/to.txt
# Build request-pull message
	-@(echo Cc: $$(awk '/--/ {print $$2","}' ${TMPDIR}/to.txt) | sed -e 's/,$$//'; \
	echo; \
	$(call git,${KERNELDIR},request-pull master ${REQUEST_REPO_URI} ${REQUEST_TAG}); \
	) > ${TARGETDIR}/${REQUEST_FILE}
	@$(call banner,Created ${REQUEST_FILE})
# Checkout build branch
	@$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH})

