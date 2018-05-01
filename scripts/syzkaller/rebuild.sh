#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

# Can't change the source directory
SYZKALLER_DIR=$SYZKALLER_HOME/src/github.com/google/syzkaller

if [ -z "$1" ]; then
    TARGET="all"
else
    TARGET="$1"
fi

pushd $SYZKALLER_DIR > /dev/null
  echo "[*] Run: make $TARGET"
  CC=$GCC_HOME/install/bin/g++ make $TARGET
popd > /dev/null

if [ ! -d $PROJECT_DIR/race-syzkaller/syzkaller ]; then
	ln -s $SYZKALLER_DIR $PROJECT_DIR/race-syzkaller/syzkaller > /dev/null
fi

rm $PROJECT_HOME/race-syzkaller/bin/*
ln -s $SYZKALLER_DIR/bin/* $PROJECT_HOME/race-syzkaller/bin 2>/dev/null
