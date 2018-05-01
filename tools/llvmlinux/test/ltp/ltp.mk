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

# Assumes has been included from ../test.mk

LTPTMPDIR	= ${LTPDIR}/tmp
LTPSRCDIR	= ${LTPDIR}/src
TOPLTPINSTALLDIR= ${LTPDIR}/install
LTPINSTALLDIR	= ${TOPLTPINSTALLDIR}/opt/ltp
LTPBUILDDIR	= ${LTPSRCDIR}/$(basename $(notdir ${LTPSF_TAR}))
LTPSTATE	= ${LTPDIR}/state
LTPSCRIPTS	= ${LTPDIR}/scripts

LTPCVS=":pserver:anonymous@ltp.cvs.sourceforge.net:/cvsroot/ltp"
LTPBRANCH="stable-1.0"

LTPSF_RELEASE	= 20120614
LTPSF_TAR	= ltp-full-${LTPSF_RELEASE}.bz2
LTPSF_URI	= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-${LTPSF_RELEASE}/${LTPSF_TAR}
LTPSF_FILE	= $(call shared,${LTPTMPDIR}/${LTPSF_TAR})

TMPDIRS		+= ${LTPTMPDIR}

.PHONY:		${LTP_TARGETS}
LTP_TARGETS	= ltp-fetch ltp-configure ltp-build ltp-sync ltp-clean ltp-mrproper ltp-raze ltp-version
TARGETS_TEST	+= ltp-[fetch,configure,build,sync,settings,clean,mrproper,raze]
CLEAN_TARGETS	+= ltp-clean
HELP_TARGETS	+= ltp-help
MRPROPER_TARGETS+= ltp-mrproper
RAZE_TARGETS	+= ltp-raze
SETTINGS_TARGETS+= ltp-settings
#FETCH_TARGETS	+= ltp-fetch
#SYNC_TARGETS	+= ltp-sync
VERSION_TARGETS	+= ltp-version

ltpstate=mkdir -p ${LTPSTATE}; touch $(1); echo "Entering state $(notdir $(1))"; rm -f ${LTPSTATE}/ltp-$(2)

ltp-help:
	@echo
	@echo "These are the make targets for the Linux Test Project (LTP):"
	@echo "* make ltp-[fetch,configure,build,sync,clean]"

ltp-settings:
	@echo "# LTP settings"
	@$(call prsetting,LTPSF_RELEASE,${LTPSF_RELEASE})
	@$(call prsetting,LTPSF_TAR,${LTPSF_TAR})
	@$(call prsetting,LTPSF_URI,${LTPSF_URI})

${LTPSF_FILE}:
	@$(call wget,${LTPSF_URI},$(dir $@))

ltp-fetch: ltp-sf
ltp-sf: ${LTPSTATE}/ltp-fetch
${LTPSTATE}/ltp-fetch: ${LTPSF_FILE}
	@$(call banner,Fetching LTP...)
	@mkdir -p ${LTPSRCDIR}
	@rm -rf ${LTPBUILDDIR}
	tar -x -C ${LTPSRCDIR} -f $<
	@$(call ltpstate,$@,configure)

ltp-cvs:
	@mkdir -p ${LTPSRCDIR}
	(cd ${LTPSRCDIR} && cvs -z3 -d ${LTPCVS} co -P ltp)

ltp-sync: ${LTPSTATE}/ltp-fetch
	@$(call banner,Updating LTP...)
	@make ltp-clean
	(( test -e ${LTPSF_FILE} && echo "Skipping cvs up (tarball present)" )|| ( cd ${LTPBUILDDIR} && cvs update ))

ltp-configure: ${LTPSTATE}/ltp-configure
${LTPSTATE}/ltp-configure: ${LTPSTATE}/ltp-fetch
	@$(call banner,Configure LTP...)
	@mkdir -p ${LTPBUILDDIR}
	(cd ${LTPBUILDDIR} && ${LTPSRCDIR}/ltp/configure \
		--host arm-none-linux-gnueabi \
		--disable-docs --prefix=${LTPINSTALLDIR})
	@$(call makeclean,${LTPBUILDDIR}) >/dev/null
	@$(call ltpstate,$@,build)

ltp-build: ${LTPSTATE}/ltp-build
${LTPSTATE}/ltp-build: ${LTPSTATE}/ltp-configure
	@$(call banner,Build LTP...)
	make -C ${LTPBUILDDIR}
#	make -C ${LTPBUILDDIR} top_builddir=${LTPBUILDDIR} \
#		-f ${LTPSRCDIR}/ltp/Makefile top_srcdir=${LTPSRCDIR}/ltp
	rm -rf ${LTPINSTALLDIR}
	@mkdir -p ${LTPINSTALLDIR}
	SKIP_IDCHECK=1 make -C ${LTPBUILDDIR} -j${JOBS} install
#	SKIP_IDCHECK=1 make -C ${LTPBUILDDIR} top_builddir=${LTPBUILDDIR} \
#		-f ${LTPSRCDIR}/ltp/Makefile top_srcdir=${LTPSRCDIR}/ltp \
#		-j${JOBS} install
	@$(call ltpstate,$@,scripts)
	
ltp-scripts: ${LTPSTATE}/ltp-scripts
${LTPSTATE}/ltp-scripts: ${LTPSTATE}/ltp-build
	@$(call banner,Install LTP scripts...)
	cp -rv ${LTPSCRIPTS}/* ${LTPINSTALLDIR}/
	@$(call ltpstate,$@)

ltp-clean-all:
	@$(call banner,Cleaning LTP...)
	rm -f $(addprefix ${LTPSTATE}/ltp-,configure build)
	rm -rf ${TOPLTPINSTALLDIR}

ltp-clean: ltp-clean-all
	@$(call makeclean,${LTPBUILDDIR}) >/dev/null

ltp-mrproper: ltp-clean-all
	rm -f ${LTPSTATE}/ltp-*
	rm -rf ${LTPBUILDDIR}

ltp-raze: ltp-mrproper
	@$(call banner,Razing LTP...)
	rm -rf ${LTPSTATE} ${LTPTMPDIR} ${LTPSRCDIR}

ltp-version:
	@echo -e "LTP\t\t= LTP version ${LTPSF_RELEASE} (from sourceforge)"

# ${1}=logdir ${2}=toolchain ${3}=testname
ltplog	= ${1}/${2}-${ARCH}-`date +%Y-%m-%d_%H:%M:%S`-${3}.log
