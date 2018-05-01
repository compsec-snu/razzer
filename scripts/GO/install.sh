#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

# Installing GO 1.8.1
TMP_DIR=$PROJECT_DIR/tmp
GO_URL=https://storage.googleapis.com/golang/go1.8.1.linux-amd64.tar.gz

GOROOT=$GO_HOME

# already installed
if [ -d $GOROOT ]; then
  echo $GOROOT exits
  exit
fi

mkdir -p $TMP_DIR
pushd $TMP_DIR > /dev/null
  GO_TAR=go1.8.1.linux-amd64.tar.gz
  wget $GO_URL
  tar -xf $GO_TAR
  mv go $GOROOT
popd > /dev/null
rm -rf $TMP_DIR

# External library
# go get -u -d github.com/emirpasic/gods/...
