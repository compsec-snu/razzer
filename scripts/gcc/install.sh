#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

GCC_VER=gcc-7.3.0
GCC_DIR=$TOOLCHAINS_HOME/$GCC_VER

if [ -d "$GCC_DIR" ]; then
  echo "[ERR] $GCC_DIR exist"
  exit
fi

pushd $TOOLCHAINS_HOME/ > /dev/null
  rm -f $GCC_VER.tar.xz
  wget https://ftp.gnu.org/gnu/gcc/$GCC_VER/$GCC_VER.tar.xz
  tar xf $GCC_VER.tar.xz
  rm -f $GCC_VER.tar.xz

  cd $GCC_DIR > /dev/null
  mkdir build
  mkdir install
  ./contrib/download_prerequisites
  cd build
  ../configure --enable-languages=c,c++ --disable-bootstrap \
               --enable-checking=no --with-gnu-as \
               --with-gnu-ld --with-ld=/usr/bin/ld.bfd \
               --disable-multilib --enable-plugin --prefix=$GCC_DIR/install/
  make -j`nproc`
  make install
popd > /dev/null
