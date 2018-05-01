# Run Razzer

To run Razzer, one should build QEMU and the modified Syzkaller first.

To build QEMU,

```
cd scripts/qemu
./install.sh
```

To build the modified Syzkaller,

```
cd scripts/syzkaller
./install.sh
```

To run Razzer, one can execute the `run.sh` script with a syzkaller
configuration file.

```
cd tools/race-syzkaller/exp/
./run.sh --config configs/kernel/config
```
