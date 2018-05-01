#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

export GOROOT=$GO_HOME
export PATH=$GOROOT/bin/:$PATH

printenv 'GO' 'GOROOT'
