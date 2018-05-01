LLVMLINUX_COMMIT	= 6f941c4a48a958417c0dae1e7a92131bc7bee34f
FORCE_LLVMLINUX_COMMIT  = 1
# LLVM settings
LLVM_GIT		= http://llvm.org/git/llvm.git
LLVM_BRANCH		= master
LLVM_COMMIT		= baabdecbb9bf5b32fa81b1e2830ab13076d549f1
LLVM_OPTIMIZED		= --enable-optimized --enable-assertions
# Clang settings
CLANG_GIT		= http://llvm.org/git/clang.git
CLANG_BRANCH		= master
CLANG_COMMIT		= 52635ff9fb530dfdfc6a94e52a2270bf1bb8346b
COMPILERRT_GIT		= http://llvm.org/git/compiler-rt.git
COMPILERRT_BRANCH	= master
COMPILERRT_COMMIT	= d1b8f588d6b712b6ff2b3d58c73d71614f520122
# Kernel settings
KERNEL_GIT		= git://github.com/CyanogenMod/android_kernel_asus_grouper
KERNEL_BRANCH		= cm-10.1
KERNEL_TAG		=
KERNEL_COMMIT		= 72e6ca1f349716b36017732bdedcb12739478d2b
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
BUILDROOT_COMMIT	= 85ffaecb27d3ae5929437ae878a865b57f708df1
# initramfs settings
# LTP settings
LTPSF_RELEASE		= 20120614
LTPSF_TAR		= ltp-full-20120614.bz2
LTPSF_URI		= http://downloads.sourceforge.net/project/ltp/LTP%20Source/ltp-20120614/ltp-full-20120614.bz2
# QEMU settings
QEMU_BRANCH		= master
QEMU_TAG		=
QEMU_GIT		= git://git.qemu.org/qemu.git
QEMU_COMMIT		= 70ef6a5b7121cb54d7f9713d6315fb8547761bfc
# ARM settings
CROSS_ARM_TOOLCHAIN	= android
EXTRAFLAGS		=
KERNEL_MAKE_TARGETS	=
