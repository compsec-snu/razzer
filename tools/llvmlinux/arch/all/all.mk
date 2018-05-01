#############################################################################
# Copyright (c) 2012 Mark Charlebois
#               2012-2014 Behan Webster
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

# The ARCH makefile must provide the following:
#   - KERNEL_PATCH_DIR += ${ARCH_xxx_PATCHES} ${ARCH_xxx_PATCHES}/${KERNEL_REPO_PATCHES}
#   
# The target makefile must provide the following:
#   - KERNEL_CFG
#   - KERNEL_PATCH_DIR += ${PATCHDIR} ${PATCHDIR}/${KERNEL_REPO_PATCHES}

export TMPDIR V W

ARCH_ALL_DIR	= ${ARCHDIR}/all
ARCH_ALL_BINDIR	= ${ARCH_ALL_DIR}/bin
ARCH_ALL_PATCHES= ${ARCH_ALL_DIR}/patches

PATH		:= ${PATH}:${ARCH_ALL_BINDIR}

MAINLINEURI	= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
SHARED_KERNEL	= $(call shared,${ARCH_ALL_DIR}/kernel.git)

#############################################################################
TOPLOGDIR	= ${TOPDIR}/log

LOGDIR		= ${TARGETDIR}/log
PATCHDIR	= ${TARGETDIR}/patches
SRCDIR		= ${TARGETDIR}/src
BUILDDIR	= ${TARGETDIR}/build
STATEDIR	= ${TARGETDIR}/state
TMPDIR		= $(call buildroot,${TARGETDIR}/tmp)

TMPDIRS		+= ${TMPDIR}

#############################################################################
export TIME
TIME		= $(shell echo ${seperator})\n\
$(shell echo Build Time)\n\
$(shell echo ${seperator})\n\
	User time (seconds): %U\n\
	System time (seconds): %S\n\
	Percent of CPU this job got: %P\n\
	Elapsed (wall clock) time (h:mm:ss or m:ss): %E\n\
	Maximum resident set size (kbytes): %M\n\
	Major (requiring I/O) page faults: %F\n\
	Minor (reclaiming a frame) page faults: %R\n\
	Voluntary context switches: %w\n\
	Involuntary context switches: %c\n\
	Command being timed: "%C"\n\
	Exit status: %x

#############################################################################
ifeq "${KERNEL_GIT}" ""
KERNEL_GIT	= ${MAINLINEURI}
endif
ifeq "${KERNEL_BRANCH}" ""
KERNEL_BRANCH	= master
endif
ifeq "${KERNELDIR}" ""
KERNELDIR	= ${SRCDIR}/linux
endif

#############################################################################
KERNEL_BUILD	= $(call buildroot,${BUILDDIR})/kernel-clang
KERNELGCC_BUILD	= $(call buildroot,${BUILDDIR})/kernel-gcc
KERNEL_ENV	+= KBUILD_OUTPUT=${KERNEL_BUILD} HOSTCC="${CLANG}" CC="${CLANGCC}" LD="${LLVMLINK}" AR="${AR}"
KERNELGCC_ENV	+= KBUILD_OUTPUT=${KERNELGCC_BUILD}

KERNEL_CLANG_LOG= ${TMPDIR}/kernel-clang-stderr.log
ERROR_ZIP	= ${TMPDIR}/llvmlinux-clang-error.zip

#############################################################################
GCC             ?= gcc

ifneq "${BITCODE}" ""
export CLANG
CLANGCC		= ${ARCH_ALL_BINDIR}/clang-emit-bc.sh ${CCOPTS} -fno-integrated-as
LLVMLINK	= ${ARCH_ALL_BINDIR}/llvm-link-bc.sh
AR			= ${ARCH_ALL_BINDIR}/ar.sh
else
CLANGCC		= ${CLANG} ${CCOPTS}
LLVMLINK	= ld
endif

