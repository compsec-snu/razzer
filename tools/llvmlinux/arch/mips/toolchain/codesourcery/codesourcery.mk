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

# Note: use CROSS_MIPS_TOOLCHAIN=codesourcery to include this file

CSCC_URL  = https://sourcery.mentor.com/GNUToolchain/package12797/public/mips-linux-gnu/mips-2014.05-27-mips-linux-gnu-i686-pc-linux-gnu.tar.bz2
CSCC_NAME = mips-2014.05
CSCC_TAR	= ${notdir ${CSCC_URL}}
CSCC_TOPDIR	= ${ARCH_MIPS_TOOLCHAIN}/codesourcery
CSCC_TMPDIR	= ${CSCC_TOPDIR}/tmp

HOST            = mips-linux-gnu
CSCC_DIR	= ${CSCC_TOPDIR}/${CSCC_NAME}
CSCC_BINDIR	= ${CSCC_DIR}/bin
HOST_TRIPLE     = mips-linux-gnu
COMPILER_PATH	= ${CSCC_DIR}
CROSS_GCC	= ${CSCC_BINDIR}/${HOST}-gcc
CROSS_GDB	= ${CSCC_BINDIR}/${HOST}-gdb

MIPS_CROSS_GCC_TOOLCHAIN = ${CSCC_DIR}

# Add path so that ${CROSS_COMPILE}${CC} is resolved
PATH           := ${CSCC_BINDIR}:${PATH}

# Get MIPS cross compiler
${CSCC_TMPDIR}/${CSCC_TAR}:
	@mkdir -p ${CSCC_TMPDIR}
	wget -c -P ${CSCC_TMPDIR} "${CSCC_URL}"

CROSS_GCC=${CSCC_BINDIR}/${CROSS_COMPILE}gcc
codesourcery-gcc mips-cc: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}: ${CSCC_TMPDIR}/${CSCC_TAR}
	tar -x -j -C ${CSCC_TOPDIR} -f $<
	$(call state,$@)

${CSCC_DIR}/bin/mips-ar: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/mips-linux-gnu-ar $@)

${CSCC_DIR}/bin/mips-as: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/mips-linux-gnu-as $@)

${CSCC_DIR}/bin/mips-strip: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/mips-linux-gnu-strip $@)

${CSCC_DIR}/bin/mips-ranlib: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/mips-linux-gnu-ranlib $@)

${CSCC_DIR}/bin/mips-ld: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	(cd ${CSCC_DIR} && ln -s ${CSCC_CC_BINDIR}/mips-linux-gnu-ld $@)

state/mips-cc: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	$(call state,$@)
	
codesourcery-gcc-clean mips-cc-clean:
	@$(call banner,Removing Codesourcery compiler...)
	@rm -f state/mips-cc ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-*
	@rm -rf ${CSCC_DIR} ${CSCC_TMPDIR}

mips-cc-version: ${ARCH_MIPS_TOOLCHAIN_STATE}/codesourcery-gcc-${CSCC_NAME}
	@${CROSS_GCC} --version | head -1

${ARCH_MIPS_TMPDIR}:
	@mkdir -p $@
