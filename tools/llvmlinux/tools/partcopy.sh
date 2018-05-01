#!/bin/bash
##############################################################################
# Copyright (c) 2012 Behan Webster
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
##############################################################################

export LANG=C

usage() {
	cat <<ENDHELP
Usage: `basename $0` [options] <sd-card-image> <partition-name> <from-path> <to-path>
    <sd-card-image>   A file image of an SD card
    <partition-name>  The partition or volume name to which to copy files on the SD card image
    <from-path>       The path from which to copy files
    <to-path>         The path to which to copy files in the named partition on the SD card image

    --delete          Means delete what was at the to-path previously
    --shell           Drop to a shell after the file copy, before unmounting the image (for debugging)
    --verbose         Show more output

    This utility can be used to copy files into an existing SD card image.
ENDHELP
	exit -1
}

error() {
	echo "E: $*"
	return 1
}

while [ $# -gt 0 ] ; do
	case "$1" in
	-d*|--delete) DELETE=--delete;;
	--shell) DROPTOSHELL=1;;
	-v*|--verbose) VERBOSE=--verbose;;
	--) shift; break;;
	-*|--help) usage;;
	*) break;;
	esac
	shift
done
[ $# -lt 3 ] && usage
SDCARD=$1
LABEL=$2
FROM=$3
TO=${4:-/}

KPARTX=/sbin/kpartx
LOSETUP=/sbin/losetup
RSYNC=/usr/bin/rsync
FINDFS=/sbin/findfs

[ -x $KPARTX ] || error "$KPARTX not found (you may need to install the package)"
[ -x $LOSETUP ] || error "$LOSETUP not found (you may need to install the package)"
[ -x $RSYNC ] || error "$RSYNC not found (you may need to install the package)"
[ -x $FINDFS ] || error "$FINDFS not found (you may need to install the package)"

cleanup() {
	set +e
	FILENAME=`basename "$SDCARD"`
	[ -n "$FILENAME" ] && DEV=`sudo $LOSETUP -a | grep "($FILENAME)" | sed -e 's|^/dev/||; s|:.*$||'`
	[ -n "$DEV" ] && MP=`mount | awk '/'$DEV'/ {print $3}'`
	[ -n "$MP" ] && sudo umount "$MP" && rmdir "$MP"
	[ -n "$SDCARD" ] && sudo $KPARTX -d "$SDCARD" >/dev/null
}

# Clean up mount and looped partitions
finshup() {
	cleanup
	exit 0
}
trap finshup INT

# Get rid of any mess from a failed attempt before
cleanup

set -e
MAPPED=`sudo $KPARTX -av "$SDCARD" | awk '{print $3}'`
for DEV in $MAPPED ; do
	DEV2=/dev/mapper/$DEV
	[ -n "$VERBOSE" ] && echo $DEV2
	sleep 2   # allow some time to settle device creation (!)
	if [ `sudo $FINDFS LABEL=rootfs | grep -c $DEV2` -gt 0 ] ; then
		echo "copy..."
		MP=`mktemp -d`
		sudo mount $DEV2 $MP
		sudo mkdir -p $MP/$TO
		sudo $RSYNC -a $VERBOSE $DELETE $FROM/ $MP/$TO/
		[ -n "$DROPTOSHELL" ] && (echo $MP && cd $MP && sh)
	fi
done
finshup