CFLAGS += "-Wno-incompatible-pointer-types-discards-qualifiers"
ifneq ("${ARCH}", "")
MAKE_FLAGS	+= ARCH=${ARCH}
endif
ifneq ("${CROSS_COMPILE}", "")
MAKE_FLAGS	+= CROSS_COMPILE=${CROSS_COMPILE}
endif
ifneq ("${GCC_TOOLCHAIN}", "")
MAKE_FLAGS	+= GCC_TOOLCHAIN=${GCC_TOOLCHAIN}
endif
ifneq ("${MAXLOAD}", "")
KERNEL_VAR	+= -l${MAXLOAD}
endif
ifneq ("${JOBS}", "")
KERNEL_VAR	+= -j${JOBS}
endif
ifneq ("${CFLAGS}", "")
KERNEL_VAR	+= CFLAGS_KERNEL="${CFLAGS}" CFLAGS_MODULE="${CFLAGS}"
endif
KERNEL_VAR	+= CONFIG_DEBUG_INFO=1
KERNEL_VAR	+= CONFIG_DEBUG_SECTION_MISMATCH=y
KERNEL_VAR	+= CONFIG_NO_ERROR_ON_MISMATCH=y
#KERNEL_VAR	+= KALLSYMS_EXTRA_PASS=1
KERNEL_VAR	+= ${EXTRAFLAGS}

list-var: list-buildroot
	@( $(call which,clang); \
	$(call which,gcc); \
	$(call which,${CROSS_COMPILE}gcc); \
	echo ${seperator}; \
	$(call echovar,ARCH); \
	$(call echovar,BITCODE); \
	$(call echovar,CC); \
	$(call echovar,CFLAGS); \
	$(call echovar,CLANG); \
	$(call echovar,CLANGCC); \
	$(call echovar,COMPILER_PATH); \
	$(call echovar,CROSS_COMPILE); \
	$(call echovar,CROSS_GCC); \
	$(call echovar,GENERIC_PATCH_DIR); \
	$(call echovar,HOST); \
	$(call echovar,HOST_TRIPLE); \
	$(call echovar,JOBS); \
	$(call echovar,KBUILD_OUTPUT); \
	$(call echovar,KERNELDIR); \
	$(call echovar,KERNEL_BUILD); \
	$(call echovar,KERNEL_ENV); \
	$(call echovar,KERNEL_VAR); \
	$(call echovar,MAKE_FLAGS); \
	$(call echovar,MARCH); \
	$(call echovar,MAXLOAD); \
	$(call echovar,MFLOAT); \
	$(call echovar,PATH); \
	$(call echovar,TMPDIR); \
	$(call echovar,USE_CCACHE); \
	$(call echovar,V); \
	echo ${seperator}; \
	echo "${CLANG} -print-file-name=include"; \
	${CLANG} -print-file-name=include; \
	echo 'kernel-build -> $(call make-kernel,${KERNELDIR},,${CHECKER},${KERNEL_ENV} ${CHECK_VARS})'; \
	echo 'kernel-gcc-build -> $(call make-kernel,${KERNELDIR},${SPARSE},,${KERNELGCC_ENV} CC?="${CCACHE} ${CROSS_COMPILE}${GCC}")'; \
	) | sed 's|${TOPDIR}/||g'

#############################################################################
catfile		= ([ -f ${1} ] && cat ${1})
add_patches	= $(addprefix ${1}/,$(shell $(call catfile,${1}/series.target) || $(call catfile,${1}/series)))
KERNEL_PATCH_DIR+= ${ARCH_ALL_PATCHES} ${ARCH_ALL_PATCHES}/${KERNEL_REPO_PATCHES}

# ${1}=logdir ${2}=toolchain ${3}=testname
sizelog	= ${1}/${2}-${ARCH}-`date +%Y-%m-%d_%H:%M:%S`-kernel-size.log

KERNEL_SIZE_CLANG_LOG	= clang-`date +%Y-%m-%d_%H:%M:%S`-kernel-size.log
KERNEL_SIZE_GCC_LOG	= gcc-`date +%Y-%m-%d_%H:%M:%S`-kernel-size.log

get-kernel-version	= [ ! -d ${1} ] || (cd ${1} && echo "src/$(notdir ${1}) version `make -s kernelversion 2>/dev/null` commit `git rev-parse HEAD`")
get-kernel-size		= mkdir -p ${TOPLOGDIR} ; \
			( ${2} --version | head -1 ; \
			cd ${3} && wc -c ${KERNEL_SIZE_ARTIFACTS} ) \
			| tee $(call sizelog,${TOPLOGDIR},${1})
