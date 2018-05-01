CHECKPOINT		= llvm3.3-linux040a0a3
CLANG_TOOLCHAIN		= prebuilt
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_COMMIT		= f667db3652e1fd198ce4e3aec4cebf080a124552
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVMPATCHES		= ${CHECKPOINT_DIR}/patches
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_COMMIT		= 82a5430ee824bbe3a49360db41d53d316f9fd016
# Kernel settings
KERNEL_GIT		= git://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
KERNEL_BRANCH		= master
KERNEL_TAG		= 
KERNEL_COMMIT		= 040a0a37100563754bb1fee6ff6427420bcfa609
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
