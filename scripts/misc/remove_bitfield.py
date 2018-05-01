#!/usr/bin/python3

import os
import sys
import re

# traverse root directory, and list directories as dirs and files as files
for root, dirs, files in os.walk(sys.argv[1]):
    for file in files:
        if file == "tags":
            continue
        name = os.path.join(root,file)
        if os.path.islink(name):
            continue
        temp = open('/tmp/temp', 'w')
        print(name)
        with open(name) as f:
            instruct = False
            bcount = 0
            for line in f:
                if re.match(r'struct.*{', line):
                    instruct = True
                bcount += line.count('{')
                bcount -= line.count('}')
                if bcount == 0:
                    instruct = False
                if instruct:
                    if re.search(r"^[^?]*:\ *[0-9]+;", line):
                        line = re.sub(r':\ *[0-9]+;', ';', line)
                    if re.search(r"^[^?]*:\ *[0-9]+,", line):
                        line = re.sub(r':\ *[0-9]+,', ',', line)
                temp.write(line)
        os.rename('/tmp/temp', name)
