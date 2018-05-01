##############################################################################
# Copyright {c} 2012 Mark Charlebois
#               2012 Behan Webster
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files {the "Software"}, to 
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

SDK_URL  = http://codescape-mips-sdk.imgtec.com/components/toolchain/2015.01-7/Codescape.GNU.Tools.Package.2015.01-7.for.MIPS.IMG.Linux.CentOS-5.x86_64.tar.gz
SDK_TAR  = ${notdir ${SDK_URL}}
SDK_NAME = 2015.01-7

# Set directory-related variables.
SDK_TOPDIR    = ${ARCH_MIPS_TOOLCHAIN}/codescape-sdk-img
SDK_DIR       = ${SDK_TOPDIR}/${SDK_NAME}
SDK_BINDIR    = ${SDK_DIR}/bin
SDK_TMPDIR    = ${SDK_TOPDIR}/tmp

# Set cross-compiler-related variables.
HOST                     = mips-img-linux-gnu
HOST_TRIPLE              = mips-img-linux-gnu
COMPILER_PATH            = ${SDK_DIR}
CROSS_GCC                = ${SDK_BINDIR}/${HOST}-gcc
CROSS_GDB                = ${SDK_BINDIR}/${HOST}-gdb
MIPS_CROSS_GCC_TOOLCHAIN = ${SDK_DIR}

# Add to PATH so that ${CROSS_COMPILE}${CC} is resolved.
PATH := ${SDK_BINDIR}:${PATH}

# Download the Codescape MIPS SDK archive in a temp directory.
${SDK_TMPDIR}/${SDK_TAR}:
	@mkdir -p ${SDK_TMPDIR}
	wget -c -P ${SDK_TMPDIR} "${SDK_URL}"

# Unpack the Codescape MIPS SDK archive into the appropriate directory.
${ARCH_MIPS_TOOLCHAIN_STATE}/codescape-sdk-img-${SDK_NAME}: ${SDK_TMPDIR}/${SDK_TAR}
	tar -x -z --strip-components=1 -C ${SDK_TOPDIR} -f $<
	$(call state,$@)

codescape-sdk-img mips-cc: ${ARCH_MIPS_TOOLCHAIN_STATE}/codescape-sdk-img-${SDK_NAME}

${STATEDIR}/mips-cc: ${ARCH_MIPS_TOOLCHAIN_STATE}/codescape-sdk-img-${SDK_NAME}
	$(call state,$@)

codescape-sdk-img-clean mips-cc-clean:
	@$(call banner,Removing the Codescape MIPS SDK GCC toolchain...)
	@rm -f ${STATEDIR}/mips-cc ${ARCH_MIPS_TOOLCHAIN_STATE}/codescape-sdk-img-*
	@rm -rf ${SDK_DIR} ${SDK_TMPDIR}

mips-cc-version: ${ARCH_MIPS_TOOLCHAIN_STATE}/codescape-sdk-img-${SDK_NAME}
	@${CROSS_GCC} --version | head -1

mips-cc-which: ${ARCH_MIPS_TOOLCHAIN_STATE}/codescape-sdk-img-${SDK_NAME}
	@which ${CROSS_GCC}
