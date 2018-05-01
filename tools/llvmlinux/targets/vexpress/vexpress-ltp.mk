##############################################################################
# Copyright (c) 2012 Mark Charlebois
#               2012 Jan-Simon Möller
#               2012 Behan Webster
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

# The assumption is that this will be imported from the vexpress Makfile
# Also that it is imported after the vexpress-linaro.mk

VEXPRESS_LTP_TARGETS	= test3-ltp test3-gcc-ltp test3-all-ltp
TARGETS_BUILD		+= test3[-gcc,-all]-ltp
CLEAN_TARGETS		+= vexpress-ltp-clean
HELP_TARGETS		+= vexpress-ltp-help
FETCH_TARGETS		+= ${VEXPRESS_LTP_BZ_TMP}
MRPROPER_TARGETS	+= vexpress-ltp-mrproper
RAZE_TARGETS		+= vexpress-ltp-mrproper
.PHONY:			${VEXPRESS_LTP_TARGETS}

DEBDEP			+= kpartx rsync
RPMDEP			+= kpartx rsync

vexpress-ltp-help:
	@echo
	@echo "These are the make targets for LTP testing vexpress:"
	@echo "* make test3-ltp	- linaro/ubuntu rootfs starting LTP, kernel built with clang"
	@echo "* make test3-gcc-ltp	- linaro/ubuntu rootfs starting LTP, kernel built with gcc"
	@echo "* make test3-all-ltp	- linaro/ubuntu rootfs starting LTP, for all built kernels"

#LTPTESTS = fcntl-locktests filecaps fs ipc mm pipes pty quickhit sched syscalls timers
LTPTESTS = ltplite

VEXPRESS_LTP_IMG	= vexpress-ltp.img
VEXPRESS_LTP_BZ		= ${VEXPRESS_LTP_IMG}.bz2
VEXPRESS_LTP_IMG_TMP	= $(call shared,${TMPDIR}/${VEXPRESS_LTP_IMG})
VEXPRESS_LTP_GCCIMG_TMP	= $(call shared,${TMPDIR}/vexpress-ltp-gcc.img)
VEXPRESS_LTP_BZ_TMP	= ${VEXPRESS_LTP_IMG_TMP}.bz2
LTP_RESULTS_DIR		= test-results

# Old attempt at LTP
#test-ltp: state/prep ${QEMUSTATE}/qemu-build state/kernel-build ${INITRAMFS}
#	@$(call qemu,${BOARD} -cpu cortex-a9,${KERNELDIR},768,/dev/ram0,ramdisk_size=327680 rw rdinit=/bin/sh,-initrd ${INITRAMFS} -net none)

# Build LTP image into linaro vexpress-a9 image (for uploading to prebuilt dir on website)
VEXPRESS_LTP_BZ: ${NANOIMG} ${LTPSTATE}/ltp-build ${LTPSTATE}/ltp-scripts
	@cp -v $< $@
	${TOOLSDIR}/partcopy.sh $@ rootfs ${LTPINSTALLDIR}/ /opt/ltp/ || (rm $@ && echo "E: $@ error" && false)
	bzip2 -9c $< > $@

# Get LTP image from prebuilt images on website
${VEXPRESS_LTP_BZ_TMP}:
	$(call get_prebuilt, $@)

# Uncompress LTP image from prebuilt LTP image
.PHONY: ${VEXPRESS_LTP_IMG_TMP} ${VEXPRESS_LTP_GCCIMG_TMP}
${VEXPRESS_LTP_IMG_TMP} ${VEXPRESS_LTP_GCCIMG_TMP}: ${VEXPRESS_LTP_BZ_TMP}
	bunzip2 -9c $< > $@

fresh-vexpress-ltp-img: vexpress-ltp-img-clean ${VEXPRESS_LTP_IMG_TMP}
fresh-vexpress-ltp-gcc-img: vexpress-ltp-gccimg-clean ${VEXPRESS_LTP_GCCIMG_TMP}

# Command to run the LTP on a built kernel
vexpress_run_ltp = $(MAKE) "${3}" && $(call qemu_arm_dtb,${BOARD},${1},${2},256,/dev/mmcblk0p2,rootfstype=ext4 rw init=/opt/ltp/run-tests.sh ltptest=${4},-sd ${3}) ${NET}

# Run LTP tests on clang built kernel
test3-ltp: state/prep ${QEMUSTATE}/qemu-build state/kernel-build ${VEXPRESS_LTP_BZ_TMP}
	mkdir -p ${LTP_RESULTS_DIR}
	for LTPTEST in ${LTPTESTS} ; do \
		$(call vexpress_run_ltp,${KERNEL_BUILD}/${ZIMAGE},${KERNEL_BUILD}/${KERNEL_DTB},${VEXPRESS_LTP_IMG_TMP},$$LTPTEST) \
		| tee $(call ltplog,${LTP_RESULTS_DIR},clang,$$LTPTEST); \
	done

# Run LTP tests on gcc built kernel
test3-gcc-ltp: state/prep ${QEMUSTATE}/qemu-build state/kernel-gcc-build ${VEXPRESS_LTP_BZ_TMP}
	mkdir -p ${LTP_RESULTS_DIR}
	for LTPTEST in ${LTPTESTS} ; do \
		$(call vexpress_run_ltp,${KERNELGCC_BUILD}/${ZIMAGE},${KERNELGCC_BUILD}/${KERNEL_DTB},${VEXPRESS_LTP_GCCIMG_TMP},$$LTPTEST) \
		| tee $(call ltplog,${LTP_RESULTS_DIR},gcc,$$LTPTEST); \
	done

test3-all-ltp: test3-ltp test3-gcc-ltp

vexpress-ltp-bz-clean:
	rm -f ${VEXPRESS_LTP_BZ}

vexpress-ltp-img-clean:
	rm -f ${VEXPRESS_LTP_IMG_TMP}

vexpress-ltp-gccimg-clean:
	rm -f ${VEXPRESS_LTP_GCCIMG_TMP}

vexpress-ltp-clean: vexpress-ltp-bz-clean vexpress-ltp-img-clean vexpress-ltp-gccimg-clean

vexpress-ltp-mrproper: vexpress-ltp-clean ltp-mrproper
	rm -f ${VEXPRESS_LTP_BZ_TMP}

