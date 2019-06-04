#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

echo "QEMU_HOME:" $QEMU_HOME
pushd $QEMU_HOME>/dev/null

mkdir build
pushd build

# This is just placehold. Actual HYPEADDR will be filled when executing exp.sh
HYPEADDR='0x0'

../configure --target-list=x86_64-softmmu --cc=$GCC_HOME/install/bin/gcc --cxx=$GCC_HOME/install/bin/g++

CC=$GCC_HOME/install/bin/gcc CFLAGS="-D_HYPERCALL_ADDR=$HYPEADDR" make -j`nproc`

popd
popd>/dev/null
