# Run Razzer's static analysis

To analyze the Linux source code, bitcodes files should be built
first. To build the bitcode files,

```
cd tools/llvmlinux/targets/x86_64
./build-kernel.sh --config CONFIG_FILE
```

For example, if the target kernel version is v4.17,

```
cd tools/llvmlinux/targets/x86_64
./build-kernel.sh --config configs/static_analysis_v4.17.mk
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