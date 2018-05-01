CHECKPOINT		= kernel-3.13-rc4
CLANG_TOOLCHAIN		= from-source
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_COMMIT		= a93239b7c6f0d78cb8836768c3ffbc39fb15b79f
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVMPATCHES		= ${CHECKPOINT_DIR}/patches
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_COMMIT		= f2090bb0b03f4a112e44bbd17564fdd404376629
# Kernel settings
KERNEL_GIT		= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
KERNEL_BRANCH		= master
KERNEL_TAG		= 
KERNEL_COMMIT		= b0031f227e47919797dc0e1c1990f3ef151ff0cc
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
QEMU_COMMIT		= 89400a80f5827ae3696e3da73df0996154965a0a
QEMUPATCHES		= ${CHECKPOINT_DIR}/patches/qemu
