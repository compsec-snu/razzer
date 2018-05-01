#!/bin/bash -e
. $(dirname $BASH_SOURCE)/common.sh

for _SUBDIR in gcc GO llvm llvmlinux SVF syzkaller qemu capstone; do
  SUBDIR=$(basename $_SUBDIR)
  [ ! -f $SCRIPT_HOME/$SUBDIR/envsetup.sh ] || . $SCRIPT_HOME/$SUBDIR/envsetup.sh
  [ ! -f $SCRIPT_HOME/$SUBDIR/install.sh ] || $SCRIPT_HOME/$SUBDIR/install.sh
done
