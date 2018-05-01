#!/bin/bash

cd $1
mknod dev/console c 5 1 
mknod dev/tty0 c 4 0 
find . | cpio -H newc -o > $2
