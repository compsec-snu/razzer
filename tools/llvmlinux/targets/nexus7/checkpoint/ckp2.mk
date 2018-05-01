LLVMLINUX_COMMIT	= 26eec33caae67b371961cf568608c3fa68df544d
FORCE_LLVMLINUX_COMMIT  = 1
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_COMMIT		= ae19c89e1da816adbd6c7ffc28f679dabec83573
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_COMMIT		= 1d7bb6c8b5b8f98fe79607718441f6543de598f1
# Kernel settings
KERNEL_GIT		= git://github.com/CyanogenMod/android_kernel_asus_grouper
KERNEL_BRANCH		= cm-10.1
KERNEL_TAG		= 
KERNEL_COMMIT		= ea4891270ba97888af646940096082e5b3a4e9d0
KERNELDIR		= ${TARGETDIR}/src/android_kernel_nexus7
KERNELGCC		= ${TARGETDIR}/src/android_kernel_nexus7-gcc
KERNEL_CFG		= ${TARGETDIR}/src/android_kernel_nexus7/arch/arm/configs/cyanogenmod_grouper_defconfig
KERNEL_REPO_PATCHES	= cm-10.1
KERNEL_PATCH_DIR       += ${TARGETDIR}/patches ${TARGETDIR}/patches/cm-10.1
# buildroot settings
BUILDROOT_ARCH		= qemu_arm_vexpress
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		= 
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_COMMIT	= 04ac296a3b7230c23afbed2c8db9309ed91366ec
# initramfs settings
# LTP settings
LTPSF_RELEASE		= 20120614
LTPSF_TAR		= ltp-full-20120614.bz2
LTPSF_URI		= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-20120614/ltp-full-20120614.bz2
# QEMU settings
QEMU_BRANCH		= master
QEMU_TAG		= 
QEMU_GIT		= git://git.qemu.org/qemu.git
QEMU_COMMIT		= ec3f8c9913c1eeab78a02711be7c2a803dfb4d62
# ARM settings
CROSS_ARM_TOOLCHAIN	= android
EXTRAFLAGS		= 
KERNEL_MAKE_TARGETS	= 
