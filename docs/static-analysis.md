# Instruction: How to run Razzer's static analysis

To analyze the Linux source code, bitcodes files should be built
first. To build the bitcode files,

```
$ cd tools/llvmlinux/targets/x86_64
$ ./build-kernel.sh --config CONFIG_FILE
```

For example, if the target kernel version is v4.17,

```
$ cd tools/llvmlinux/targets/x86_64
$ ./build-kernel.sh --config configs/static_analysis_v4.17.mk
```

Razzer's static analysis is built based on SVF. To run it, execute
following commands.

```
cd tools/race-syzkaller/exp/partition-scripts/
./run-partition-analysis.py
./merge-mempairs.py
```

The result will be found in
`tools/race-syzkaller/exp/configs/kernel/partition/$KERNEL_VERSION` as
follows.

```
...
crypto/rsa.c:282:0 crypto/twofish_generic.c:133:0 W R
drivers/acpi/ec.c:1136:0 drivers/acpi/scan.c:199:0 W R
arch/x86/xen/enlighten.c:215:0 arch/x86/xen/enlighten.c:215:0 W W
drivers/tty/n_tty.c:1277:0 drivers/tty/tty_ioctl.c:251:0 R W
net/ipv4/ip_gre.c:885:0 net/ipv4/ipmr.c:2048:0 W R
net/ipv4/fib_semantics.c:1342:0 net/ipv4/route.c:2612:0 W W
drivers/infiniband/core/cma.c:3572:0 drivers/infiniband/core/iwcm.c:776:0 R W
net/mac80211/iface.c:1287:0 net/mac80211/tdls.c:807:0 R W
net/ipv4/ipconfig.c:682:0 net/ipv4/tcp_ipv4.c:1376:0 W R
net/ipv6/ip6_gre.c:1345:0 net/ipv6/netfilter/ip6t_SYNPROXY.c:205:0 W W
fs/devpts/inode.c:459:0 fs/proc_namespace.c:230:0 W R
net/ipv4/fib_trie.c:356:0 net/ipv4/fib_trie.c:646:0 W R
net/ipv4/tcp_input.c:6106:0 net/ipv4/udp.c:572:0 W R
kernel/sysctl.c:2161:0 kernel/sysctl.c:2856:0 W R
...
```

# LLVM Linux

Razzer leverages LLVM Linux to extract all bitcode files for each C
source code.

## Kernel Modfication

Razzer needs to modify a Linux source code for a few reasons.

1. At the time of this project, LLVM/Clang doesn't support ASM-GOTO
and can't build a Linux kernel. LLVM now has merged ASM-GOTO so
hopefully, we may be able to build a Linux kernel with LLVM/Clang.
[1](https://www.phoronix.com/scan.php?page=news_item&px=LLVM-Asm-Goto-Merged)

2. To be specific with SVF, there is a few requirement to analyze a
   source code.
  1. Memory allocation/free functions should be external function.
  2. Pointer-to-Int and Int-to-Pointer case should be avoided.
  3. SVF can't handle assembly code, which is expressed in inline
     assembler expression.
   
As a consequence, LLVM Linux will fail to build the entire kernel
binary. It is okay if .bc files for files under interests and
built-in.bc for each subdirectory (e.g., drivers/built-in.bc,
net/built-in.bc) is built.


# Linux Kernel modification

SVF requires a few modification to analyze a kernel.

## Memory allocation functions

SVF has a list of memory allocation functions in
`lib/Util/ExtAPI.cpp`, and when SVF faces a external function, it
checks that the external function is in the list. If so, SVF thinks it
is a memory allcation function. To handle memory allocation functions
in a kernel (e.g., kmalloc/kmem_cache_alloc...), they should be a
external function. We modifies a kernel to make them external
function.

## Pointer-to-Int cast and Int-to-Pointer cast

If a pointer is casted to integer, SVF thinks the integer points to
nothing. So SVF discards all points-to information for that variable.
In a Linux kernel, there are a lot of this kind of pointer-to-int
casting. The `__to_fd()` function called by the `fdget()` function is
an example. To work around this, we modifies the kernel source code
not to cast a pointer type to integer type.

https://github.com/SVF-tools/SVF/issues/26

## Handling assmebly code

SVF analyzes a kernel based on LLVM IR. So assembly codes which are
represented as a inline assembler in LLVM IR can't be analyzed. Mostly
used assembly code in a Linux kernel is `current` pointer. We modifies
the current pointer implementaion, so current pointer always points to
`init_task`. Of course it is broken and can't be booted up. But it is
okay in the view point of static analysis.
