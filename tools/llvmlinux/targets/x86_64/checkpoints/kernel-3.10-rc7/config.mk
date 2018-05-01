CHECKPOINT		= kernel-3.10-rc7
CLANG_TOOLCHAIN		= from-source
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= release_33
LLVM_COMMIT		= release_33
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVMPATCHES		= ${CHECKPOINT_DIR}/patches
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= release_33
CLANG_COMMIT		= release_33
# Kernel settings
KERNEL_GIT		= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
KERNEL_BRANCH		= master
KERNEL_TAG		= 
KERNEL_COMMIT		= 4300a0f8bdcce5a03b88bfa16fc9827e15c52dc4
KERNELDIR		= ${TARGETDIR}/src/linux
KERNELGCC		= ${TARGETDIR}/src/linux-gcc
KERNEL_CFG		= ${CHECKPOINT_DIR}/kernel.config
KERNEL_REPO_PATCHES	= master
PATCHDIR		= ${CHECKPOINT_DIR}/patches/kernel
KERNEL_PATCH_DIR	= ${CHECKPOINT_DIR}/patches/kernel
# buildroot settings
BUILDROOT_ARCH		= qemu_arm_vexpress
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		= 
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_COMMIT	= 4cf02e6bfec9bfdb9d06081537b928e54623857c
BUILDROOT_PATCHES	= ${CHECKPOINT_DIR}/patches/buildroot
BUILDROOT_CONFIG	= ${CHECKPOINT_DIR}/buildroot.config
# initramfs settings
# LTP settings
LTPSF_RELEASE		= 20120614
LTPSF_TAR		= ltp-full-20120614.bz2
LTPSF_URI		= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-20120614/ltp-full-20120614.bz2
# QEMU settings
QEMU_BRANCH		= stable-1.4
QEMU_TAG		= 
QEMU_GIT		= git://git.qemu.org/qemu.git
QEMU_COMMIT		= f46e720a82ccdf1a521cf459448f3f96ed895d43
QEMUPATCHES		= ${CHECKPOINT_DIR}/patches/qemu
