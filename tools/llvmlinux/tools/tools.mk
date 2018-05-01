##############################################################################
# Copyright (c) 2012 Mark Charlebois
#               2012 Jan-Simon Möller
#               2012 Behan Webster
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

# Assumes has been included from ../common.mk

PATH	:= ${PATH}:${TOOLSDIR}

PATCHSTATUS = ${TOOLSDIR}/patchstatus
patch_series_stats = ${PATCHSTATUS} --stats `egrep -v '^\#' $(1)/series`
patch_series_status = ${PATCHSTATUS} `egrep -v '^\#' $(1)/series`
patch_series_status_leftover = ${PATCHSTATUS} --left-over `egrep -v '^\#' $(1)/series`

PATCHSTATUSEXTRACT = ${TOOLSDIR}/patchstatusextract
patch_status_extract = ${PATCHSTATUSEXTRACT} '$(1)' '$(2)' `egrep -v '^\#' $(3)/series`
