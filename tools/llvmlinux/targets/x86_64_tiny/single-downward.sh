#!/bin/bash
set +x

export RUNNING=true

while $RUNNING; do

    patched=0
    result=""
    
    rm tmp/qemu_log

    # for old kernels ... we deprecated that patch already.
    sed -i -e "s#extern inline#static inline#g" src/linux/drivers/gpu/drm/i915/i915_drv.h
    make $1 all test-kill
    ret=$?
    echo "ret = $ret"
    sleep 2

    if test -f state/kernel-patch ; then
	result="$result patched"
	patched=1
    fi

    if test -f state/kernel-build ; then
	result="$result built"
    fi

    make kernel-mrproper
    # revert above hack again.
    pushd src/linux 
     git checkout -- drivers/gpu/drm/i915/i915_drv.h
     git log -1 --pretty=oneline >> ../../_single
    popd
    result=" -- $result return:$ret --"

	if test x"$ret" == x"0" ; then
	    echo good
	    export RUNNING=false
	fi

	# 2nd if
	if grep " BUG: " tmp/qemu_log ; then
	    echo BUG
	    result="$result BUG"
	    export RUNNING=true;
	fi

	if grep "Kernel panic" tmp/qemu_log ; then
	    echo panic
	    result="$result PANIC"
	    export RUNNING=true;
	fi

	if grep "test_string_helpers: Test failed:" tmp/qemu_log ; then
	    echo "test_string_helpers: Test failed:"
	    result="$result test_string_helpers failed"
	    export RUNNING=true;
	fi
	

	if $RUNNING; then
	    echo bad
	    pushd src/linux
	    git reset --hard HEAD~
	    popd
	fi

echo "$result" >> _single
echo "############" >> _single

    if test x"$patched" == x"0" ; then
	echo "Patching failed - still continue?"
	read aw
    fi
done