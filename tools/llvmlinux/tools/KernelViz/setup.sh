#!/bin/bash
##############################################################################
# Copyright (c) 2014 Mark Charlebois
#
# All rights reserved. 
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted (subject to the limitations in the disclaimer
# below) provided that the following conditions are met:
# 
# * Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
#  
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
# 
# * Neither the name KernelViz nor the names of its contributors may be used
#   to endorse or promote products derived from this software without 
#   specific prior written permission.
# 
# NO EXPRESS OR IMPLIED LICENSES TO ANY PARTY'S PATENT RIGHTS ARE GRANTED BY
# THIS LICENSE. THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT
# NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
# PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
##############################################################################

[ -d node_modules/string ] || npm install string
[ -d node_modules/node-dir ] || npm install node-dir
[ -d node_modules/graphlib ] || npm install graphlib
[ -d node_modules/graphlib-dot ] || npm install graphlib-dot@0.4.10
[ -d node_modules/object-keys ] || npm install object-keys
[ -d node_modules/path ] || npm install path

# Set these to the locations on your system
TARGET=vexpress
export FILE_BASE=../../targets/${TARGET}/build/kernel-clang

# Get the data from the dot files
rm -f tmp/defined_symbols
nodejs ReadDotFiles.js ${FILE_BASE}
nodejs ReadSymbols.js ${FILE_BASE} `cat ${FILE_BASE}/callgraph_srcdir`
nodejs Resolve.js
nodejs TopView.js

echo
echo "Ready to go..."
echo "Run: nodejs KernelViz.js"
