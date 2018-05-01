##############################################################################
# Copyright (c) 2014 Mark Charlebois
#               2014 Behan Webster
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

TOPDIR = $(realpath ../..)

all: kernelviz

include ../../common.mk 

# Set these to the locations on your system
TARGET=vexpress64
FILE_BASE=${BUILDROOT}/targets/${TARGET}/build/kernel-clang

export FILE_BASE

node_modules: 
	-[ -d node_modules/string ] || npm install string
	-[ -d node_modules/node-dir ] || npm install node-dir
	-[ -d node_modules/graphlib ] || npm install graphlib
	-[ -d node_modules/graphlib-dot ] || npm install graphlib-dot@0.4.10
	-[ -d node_modules/object-keys ] || npm install object-keys
	-[ -d node_modules/path ] || npm install path

data/Modules.json: ReadDotFiles.js node_modules
	nodejs $< ${FILE_BASE}

data/Symbols.json: ReadSymbols.js node_modules
	rm -f tmp/defined_symbols
	nodejs $< ${FILE_BASE} `cat ${FILE_BASE}/callgraph_srcdir`

data/ModulesResolved.json: Resolve.js node_modules data/Modules.json data/Symbols.json
	nodejs $<

data/TopViewFG.json: TopView.js node_modules data/ModulesResolved.json
	nodejs $<

database: data/ModulesResolved.json data/TopViewFG.json

kernelviz: database
	@echo "Open your browser to http://localhost:8001"
	nodejs KernelViz.js
