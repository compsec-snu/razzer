#############################################################################
# Copyright (c) 2012-2014 Behan Webster
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

# Must be included by all.mk

#############################################################################
ifeq "${KERNEL_REPO_PATCHES}" ""
ifneq "${KERNEL_TAG}" ""
KERNEL_REPO_PATCHES = ${KERNEL_TAG}
else
KERNEL_REPO_PATCHES = ${KERNEL_BRANCH}
endif
endif

#############################################################################
GENERIC_PATCH_DIR	= $(filter-out %${KERNEL_REPO_PATCHES},$(filter-out ${TARGETDIR}/patches,${KERNEL_PATCH_DIR}))
GENERIC_PATCH_SERIES	= $(addsuffix /series,$(GENERIC_PATCH_DIR))
TARGET_PATCH_SERIES	= ${PATCHDIR}/series
SERIES_DOT_TARGET	= ${TARGET_PATCH_SERIES}.target
ALL_PATCH_SERIES	= ${GENERIC_PATCH_SERIES} ${SERIES_DOT_TARGET}
PATCH_FILTER_REGEX	= .*
KERNEL_LOG_CACHE	= $(dir ${KERNEL_BUILD})git-log-cache.txt.gz
KERNEL_LOG_DB		= ${KERNEL_LOG_CACHE:%.txt.gz=%.db}

#############################################################################
checkfilefor	= grep -q ${2} ${1} || echo "${2}${3}" >> ${1}
reverselist	= mkdir -p ${TMPDIR}; for DIR in ${1} ; do echo $$DIR; done | tac
ln_if_new	= ls -l "${2}" 2>&1 | grep -q "${1}" || ln -fsv "${1}" "${2}"
mv_n_ln		= mv "${1}" "${2}" ; ln -sv "${2}" "${1}"
tar_patches	= mkdir -p $(dir $@); tar chfj ${1} patches/series `grep -v '^\#' patches/series | sed -e 's|^|patches/|'`
link_files	= $(call banner,Symlink ${1} "->" ${2}); rm -f ${1}; ln -sf ${2} ${1}

#############################################################################
QUILT_TARGETS		= kernel-quilt kernel-quilt-clean kernel-quilt-generate-series \
			kernel-quilt-update-series-dot-target kernel-quilt-link-patches \
			kernel-patches-tar kernel-quilt-clean-broken-symlinks \
			list-kernel-patches list-kernel-patches-path \
			list-kernel-patches-series list-kernel-maintainer \
			list-kernel-checkpatch

TARGETS_BUILD		+= ${QUILT_TARGETS}
CLEAN_TARGETS		+= kernel-quilt-clean
HELP_TARGETS		+= kernel-quilt-help
MRPROPER_TARGETS	+= kernel-quilt-mrproper
RAZE_TARGETS		+= kernel-quilt-raze
SETTINGS_TARGETS	+= kernel-quilt-settings

.PHONY:			${QUILT_TARGETS} kernel-quilt-help kernel-quilt-settings

#############################################################################
kernel-quilt-help:
	@echo
	@echo "These are the quilt (patching) make targets:"
	@echo "* make kernel-quilt - Setup kernel(s) to be patched by quilt"
	@echo "* make kernel-quilt-clean - Remove quilt setup"
	@echo "* make kernel-quilt-generate-series (or make series)"
	@echo "			- Build kernel quilt series file"
	@echo "                   - You can specify a list of patches with PATCH_LIST"
	@echo "                   - or a patch regex with PATCH_FILTER_REGEX"
	@echo "                   - or list a predefined patches/series.foo file to use with SERIES=foo"
	@echo "                   - or use no patches by setting NO_PATCH=1"
	@echo "* make kernel-quilt-update-series-dot-target"
	@echo "			- Save updates from kernel quilt series file to series.target file"
	@echo "* make kernel-quilt-link-patches"
	@echo "	 		- Link kernel patches to target patches directory"
	@echo "* make refresh	- Rebuild series file and quilt patch symlinks"
	@echo "* make kernel-patches-tar"
	@echo "			- build a patches.tar.bz2 file containing all the patches for this target"
	@echo "* make kernel-quilt-clean-broken-symlinks"
	@echo "			- Remove links to deleted kernel patches from target patches directory"
	@echo "* make list-kernel-patches-path"
	@echo "			- List the order in which kernel patches directories are searched for patch filenames"
	@echo "* make list-kernel-patches-series"
	@echo "			- List the series files which will make up the target/*/patches/series file"
	@echo "* make list-kernel-patches"
	@echo "			- List which kernel patches will be applied"
	@echo
	@echo "* make list-kernel-checkpatch [PATCH_FILTER_REGEX=<regex>]"
	@echo "			- List which kernel maintainers should be contacted for each patch"
	@echo "			- NOFAIL=1 hides the failure details"
	@echo "			- NOPASS=1 hides passes (if all you care about is FAILs)"
	@echo "* make list-kernel-maintainer [PATCH_FILTER_REGEX=<regex>]"
	@echo "			- List which kernel maintainers should be contacted for each patch"

