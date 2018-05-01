#!/bin/bash -e

AR=ar
LLVM_LINK=llvm-link
OPTS=$*
NUM=0
OFILE=

for TOK in $OPTS; do
	case $TOK in
		*.a)
			if [ -z $OFILE ]; then
				OFILE=$(echo $TOK | sed -e 's/\.a/\.bc/g')
				continue
			fi
            REP=$(echo $TOK | sed -e 's/\.a/\.bc/g')
			;;
        *.o)
            REP=$(echo $TOK | sed -e 's/\.o/\.bc/g')
            ;;
		*)
			continue
			;;
	esac
  if [[ ! -f $REP || "$REP" == ver$ ]] ; then
	  continue
  fi
  NEW+=$REP' '
  NUM=$(expr $NUM + 1)
done

if [ $NUM -ge 1 ] && [ ! -z $OFILE ];
then
  $LLVM_LINK $NEW -o $OFILE
fi

$AR $*
