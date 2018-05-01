#!/bin/bash -e

if [ "$ENV_SETUP" != "SETUP" ]; then
    echo "Execute scripts/envsetup.sh first!"
    exit 1
fi

if [ -z "$KERNEL_VERSION" ]; then
	echo "[ERROR] unknown kernel version"
	exit 1
fi

NAME=`dirname $1`
# Drop prepended "./"
NAME=${NAME/.\//}
# Replace "/" with "-"
NAME=${NAME//\//-}
echo "[*] NAME: [$NAME]"

echo "[*] Kernel version: $KERNEL_VERSION"

echo "[*] Making static analysis directory"
ANALYSIS_DIR=../configs/kernel/partition
mkdir -p $ANALYSIS_DIR/$KERNEL_VERSION
DIR=$(realpath "../configs/kernel/partition/$KERNEL_VERSION/")
echo "[*] DIR:" $DIR

pushd $DIR >> /dev/null

BUILD_DIR=$LLVMLINUX_HOME/targets/x86_64/build-$KERNEL_VERSION/kernel-clang

BCFILES=""
for param in "$@"
do
    BC=$BUILD_DIR/$param
    if [ ! -f $BC ]; then
        echo "[ERROR] Cannot find .bc file: $BC"
        exit 1
    fi
    BCFILES="$BCFILES $BC"
done

if [ ! -s ./combined.$NAME.bc ]; then
    echo "[*] Generating combined-$NAME.bc"
    rm -f combined.$NAME.bc
    llvm-link $BCFILES -o combined.$NAME.bc
fi

if [ ! -s ./mssa.$NAME ]; then
    echo "[*] Generating mssa.$NAME"
    rm -f ./mssa.$NAME
    analysis.py ./combined.$NAME.bc > ./mssa.$NAME
fi

if [ ! -s ./mempair_all.$NAME ]; then
    echo "[*] Generating mempair_all.$NAME"
    rm -f ./mempair_all.$NAME
    get_aliased_pair.py ./mssa.$NAME > ./mempair_all.$NAME
fi

if [ ! -s ./mempair.$NAME ]; then
    echo "[*] Prune and check_testing_bugs"
    rm -f ./mempair.$NAME
    prune.py ./mempair_all.$NAME > ./mempair.$NAME
    check_testing_bugs.py ./mempair.$NAME
fi

ls -lh *$NAME*
popd 2>/dev/null
