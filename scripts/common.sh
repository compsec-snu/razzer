#!/bin/bash -e

printenv() {
echo -----------------------------------------------------------------------
echo "Setting environment for $1"
echo
  for ENV in $2; do
    echo "$ENV = ${!ENV} " | column -t
  done
echo -----------------------------------------------------------------------
}

DIR=$(dirname $BASH_SOURCE)
export SCRIPT_HOME=$(realpath $DIR)
export PROJECT_HOME=$(realpath $DIR/../)
export TOOLS_HOME=$(realpath $PROJECT_HOME/tools/)

# tools
export SVF_HOME=$TOOLS_HOME/SVF
export LLVMLINUX_HOME=$TOOLS_HOME/llvmlinux
export SYZKALLER_HOME=$TOOLS_HOME/race-syzkaller
export QEMU_HOME=$TOOLS_HOME/qemu-2.5.0

# toolchains
export TOOLCHAINS_HOME=$PROJECT_HOME/toolchains
mkdir -p $TOOLCHAINS_HOME
export GO_HOME=$TOOLCHAINS_HOME/GO-1.8.1
export GCC_HOME=$TOOLCHAINS_HOME/gcc-7.3.0
export LLVM_HOME=$TOOLCHAINS_HOME/llvm-4.0.0
export LLVM5_HOME=$TOOLCHAINS_HOME/llvm-5.0.1
export GDB_HOME=$TOOLCHAINS_HOME/gdb-8.1
export CAPSTONE_HOME=$TOOLCHAINS_HOME/capstone-3.0.5-rc2
