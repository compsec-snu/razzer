#!/bin/bash -e

PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh
. $PROJECT_DIR/scripts/llvm/envsetup.sh

SRC_DIR=$SVF_HOME

if [ ! -d $SRC_DIR ]; then
    echo Error: cannot find SVF source directory
    exit 1
fi

echo "Install SVF into $SRC_DIR/Release-build..."
echo

pushd $SRC_DIR > /dev/null
    if [ -d "Release-build" ];
    then
        echo [WARN]: Release-build dir exists, so assume it is installed correctly
        echo Run [ rm -rf $SRC_DIR/Release-build ]if you want to reinstall
    else
        mkdir Release-build
        cd Release-build
        cmake ../
        make -j4
        echo Done
    fi
popd > /dev/null
