LLVMLINUX_COMMIT	= 22371ce5f5f142909545f18abb58f47a2ca145af
LLVMLINUX_DATE		= 2014-11-28 22:45:40 -0200
FORCE_LLVMLINUX_COMMIT  = 1
CLANG_TOOLCHAIN		= from-source
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_DATE		= 2014-11-28 23:00:22 +0000
LLVM_COMMIT		= b60bcfde6932ae81fc858afd163dbeab551c78ae
LLVM_REV		= 222943
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86;Mips'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_DATE		= 2014-11-28 22:22:46 +0000
CLANG_COMMIT		= 76742aedda1189059fbc0a4c6af6d0285dbec9da
CLANG_REV		= 222941
# Kernel settings
KERNEL_GIT		= https://github.com/raspberrypi/linux.git
KERNEL_BRANCH		= rpi-3.17.y
KERNEL_TAG		= 
KERNEL_DATE		= 2014-11-22 11:11:44 +0000
KERNEL_COMMIT		= 8c9b93e89533f9dceb0284441540e2c8d666d9f1
KERNELDIR		= ${TARGETDIR}/src/rpi
KERNEL_CFG		= ${TARGETDIR}/config_rpi
KERNEL_REPO_PATCHES	= rpi-3.17.y
KERNEL_PATCH_DIR       += ${TARGETDIR}/patches ${TARGETDIR}/patches/rpi-3.17.y
# buildroot settings
BUILDROOT_ARCH		= rpi
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		= 
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_DATE		= 2014-11-28 22:13:31 +0100
BUILDROOT_COMMIT	= da654a7b65b1f7da70b3c0fd1685272c255d893f
BUILDROOT_CONFIG	= config_rpi_buildroot
# initramfs settings
# LTP settings
LTPSF_RELEASE		= 20120614
LTPSF_TAR		= ltp-full-20120614.bz2
LTPSF_URI		= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-20120614/ltp-full-20120614.bz2
# QEMU settings
QEMU_BRANCH		= master
QEMU_TAG		= 
QEMU_GIT		= git://git.qemu.org/qemu.git
QEMU_DATE		= 2014-11-28 13:06:00 +0000
QEMU_COMMIT		= db12451decf7dfe0f083564183e135f2095228b9
# ARM settings
CROSS_ARM_TOOLCHAIN	= linaro
EXTRAFLAGS		= 
KERNEL_MAKE_TARGETS	= 
