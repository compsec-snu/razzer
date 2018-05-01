#
# Unit test framwork for Kbuild
#

all: run-tests

TOPDIR		= $(realpath ../../..)
TARGETDIR	= $(TOPDIR)/targets/vexpress

include ${TOPDIR}/common.mk
# We need one arch, this is as good as any
include ${ARCHDIR}/arm/arm.mk

TMPSCRIPTDIR	= $(CURDIR)/scripts
TESTFILE	= unittests.mk
COMPILERS	= gcc $(CLANG)
KBUILD_ORIG	= $(TMPSCRIPTDIR)/Kbuild.include
KBUILD_PATCHED	= $(TMPSCRIPTDIR)/Kbuild.patched
KBUILDS		= $(KBUILD_ORIG) $(KBUILD_PATCHED)

#================================================================================
# Read tests from unit tests file
TESTS := $(shell grep '^[a-z-]*:' $(TESTFILE) | grep -v SKIP | cut -d: -f1)

unittests:
	@for TEST in $(TESTS); do echo -e $$TEST ; done

run-tests: $(KBUILDS)
	@for TEST in $(TESTS); do \
		RAWTEST=""; RESULT=""; \
		for KBUILD in $(KBUILDS); do \
			for CC in $(COMPILERS); do \
				OUT=`KBUILD=$$KBUILD CC=$$CC srctree=. make -f $(TESTFILE) $$TEST | grep -v '^make\['` ; \
				RAWTEST="$$RAWTEST\n  KBUILD=`basename $$KBUILD` CC=`basename $$CC` OUT='$$OUT'" ; \
				[ -z "$$OUT" ] && OUT="''" ; \
				RESULT="$$RESULT $$OUT" ; \
			done ; \
		done ; \
		egrep -q "^$$TEST: #$$RESULT" $(TESTFILE) && echo -e "${PASS}: $$TEST" \
			|| (echo -en "${FAIL}: `egrep "^$$TEST:" $(TESTFILE)`"; echo -e $$RAWTEST) ; \
	done ;

#================================================================================
# Get files from Linux Kernel
kbuild: $(KBUILD_ORIG)
$(KBUILD_ORIG):
	mkdir -p $(dir $@)
	@[ -f $(STATEDIR)/kernel-patch ] && $(call unpatch,$(KERNELDIR)) >/dev/null
	cp $(KERNELDIR)/scripts/$(notdir $@) $@
	cp $(KERNELDIR)/scripts/gcc-version.sh  $(TMPSCRIPTDIR)
	chmod a+x $(TMPSCRIPTDIR)/gcc-version.sh
	@$(call patch,$(KERNELDIR)) >/dev/null
	cp $(KERNELDIR)/scripts/$(notdir $@) $(KBUILD_PATCHED)
	@[ -f $(STATEDIR)/kernel-patch ] || $(call unpatch,$(KERNELDIR)) >/dev/null

$(KBUILD_PATCHED): $(KBUILD_ORIG)

#================================================================================
clean:
	@rm -rf $(TMPSCRIPTDIR)
