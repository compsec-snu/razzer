#!/bin/bash
##############################################################################
# Copyright (c) 2013 Behan Webster
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

set -e
CLANG=${CLANG:-clang}
OPTS=$*
OFILE=$(echo $OPTS | awk -F'-o ' '{print $2}' | cut -d' ' -f1)
if [ -n "$OFILE" ] ; then 
  EMIT=
  # These files are linked by clang command (not ld command)
  if [[ ! $OFILE =~ .*\.so\.dbg ]]; then
      EMIT='-emit-llvm'
  else
    #TODO: link into above files
    :
    EMIT=
  fi
  $CLANG $EMIT $OPTS -fno-pack-struct >/dev/null 2>&1
  if [ -f "$OFILE" ] ; then 
    BCFILE=`echo $OFILE | sed -e 's/o$/bc/'`
    file $OFILE | grep -q "LLVM IR bitcode" && mv $OFILE $BCFILE || true
  fi
fi
exec $CLANG $*
