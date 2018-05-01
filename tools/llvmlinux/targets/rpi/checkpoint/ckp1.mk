LLVMLINUX_COMMIT	= 5a765fec6451c8d3607e348156460ecc22fd38da
FORCE_LLVMLINUX_COMMIT  = 1
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_COMMIT		= c73b7f702258b844dc2702fd9d79d8a8706460a7
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_COMMIT		= d5617eeafc93209a26b9f88276c88cf997c3a0a7
COMPILERRT_GIT		= http://llvm.org/git/compiler-rt.git
COMPILERRT_BRANCH	= master
COMPILERRT_COMMIT	= d1b8f588d6b712b6ff2b3d58c73d71614f520122
# Kernel settings
KERNEL_GIT		= https://github.com/raspberrypi/linux.git
KERNEL_BRANCH		= rpi-3.2.27
KERNEL_TAG		=
KERNEL_COMMIT		= ada8b4415ff44d535d63e4291a0eca733bc2ad0f
KERNELDIR		= ${TARGETDIR}/src/rpi
KERNELGCC		= ${TARGETDIR}/src/rpi-gcc
KERNEL_CFG		= ${TARGETDIR}/config_rpi
KERNEL_REPO_PATCHES	= rpi-3.2.27
KERNEL_PATCH_DIR       += ${TARGETDIR}/patches ${TARGETDIR}/patches/rpi-3.2.27
# buildroot settings
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		=
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_COMMIT	= 41a221332682db9902ca1572d548e56cda87f260
# initramfs settings
# LTP settings
LTPSF_RELEASE		= 20120614
LTPSF_TAR		= ltp-full-20120614.bz2
LTPSF_URI		= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-20120614/ltp-full-20120614.bz2
# QEMU settings
QEMU_BRANCH		= master
QEMU_TAG		=
QEMU_GIT		= git://git.qemu.org/qemu.git
QEMU_COMMIT		= 11c29918be32be5b00f367c7da9724a5cddbbb0f
# ARM settings
CROSS_ARM_TOOLCHAIN	=
EXTRAFLAGS		=
KERNEL_MAKE_TARGETS	=
