BASE=${PWD}/../../../..
CLANGDIR=${BASE}/toolchain/clang/install/bin
VEXPRESSDIR=${BASE}/targets/vexpress

all: ${VEXPRESSDIR}/src/linux/scripts/mod/modpost /usr/bin/creduce
	cp rtnetlink.orig foo.c
	(export BASE=${BASE}; creduce ./c4.sh foo.c)

${VEXPRESSDIR}/src/linux/scripts/mod/modpost: 
	(cd ${VEXPRESSDIR} && make kernel-config)
	(cd ${VEXPRESSDIR}/src/linux &&  time  make ARCH=arm CROSS_COMPILE=arm-none-linux-gnueabi- CONFIG_DEBUG_INFO=1 CONFIG_DEBUG_SECTION_MISMATCH=y CONFIG_NO_ERROR_ON_MISMATCH=y CC="${CLANGDIR}/clang -gcc-toolchain ${BASE}/arch/arm/toolchain/codesourcery/arm-2013.05" init/main.o )

/usr/bin/creduce:
	sudo apt-get install creduce

clean:
	rm foo.best foo.c foo.orig
