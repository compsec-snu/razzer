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
export USE_CCACHE CCACHE_COMPRESS CCACHE_CPP2 CCACHE_DIR

PAGER		= less

ifeq "${USE_CCACHE}" "1"
CCACHE		?= ccache
CCACHE_COMPRESS	?= true
CCACHE_CPP2	?= true
CCACHE_ROOT	?= ${BUILDROOT}
CCACHE_DIR	= $(subst ${TOPDIR},${CCACHE_ROOT},${BUILDDIR})/ccache
#CCACHE_CLANG_OPTS = -fcolor-diagnostics
CCACHE_DIRS	+= ${CCACHE_DIR}
endif

foreach_ccache	= for C in ${CCACHE_DIRS}; do $(call banner,$$C); (CCACHE_DIR=$$C $(1)); done

#############################################################################
ccache-clean:
	@$(call foreach_ccache,ccache --cleanup)

#############################################################################
ccache-mrproper:
	@$(call foreach_ccache,ccache --clear)

#############################################################################
ccache-raze:
	@$(call foreach_ccache,rm -rf $$C)

#############################################################################
ccache-stats:
	@$(call foreach_ccache,ccache --show-stats) | ${PAGER}

#############################################################################
list-ccache-dir::
	@$(call echovar,CCACHE_DIR)
	@$(call echovar,CCACHE_ROOT)
