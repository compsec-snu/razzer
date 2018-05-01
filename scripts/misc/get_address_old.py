#!/usr/bin/python

from __future__ import print_function
import re
import sys
import argparse
import subprocess
import os

parser = argparse.ArgumentParser()
parser.add_argument("mem_pair_file")

args = parser.parse_args()

vmlinux = os.environ['KERNEL_BUILD'] + 'vmlinux'
mempair_fn = args.mem_pair_file

def get_lncl_num(line):
    pos = line[line.find('[')+1: line.find(']')]
    ln, cl = pos.split(',')
    return int(ln), int(cl)

def strip_start(text, prefix):
    if not text.startswith(prefix):
        return text
    ret = text[-(len(text) - len(prefix)):]
    if ret.startswith("./"):
        return ret[2:]
    return ret

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def check_mem_access(insn, args):
    # TODO: Modify this to be more accurate
    if insn.startswith('j') or insn.startswith("lea") or insn.startswith("nop"):
        return False
    elif insn.startswith('call'):
        if "memcpy" in args or "strcpy" in args:
            return True
        else:
            return False
    # I assume that the stack is accessed through rbp and rsp
    if "PTR" in args and not "rbp" in args and not "rsp" in args and not "f1f1f1f1" in args and not "f2f20000" in args and not "f3f3f3f3" in args:
        return True
    return False

def insert_addr(locToAddr, loc, addr, mempair_locs):
    if not loc in mempair_locs:
        return
    if not addr in memacc_addr:
        return
    if locToAddr.has_key(loc) == False:
        locToAddr[loc] = []
    locToAddr[loc].append(addr)

def take_objdump_lines(vmlinux):
    objdump = 'objdump'
    objdumpopt = '-drwC -Mintel --no-show-raw-insn'
    cmd = objdump + ' ' + objdumpopt + ' ' + vmlinux

    asm = subprocess.check_output(cmd, shell=True)
    open('objdump.txt', "w").write(asm)
    asm_lines = asm.split('\n')
    return asm_lines

def parse_objdump(asm_lines):
    memacc_addr = set()
    funcs = {}

    num_addr = 0
    cur_func = ""
    for line in asm_lines:
        if len(line) == 0:
            continue
        if line.endswith(">:"):
            # get the function name
            cur_func = line[line.find('<'): line.find('>')+1]
        if line.startswith("ffffffff") and line[16] == ':':
            # this line contains the machine code
            addr = int(line[:16],16)
            num_addr += 1
            toks = line.split(None, 2)
            if len(toks) < 3:
                continue
            insn = toks[1]
            args = toks[2]
            if check_mem_access(insn, args):
                memacc_addr.add(addr)
                funcs[addr] = cur_func[1:-1]

    return memacc_addr, funcs

def collect_debug_info(vmlinux, mempair_locs):
    dwarfdump = "dwarfdump"
    dwarfopt = '-l'

    out_dwarfdump = subprocess.check_output([dwarfdump, dwarfopt, vmlinux])
    open('dwarfdump.txt', "w").write(out_dwarfdump)
    debug_infos = out_dwarfdump.split('\n')

    filename = None
    locToAddr = {}

    prev_addr = -1
    prev_loc = None
    PREFIX=os.environ['KERNEL_DIR']
    for line in debug_infos:
        if len(line) == 0:
            continue
        # if line starts with "0x" then line contains the source code info
        toks = line.split()
        if "0x" in toks[0]:
            # parse addr
            addr = int(toks[0], 16)
        else:
            continue

        # if one of the toks is "uri:" then following infos are contained by new source line
        # otherwise, filename will be used
        if "uri:" in toks:
            # Assumption: filename and dir path don't contain the blank
            filename = toks[-1][1:-1]
            filename = strip_start(filename, PREFIX)

        if filename.endswith(".S") or filename.endswith(".s"):
            # ignore asm
            continue
        linenum, colnum = get_lncl_num(line)

        # TODO: While our static analysis (on llvmlinux built kernel)
        # simply returns zero column number, dwarfdump (on gcc built
        # kernel) may return non-zero column number. So we simply
        # ignore this column number information for now
        colnum = 0

        # Key
        loc = ":".join((filename, str(linenum), str(colnum)))
        insert_addr(locToAddr, loc, addr, mempair_locs)
        if prev_addr != -1:
            for addr0 in range(prev_addr+1, addr):
                # If this addr doesn't access memory
                insert_addr(locToAddr, prev_loc, addr0, mempair_locs)
        prev_addr = addr
        prev_loc = loc

        # End of text sequence
        if "ET" in line:
            prev_addr = -1
            prev_loc = None

    return locToAddr

def take_mempair_locs(mempair_fn):
    mempair_locs = set()
    for line in open(mempair_fn):
        a = line.split()
        for loc in a:
            mempair_locs.add(loc)
    return mempair_locs

if __name__ == '__main__':
    eprint("[*] vmlinux: ", vmlinux)
    eprint("[*] mempair: ", mempair_fn)
    eprint("[*] kernel : ", os.environ['KERNEL_DIR'])

    # ===================================================
    eprint("[*] Taking mempair locations")
    mempair_locs = take_mempair_locs(mempair_fn)

    # ===================================================
    eprint("[*] Taking objdump of vmlinux")
    asm_lines = take_objdump_lines(vmlinux)

    # ===================================================
    # Parse the instruction and guess it accesses memory
    # Result: memacc_addr, addresses that access memory
    eprint("[*] Parsing objdump to compute addresses that access memory")
    memacc_addr, funcs = parse_objdump(asm_lines)

    # ===================================================
    # get the dwarf info
    # Result: map (filename, line, column=0) -> {memacc_addr}
    eprint("[*] Collecting debug infos")
    locToAddr = collect_debug_info(vmlinux, mempair_locs)

    # ===========================================================================
    # Result: reduced map (filename, line, column) -> {memacc_addr}
    eprint("[*] Calculating the address of each source location")

    print("[", end='')
    not_first = False
    for loc in locToAddr:
        if len(locToAddr[loc]) == 0:
            continue
        if not_first:
            print(",")
        not_first = True
        print("{", end='')
        print("\"loc\"\t: ", end='')
        print("\"" + loc + "\"", end='')
        print(",")
        print("\"item\"\t: [", end='')
        not_first_ = False
        for addr in locToAddr[loc]:
            if not_first_:
                print(",", end='')
            print(addr, end='')
            not_first_ = True
        print("],")
        print("\"func\"\t: [", end='')
        not_first_ = False
        for addr in locToAddr[loc]:
            if not_first_:
                print(",", end='')
            print("\"" + funcs[addr] + "\"", end='')
            not_first_ = True
        print("]", end='')
        print("}", end='')
    print("]")

    eprint("[*] DONE")
