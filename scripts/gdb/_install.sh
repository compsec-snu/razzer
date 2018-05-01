#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

echo "GDB_HOME:" $GDB_HOME

pushd $GDB_HOME/.. > /dev/null
wget https://ftp.gnu.org/gnu/gdb/gdb-8.1.tar.gz
tar xzf gdb-8.1.tar.gz
rm -f gdb-8.1.tar.gz
popd

pushd $GDB_HOME > /dev/null

mkdir build
cd build
../configure
make -j`nproc`

popd>/dev/null
