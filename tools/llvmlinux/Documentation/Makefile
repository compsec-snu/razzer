##############################################################################
# Copyright (c) 2012 Behan Webster
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
# This make file is used for documentation file maintenance.
# Some of the documents are generated from the code

DEFAULT_TARGET	= vexpress

all: help

help:
	@echo "Document maintenance targets:"
	@echo "  make update_docs"

update_docs: make_targets

make_targets:
	@(echo "= Make targets for ${DEFAULT_TARGET} =" ; \
	echo ; \
	echo "Other build targets have similar make targets. You can get the following with:" ; \
	echo ; \
 	echo " make -C targets/${DEFAULT_TARGET} help" ; \
	echo ; \
	make -C ../targets/${DEFAULT_TARGET} help | grep -v '^make\[' ; \
	) > $@.txt

