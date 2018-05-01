#!/bin/bash -e

if [ "$ENV_SETUP" != "SETUP" ]; then
    echo "Execute scripts/envsetup.sh first!"
    exit 1
fi

SYZMANAGER="$PROJECT_HOME/tools/race-syzkaller/src/github.com/google/syzkaller/bin/syz-manager"

optstrl="config:,supp:,bench:"
OPTS=`getopt -o vdhrfw -l $optstrl -n $0 -- "$@"`
eval set -- "$OPTS"

function usage {
	echo "Usage $0 [--config=CONF] [-h] [-v] [-f] [-r] [-w] [-o]"; exit 1
}

VERBOSE=0
while true; do
	case "$1" in
        --supp)
            SUPPOPTION="-supp=$2" ; shift 2;;
		--config)
			CONFIG=$2 ; shift 2 ;;
        --bench)
            BENCH="-bench=$2" ; shift 2;;
		--) shift ; break;;
		-f) DEBUG="-fdebug" ; shift 1 ;;
		-r) DEBUG="-rdebug" ; shift 1 ;;
		-d) DELETE=true ; shift 1 ;;
		-w) WARN="-no-warn" ; shift 1 ;;
		-v) VERBOSE=$(expr $VERBOSE + 1) ; shift 1 ;;
		-h|*) usage ;;
	esac
done

if [ -z $CONFIG ]; then
	echo "No config"
	exit 1
fi

if [ $SUPP ]; then
    SUPPOPTION=$SUPP
fi

if [ "$DELETE" = true ]; then
	rm -rf workdir
fi

pushd $QEMU_HOME
echo "[*] Rebuilding QEMU"
./rebuild.sh
popd

mkdir -p workdir
echo "[*] KERNEL_VERSION: $KERNEL_VERSION" | tee -a workdir/log
echo "[*] git: `git rev-parse HEAD` (`git rev-parse --abbrev-ref HEAD`)" | tee -a workdir/log
git diff --stat HEAD| tee -a workdir/log
echo "[*] Running: syz-manager -config $CONFIG -v $VERBOSE $DEBUG $WARN $SUPPOPTION $BENCH" | tee -a workdir/log
$SYZMANAGER -config $CONFIG -v $VERBOSE $DEBUG $WARN $SUPPOPTION $BENCH 2>&1 | tee -a workdir/log
