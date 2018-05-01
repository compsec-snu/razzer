#!/bin/bash -e

if [ "$#" -gt "0" ]; then
    VMLINUX=$1
else
    VMLINUX=$KERNEL_BUILD/vmlinux
fi

if [ ! -f $VMLINUX ]; then
	echo "Build kernel first!"
	exit 1
fi

echo "VMLINUX: $(realpath $VMLINUX)"

HYPEADDR=$(objdump -d $VMLINUX | grep "sys_hypercall" -A 100 -m 1 | grep nop | cut -d':' -f1 | head -n1)
HYPEADDR='0x'$HYPEADDR

echo "HYPEADDR: $HYPEADDR"

# Force these files always rebuilt
touch ./kvm-all.c
touch ./cpus.c
touch ./disas/i386.c
touch ./hypercall.c

pushd build >/dev/null
CC=$GCC7_HOME/install/bin/gcc CFLAGS="-D_HYPERCALL_ADDR=$HYPEADDR" make -j8
popd >/dev/null
