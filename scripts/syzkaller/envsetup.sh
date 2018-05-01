#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

export GOPATH=$SYZKALLER_HOME
export PATH=$SYZKALLER_HOME/bin:$PATH
printenv 'syzkaller' 'GOPATH'
