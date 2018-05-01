#!/usr/bin/python

import os
import sys

with open(sys.argv[1]) as f:
    for line in f:
        line = line.strip()
        toks = line.split()

        if len(toks) != 2 and len(toks) != 4:
            sys.stderr.write("\t [ERROR] Wrong mempair format\n")
            exit(1)

        # functions in header files might be inlined many times.
        # Ignore it for now
        # TODO: handle it correctly
        if toks[0].find('.h') != -1 or toks[1].find('.h') != -1:
            continue

        dirs = [os.path.dirname(x) for x in toks]

        # TODO: we may need to handle "include" dir.
        if (dirs[0] in dirs[1]) or (dirs[1] in dirs[0]):
            print line
        else:
            # skip if two paths are in a different sub-directory.
            pass

