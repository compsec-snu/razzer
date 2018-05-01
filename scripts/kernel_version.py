#!/usr/bin/python3

import os, sys

kernel_version_file=os.path.join(os.environ["SCRIPT_HOME"], "kernel_version.lst")
project_home = os.environ["PROJECT_HOME"]

with open(kernel_version_file) as f:

    kernel_versions = []
    for line in f:
        line = line.strip()
        if line.find(":") != -1:
            rootdir=os.path.join(project_home, line[:line.find(":")])
            continue

        if len(line) != 0:
            kernel_versions.append( (rootdir, line) )

    print("Select the kernel version", file=sys.stderr)
    for i, (rootdir, kver) in enumerate(kernel_versions):
        print("[%d] %s" % (i, kver), file=sys.stderr)

    idx = int(input())
    rootdir, kver = kernel_versions[idx]

    # To use eval
    print("export KERNEL_VERSION=\"%s\"" % (os.path.join(kver)))
    print("export KERNEL_DIR=\"%s/\"" % (os.path.join(rootdir, "kernel_" + kver)))
    print("export STATIC_ANALYSIS_KERNEL_DIR=\"%s/\"" % (os.path.join(rootdir+"/static_analysis/", "kernel_" + kver)))
