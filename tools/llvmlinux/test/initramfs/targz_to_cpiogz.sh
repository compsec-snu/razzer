#!/bin/bash

# Convert a tar.gz to a cpio.gz
cd $1
tar xzf $2
find . | cpio -H newc -o > ${3}.cpio
if test -e /usr/bin/pigz; then 
	cat ${3}.cpio | pigz -9c > ${3}.cpio.gz
else 
	cat ${3}.cpio | gzip -9c > ${3}.cpio.gz 
fi
rm -f ${3}.cpio
