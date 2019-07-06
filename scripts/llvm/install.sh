#!/bin/bash -e

PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

LLVM_DIR=$LLVM_HOME
CLANG_DIR=$LLVM_HOME/tools/clang
LLD_DIR=$LLVM_HOME/tools/lld

LLVM_URL='http://llvm.org/releases/4.0.0/llvm-4.0.0.src.tar.xz'
CLANG_URL='http://llvm.org/releases/4.0.0/cfe-4.0.0.src.tar.xz'
LLD_URL='http://releases.llvm.org/4.0.0/lld-4.0.0.src.tar.xz'

echo "LLVM_DIR:" $LLVM_DIR

if [ -d "$LLVM_DIR" ]; then
    echo $LLVM_DIR exist
    exit
fi

TEMP_DIR=$PROJECT_DIR/tmp
mkdir $TEMP_DIR
pushd $TEMP_DIR > /dev/null
    # install LLVM/Clang-4.0.0
    
    wget $LLVM_URL -O llvm.tar.xz
    wget $CLANG_URL -O clang.tar.xz
    wget $LLD_URL -O lld.tar.xz

    tar xf llvm.tar.xz
    tar xf clang.tar.xz
    tar xf lld.tar.xz

    mv llvm-4.0.0.src $LLVM_DIR
    mv cfe-4.0.0.src $CLANG_DIR
    mv lld-4.0.0.src $LLD_DIR
# I assume that I can always delete tmp/temp directories
popd > /dev/null
rm -rf $TEMP_DIR

pushd $LLVM_DIR > /dev/null
mkdir build
pushd build > /dev/null

cmake -DLLVM_TARGETS_TO_BUILD=X86 \
      -DLLVM_ENABLE_ASSERTIONS=On \
      -DCMAKE_BUILD_TYPE=RelWithDebInfo \
      ../

make -j`nproc`
popd > /dev/null
popd > /dev/null
