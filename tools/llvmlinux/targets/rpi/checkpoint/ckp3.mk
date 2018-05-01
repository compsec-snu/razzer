LLVMLINUX_COMMIT	= 40253a8e72cfa1bf6b8f32fb9a55b479ea63fead
LLVMLINUX_DATE		= 2014-10-27 20:19:55 -0200
FORCE_LLVMLINUX_COMMIT  = 1
CLANG_TOOLCHAIN		= from-source
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_DATE		= 2014-10-27 19:58:36 +0000
LLVM_COMMIT		= 52a6f59d41086b05b11b2ce86946a22f1dc5c5b4
LLVM_REV		= 220713
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
LLVM_TARGETS_TO_BUILD	= 'AArch64;ARM;X86;Mips'
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_DATE		= 2014-10-27 20:02:19 +0000
CLANG_COMMIT		= 16446f30e738aebd31a9d3b1ff81661a395c1553
CLANG_REV		= 220714
# Kernel settings
KERNEL_GIT		= https://github.com/raspberrypi/linux.git
KERNEL_BRANCH		= rpi-3.17.y
KERNEL_TAG		= 
KERNEL_DATE		= 2014-10-26 14:21:26 +0000
KERNEL_COMMIT		= e2d674b3b7454c3c73e89157ab775b91cd5a28d0
KERNELDIR		= ${TARGETDIR}/src/rpi
KERNEL_CFG		= ${TARGETDIR}/config_rpi
KERNEL_REPO_PATCHES	= rpi-3.17.y
KERNEL_PATCH_DIR       += ${TARGETDIR}/patches ${TARGETDIR}/patches/rpi-3.17.y
# buildroot settings
BUILDROOT_ARCH		= rpi
BUILDROOT_BRANCH	= master
BUILDROOT_TAG		= 
BUILDROOT_GIT		= http://git.buildroot.net/git/buildroot.git
BUILDROOT_DATE		= 2014-10-27 17:41:42 +0100
BUILDROOT_COMMIT	= 97c5d445202b082d0bb390a8c395dacb09942416
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
QEMU_DATE		= 2014-10-27 15:05:09 +0000
QEMU_COMMIT		= 3e9418e160cd8901c83a3c88967158084f5b5c03
# ARM settings
CROSS_ARM_TOOLCHAIN	= codesourcery
EXTRAFLAGS		= 
KERNEL_MAKE_TARGETS	= 
