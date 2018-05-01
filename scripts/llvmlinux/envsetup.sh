#!/bin/bash -e

PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

export CLANG_TOOLCHAIN=native

printenv 'llvmlinux' 'CLANG_TOOLCHAIN'
