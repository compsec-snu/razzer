#!/bin/bash

set -e

LD=ld
LLVM_LINK=llvm-link

# link llvm bitcode files

OPT=$*
F=0
NEW=

NUM=0
PREV=

#TODO: To many corner cases...
for TOK in $OPT
do
  case "$TOK" in
    "-r"|"-m"|"elf_x86_64"|"--emit-relocs"|"-T"|"--start-group"|"--end-group"|*.lds|*.ld|*.a|*.ver)
      continue
      ;;
  esac

  REP=$(echo $TOK | sed -e 's/\.o/\.bc/g')
  if [[ $TOK != '-o' ]] && [[ $PREV != '-o' ]] && [[ ! -f "$REP" ]]; then
    # File not exists
    PREV=$TOK
    continue
  fi

  # TODO: Fix it
  if [[ $PREV = '-o' ]] && [[ $REP =~ '\.bc' ]]; then
    REP=$REP.bc
  fi

  PREV=$TOK
  NEW+=$REP' '
  NUM=`expr $NUM + 1`
done

if [ $NUM -ge 3 ];
then
  $LLVM_LINK $NEW
fi

$LD $*
