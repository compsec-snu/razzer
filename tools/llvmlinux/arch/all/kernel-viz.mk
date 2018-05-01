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
export FILE_BASE

FILE_BASE	= ${KERNEL_BUILD}
KERNELVIZ_FILE	= ${BUILDBOTDIR}/kernelviz.tar.xz

rsync-only	= rsync -rq --include '*/' --include '${1}' --exclude '*' --prune-empty-dirs ${2}/ ${3}/
rm-only		= find ${2} -name '${1}' | xargs --no-run-if-empty rm
tarxz		= tar -cvJ -f ${1} ${2} | \
	( which pv && pv --bytes --eta --progress --rate --timer || cat ) >/dev/null

#############################################################################
ifdef KERNELVIZ
KERNEL_VAR	+= CFLAGS_KERNEL=" -mllvm -print-call-graph"
endif

#############################################################################
HELP_TARGETS	+= kernel-viz-help
kernel-viz-help:
	@echo
	@echo "These are the KernelViz make targets:"
	@echo "* make kernel-build-viz - Build clang kernel with KernelViz"
	@echo "* make kernelviz        - Start KernelViz"
	@echo "* make kernel-viz-tar   - Tar up files for KernelViz"

#############################################################################
kernel-build-viz:
	@$(call banner,Build dot files)
	@${MAKE} KERNELVIZ=1 kernel-build
	@$(call banner,Move dot files)
	@$(call rsync-only,*_.dot,${KERNELDIR},${KERNEL_BUILD})
	@$(call rm-only,*_.dot,${KERNELDIR})

#############################################################################
kernel-callgraph-new: kernel-clean kernel-build-viz

#############################################################################
kernelviz: kernel-build-viz
	@$(call makequiet,-C ${TOOLSDIR}/KernelViz FILE_BASE=${FILE_BASE})

#############################################################################
kernel-viz-tar:
	du -sk ${FILE_BASE}
	@mkdir -p $(dir ${KERNELVIZ_FILE})
	( cd $(dir ${FILE_BASE}); \
		echo $(notdir ${FILE_BASE})/vmlinux; \
		find $(notdir ${FILE_BASE}) -name \*_.dot -o -name \*.ko; \
	) | $(call tarxz,${KERNELVIZ_FILE},-C $(dir ${FILE_BASE}) -T -)
	du -sk ${FILE_BASE}
	du -sk ${FILE_BASE}

#############################################################################
ifdef KERNELVIZ_TAR
kernel-build::
	@$(call makequiet,kernel-viz-tar)
endif
