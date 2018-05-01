#!/bin/bash -e

if [ -z $ENV_SETUP ]; then
	echo "[ERR] Execute scripts/envsetup.sh first"
	exit 1
fi

optstrl="config:"
OPTS=`getopt -o sh -l $optstrl -n $0 -- "$@"`
eval set -- "$OPTS"

function usage {
	echo "[ERR] Usage $0 [--config=CONF] [-h] [-s]"; exit 1
}

BUILD_DIR=$KERNEL_BUILD
CC_HOME=$GCC_HOME
while true; do
	case "$1" in
		--config)
			CONFIG=$2 ; shift 2 ;;
		-s)
			CC_HOME=$GCC7_HOME ; shift ;;
		--) shift ; break;;
		-h|*) usage ;;
	esac
done

if [ -z $CONFIG ]; then
	echo "[ERR] Should provide kernel config file"
	exit 1
fi

echo "Remove the built kernel (y/N)?"
echo "'y' will remove '$BUILD_DIR'"
read REMOVE
if [ "$REMOVE" = "y" ]; then
    rm -rf $BUILD_DIR
fi

CONFIG=$(realpath $CONFIG)
echo $CONFIG

mkdir $BUILD_DIR
pushd $KERNEL_DIR >/dev/null
make mrproper O=$BUILD_DIR
cp $CONFIG $BUILD_DIR/.config
make -j`nproc` CC=$CC_HOME/install/bin/gcc O=$BUILD_DIR
popd >/dev/null
