TARGETDIR	= ${CURDIR}
TOPDIR		= $(realpath ${TARGETDIR}/../..)
include ${TOPDIR}/common.mk

all: aligned-attribute-gcc aligned-attribute-clang diff-all t2 t3

aligned-attribute-gcc: aligned-attribute.c
	gcc $< -o $@

aligned-attribute-clang: aligned-attribute.c
	../../../toolchain/clang/install/bin/clang $< -o $@

diff-all: aligned-attribute-gcc aligned-attribute-clang
	@./aligned-attribute-gcc > gcc-log
	@./aligned-attribute-clang > clang-log
	@printf "%s: aligned-attribute\n" `diff -q gcc-log clang-log && echo ${PASS} || echo ${FAIL}`

t2: t2.c
	gcc $< -o $@

t3: t3.c
	gcc $< -o $@

clean:
	rm -f aligned-attribute-* *-log
