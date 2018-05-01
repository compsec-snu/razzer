#!/bin/bash -e

# Environment setup scripts for all subprojects

pushd "$(dirname $BASH_SOURCE)" > /dev/null

# Setup common env variables
. $(pwd)/common.sh

#echo "Select the kernel version
eval `./kernel_version.py`
export KERNEL_BUILD=$SYZKALLER_HOME/kernel-build/build-$KERNEL_VERSION/

export ENV_SETUP=SETUP
export PATH=$PATH:/$SCRIPT_HOME/misc

for SUBDIR in $(ls -d */); do
  [ ! -f $SUBDIR/envsetup.sh ] || . $SUBDIR/envsetup.sh
done

# TODO: Another way?
printenv 'all subprojects' \
	'PROJECT_HOME SCRIPT_HOME PATCHES_HOME SVF_HOME LLVMLINUX_HOME PATH KERNEL_DIR'

popd > /dev/null