make-kernel		= (cd ${1} && ${2} time ${3} make ${MAKE_FLAGS} ${KERNEL_VAR} ${4} ${KERNEL_MAKE_TARGETS} ${5})
zip-error		= ($(call banner,Error file: ${1}); cat "${1}"; \
				$(call banner,Error file: ${1}); \
				cd `dirname "${1}"`; \
				rm -f ${2}; \
				zip "${2}" `basename "${1}"` `egrep "^clang.*diagnostic msg: ${TMPDIR}/" ${1} | sed 's|^.*/||'`; \
				$(call banner,Error log and files: ${2}); \
			)
save-log		= (echo '${1}'; rm -f "${2}"; ${1} 2> >(tee "${2}") \
				|| ($(call zip-error,${2},${3}); false); \
			)

#############################################################################
KERNEL_TARGETS_CLANG	= kernel-[fetch,patch,configure,build,clean,sync]
KERNEL_TARGETS_GCC	= kernel-gcc-[configure,build,clean,sync] kernel-gcc-sparse
KERNEL_TARGETS_APPLIED	= kernel-patch-applied
KERNEL_TARGETS_CLEAN	= tmp-clean
KERNEL_TARGETS_VERSION	= kernel-version

#############################################################################

KERNEL_BISECT_START_DATE := 2012-11-01

#############################################################################
TARGETS_BUILD		+= ${KERNEL_TARGETS_CLANG} ${KERNEL_TARGETS_GCC} ${KERNEL_TARGETS_APPLIED} ${KERNEL_TARGETS_CLEAN}
CLEAN_TARGETS		+= ${KERNEL_TARGETS_CLEAN}
FETCH_TARGETS		+= kernel-fetch
HELP_TARGETS		+= kernel-help
MRPROPER_TARGETS	+= kernel-clean kernel-gcc-clean
PATCH_APPLIED_TARGETS	+= ${KERNEL_TARGETS_APPLIED}
RAZE_TARGETS		+= kernel-raze
SETTINGS_TARGETS	+= kernel-settings
SYNC_TARGETS		+= kernel-sync
VERSION_TARGETS		+= ${KERNEL_TARGETS_VERSION}

.PHONY:			${KERNEL_TARGETS_CLANG} ${KERNEL_TARGETS_GCC} ${KERNEL_TARGETS_APPLIED} ${KERNEL_TARGETS_CLEAN} ${KERNEL_TARGETS_VERSION}

#############################################################################
SCAN_BUILD		:= scan-build
SCAN_BUILD_FLAGS	:= --use-cc=${CLANG}
ENABLE_CHECKERS		?=
DISABLE_CHECKERS	?= core.CallAndMessage,core.UndefinedBinaryOperatorResult,core.uninitialized.Assign,cplusplus.NewDelete,deadcode.DeadStores,security.insecureAPI.getpw,security.insecureAPI.gets,security.insecureAPI.mktemp,security.insecureAPI.mktemp,unix.MismatchedDeallocator
ifdef ENABLE_CHECKERS
	SCAN_BUILD_FLAGS += -enable-checker ${ENABLE_CHECKERS}
endif
ifdef DISABLE_CHECKERS
	SCAN_BUILD_FLAGS += -disable-checker ${DISABLE_CHECKERS}
endif

#############################################################################
kernel-help:
	@echo
	@echo "These are the kernel make targets:"
	@echo "* make kernel-[fetch,patch,configure,build,sync,clean]"
	@echo "* make kernel-gcc-[configure,build,sync,clean]"
	@echo "               fetch      - clone kernel code"
	@echo "               patch      - patch kernel code"
	@echo "               configure  - configure kernel code (add .config file, etc)"
	@echo "               build      - build kernel code"
	@echo "               sync       - clean, unpatch, then git pull kernel code"
	@echo "               clean      - clean, unpatch kernel code"
	@echo "* make kernel-gcc-build-pristine  - build gcc kernel without patches"
	@echo "* make kernel-gcc-sparse  - build gcc kernel with sparse"
	@echo "* make kernels		 - build kernel with both clang and gcc"
	@echo
	@echo "* make BITCODE=1          - Output llvm bitcode to *.bc files"
	@echo "* make NOLOG=1            - Don't log stderr to a seperate file (used for error zipfile)"
	@echo
	@echo "* make kernel-bisect-start KERNEL_BISECT_START_DATE=2012-11-01"
	@echo "                          - start bisect process at date ^^^"
	@echo "* make kernel-bisect-good - mark as good"
	@echo "* make kernel-bisect-bad  - mark as bad"
	@echo "* make kernel-bisect-skip - skip revision"
	@echo
	@echo "These also include static analysis:"
	@echo "* make kernel-scan-build  - Run build through scan-build and generate"
	@echo "                            HTML output to trace the found issue"
	@echo "* make kernel-check-build - Use the kbuild's \$CHECK to run clang's"
	@echo "                            static analyzer"
	@echo
	@echo "* make kernel-patch-status - Read status of patches from patch triage spreadsheet"
	@echo "* make kernel-patch-status-leftover"
	@echo "                          - Patches on the triage list which aren't used for this triage"
	@echo
	@echo "Warning collection:"
	@echo "* make warning-save      - Save build log to tmp/build.log"
	@echo "* make warning-grep      - Grep out warnings to tmp/build-warnings.log"
	@echo "* make warning-sort      - Sort out warnings from tmp/build-warnings.log"
	@echo "* make warning-kind      - Break down warnings by type from tmp/build-warnings.log"

