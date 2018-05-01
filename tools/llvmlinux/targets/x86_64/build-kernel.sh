#!/bin/bash -e

if [ "$ENV_SETUP" != "SETUP" ]; then
    echo "Execute scripts/envsetup.sh first!"
    exit 1
fi

optstrl="clean,config:"
OPTS=`getopt -o h -l $optstrl -n $0 -- "$@"`
eval set -- "$OPTS"

CLEAN=0
while true; do
    case "$1" in
        --clean)
            CLEAN=1; shift ;;
        --config)
            KERNEL_CFG=$2 ; shift 2;;
        --) shift ; break;;
        -h|*) echo "Usage: $0 [--clean] [--config=CONF]" ; exit 1 ;;
    esac
done

if [ -z $KERNEL_CFG ] && [ $CLEAN -eq '0' ]; then
	echo "--config option is missing"
	exit 1
fi

if [ ! -d "build-$KERNEL_VERSION" ]; then
	mkdir build-$KERNEL_VERSION
fi
rm -rf build
ln -s build-$KERNEL_VERSION build

if [ $CLEAN -eq 1 ]; then
    make kernel-clean
else
	mkdir -p tmp
    make V=1 CONFIG=$KERNEL_CFG BITCODE=1 CC=$GCC_HOME/install/bin/gcc > tmp/log
fi
