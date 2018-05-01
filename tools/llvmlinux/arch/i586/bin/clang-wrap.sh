#!/bin/bash

# PATH, CLANG, CSCC_DIR, CSCC_BINDIR, and HOST_TYPE are exported from the Makefile

export PATH=`echo $PATH | sed -E 's/(.*?) :(.*)/\2\1/g; s/(.*?) :(.*)/\2\1/g; s/(.*?) :(.*)/\2\1/g'`

CLANGFLAGS="-march=x86_64 -fcatch-undefined-behavior -Qunused-arguments"

CC="$CLANG ${CLANGFLAGS}"

${CC} $*
