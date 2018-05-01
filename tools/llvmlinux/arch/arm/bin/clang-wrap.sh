#!/bin/bash

CWD=`dirname $0`
TOPDIR=`readlink -f ${CWD}/../../../`
CLANG=${TOPDIR}/toolchain/clang/install/bin/clang

# CODESORCERY SETTINGS
HOST_TRIPLE=arm-none-linux-gnueabi
ARMGCC_DIR=${TOPDIR}/arch/arm/toolchain/codesourcery/arm-2013.05
ARMGCC=${TOPDIR}/arch/arm/toolchain/codesourcery/arm-2013.05/bin/${HOST_TRIPLE}-gcc
[ ! -f ${ARMGCC} ] && echo "codesourcery arm-2013.05 compiler not installed" && exit 1
ARMGCCSYSROOT=`${ARMGCC} -print-sysroot`


CLANGFLAGS="-march=armv7-a -mfloat-abi=softfp -mfpu=neon -fsanitize=undefined-trap -fsanitize-undefined-trap-on-error"

CC="${CLANG} -target ${HOST_TRIPLE} -gcc-toolchain ${ARM_GCC_DIR} --sysroot=${ARMGCCSYSROOT} ${CLANGFLAGS}"

${CC} $*
