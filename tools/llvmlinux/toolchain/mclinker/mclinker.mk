##############################################################################
# Copyright (c) 2014 Mark Charlebois
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

# Assumes has been included from target/foo/Makefile after the ARCH include

#mclinker-deps:
DEBDEP		+= subversion 

MCLINKERSTATE	= ${MCLINKERTOP}/state
MCLINKER_SRC	= ${MCLINKERTOP}/src/mclinker
MCLINKER_BUILD	= ${MCLINKERTOP}/build/mclinker
MCLINKER_INSTALL= ${MCLINKERTOP}/install/mclinker
MCLLLVM_SRC	= ${MCLINKERTOP}/src/llvm
MCLLLVM_BUILD	= ${MCLINKERTOP}/build/llvm
MCLLLVM_INSTALL = ${MCLINKERTOP}/install/llvm
MCLLLVM_COMMIT	= "212505"

PATH		:= ${MCLINKER_INSTALL}/bin:${PATH}

mclinker-llvm-fetch: ${MCLINKERSTATE}/mclinker-llvm-fetch
${MCLINKERSTATE}/mclinker-llvm-fetch:
	mkdir -p ${MCLINKERTOP}/src
	(cd ${MCLINKERTOP}/src; svn co -r ${MCLLLVM_COMMIT} http://llvm.org/svn/llvm-project/llvm/trunk llvm)
	$(call state,$@,mclinker-llvm-configure)

mclinker-llvm-configure: ${MCLINKERSTATE}/mclinker-llvm-configure
${MCLINKERSTATE}/mclinker-llvm-configure: ${MCLINKERSTATE}/mclinker-llvm-fetch
	mkdir -p ${MCLLLVM_BUILD}
	(cd ${MCLLLVM_BUILD}; ${MCLLLVM_SRC}/configure --prefix=${MCLLLVM_INSTALL} CC="clang" CXX="clang++ -stdlib=libstdc++")
	$(call state,$@,mclinker-llvm-build)

mclinker-llvm-build: ${MCLINKERSTATE}/mclinker-llvm-build
${MCLINKERSTATE}/mclinker-llvm-build: ${MCLINKERSTATE}/mclinker-llvm-configure
	(cd ${MCLLLVM_BUILD}; make all install)
	$(call state,$@)

mclinker-fetch: ${MCLINKERSTATE}/mclinker-fetch
${MCLINKERSTATE}/mclinker-fetch: 
	mkdir -p ${MCLINKERTOP}/src
	(cd ${MCLINKERTOP}/src; git clone https://code.google.com/p/mclinker)
	$(call state,$@,mclinker-patch)

mclinker-patch: ${MCLINKERSTATE}/mclinker-patch
${MCLINKERSTATE}/mclinker-patch: ${MCLINKERSTATE}/mclinker-fetch
	(cd ${MCLINKERTOP}/src/mclinker; patch -p1 < ${MCLINKERTOP}/patches/compare-bug.patch)
	$(call state,$@,mclinker-configure)

mclinker-configure: ${MCLINKERSTATE}/mclinker-llvm-build ${MCLINKERSTATE}/mclinker-configure
${MCLINKERSTATE}/mclinker-configure: ${MCLINKERSTATE}/mclinker-llvm-build ${MCLINKERSTATE}/mclinker-patch
	mkdir -p ${MCLINKER_SRC}
	(cd ${MCLINKER_SRC}; ./autogen.sh)
	mkdir -p ${MCLINKER_BUILD}
	(cd ${MCLINKER_BUILD}; ${MCLINKER_SRC}/configure --prefix=${MCLINKER_INSTALL} --with-llvm-config=${MCLLLVM_INSTALL}/bin/llvm-config CC="clang" CXX="clang++ -stdlib=libstdc++ -Wno-c99-extensions -Wno-deprecated-register")
	find ${MCLINKER_BUILD} -name Makefile | xargs sed -i -e s/-Wno-maybe-uninitialized//g
	$(call state,$@,mclinker-build)

mclinker-build: ${MCLINKERSTATE}/mclinker-build
${MCLINKERSTATE}/mclinker-build: ${MCLINKERSTATE}/mclinker-configure
	(cd ${MCLINKER_BUILD}; make -j10 && make install)
	$(call state,$@)

mclinker-symlink: ${MCLINKER_INSTALL}/bin/${CROSS_COMPILE}ld
${MCLINKER_INSTALL}/bin/${CROSS_COMPILE}ld:
	[ ! -L $@ ] && ln -s ${MCLINKER_INSTALL}/bin/ld.mcld $@

mclinker-clean:
	-rm -r ${MCLINKER_SRC}
	-rm -r ${MCLINKER_BUILD} 
	-rm -r ${MCLINKER_INSTALL}
	-rm ${MCLINKERSTATE}/mclinker-fetch
	-rm ${MCLINKERSTATE}/mclinker-patch
	-rm ${MCLINKERSTATE}/mclinker-configure
	-rm ${MCLINKERSTATE}/mclinker-build
