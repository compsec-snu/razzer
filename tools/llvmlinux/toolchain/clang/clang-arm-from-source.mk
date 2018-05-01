##############################################################################
# Copyright (c) 2014 Mark Charlebois
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
#
# Based on directions from: http://llvm.org/docs/HowToCrossCompileLLVM.html
#
##############################################################################
ARMTMPDIR 	= ${LLVMTOP}/arm/tmp
ARMULIBROOT 	= ${LLVMTOP}/arm/user-libs
ARMINSTALLDIR	= ${LLVMTOP}/arm/install
ARMLIBDIRS	= -L${LLVMTOP}/arm/user-libs/usr/lib -L${LLVMTOP}/arm/user-libs/usr/lib -L${LLVMTOP}/arm/user-libs/lib -L${LLVMTOP}/arm/user-libs/lib
ARMINCLUDEDIR	= ${LLVMTOP}/arm/user-libs/usr/include
ARMLLVMBUILDDIR	= ${LLVMTOP}/arm/build/llvm
ARMCLANGBUILDDIR	= ${LLVMTOP}/arm/build/clang
LLVMBINDIR	= ${TOOLCHAINTOP}/build/llvm/bin
CLANGBINDIR	= ${TOOLCHAINTOP}/build/clang/bin

DEBDEP += ninja-build gcc-4.8-arm-linux-gnueabihf \
	gcc-4.8-multilib-arm-linux-gnueabihf binutils-arm-linux-gnueabihf \
	libgcc1-armhf-cross libsfgcc1-armhf-cross libstdc++6-armhf-cross \
	libstdc++-4.8-dev-armhf-cross g++-4.8-arm-linux-gnueabihf

include ${LLVMTOP}/clang-from-source.mk

llvm-arm: ${LLVMSTATE}/llvm-arm-build 
${LLVMSTATE}/llvm-arm-build: ${LLVMSTATE}/clang-build
	$(shell mkdir -p ${ARMINSTALLDIR})
	$(shell mkdir -p ${ARMLLVMBUILDDIR})
	$(call assert,-d ${ARMLIBDIR},"missing ARMLIBDIR")
	$(call assert,-d ${ARMINCLUDEDIR},"missing ARMINCLUDEDIR")
	cd ${ARMLLVMBUILDDIR} && CC=arm-linux-gnueabihf-gcc CXX=arm-linux-gnueabihf-g++-4.8 cmake -G Ninja ${TOOLCHAINTOP}/src/llvm -DCMAKE_CROSSCOMPILING=True \
		-DCMAKE_INSTALL_PREFIX=${ARMINSTALLDIR} \
		-DLLVM_TABLEGEN=${LLVMBINDIR}/llvm-tblgen \
		-DLLVM_DEFAULT_TARGET_TRIPLE=arm-linux-gnueabihf \
		-DLLVM_TARGET_ARCH=ARM \
		-DLLVM_TARGETS_TO_BUILD=ARM \
		-DCMAKE_CXX_FLAGS='-mcpu=cortex-a9 -I/usr/arm-linux-gnueabihf/include/c++/4.8.1/arm-linux-gnueabihf/ -I/usr/arm-linux-gnueabihf/include/ -I${ARMINCLUDEDIR} -mfloat-abi=hard'
	@cd ${ARMLLVMBUILDDIR} && ninja
	@cd ${ARMLLVMBUILDDIR} && ninja install
	$(call state,$@)

HELP_TARGETS	+= clang-arm-help
##############################################################################
clang-arm-help:
	@echo
	@echo "These are the make targets for building LLVM and Clang for ARM:"
	@echo "* make clang-arm - cross compile clang (and LLVM) for armhf"
	@echo "* make arm-clang-dep-install-deb - install the required packages"

##############################################################################
clang-arm: ${LLVMSTATE}/clang-arm-build 
${LLVMSTATE}/clang-arm-build: ${LLVMSTATE}/clang-build ${LLVMSTATE}/llvm-arm-build \
		build-dep-check clang-arm-user-libs
	$(shell mkdir -p ${ARMCLANGBUILDDIR})
	cd ${ARMCLANGBUILDDIR} && CC=arm-linux-gnueabihf-gcc CXX=arm-linux-gnueabihf-g++-4.8 cmake -G Ninja ${TOOLCHAINTOP}/src/clang -DCMAKE_CROSSCOMPILING=True \
		-DCMAKE_INSTALL_PREFIX=${ARMINSTALLDIR} \
		-DCLANG_TABLEGEN=${CLANGBINDIR}/clang-tblgen \
		-DLLVM_TARGETS_TO_BUILD=ARM \
		-DLLVM_LIBRARY_DIR=${ARMINSTALLDIR}/lib \
		-DLLVM_MAIN_INCLUDE_DIR=${ARMINSTALLDIR}/include \
		-DLIBXML2_INCLUDE_DIR=${LLVMTOP}/arm/user-libs/usr/include \
		-DLIBXML2_LIBRARIES=${LLVMTOP}/arm/user-libs/usr/lib/libxml2.a \
		-DLLVM_CONFIG=${LLVMTOP}/arm/llvm-config \
		-DLLVM_TABLEGEN_EXE=${LLVMBINDIR}/llvm-tblgen \
		-DCMAKE_CXX_FLAGS='-mcpu=cortex-a9 -I/usr/arm-linux-gnueabihf/include/c++/4.8.1/arm-linux-gnueabihf/ -I/usr/arm-linux-gnueabihf/include/ -I${ARMINSTALLDIR}/include -L${ARMINSTALLDIR}/lib -I${ARMINCLUDEDIR} -mfloat-abi=hard'
	@cd ${ARMCLANGBUILDDIR} && ninja
	@cd ${ARMCLANGBUILDDIR} && ninja install
	$(call state,$@)

ARM_LIBXML_URL	= ftp://ftp.arm.slackware.com/slackwarearm/slackwarearm-14.1/slackware/l/libxml2-2.9.1-arm-1.tgz
ARM_LIBXML	= $(call shared,${ARMTMPDIR}/libxml2-2.9.1-arm-1.tgz)

${ARM_LIBXML}:
	@$(call wget,${ARM_LIBXML_URL},$(dir $@))

clang-arm-user-libs: ${ARM_LIBXML}
	@mkdir -p ${ARMULIBROOT}
	(cd ${ARMULIBROOT} && tar xvzf ${ARM_LIBXML})

