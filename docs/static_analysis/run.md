# Run Razzer's static analysis

Razzer's static analysis is built based on SVF. To run it, execute the
following commands.

```
cd tools/race-syzkaller/exp/partition-scripts/
./run-partition-analysis.py
./merge-mempairs.py
```

The result will be in
`tools/race-syzkaller/exp/configs/kernel/partition/$KERNEL_VERSION`.
