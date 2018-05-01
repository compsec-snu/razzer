LLVMLINUX_COMMIT	= 5cc005b9e1f315f8fa6e1579517fb9d57fc7fbf6
FORCE_LLVMLINUX_COMMIT  = 1
CLANG_TOOLCHAIN		= from-source
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_COMMIT		= 793622668ef3dede3b020f92680cbc0d71bd3f6b
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_COMMIT		= d478c0d8abeafb9d57600e4ca271a63aa8e05386
# Kernel settings
KERNEL_GIT		= git://github.com/CyanogenMod/android_kernel_asus_grouper
KERNEL_BRANCH		= cm-10.2
KERNEL_TAG		= 
KERNEL_COMMIT		= 30c5396ebdf970fc079a617066ff69dfa0d043ce
KERNELDIR		= ${TARGETDIR}/src/android_kernel_nexus7
KERNELGCC		= ${TARGETDIR}/src/android_kernel_nexus7-gcc
KERNEL_CFG		= ${TARGETDIR}/src/android_kernel_nexus7/arch/arm/configs/cyanogenmod_grouper_defconfig
KERNEL_REPO_PATCHES	= cm-10.2
KERNEL_PATCH_DIR       += ${TARGETDIR}/patches ${TARGETDIR}/patches/cm-10.2
# buildroot settings
BUILDROOT_ARCH		= qemu_arm_vexpress
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		= 
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_COMMIT	= 893108810b952777feca054a90c7ecfe7cad06e1
BUILDROOT_CONFIG	= ${TESTDIR}/buildroot/src/buildroot/configs/qemu_arm_vexpress_defconfig
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
# ARM settings
CROSS_ARM_TOOLCHAIN	= android
EXTRAFLAGS		= 
KERNEL_MAKE_TARGETS	= 
