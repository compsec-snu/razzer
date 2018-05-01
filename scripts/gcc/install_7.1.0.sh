#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh
GCC_DIR=$GCC7_HOME

if [ -d "$GCC_DIR" ]; then
  echo "$GCC_DIR exist"
  exit
fi

svn checkout svn://gcc.gnu.org/svn/gcc/trunk $GCC_DIR

# Is this needed?
sleep 1

pushd $GCC_DIR > /dev/null
  svn ls -v ^/tags | grep gcc_7_1_0 # This line isn't needed
  svn up -r 247494

  # apply_patches $GCC_DIR gcc-6.1.0

  mkdir build
  mkdir install
  cd build
  ../configure --enable-languages=c,c++ --disable-bootstrap \
  --enable-checking=no --with-gnu-as --with-gnu-ld --with-ld=/usr/bin/ld.bfd \
  --disable-multilib --enable-plugin --prefix=$GCC_DIR/install/
  make -j`nproc`
  make install

popd > /dev/null
