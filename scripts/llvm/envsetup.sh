#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

LLVM_BUILD=$LLVM_HOME/build

export LLVM_SRC=$LLVM_HOME
export LLVM_OBJ=$LLVM_BUILD
export LLVM_DIR=$LLVM_BUILD
export PATH=$LLVM_DIR/bin:$PATH

printenv 'llvm' 'LLVM_SRC LLVM_OBJ LLVM_DIR'
