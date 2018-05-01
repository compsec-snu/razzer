LLVMLINUX_COMMIT	= e068709ab22a450dc598be2e058a8f612544fa2b
FORCE_LLVMLINUX_COMMIT  = 1
CLANG_TOOLCHAIN		= from-source
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= release_34
LLVM_COMMIT		= f667db3652e1fd198ce4e3aec4cebf080a124552
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= release_34
CLANG_COMMIT		= 82a5430ee824bbe3a49360db41d53d316f9fd016
# Kernel settings
KERNEL_GIT		= https://github.com/raspberrypi/linux.git
KERNEL_BRANCH		= rpi-3.13.y
KERNEL_TAG		= 
KERNEL_COMMIT		= 6928683112b227f5f62124b066a45b8feac57d6e
KERNELDIR		= ${TARGETDIR}/src/rpi
KERNELGCC		= ${TARGETDIR}/src/rpi-gcc
KERNEL_CFG		= ${TARGETDIR}/config_rpi
KERNEL_REPO_PATCHES	= rpi-3.13.y
KERNEL_PATCH_DIR       += ${TARGETDIR}/patches ${TARGETDIR}/patches/rpi-3.13.y
# buildroot settings
BUILDROOT_ARCH		= rpi
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		= 
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_COMMIT	= e7d309cba02df66ebfe0b9ddd46e26458465125d
BUILDROOT_CONFIG	= config_rpi_buildroot
# initramfs settings
# LTP settings
LTPSF_RELEASE		= 20120614
LTPSF_TAR		= ltp-full-20120614.bz2
LTPSF_URI		= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-20120614/ltp-full-20120614.bz2
# QEMU settings
QEMU_BRANCH		= stable-1.6
QEMU_TAG		= 
QEMU_GIT		= git://git.qemu.org/qemu.git
QEMU_COMMIT		= 89400a80f5827ae3696e3da73df0996154965a0a
# ARM settings
CROSS_ARM_TOOLCHAIN	= codesourcery
EXTRAFLAGS		= 
KERNEL_MAKE_TARGETS	= 
