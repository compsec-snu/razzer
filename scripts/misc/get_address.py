#!/usr/bin/python2

from __future__ import print_function
import re
import sys
import argparse
import subprocess
import os
import hashlib
import json

from capstone import *
from capstone.x86 import *

KERNEL_PREFIX = os.environ['KERNEL_DIR']
TMP_DIR = os.path.join(os.environ['PROJECT_HOME'], "tmp")
try:
    os.makedirs(TMP_DIR)
except:
    pass

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

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

def compute_md5(fname):
    hash_md5 = hashlib.md5()
    with open(fname, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            hash_md5.update(chunk)
    return hash_md5.hexdigest()

def take_objdump_lines(vmlinux, vmlinux_md5):
    save_fn = os.path.join(TMP_DIR, "objdump-%s.txt" % vmlinux_md5)
    if os.path.exists(save_fn):
        eprint("\t Loading from backup: [%s]" % save_fn)
        return open(save_fn).read().split('\n')

    objdump = 'objdump'
    objdumpopt = '-drwC -Mintel'
    cmd = objdump + ' ' + objdumpopt + ' ' + vmlinux

    asm = subprocess.check_output(cmd, shell=True)
    open(save_fn, "w").write(asm)
    asm_lines = asm.split('\n')
    return asm_lines

# https://github.com/aquynh/capstone/blob/master/bindings/python/capstone/__init__.py
# https://github.com/aquynh/capstone/blob/master/bindings/python/capstone/x86.py
def get_cinst_from_raw_bytes(addr, raw_bytes):
    raw_str = "".join([chr(int(x,16)) for x in raw_bytes.split()])
    md = Cs(CS_ARCH_X86, CS_MODE_64)
    md.detail = True
    cinsts = []

    for cinst in md.disasm(raw_str, addr):
        cinsts.append(cinst)

    # We always decode raw bytes for a single instruction, so capstone
    # should not yield multiple instructions.
    assert(len(cinsts)==1)
    return cinsts[0]


def is_stack_base_access(operand, cinst):
    reg = ""
    if operand.mem.segment != 0:
        reg = cinst.reg_name(operand.mem.segment)
    elif operand.mem.base != 0:
        reg = cinst.reg_name(operand.mem.base)
    elif operand.mem.index != 0:
        reg = cinst.reg_name(operand.mem.index)
    if reg in ["rsp", "rbp"]:
        return True
    return False


class LocInfo:
    def __init__(self, loc):
        self.loc = loc
        self.addrToCinst = {}
        self.addrToFunc = {}
        self.addrToSize = {}
        self.addrToObjdumpDisas = {}
        self.addrToTag = {}

    def add_instr(self, addr, func, raw_bytes, objdump_disas):
        self.addrToFunc[addr] = func
        cinst = get_cinst_from_raw_bytes(addr, raw_bytes)
        self.addrToCinst[addr] = cinst
        self.addrToSize[addr] = cinst.size
        self.addrToObjdumpDisas[addr] = objdump_disas
        self.addrToTag[addr] = self.get_addr_tag(addr)

    def get_addr_tag(self, addr):
        # I: ignore
        # U: unknown
        # R: read
        # W: write
        # W: error (capstone)

        objdump_disas = self.addrToObjdumpDisas[addr]

        if "__asan_" in objdump_disas:
            # Ignored as it's ASAN's load/store check
            return "I (asan)"

        if "__sanitizer_cov" in objdump_disas:
            # Ignored as it's coverage trace
            return "I (cov)"

        cinst = self.addrToCinst[addr]

        if cinst.mnemonic == "nop":
            return "I (nop)"

        if cinst.mnemonic == "lea":
            # "lea" instruction can't be a memory load/store instruction.
            return "I (lea)"

        try:
            num_operands = len(cinst.operands)
        except:
            raise()
            eprint("[ERR] Parsing on addr %x" % addr)
            return "E"

        # See https://github.com/aquynh/capstone/blob/master/include/x86.h#L75
        if num_operands == 0:
            return "I (OP0)"
        elif num_operands == 1:
            operand = cinst.operands[0]
            if operand.type == X86_OP_MEM:
                if is_stack_base_access(operand, cinst):
                    return "I (stk)"
                if cinst.mnemonic in ["call", "jmp"]:
                    return "R"
                return "RW"
            else:
                return "I (OP1)"
        elif num_operands == 2:
            if cinst.operands[0].type == X86_OP_MEM:
                if is_stack_base_access(cinst.operands[0], cinst):
                    return "I (stk)"
                if cinst.mnemonic in ["cmp", "test"]:
                    return "R"
                if cinst.mnemonic in ["add", "sub"]:
                    return "RW"
                return "W"
            elif cinst.operands[1].type == X86_OP_MEM:
                if is_stack_base_access(cinst.operands[1], cinst):
                    return "I (stk)"
                return "R"
            else:
                return "I (OP2)"
        elif num_operands == 3:
            return "I (OP3)"

        return "U"

    def __str__(self):
        addrs = self.addrToCinst.keys()

        rets = []
        rets += ["="*30]
        rets += ["LOC: %s" % self.loc]
        rets += ["\t %s" % get_kernel_srcline(self.loc)]
        rets += [""]
        next_addr = -1
        for addr in sorted(addrs):
            tag = self.addrToTag[addr]
            cinst = self.addrToCinst[addr]
            if next_addr != addr:
                # broken instruction stream, so represent this steam into newline.
                rets += [""]
            addr_info = "[%8s] 0x%x: [%d][%s %s] (%s)" % (tag, addr, self.addrToSize[addr],
                                                          cinst.mnemonic, cinst.op_str,
                                                          self.addrToObjdumpDisas[addr])
            next_addr = addr + self.addrToSize[addr]
            rets += [addr_info]
        return "\n" + "\n".join(rets)

def collect_asms_per_loc(asm_lines, addrToLoc):
    cur_func = ""

    locInfoMap = {}

    for line in asm_lines:
        if len(line) == 0:
            continue
        if line.endswith(">:"):
            # get the function name
            cur_func = line[line.find('<')+1: line.find('>')]
        if line.startswith("ffffffff") and line[16] == ':':
            # this line contains the machine code
            addr = int(line[:16],16)

            loc = addrToLoc.get(addr, None)
            if loc == None:
                continue

            toks = [x.strip() for x in line.split("\t")]

            if len(toks) < 3:
                continue
            raw_bytes = toks[1]
            disas = toks[2]

            if not loc in locInfoMap:
                locInfoMap[loc] = LocInfo(loc)
            locInfoMap[loc].add_instr(addr, cur_func, raw_bytes, disas)
    return locInfoMap

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


def take_dwarfdump_lines(vmlinux, vmlinux_md5):
    save_fn = os.path.join(TMP_DIR, "dwarfdump-%s.txt" % vmlinux_md5)
    if os.path.exists(save_fn):
        eprint("\t Loading from backup: %s" % save_fn)
        return open(save_fn).read().split('\n')

    dwarfdump = "dwarfdump"
    dwarfopt = '-l'

    out_dwarfdump = subprocess.check_output([dwarfdump, dwarfopt, vmlinux])
    open(save_fn, "w").write(out_dwarfdump)
    return out_dwarfdump.split('\n')

def collect_debug_info(dwarfdump_lines, mempair_locs):
    filename = None
    addrToLoc = {}

    prev_addr = -1
    prev_loc = None
    for line in dwarfdump_lines:
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
            filename = strip_start(filename, KERNEL_PREFIX)

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

        if loc in mempair_locs:
            addrToLoc[addr] = loc

        if prev_addr != -1:
            for addr0 in range(prev_addr+1, addr):
                if prev_loc in mempair_locs:
                    addrToLoc[addr0] = prev_loc
        prev_addr = addr
        prev_loc = loc

        # End of text sequence
        if "ET" in line:
            prev_addr = -1
            prev_loc = None

    return addrToLoc

def take_mempair_locs(mempair_fn):
    mempair_locs = set()
    for line in open(mempair_fn):
        a = line.split()[:2]
        for loc in a:
            mempair_locs.add(loc)

    return mempair_locs

def dump_loc_instr_info(locInfoMap):
    f = open("loc_to_instr.txt", "w")
    for _, locInfo in locInfoMap.iteritems():
        f.write(str(locInfo))
    f.close()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("mem_pair_file")

    args = parser.parse_args()

    vmlinux = os.environ['KERNEL_BUILD'] + 'vmlinux'
    mempair_fn = args.mem_pair_file

    vmlinux_md5 = compute_md5(vmlinux)

    eprint("[*] vmlinux: ", vmlinux)
    eprint("[*] mempair: ", mempair_fn)
    eprint("[*] kernel : ", os.environ['KERNEL_DIR'])

    # ===================================================
    eprint("[*] Loading mempair locs")
    mempair_locs = take_mempair_locs(mempair_fn)
    eprint("[*] Loaded %d mempair locs" % len(mempair_locs))

    # ===================================================
    # get the dwarf info
    # Result: map (filename, line, column=0) -> {memacc_addr}
    eprint("[*] Taking dwarfdump of vmlinux")
    dwarfdump_lines = take_dwarfdump_lines(vmlinux, vmlinux_md5)

    eprint("[*] Collecting debug info from dwarfdump")
    addrToLoc = collect_debug_info(dwarfdump_lines, mempair_locs)

    # for addr in dbg_addrs:
    #     print("%x : %s" % (addr, addrToLoc.get(addr, "NA")))

    # ===================================================
    eprint("[*] Taking objdump of vmlinux")
    asm_lines = take_objdump_lines(vmlinux, vmlinux_md5)

    eprint("[*] Collecting asms per loc")
    locInfoMap = collect_asms_per_loc(asm_lines, addrToLoc)
    eprint("[*] Loaded %d locInfos (<> %d mempair locs)" % (len(locInfoMap), len(mempair_locs)))

    # for loc in mempair_locs:
    #     if locInfoMap.get(loc, None) == None:
    #         eprint("\t missing %s in locInfoMap" % loc)


    eprint("[*] Dumping loc instr info")
    dump_loc_instr_info(locInfoMap)

    eprint("[*] Print mapping info")
    print_mapping(locInfoMap)
    eprint("[*] DONE")

    # ===================================================
    # Parse the instruction and guess it accesses memory
    # Result: memacc_addr, addresses that access memory
    # eprint("[*] Parsing objdump to compute addresses that access memory")
    # memacc_addr, funcs = parse_objdump(asm_lines)

    # # ===========================================================================
    # # Result: reduced map (filename, line, column) -> {memacc_addr}
    # eprint("[*] Calculating the address of each source location")

    # print("[", end='')
    # not_first = False
    # for loc in locToAddrs:
    #     if len(locToAddrs[loc]) == 0:
    #         continue
    #     if not_first:
    #         print(",")
    #     not_first = True
    #     print("{", end='')
    #     print("\"loc\"\t: ", end='')
    #     print("\"" + loc + "\"", end='')
    #     print(",")
    #     print("\"item\"\t: [", end='')
    #     not_first_ = False
    #     for addr in locToAddrs[loc]:
    #         if not_first_:
    #             print(",", end='')
    #         print(addr, end='')
    #         not_first_ = True
    #     print("],")
    #     print("\"func\"\t: [", end='')
    #     not_first_ = False
    #     for addr in locToAddrs[loc]:
    #         if not_first_:
    #             print(",", end='')
    #         print("\"" + funcs[addr] + "\"", end='')
    #         not_first_ = True
    #     print("]", end='')
    #     print("}", end='')
    # print("]")


def print_mapping(locInfoMap):
    entries = []

    for loc, locInfo in locInfoMap.iteritems():
        for tag in ["R", "W", "RW"]:
            entry = {}
            entry["loc"] = loc
            entry["tag"] = tag
            item_set = set()
            func_set = set()
            addrs = locInfo.addrToTag.keys()
            for addr in sorted(addrs):
                if locInfo.addrToTag[addr] == tag:
                    func = locInfo.addrToFunc[addr]
                    item_set.add(addr)
                    func_set.add(func)
            entry["item"] = list(item_set)
            entry["func"] = list(func_set)

            if len(entry["item"]) > 0:
                entries.append(entry)

    json_str = json.dumps(entries, sort_keys=True, indent=4, separators=(',', ': '))
    print (json_str)


def test_dwarfdump():
    parser = argparse.ArgumentParser()
    parser.add_argument("mem_pair_file")

    args = parser.parse_args()

    vmlinux = os.environ['KERNEL_BUILD'] + 'vmlinux'
    mempair_fn = args.mem_pair_file


    mempair_locs = take_mempair_locs(mempair_fn)
    dwarfdump_lines = dbg_dwarfdump.split("\n")
    addrToLoc = collect_debug_info(dwarfdump_lines, mempair_locs)
    print("")
    for addr in dbg_addrs:
        print("%x : %s" % (addr, addrToLoc.get(addr, "NA")))

def get_kernel_srcline(loc):
    toks = loc.split(":")
    fn = os.path.join(KERNEL_PREFIX, toks[0])
    line_num = int(toks[1])

    srcline = open(fn).read().split("\n")[line_num-1]
    return srcline.strip()

def test_capstone():
    raw_bytes_to_test = []
    raw_bytes_to_test += ["55"]
    raw_bytes_to_test += ["e8 47 5a ed ff"]
    raw_bytes_to_test += ["4d 8b 6c 24 20"]
    raw_bytes_to_test += ["0f 85 3a 02 00 00"]
    raw_bytes_to_test += ["48 bb 00 00 00 00 00 fc ff df"]
    raw_bytes_to_test += ["48 c7 83 40 ff ff ff 00 00 00 00"]

    for raw_bytes in raw_bytes_to_test:
        cinst = get_cinst_from_raw_bytes(0x1000, raw_bytes)
        eprint("%s %s" % (cinst.mnemonic, cinst.op_str))
        eprint("\t operands:", cinst.operands)


if __name__ == '__main__':
    main()
    # test_dwarfdump()
    # eprint(get_kernel_srcline("drivers/tty/n_hdlc.c:766:0"))
    # test_capstone()
