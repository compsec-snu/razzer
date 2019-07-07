# Razzer: Finding kernel race bugs through fuzzing

# Environment setup

```
$ source scripts/envsetup.sh
```

`scripts/envsetup.sh` sets up necessary environment variables. One
should select the kernel version during environment setup, for
example, `v4.17`.

# Install

## Initialize kernels_repo submodule

Kernel source codes used in this project are in the other reprository
which is included as a submodule. To initialize the submodule one
should execute `git submodule update` command as a follow.

```
$ git submodule update --init --depth=1 kernels_repo
```


## Dependencies

```
$ sudo apt install zlib libglib-dev python-setuptools quilt libssl-dev dwarfdump
```

## Install toolchains / tools


```
$ scripts/install.sh
```

`scripts/install.sh` then installs all the rest necessary toolchains and tools.

# Static analysis

The Razzer's static analysis is based on the LLVM toolchain and the
SVF static analysis tool. See documents in `docs/static-analysis.md`.

# Fuzzing

Razzer's two-phases fuzzing is based on Syzkaller. The deterministic
scheduler is implemented using QEMU/KVM. See documents in
`docs/fuzzing.md`.

# Paper

[Razzer: Finding Kernel Race Bugs through Fuzzing (IEEE S&P 2019)](https://lifeasageek.github.io/papers/jeong:razzer.pdf)

# Trophies

- [KASAN: slab-out-of-bounds write in tty_insert_flip_string_flag](https://lkml.org/lkml/2018/4/19/107)
- [WARNING in __static_key_slow_dec](https://lkml.org/lkml/2018/5/18/160)
- [Kernel BUG at net/packet/af_packet.c:LINE!](https://lkml.org/lkml/2018/3/30/428)
- [WARNING in refcount_dec](https://lkml.org/lkml/2018/3/28/12)
- [unable to handle kernel paging request in snd_seq_oss_readq_puts](https://lkml.org/lkml/2018/4/26/89)
- [KASAN: use-after-free Read in loopback_active_get](https://lkml.org/lkml/2018/4/30/88)
- [KASAN: null-ptr-deref Read in rds_ib_get_mr](https://lkml.org/lkml/2018/5/11/17) (assisted Syzkaller)
- [KASAN: use-after-free Read in nd_jump_root](https://lkml.org/lkml/2018/7/24/34) (discussed more in the linux security mailing list)
- KASAN: use-after-free Read in link_path_walk (discussed in the linux security mailing list)
- [WARNING in ip_recv_error](https://lkml.org/lkml/2018/5/18/595)
- [KASAN: use-after-free Read in vhost_chr_write_iter](https://lkml.org/lkml/2018/5/17/536)
- [BUG: soft lockup in snd_virmidi_output_trigger](https://lkml.org/lkml/2018/7/26/73) (assisted Syzkaller)
- [KASAN: null-ptr-deref Read in smc_ioctl](https://lkml.org/lkml/2018/7/9/1008)
- [KASAN: null-ptr-deref Write in binder_update_page_range](https://lkml.org/lkml/2018/8/22/73)
- [WARNING in port_delete](https://lkml.org/lkml/2018/7/24/28)
- KASAN: null-ptr-deref in inode_permission (discussed in the linux security mailing list)

# Contributors

- Dae R. Jeong (threeearcat@gmail.com)
- Kyungtae Kim (kim1798@purdue.edu)
- Basavesh Ammanaghatta Shivakumar (bammanag@purdue.edu)
- Byoungyoung Lee (byoungyoung@snu.ac.kr)
- Insik Shin (insik.shin@cs.kaist.ac.kr)