#############################################################################
kernel-quilt-settings:
	@($(call prsetting,KERNEL_REPO_PATCHES,${KERNEL_REPO_PATCHES}) ; \
	[ -n "${CHECKPOINT}" ] && $(call prsetting,PATCHDIR,${CHECKPOINT_KERNEL_PATCHES}) \
	&& $(call prsetting,KERNEL_PATCH_DIR,${CHECKPOINT_KERNEL_PATCHES}) \
	|| $(call praddsetting,KERNEL_PATCH_DIR,${PATCHDIR} ${PATCHDIR}/${KERNEL_REPO_PATCHES}) ; \
	) | $(call configfilter)

##############################################################################
# Tweak quilt setup to make diffs-of-diffs easier to read
QUILTRC	= ${HOME}/.quiltrc
kernel-quiltrc: ${QUILTRC}
${QUILTRC}:
	@$(call banner,Setting up quilt rc file...)
	@touch $@
	@$(call checkfilefor,$@,QUILT_NO_DIFF_INDEX,=1)
	@$(call checkfilefor,$@,QUILT_NO_DIFF_TIMESTAMPS,=1)
	@$(call checkfilefor,$@,QUILT_PAGER,=)

# Always check ~/.quiltrc
.PHONY: ${QUILTRC}

##############################################################################
# Handle the case of renaming target/%/series -> target/%/series.target
kernel-quilt-series-dot-target: ${SERIES_DOT_TARGET}
${SERIES_DOT_TARGET}:
	@$(call banner,Updating quilt series.target file for kernel...)
	@mkdir -p $(dir $@)
	@[ -f ${TARGET_PATCH_SERIES} ] || touch ${TARGET_PATCH_SERIES}
# Rename target series file to series.target (we will be generating the new series file)
	@[ -e $@ ] || mv ${TARGET_PATCH_SERIES} $@

##############################################################################
# Save any new patches from the generated series file to the series.target file
kernel-quilt-update-series-dot-target: ${SERIES_DOT_TARGET}
	-@[ ! -f ${TARGET_PATCH_SERIES} ] \
		|| [ `stat -c %Z ${TARGET_PATCH_SERIES}` -le `stat -c %Z ${SERIES_DOT_TARGET}` ] \
		|| ($(call echo,Saving quilt changes to series.target file for kernel...) ; \
		diff ${TARGET_PATCH_SERIES} ${SERIES_DOT_TARGET} \
		| perl -ne 'print "$$1\n" if $$hunk>1 && /^< (.*)$$/; $$hunk++ if /^[^<>]/' \
		>> ${SERIES_DOT_TARGET}; touch ${SERIES_DOT_TARGET})

##############################################################################
catuniq = grep --no-filename --invert-match '^\#' $(1) | perl -ne 'print unless $$u{$$_}; $$u{$$_}=1'
ignore_if_empty = perl -ne '{chomp; print "$$_\n" unless -z "${1}/$$_"}'

##############################################################################
# Generate git log cache file
${KERNEL_LOG_CACHE}: ${STATEDIR}/kernel-fetch ${KERNELDIR}/.git
	@mkdir -p $(dir $@)
	@cd ${KERNELDIR} ; \
	if [ -f $@ ] ; then \
		TOPLOG=`git log --pretty=oneline -n1 HEAD`; \
		zgrep -q "$$TOPLOG" $@ && FOUND=1; \
	fi; \
	if [ -z "$$FOUND" ] ; then \
		$(call banner,Building commit log cache...); \
		git log --pretty=oneline | gzip -9c > $@; \
	fi

##############################################################################
${KERNEL_LOG_DB}: ${KERNEL_LOG_CACHE}
	@$(call banner,Building commit db cache...); \
	zcat $< | perl -ne 'BEGIN{use DB_File; tie %d, "DB_File", "$@"} $$d{$$2}=$$1 if /(\S+)\s+(.*)$$/;'

##############################################################################
# Check to see if Subject line of patches are found in the short git log already
check_if_already_commited = perl -e 'use DB_File; tie %d, "DB_File", "${KERNEL_LOG_DB}"; \
	chdir "$(dir ${2})"; \
	undef $$/; \
	foreach $$p (@ARGV) { \
		print STDERR "I: Considering patch $$p\n"; \
		open( F, "$$p" ) || warn "$$p: $$!"; \
		$$f = <F>; \
		close F; \
		if( $$f =~ /Subject: (.*)\n/ && defined $$d{$$1} ) { \
			print STDERR "W: Patch $$p is already applied\n"; \
		} else { \
			print "$$p\n"; \
		} \
	}' ${1} 2>&1 >${2}

