#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

SYZKALLER_DIR=$SYZKALLER_HOME/src/github.com/google/syzkaller
pushd $SYZKALLER_DIR > /dev/null
  CC=$GCC_HOME/install/bin/g++ make
popd > /dev/null


rm -f $PROJECT_DIR/tools/race-syzkaller/syzkaller
ln -s $SYZKALLER_DIR $PROJECT_DIR/tools/race-syzkaller/syzkaller > /dev/null
