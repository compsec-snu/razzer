#!/bin/bash -e

if [ "$ENV_SETUP" != "SETUP" ]; then
    echo "Execute scripts/envsetup.sh first!"
    exit 1
fi

if [ -z $1 ]; then
	echo "[Usage] $0 <dir>"
	echo "   <dir>: analysis base directory"
	exit 1
fi

if [ -z "$KERNEL_VERSION" ]; then
	echo "[ERROR] unknown kernel version"
	exit 1
fi
echo "[*] Kernel version: $1"

if [ ! -f $1/link.sh ]; then
    echo "[ERROR] $1/link.sh does not exist."
    exit 1
fi

echo "[*] Making static analysis directory"
mkdir -p $1/$KERNEL_VERSION
DIR=$(realpath "$1/$KERNEL_VERSION/")
echo "[*] DIR:" $DIR

ln -sf $(realpath "$1/link.sh") "$DIR"

pushd $DIR 2>/dev/null

if [ ! -f ./combined.bc ]; then
    echo "[*] Generating combined.bc"
    ./link.sh
fi

if [ ! -f ./mssa ]; then
    echo "[*] Generating mssa"
    analysis.py ./combined.bc > ./mssa
fi

if [ ! -f ./mempair_all ]; then
    echo "[*] Generating mempair"
    get_aliased_pair.py ./mssa > ./mempair_all
fi

if [ ! -f ./mempair ]; then
    echo "[*] Prune and check_testing_bugs"
    prune.py ./mempair_all > ./mempair
    check_testing_bugs.py ./mempair
fi

if [ ! -f ./mapping ]; then
    echo "[*] Generating mapping"
    get_address.py ./mempair > ./mapping
fi

if [ ! -f ./callgraph ]; then
    echo "[*] Generating callgraph"
    call_graph.py ./callgraph_final.dot > ./callgraph
fi

ls -l .
popd 2>/dev/null