##############################################################################
# Generate target series file from relevant kernel quilt patch series files
export NO_PATCH
kernel-quilt-generate-series: ${TARGET_PATCH_SERIES}
${TARGET_PATCH_SERIES}: ${ALL_PATCH_SERIES}
	@if [ -n "${CHECKPOINT}" ] ; then \
		$(call banner,You shouldn\'t be able to get here. $@ shouldn\'t be generated.); \
	elif [ -n "${NO_PATCH}" ] ; then \
		> $@; \
	elif [ -n "${SERIES}" ] ; then \
		[ -f "$@.${SERIES}" ] && (echo "Using $@.${SERIES}"; cp $@.${SERIES} $@) \
			|| (echo "$@.${SERIES} not found"; false); \
	else \
		$(MAKE) kernel-quilt-update-series-dot-target; \
		$(call banner,Building quilt series file for kernel...); \
		if [ -z "$$PATCH_LIST" ] ; then \
			if [ -n '${PATCH_FILTER_REGEX}' ] ; then \
				PATCH_LIST=`$(call catuniq,${ALL_PATCH_SERIES}) | grep "${PATCH_FILTER_REGEX}"`; \
			else \
				PATCH_LIST=`$(call catuniq,${ALL_PATCH_SERIES}) | $(call ignore_if_empty,$(dir $@))`; \
			fi ; \
		fi ; \
		$(MAKE) kernel-quilt-clean-broken-symlinks; \
		$(MAKE) ${KERNEL_LOG_DB}; \
		$(call check_if_already_commited,$$PATCH_LIST,$@) \
			|| (rm -f $@; $(MAKE) kernel-quilt-link-patches); \
	fi
series:
	@echo ${TARGET_PATCH_SERIES} | grep -q checkpoint || ( \
		$(call banner,Forcing quilt series file rebuild for kernel...); \
		rm -f ${TARGET_PATCH_SERIES}; \
		$(MAKE) ${TARGET_PATCH_SERIES}; \
	)
refresh: kernel-quilt-clean kernel-quilt-link-patches series kernel-quilt-clean-broken-symlinks
refresh-sync: kernel-sync refresh

##############################################################################
# Have git ignore extra patch files
QUILT_GITIGNORE	= ${PATCHDIR}/.gitignore
kernel-quilt-ignore-links: ${QUILT_GITIGNORE}
${QUILT_GITIGNORE}: ${GENERIC_PATCH_SERIES}
	@$(call banner,Ignore symbolic linked quilt patches for kernel...)
	@mkdir -p $(dir $@)
	@echo .gitignore > $@
	@echo series >> $@
	@$(call catuniq,${GENERIC_PATCH_SERIES}) >> $@
kernel-quilt-ignore-links-refresh:
	@rm -rf ${QUILT_GITIGNORE}
	@$(MAKE) ${QUILT_GITIGNORE}

##############################################################################
# Remove broken symbolic links to old patches
kernel-quilt-clean-broken-symlinks:
	@$(call banner,Removing broken symbolic linked quilt patches for kernel...)
	@[ -d ${PATCHDIR} ] && file ${PATCHDIR}/* | awk -F: '/broken symbolic link to/ {print $$1}' | xargs --no-run-if-empty rm

##############################################################################
# Move updated patches back to their proper place, and link patch files into target patches dir
kernel-quilt-link-patches: ${QUILT_GITIGNORE}
	@[ -z "${GENERIC_PATCH_SERIES}" ] \
	|| ($(MAKE) kernel-quilt-update-series-dot-target kernel-quilt-clean-broken-symlinks \
	&& $(call banner,Linking quilt patches for kernel...) \
	&& REVDIRS=`$(call reverselist,${KERNEL_PATCH_DIR})` \
	&& for PATCH in `cat ${GENERIC_PATCH_SERIES}` ; do \
		PATCHLINK="${PATCHDIR}/$$PATCH" ; \
		for DIR in $$REVDIRS ; do \
			[ "$$DIR" != "${PATCHDIR}" ] || continue ; \
			if [ -f "$$DIR/$$PATCH" -a ! -L "$$DIR/$$PATCH" ] ; then \
				if [ -f "$$PATCHLINK" -a ! -L "$$PATCHLINK" ] ; then \
					$(call mv_n_ln,$$PATCHLINK,$$DIR/$$PATCH) ; \
				else \
					$(call ln_if_new,$$DIR/$$PATCH,$$PATCHLINK) ; \
				fi ; \
				break; \
			fi ; \
		done ; \
	done | sed -e 's|${TARGETDIR}|.|g; s|${TOPDIR}|...|g')
	@$(MAKE) kernel-quilt-ignore-links-refresh
	@$(MAKE) ${TARGET_PATCH_SERIES}

##############################################################################
KERNEL_PATCHES_TAR = patches.tar.bz2
kernel-patches-tar: ${KERNEL_PATCHES_TAR}
${KERNEL_PATCHES_TAR}: kernel-quilt-link-patches
	@$(call tar_patches,$@)
	@$(call banner,Created $@)

##############################################################################
QUILT_STATE	= ${STATEDIR}/kernel-quilt
kernel-quilt: ${QUILT_STATE}
${QUILT_STATE}: ${STATEDIR}/prep ${STATEDIR}/kernel-fetch
	@$(MAKE) ${QUILTRC} kernel-quilt-link-patches
	@$(call banner,Quilted kernel...)
	$(call state,$@,kernel-patch)

##############################################################################
# List patch search path
list-kernel-patches-path:
	@$(call reverselist,${KERNEL_PATCH_DIR})

##############################################################################
# List series file paths
list-kernel-patches-series:
	@echo $(subst ${TOPDIR}/,,${GENERIC_PATCH_SERIES}) | sed -e 's/ /\n/g'

##############################################################################
# List all patches which are being applied to the kernel
list-kernel-patches:
	@REVDIRS=`$(call reverselist,${KERNEL_PATCH_DIR})` ; \
	for PATCH in `cat ${ALL_PATCH_SERIES}` ; do \
		for DIR in $$REVDIRS ; do \
			if [ -f "$$DIR/$$PATCH" -a ! -L "$$DIR/$$PATCH" ] ; then \
				echo "$$DIR/$$PATCH" ; \
				break; \
			fi ; \
		done ; \
	done

##############################################################################
# List maintainers who are relevant to a particular patch
# You can specify a regex to narrow down the patches by setting PATCH_FILTER_REGEX
# e.g. make PATCH_FILTER_REGEX=vlais\* list-kernel-maintainer
kernel-checkpatch kernel-get_maintainer: kernel-%: list-kernel-%
list-kernel-checkpatch list-kernel-get_maintainer: list-kernel-%: kernel-fetch
	@$(call banner,Running $* for patches PATCH_FILTER_REGEX="${PATCH_FILTER_REGEX}")
	@if [ $@ = list-kernel-checkpatch ] ; then \
		[ -n "$$NOPASS" ] || echo "You can suppress passes by setting env variable NOPASS=1"; \
		[ -n "$$NOFAIL" ] || echo "You can suppress verbose failures by setting env variable NOFAIL=1"; \
	fi
	@(REVDIRS=`$(call reverselist,${KERNEL_PATCH_DIR})` ; \
	cd ${KERNELDIR} ; \
	[ -n "$$PATCH_LIST" ] || PATCH_LIST=`cat ${ALL_PATCH_SERIES} | grep "${PATCH_FILTER_REGEX}"`; \
	for PATCH in $$PATCH_LIST ; do \
		for DIR in $$REVDIRS ; do \
			if [ -f "$$DIR/$$PATCH" -a ! -L "$$DIR/$$PATCH" ] ; then \
				OUTPUT=`./scripts/$*.pl "$$DIR/$$PATCH"` ; \
				if echo "$$OUTPUT" | grep -q "total: 0 errors, 0 warnings," ; then \
					[ -z "$$NOPASS" ] && echo -e "${PASS}\t$$DIR/$$PATCH" ; \
				else \
					[ $@ = list-kernel-checkpatch ] && echo -e -n "${FAIL}\t" ; \
					echo "$$DIR/$$PATCH" ; \
					[ -n "$$NOFAIL" ] || echo -e "${seperator}\n$$OUTPUT\n${seperator}" ; \
				fi ; \
				break; \
			fi ; \
		done ; \
	done) | sed -e 's|$(TOPDIR)/||g'

##############################################################################
kernel-quilt-clean kernel-quilt-mrproper kernel-quilt-raze: ${SERIES_DOT_TARGET}
	@$(call banner,Removing symbolic linked quilt patches for kernel...)
	@rm -f ${QUILT_GITIGNORE}
	@[ ! -f ${SERIES_DOT_TARGET} ] || rm -f ${TARGET_PATCH_SERIES}
	@for FILE in ${PATCHDIR}/* ; do \
		[ ! -L $$FILE ] || rm $$FILE; \
	done
	@rm -f ${QUILT_STATE}
	@$(call banner,Quilting cleaned)

##############################################################################
kernel-quilt-pop:
	-@(cd ${KERNELDIR} && quilt pop -a)
kernel-quilt-push:
	-@(cd ${KERNELDIR} && quilt push -a)
kernel-quilt-refresh:
	-@(cd ${KERNELDIR} && quilt refresh)
kernel-quilt-pop-push: kernel-quilt-pop kernel-quilt-push
