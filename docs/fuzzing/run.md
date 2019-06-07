# Run Razzer

To run Razzer, one should build a kernel first. To build a kernel,

```
cd tools/race-syzkaller/kernel-build/
./build-kernel.sh --config CONFIG_FILE
```

For example, if the target kernel version is v4.17,

```
cd tools/race-syzkaller/kernel-build/
./build-kernel.sh --config config-v4.17-syzkaller
```

Razzer requires two necessary tools, QEMU and the modified Syzkaller.
To build QEMU,

```
./scripts/qemu/install.sh
```

To build the modified Syzkaller,

```
./scripts/syzkaller/install.sh
```

To run Razzer, one can execute the `run.sh` script with a syzkaller
configuration file.

```
cd tools/race-syzkaller/exp/
./run.sh --config configs/kernel/config
```