##############################################################################
CHECKPOINT_TARGETS		+= kernel-checkpoint
CHECKPOINT_KERNEL_CONFIG	= ${CHECKPOINT_DIR}/kernel.config
CHECKPOINT_KERNEL_PATCHES	= ${CHECKPOINT_PATCHES}/kernel
kernel-checkpoint: kernel-quilt
	@$(call banner,Checkpointing kernel)
	@cp ${KERNEL_CFG} ${CHECKPOINT_KERNEL_CONFIG}
	@$(call checkpoint-patches,${PATCHDIR},${CHECKPOINT_KERNEL_PATCHES})

#############################################################################
kernel-settings:
	@(echo "# Kernel settings" ; \
	$(call prsetting,KERNEL_GIT,${KERNEL_GIT}) ; \
	$(call prsetting,KERNEL_BRANCH,${KERNEL_BRANCH}) ; \
	$(call prsetting,KERNEL_TAG,${KERNEL_TAG}) ; \
	$(call gitdate,${KERNELDIR},KERNEL_DATE) ; \
	$(call gitcommit,${KERNELDIR},KERNEL_COMMIT) ; \
	$(call prsetting,KERNELDIR,${KERNELDIR}) ; \
	[ -n "${CHECKPOINT}" ] && $(call prsetting,KERNEL_CFG,${CHECKPOINT_KERNEL_CONFIG}) \
	|| $(call prsetting,KERNEL_CFG,${KERNEL_CFG}) ; \
	) | $(call configfilter)

include ${ARCHDIR}/all/quilt.mk
include ${ARCHDIR}/all/quilt2git.mk
include ${ARCHDIR}/all/git-submit.mk
include ${ARCHDIR}/all/known-good.mk
include ${ARCHDIR}/all/buildbot.mk

#############################################################################
# The shared kernel is a bare repository of Linus' kernel.org kernel
# It serves as a git alternate for all the other target specific kernels.
# This is purely meant as a disk space saving effort.
kernel-shared: ${SHARED_KERNEL}
${SHARED_KERNEL}:
	@$(call banner,Cloning shared kernel repo...)
	@$(call gitclone,--bare ${MAINLINEURI},$@)
	@grep -q '\[remote "origin"\]' $@/config \
		|| echo -e "[remote \"origin\"]\n\turl = ${MAINLINEURI}" >> $@/config;

