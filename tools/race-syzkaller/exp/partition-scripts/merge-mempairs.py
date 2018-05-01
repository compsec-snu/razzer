#!/usr/bin/env python3
from multiprocessing import Pool
import os
import glob

DIR_PREFIX = "../configs/kernel/partition"


def get_analysis_dir():
    kver = os.environ['KERNEL_VERSION'].strip()
    if kver == "" or not kver.startswith("v"):
        print("[ERR] Incorrect kernel version (%s)" % kver)
        sys.exit(-1)
    print("kernel version: (%s)" % kver)
    return os.path.join(DIR_PREFIX, kver)

def glob_files():
    files = glob.glob(os.path.join(get_analysis_dir(), "mempair.*"))
    return files

def save_mempairs(mempairs):
    fn = os.path.join(get_analysis_dir(), "mempair")
    f = open(fn, "w")
    for line in mempairs:
        f.write(line + "\n")
    f.close()

def load_mempair(fn):
    mempairs = []
    with open(fn) as f:
        for line in f:
            line = line.strip()
            mps = line.split(" ")
            assert(len(mps) == 2 or len(mps) == 4)

            if len(mps) == 2:
                mps.sort()
                line_to_add = " ".join(mps)
                mempairs.append(line_to_add)
            elif len(mps) == 4:
                mps_rw = list(zip(mps[:2], mps[2:]))
                mps_rw.sort(key=lambda x: x[0])
                # ah this is hacky
                line_to_add = " ".join([mps_rw[0][0], mps_rw[1][0],
                                        mps_rw[0][1], mps_rw[1][1]])
                mempairs.append(line_to_add)
    return mempairs

def merge_mempairs(files):
    merged = set([])
    for i, fn in enumerate(files):
        mempairs = load_mempair(fn)
        inter = merged.intersection(mempairs)
        merged = merged.union(mempairs)
        print("[%d] merged len: %d (duplicate %d)" % (i, len(merged), len(inter)))
    return merged

def diff(fn1, fn2):
    mp1 = set(load_mempair(fn1))
    mp2 = set(load_mempair(fn2))
    diff1 = mp1.difference(mp2)
    diff2 = mp2.difference(mp1)
    inter = mp1.intersection(mp2)
    print("mp1 len %d" % len(mp1))
    print("mp2 len %d" % len(mp2))
    print("mp1/mp2 inter: len %d" % len(inter))
    print("diff1 len %d" % len(diff1))
    print("diff2 len %d" % len(diff2))

def run_get_address():
    cmdstr = "cd %s; get_address.py ./mempair > ./mapping" % get_analysis_dir()
    os.system(cmdstr)
    return

def main():
    files = glob_files()
    print("[*] Total files: %d" % len(files))
    merged = merge_mempairs(files)
    save_mempairs(merged)

    run_get_address()

if __name__ == "__main__":
    main()
    # diff("/home/blee/project/race-fuzzer/race-syzkaller/exp/configs/kernel/partition/v4.16-rc3/mempair",
    #      "/home/blee/project/race-fuzzer/race-syzkaller/exp/configs/kernel/fs+net+drivers/v4.16-rc3/mempair")
