#
# Unit test framwork for Kbuild
#

all: unittests

TOPDIR		= $(realpath ../../..)
TARGETDIR	= $(TOPDIR)/targets/vexpress

include ${TOPDIR}/common.mk
# We need one arch, this is as good as any
include ${ARCHDIR}/arm/arm.mk

#================================================================================

isystem	= DIR=`$(1) -print-file-name=include` ; \
	printf "%s: %s -> %s\n" \
		`[ -f $$DIR/stdarg.h ] && echo ${PASS} || echo ${FAIL}` \
		"`echo $(1) | sed 's|[^ ]*/|.../|g'`" \
		"`echo $$DIR | sed 's|$(TOPDIR)|...|'`"
crossisystem = $(call isystem,$(1) -gcc-toolchain $(2)); $(call isystem,$(2))

unittests:
	@$(call isystem,gcc)
	@$(call isystem,clang)
	@$(call isystem,$(CLANG))
	@for COMP in `find $(ARCH_ARM_TOOLCHAIN) -name arm-\*-gcc` ; do \
		$(call crossisystem,$(CLANG),$$COMP) ; \
	done
#	${CLANG} -gcc-toolchain ${ANDROID_CC_DIR} -print-file-name=include
#	${ANDROID_CC_DIR}/bin/arm-linux-androideabi-gcc -print-file-name=include
#	${CLANG} -gcc-toolchain ${CSCC_DIR} -print-file-name=include
#	${CSCC_DIR}/bin/arm-none-linux-gnueabi-gcc -print-file-name=include
#	${CLANG} -gcc-toolchain ${LINARO_CC_DIR} -print-file-name=include
#	${LINARO_CC_DIR} -print-file-name=include

clean:
