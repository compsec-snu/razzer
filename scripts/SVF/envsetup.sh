#!/bin/bash -e
PROJECT_DIR=$(realpath $(dirname $BASH_SOURCE)/../../)
. $PROJECT_DIR/scripts/common.sh

pushd $SVF_HOME > /dev/null
if [ -d "$SVF_HOME/Release-build" ]; then
  export PATH=$SVF_HOME/Release-build/bin:$PATH
  DEBUG=
elif [ -d "SVF_HOME/Debug-build" ]; then
  export PATH=$SVF_HOME/Debug-build/bin:$PATH
  DEBUG='debug'
fi
popd > /dev/null
. $SVF_HOME/setup.sh $DEBUG

printenv 'SVF' 'PTAHOME PTABIN PTALIB PTARTLIB PTATEST PTATESTSCRIPTS
RUNSCRIPT'
