#!/usr/bin/python

import sys
import re

nds  = {}
edgs = set()

with open(sys.argv[1]) as f:
    for line in f:
        if line.find("Call Graph") != -1:
            continue
        if line.find("label") != -1:
            # define node
            node = line.split()[0]
            func = re.findall(r'\{.*\}', line)[0]
            nds[node] = func
        elif line.find('->') != -1:
            # define edge
            tmp = line.split('[')[0]
            src, _, dst =  tmp.split()
            edgs.add((src, dst))

    for edge in edgs:
        print nds[edge[0]][1:-1], nds[edge[1]][1:-1]