#############################################################################
kernel-raze::
	@$(call banner,Razing kernel)
	@rm -rf ${KERNELDIR} ${BUILDDIR}
	@$(call notshared,rm -rf ${SHARED_KERNEL})
	@rm -rf $(addsuffix /*,${LOGDIR} ${TMPDIR})
	@$(call leavestate,${STATEDIR},*)

#############################################################################
kernel-fetch: ${STATEDIR}/kernel-fetch
${STATEDIR}/kernel-fetch: ${STATEDIR}/prep
#	@$(call banner,Cloning kernel...)
#	@mkdir -p ${SRCDIR}
#	@[ -z "${KERNEL_BRANCH}" ] || $(call echo,Checking out kernel branch...)
#	$(call gitclone,--reference $< ${KERNEL_GIT} -b ${KERNEL_BRANCH},${KERNELDIR})
#	@if [ -n "${KERNEL_COMMIT}" ] ; then \
#		$(call echo,Checking out commit-ish kernel...) ; \
#		$(call gitcheckout,${KERNELDIR},${KERNEL_BRANCH},${KERNEL_COMMIT}) ; \
#	elif [ -n "${KERNEL_TAG}" ] ; then \
#		$(call echo,Checking out tagged kernel...) ; \
#		$(call gitmove,${KERNELDIR},${KERNEL_TAG},tag-${KERNEL_TAG}) ; \
#		$(call gitcheckout,${KERNELDIR},${KERNEL_TAG}) ; \
#	fi
	$(call state,$@,kernel-patch)

#############################################################################
kernel-patch: ${STATEDIR}/kernel-patch
${STATEDIR}/kernel-patch: ${STATEDIR}/kernel-fetch ${STATEDIR}/kernel-quilt
#	@$(call banner,Patching kernel...)
#	@echo ${PATCHDIR}
#	$(call patches_dir,${PATCHDIR},${KERNELDIR}/patches)
#	@$(call optional_gitreset,${KERNELDIR})
#	@$(call patch,${KERNELDIR})
	$(call state,$@,kernel-configure)

#############################################################################
kernel-unpatch: ${STATEDIR}/kernel-fetch ${STATEDIR}/kernel-quilt
#	@$(call banner,Unpatching kernel...)
#	@$(call unpatch,${KERNELDIR})
#	@$(call optional_gitreset,${KERNELDIR})
	@$(call leavestate,${STATEDIR},kernel-patch)

#############################################################################
kernel-patch-applied:
	@$(call banner,Patches applied for Clang kernel)
	@$(call applied,${KERNELDIR})

#############################################################################
kernel-patch-stats: refresh
	@$(call banner,Patch stats for the kernel)
	@$(call patch_series_stats,${PATCHDIR})

#############################################################################
kernel-patch-status:
	@$(call banner,Patch status for the kernel)
	@$(call patch_series_status,${PATCHDIR})

#############################################################################
kernel-patch-status-leftover:
	@$(call banner,Patches which are in the status list which aren\'t being used)
	@$(call patch_series_status_leftover,${PATCHDIR})

#############################################################################
kernel-configure: ${STATEDIR}/kernel-configure
${STATEDIR}/kernel-configure: ${STATEDIR}/kernel-patch ${TMPFS_MOUNT} ${KERNEL_CFG} ${STATE_CLANG_TOOLCHAIN} ${STATE_TOOLCHAIN}
	@make -s build-dep-check
	@$(call banner,Configuring kernel...)
	@mkdir -p ${KERNEL_BUILD}
	cp ${KERNEL_CFG} ${KERNEL_BUILD}/.config
	# git log -1 | awk '/git-svn-id:/ {gsub(".*@",""); print $1}'
	@if [ -n "${CLANGDIR}" ] ; then ( \
		REV=$(call gitsvnrev,${CLANGDIR}); \
		sed -i -e 's/-llvmlinux.*/-llvmlinux-Cr'$$REV'"/g' ${KERNEL_BUILD}/.config; \
	) fi
	@if [ -n "${LLVMDIR}" ] ; then ( \
		REV=$(call gitsvnrev,${LLVMDIR}); \
		sed -i -e "s/-llvmlinux/-llvmlinux-Lr$$REV/g" ${KERNEL_BUILD}/.config; \
	) fi
	echo ${KERNEL_ENV}
	echo ${MAKE_FLAGS}
	(cd ${KERNELDIR} && echo "" | make ${KERNEL_ENV} ${MAKE_FLAGS} oldconfig) \
		2> >(grep -v '^Error in reading or end of file.$$')
	$(call state,$@,kernel-build)

#############################################################################
kernel-allyesconfig kernel-allmodconfig: kernel-%: ${STATEDIR}/kernel-configure
	(cd ${KERNELDIR} && echo "" | make ${KERNEL_ENV} ${MAKE_FLAGS} $*)

#############################################################################
kernel-menuconfig: ${STATEDIR}/kernel-configure
	@make -C ${KERNELDIR} ${KERNEL_ENV} ${MAKE_FLAGS} menuconfig
	@$(call leavestate,${STATEDIR},kernel-build)

kernel-cmpconfig: ${STATEDIR}/kernel-configure
	diff -Nau ${KERNEL_CFG} ${KERNEL_BUILD}/.config

kernel-cpconfig: ${STATEDIR}/kernel-configure
	@cp -v ${KERNEL_BUILD}/.config ${KERNEL_CFG}

#############################################################################
kernel-cscope: ${STATEDIR}/kernel-configure
	@make -C ${KERNELDIR} ${KERNEL_ENV} ${MAKE_FLAGS} cscope
cscope:
	@(cd ${KERNELDIR}; cscope)
kernel-tags: ${STATEDIR}/kernel-configure
	make -C ${KERNELDIR} ${KERNEL_ENV} ${MAKE_FLAGS} tags

#############################################################################
kernel-gcc-configure: ${STATEDIR}/kernel-gcc-configure
${STATEDIR}/kernel-gcc-configure: ${STATEDIR}/kernel-patch ${TMPFS_MOUNT} ${KERNEL_CFG} ${STATE_TOOLCHAIN}
	@make -s build-dep-check
	@$(call banner,Configuring gcc kernel...)
	@mkdir -p ${KERNELGCC_BUILD}
	cp ${KERNEL_CFG} ${KERNELGCC_BUILD}/.config
	(cd ${KERNELDIR} && echo "" | ${KERNELGCC_ENV} make ${MAKE_FLAGS} oldconfig)
	$(call state,$@,kernel-gcc-build)

#############################################################################
kernel-gcc-allyesconfig: ${STATEDIR}/kernel-gcc-configure
	(cd ${KERNELDIR} && echo "" | ${KERNELGCC_ENV} make ${MAKE_FLAGS} allyesconfig)

#############################################################################
kernel-build:: ${STATEDIR}/kernel-build
${STATEDIR}/kernel-build: ${STATEDIR}/kernel-configure
	@[ -d ${KERNEL_BUILD} ] || ($(call leavestate,${STATEDIR},kernel-configure) && ${MAKE} kernel-configure)
	@$(MAKE) kernel-quilt-link-patches
	@$(call banner,Building kernel with clang...)
	@[ -z "${CCACHE_DIR}" ] || mkdir -p ${CCACHE_DIR}
	@if [ -z "${NOLOG}" ] ; then \
		$(call save-log,$(call make-kernel,${KERNELDIR},,${CHECKER},${KERNEL_ENV} ${CHECK_VARS}),${KERNEL_CLANG_LOG},${ERROR_ZIP}) || (${MAKE} bb_manifest; false) ; \
	else \
		$(call make-kernel,${KERNELDIR},,${CHECKER},${KERNEL_ENV} ${CHECK_VARS}); \
	fi
	@$(call banner,Successfully Built kernel with clang!)
	@$(call get-kernel-size,clang,${CLANG},${KERNEL_BUILD})
	$(call state,$@,done)

#############################################################################
kernel-gcc-build: ${STATEDIR}/kernel-gcc-build
${STATEDIR}/kernel-gcc-build: ${STATEDIR}/kernel-gcc-configure
	@[ -d ${KERNELGCC_BUILD} ] || ($(call leavestate,${STATEDIR},kernel-gcc-configure) && ${MAKE} kernel-gcc-configure)
	@$(MAKE) kernel-quilt-link-patches
	@$(call banner,Building kernel with gcc...)
	@[ -z "${CCACHE_DIR}" ] || mkdir -p ${CCACHE_DIR}
	$(call make-kernel,${KERNELDIR},${SPARSE},,${KERNELGCC_ENV} CC?="${CCACHE} ${CROSS_COMPILE}${GCC}")
	@$(call get-kernel-size,gcc,${CROSS_COMPILE}${GCC},${KERNELGCC_BUILD})
	$(call state,$@,done)

#############################################################################
kernel-build-pristine:
	@$(call banner,Building pristine kernel...)
	@$(MAKE) kernel-unpatch NO_PATCH=1 series kernel-build

#############################################################################
kernel-gcc-build-pristine:
	@$(call banner,Building pristine gcc kernel...)
	@$(MAKE) kernel-unpatch NO_PATCH=1 series kernel-gcc-build

#############################################################################
kernel-scan-build: ${STATE_CLANG_TOOLCHAIN} ${STATE_TOOLCHAIN} ${STATEDIR}/kernel-configure
	@$(call assert_found_in_path,ccc-analyzer,"(prebuilt and native clang doesn't always provide ccc-analyzer)")
	@$(eval CHECKER := ${SCAN_BUILD} ${SCAN_BUILD_FLAGS})
	@$(call banner,Enabling clang static analyzer: ${CHECKER})
	${MAKE} CHECKER="${CHECKER}" CC=ccc-analyzer kernel-build

#############################################################################
kernel-check-build: ${STATE_CLANG_TOOLCHAIN} ${STATE_TOOLCHAIN} ${STATEDIR}/kernel-configure
	@$(eval CHECK_VARS := C=1 CHECK=${CLANG} CHECKFLAGS=--analyze)
	@$(call banner,Enabling clang static analyzer as you go: ${CLANG} --analyze)
	${MAKE} CHECK_VARS="${CHECK_VARS}" kernel-build

#############################################################################
kernel-build-force kernel-gcc-build-force: %-force:
	@rm -f ${STATEDIR}/$*
	${MAKE} $*

##############################################################################
# To be defined by target Makefiles
kernel-test::
kernel-gcc-test::

#############################################################################
kernel-rebuild kernel-gcc-rebuild: kernel-%rebuild:
	@$(call leavestate,${STATEDIR},kernel-$*build)
	@$(MAKE) kernel-$*build

#############################################################################
kernel-rebuild-verbose kernel-gcc-rebuild-verbose: kernel-%rebuild-verbose:
	@$(call leavestate,${STATEDIR},kernel-$*build)
	@$(MAKE) JOBS=1 V=1 kernel-$*build

#############################################################################
kernel-gcc-sparse:
	@$(call assert_found_in_path,sparse)
	${MAKE} kernel-gcc-configure
	@$(call patches_dir,${PATCHDIR},${KERNELDIR}/patches)
	@$(call banner,Building unpatched gcc kernel for eventual analysis with sparse...)
	@$(call unpatch,${KERNELDIR})
	${MAKE} kernel-gcc-build-force
	@$(call banner,Rebuilding patched gcc kernel with sparse (changed files only)...)
	@$(call patch,${KERNELDIR})
	${MAKE} SPARSE=C=1 kernel-gcc-build-force

#############################################################################
kernels: kernel-build kernel-gcc-build
kernels-clean: kernel-clean kernel-gcc-clean

#############################################################################
kernel-shared-sync:
	@$(call banner,Syncing shared kernel.org kernel...)
	@$(call git,${SHARED_KERNEL},fetch origin +refs/heads/*:refs/heads/*)

#############################################################################
kernel-sync: ${STATEDIR}/kernel-fetch kernel-clean kernel-shared-sync
	@$(call banner,Syncing kernel...)
	@$(call check_llvmlinux_commit,${CONFIG})
	-@$(call gitabort,${KERNELDIR})
	@$(call optional_gitreset,${KERNELDIR})
	$(call gitref,${KERNELDIR},${SHARED_KERNEL})
	@$(call gitsync,${KERNELDIR},${KERNEL_COMMIT},${KERNEL_BRANCH},${KERNEL_TAG})

#############################################################################
kernel-clean kernel-mrproper:: kernel-unpatch
	@$(call makemrproper,${KERNELDIR})
	@rm -f ${LOGDIR}/*.log
	@rm -rf ${KERNEL_BUILD}
	@$(call leavestate,${STATEDIR},kernel-quilt kernel-patch kernel-configure kernel-build)
	@$(call banner,Clang compiled Kernel is now clean)
kernel-mrproper:: kernel-quilt-clean

#############################################################################
kernel-gcc-clean kernel-gcc-mrproper: kernel-unpatch
	@$(call makemrproper,${KERNELGCC})
	@rm -rf ${KERNELGCC_BUILD}
	@$(call leavestate,${STATEDIR},kernel-gcc-configure kernel-gcc-build)
	@$(call banner,Gcc compiled Kernel is now clean)

#############################################################################
kernel-shell-for-build: kernel-configure
	@echo "PATH='${COMPILER_PATH}/bin:${PATH}'" \
		"GCC_TOOLCHAIN=${COMPILER_PATH}" \
		"ARCH=${ARCH}" \
		"CROSS_COMPILE='${CROSS_COMPILE}'" \
		"KBUILD_OUTPUT=${KERNEL_BUILD}" \
		"HOSTCC='${CLANG}'" \
		"CC='${CLANGCC}'" \
		"KERNEL_SRC_DIR='${KERNELDIR}'" \
		"KERNEL_BUILD_DIR='${KERNEL_BUILD}'" \
		"KERNEL_BUILD_PARAMETERS='${MAKE_FLAGS} ${KERNEL_VAR} ${KERNEL_MAKE_TARGETS}'" \
		"BUILD_COMMAND='make -C ${KERNEL_BUILD} ${MAKE_FLAGS} ${KERNEL_VAR} ${KERNEL_MAKE_TARGETS} HOSTCC=${CLANG} CC=${CLANGCC}'"

kernel-gcc-shell-for-build: kernel-gcc-configure
	@echo "PATH='${COMPILER_PATH}/bin:${PATH}'" \
		"ARCH=${ARCH}" \
		"CROSS_COMPILE='${CROSS_COMPILE}'" \
		"KBUILD_OUTPUT=${KERNELGCC_BUILD}" \
		"CC='${CROSS_COMPILE}${GCC}'" \
		"KERNEL_SRC_DIR='${KERNELGCC}'" \
		"KERNEL_BUILD_DIR='${KERNELGCC_BUILD}'" \
		"KERNEL_BUILD_PARAMETERS='${MAKE_FLAGS} ${KERNEL_VAR} ${KERNEL_MAKE_TARGETS}'" \
		"BUILD_COMMAND='make -C ${KERNELGCC_BUILD} ${MAKE_FLAGS} ${KERNEL_VAR} ${KERNEL_MAKE_TARGETS}'"

#############################################################################
BUILD_LOG	= ${TMPDIR}/build.log
BUILD_WARNINGS	= ${TMPDIR}/build-warnings.log
warnings-save:
	@rm -f ${BUILD_LOG}
	${MAKE} ${BUILD_LOG}
${BUILD_LOG}:
	@$(MAKE) kernel-clean kernel-build 2>&1 | tee $@.tmp
	@sed -ir 's:\x1B\[[0-9;]*[mK]::g' $@.tmp
	-@savelog $@
	@mv $@.tmp $@
warnings-grep: ${BUILD_WARNINGS}
${BUILD_WARNINGS}: ${BUILD_LOG}
	@grep ': warning:' $< > $@
warnings-sort: ${BUILD_WARNINGS}
	@sort -k3,4 $<
warnings-kind: ${BUILD_WARNINGS}
	@sort -k3,4 $< \
		| sed -e 's/__check_.* /__check_* /g' \
		| cut -d' ' -f2- | sort -u

#############################################################################
kernel-version:
	@echo -e -n "KERNEL\t\t= "
	@$(call get-kernel-version,${KERNELDIR})

#############################################################################
kernel-bisect-start kernel-gcc-bisect-start: kernel-%bisect-start: kernel-%mrproper
	@(cd ${KERNELDIR} ; \
		git bisect reset ; \
		git bisect start ; \
		git bisect bad ; \
		git bisect good `git log --pretty=format:'%ai §%H'\
			| grep ${KERNEL_BISECT_START_DATE} \
			| head -1 \
			| cut -d"§" -f2` )

kernel-bisect-skip kernel-gcc-bisect-skip: kernel-%bisect-skip: kernel-%clean
	@$(call git,${KERNELDIR},bisect skip)

kernel-bisect-good kernel-gcc-bisect-good: kernel-%bisect-good: kernel-%clean
	@$(call git,${KERNELDIR},bisect good)

kernel-bisect-bad kernel-gcc-bisect-bad: kernel-%bisect-bad: kernel-%clean
	@$(call git,${KERNELDIR},bisect bad)

kernel-callgraph:
	(cd ${TARGETDIR} && make kernel-clean && make EXTRAFLAGS=CFLAGS_KERNEL='" -mllvm -print-call-graph"' kernel-build)
	(cd ${KERNELDIR} &&  find . -name "*_.dot" > dotfiles && tar czf ${TARGETDIR}/build/kernel-clang/dotfiles.tgz -T dotfiles && rm -f dotfiles)
	(cd ${TARGETDIR}/build/kernel-clang && tar xzf dotfiles.tgz && rm -f dotfiles.tgz)
	echo ${KERNELDIR} > ${TARGETDIR}/build/kernel-clang/callgraph_srcdir
	(cd ${KERNELDIR} &&  find . -name "*_.dot" | xargs rm)

#############################################################################
tmp tmpdir: ${TMPDIR}
${TMPDIR}:
	@mkdir -p $@
tmp-clean:
	rm -rf ${TMPDIR}/*

#############################################################################
# The order of these includes is important
include ${TESTDIR}/test.mk
include ${TOOLSDIR}/tools.mk
include ${ARCHDIR}/all/ccache.mk
include ${ARCHDIR}/all/kernel-stats.mk
include ${ARCHDIR}/all/kernel-viz.mk
