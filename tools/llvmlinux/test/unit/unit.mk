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

# Designed to be included from ../test.mk

UNIT_TESTS	= aligned-attribute isystem kbuild-scripts vlais

TARGETS		+= unit-tests
CLEAN_TARGETS	+= unit-tests-clean
HELP_TARGETS	+= unit-tests-help
MRPROPER_TARGETS+= unit-tests-clean

unit-tests-help:
	@echo
	@echo "These are the generic make targets for unit tests targets:"
	@echo "* make unit-tests       - Run all the unit tests (in test/unit/*)"

unit-tests:
	@for TEST in ${UNIT_TESTS} ; do \
		echo "# $$TEST test cases (build/run)" ; \
		$(MAKE) --silent -C "${UNITDIR}/$$TEST" ; \
	done

unit-tests-clean: unit-tests-%:
	@for TEST in ${UNIT_TESTS} ; do \
		echo "# $$TEST test cases ($*)" ; \
		$(MAKE) --silent -C "${UNITDIR}/$$TEST" $* ; \
	done
