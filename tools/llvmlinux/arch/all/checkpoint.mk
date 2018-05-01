##############################################################################
# Copyright (c) 2013 Behan Webster
#               2013 Jan-Simon Möller
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

export CHECKPOINT

# Need to set CHECKPOINT before invoking this target
# CHECKPOINT		= some name
CHECKPOINT_TOPDIR	= ${TARGETDIR}/checkpoints
CHECKPOINT_DIR		= ${CHECKPOINT_TOPDIR}/${CHECKPOINT}
CHECKPOINT_CONFIG	= ${CHECKPOINT_DIR}/config.mk
CHECKPOINT_MAKEFILE	= ${CHECKPOINT_DIR}/Makefile
CHECKPOINT_PATCHES	= ${CHECKPOINT_DIR}/patches

HELP_TARGETS		+= checkpoint-help
SETTINGS_TARGETS	+= checkpoint-settings

checkpoint-patches = mkdir -p ${2}\
	&& ( cd ${1} && tar -c -h -f - series `cat series` \
	| tar -C ${2} -x -f - )

#############################################################################
checkpoint-help:
	@echo
	@echo "These are the checkpoint make targets:"
	@echo "* make CHECKPOINT=<name> checkpoint   Build a checkpoint named <name>"

#############################################################################
checkpoint-settings:
	@[ -z "${CHECKPOINT}" ] \
		|| ($(call prsetting,CHECKPOINT,${CHECKPOINT}) ; \
		) | $(call configfilter)

##############################################################################
checkpoint-check:
	@$(call assert,-n "${CHECKPOINT}",Did not specify a CHECKPOINT name)

##############################################################################
checkpoint-dir: ${CHECKPOINT_DIR}
${CHECKPOINT_DIR}: checkpoint-check
	@mkdir -p $@ ${CHECKPOINT_PATCHES}

##############################################################################
checkpoint-config: ${CHECKPOINT_CONFIG}
${CHECKPOINT_CONFIG}: ${CHECKPOINT_DIR}
	@$(MAKE) list-config | egrep -v '^$$|^make|^LLVMLINUX_COMMIT' > $@
	@(echo "# Extras"; \
	$(call prsetting,GENERIC_PATCH_DIR,\$${KERNEL_PATCH_DIR}) ; \
	$(call prsetting,ALL_PATCH_SERIES,\$${GENERIC_PATCH_SERIES}) ; \
		) | $(call configfilter) >> $@

##############################################################################
checkpoint-makefile: ${CHECKPOINT_MAKEFILE}
${CHECKPOINT_MAKEFILE}: ${CHECKPOINT_CONFIG}
	@head -22 ${TOPDIR}/arch/all/checkpoint.mk > $@
	@printf '\nCONFIG = ${CHECKPOINT_CONFIG}\n' \
		| sed 's|${CHECKPOINT_TOPDIR}|$${CHECKPOINT_TOPDIR}|' >> $@
	@printf '\ndefault: all\n' >> $@
	@printf '\n%%:\n\t$$(MAKE) CONFIG=`pwd`/config.mk -C ../.. $$*\n' >> $@

##############################################################################
CHECKPOINT_TARGETS	:= checkpoint-makefile
checkpoint:
	$(MAKE) ${CHECKPOINT_TARGETS}
	@$(call banner,Created CHECKPOINT=${CHECKPOINT} in ${CHECKPOINT_DIR})

##############################################################################
list-checkpoint: checkpoint-check
	@echo ${CHECKPOINT_TARGETS}
#	$(MAKE) -n checkpoint
	
