#!/usr/bin/env python3
from __future__ import print_function

from multiprocessing import Pool
import time
import os
import sys
import glob

MAX_SIZE = 30*1024*1024
NUM_PROC = 16

kernel_build_dir = os.path.join(os.environ['LLVMLINUX_HOME'],
                                "targets/x86_64/",
                                "build-%s" % os.environ["KERNEL_VERSION"],
                                "kernel-clang")

default_bcs = []
default_bcs += ["init/built-in.bc"]
default_bcs += ["fs/built-in.bc"]
default_bcs += ["ipc/built-in.bc"]

net_default_bcs = []
net_default_bcs += ["net/core/built-in.bc"]
net_default_bcs += ["net/ipv4/built-in.bc"]

drivers_default_bcs = []
drivers_default_bcs += ["drivers/base/built-in.bc"]
drivers_default_bcs += ["drivers/char/built-in.bc"]
drivers_default_bcs += ["drivers/block/built-in.bc"]

def load_lst(fn):
    builtins = []
    fstr = open(fn).read()

    for line in fstr.split("\n"):
        line = line.strip()
        if line == "" or line.startswith("#"):
            continue
        bc, size = line.split("\t\t")
        assert(bc.endswith(".bc"))
        builtins.append([bc])
    return builtins

def get_filesize_sum(fns):
    size = 0
    for fn in fns:
        size += os.path.getsize(fn)
    return size

def add_default(bcs, default):
    for bc in default:
        bc_path = os.path.join(kernel_build_dir, bc)
        if not os.path.exists(bc_path):
            continue

        if bc not in bcs:
            bcs.append(bc)
    return bcs

def do_analyze(arg):
    i, total, bcs = arg

    analysis_title = bcs[0]

    bcs = add_default(bcs, default_bcs)

    if analysis_title.startswith("net/"):
        bcs = add_default(bcs, net_default_bcs)

    if analysis_title.startswith("drivers/"):
        bcs = add_default(bcs, drivers_default_bcs)

    bcs_str = " ".join(bcs)
    print("[%d/%d] begin do_analyze( %s )" % (i, total, bcs_str))
    cmdstr = "./partitioned_analysis.sh %s" % bcs_str

    exit_status = os.system(cmdstr)
    if exit_status != 0:
        print ("\t[WARNING] partitioned_analysis failed!: %s" % analysis_title)

    print("[%d/%d] end do_analyze( %s )"% (i, total, bcs_str))
    return

def analyze(bcgroups):
    pool = Pool(processes=NUM_PROC)
    args = zip(range(len(bcgroups)), [len(bcgroups)]*len(bcgroups), bcgroups)
    pool.map(do_analyze, args)

def get_kver():
    kver = os.environ['KERNEL_VERSION'].strip()
    if kver == "" or not kver.startswith("v"):
        print("[ERR] Incorrect kernel version (%s)" % kver)
        sys.exit(-1)
    return kver

def recursive_collect_all_bcs(kernel_build_dir):
    import fnmatch
    import os

    matches = []
    for root, dirnames, filenames in os.walk(kernel_build_dir):
        for filename in fnmatch.filter(filenames, "*.bc"):
            matches.append(os.path.join(root, filename))
    return matches

def get_readable_size(size):
    postfixes = ["B", "K", "M", "G"]

    for postfix in postfixes:
        if size < 1024:
            return "%d%s" % (size, postfix)
        size = size/1024
    return "NA"

class DirTreeNode:
    def __init__(self, dname, path, depth):
        self.dname = dname
        self.path = os.path.join(path, dname)
        self.bcs = []
        self.child_nodes = []
        self.parent_node = None
        self.depth = depth
        self.builtin_size = -1
        self.non_builtin_size = -1
        self.child_size = -1

    def add_bc(self, bc):
        self.bcs.append(bc)

    def get_builtin_bc(self):
        if not "built-in.bc" in self.bcs:
            return None
        return os.path.join(self.path, "built-in.bc")

    def get_non_builtin_bcs(self):
        return [os.path.join(self.path, x) for x in self.bcs if x != "built-in.bc"]

    def get_opt2_size(self):
        return self.builtin_size

    def get_opt2_bcs(self):
        return [self.get_builtin_bc()]

    def get_opt1_size(self):
        # TODO: Fix opt1 size, not important
        if self.parent_node and self.parent_node.non_builtin_size != -1:
            if self.builtin_size != -1:
                return self.parent_node.non_builtin_size + self.builtin_size
        return -1

    def get_opt1_bcs(self):
        pnode = self.parent_node
        if pnode == None:
            return None
        
        pnode_non_builtin_bcs = []
        while pnode != None:
            pnode_non_builtin_bcs += (pnode.get_non_builtin_bcs())
            pnode = pnode.parent_node

        if not "built-in.bc" in self.bcs:
            return None

        bcs = [self.get_builtin_bc()]
        bcs += pnode_non_builtin_bcs
        return bcs

    def get_child_node_by_dname(self, dname):
        matches = [x for x in self.child_nodes if x.dname == dname]

        assert(len(matches) == 1 or len(matches) == 0)
        if len(matches) == 1:
            return matches[0]
        return None

    def add_child_node(self, cnode):
        self.child_nodes.append(cnode)

    def set_parent_node(self, pnode):
        self.parent_node = pnode

    def __str__(self):
        s = "[%s][%d][%s] [%s]: %d childs, %d bcs" % (self.dname, self.depth, self.path,
                                                      get_readable_size(self.child_size),
                                                      len(self.child_nodes), len(self.bcs))
        return s

    def get_size_info(self, is_opt1 = True):
        if is_opt1:
            sizestr = get_readable_size(self.get_opt1_size())
        else:
            sizestr = get_readable_size(self.get_opt2_size())
        s = "[%s] %s" % (self.path, sizestr)
        return s

def build_dir_tree(pnode, sub_dirs):
    dname = sub_dirs[0]

    if dname.endswith(".bc"):
        pnode.add_bc(dname)
    else:
        node = pnode.get_child_node_by_dname(dname)
        if node == None:
            node = DirTreeNode(dname, pnode.path, pnode.depth+1)
            node.set_parent_node(pnode)
            pnode.add_child_node(node)
        build_dir_tree(node, sub_dirs[1:])
    return

def auto_collect_bcs(kver):

    print(kernel_build_dir)

    files = recursive_collect_all_bcs(kernel_build_dir)
    files = [x.replace(kernel_build_dir, "") for x in set(files)]
    files = sorted(files)

    print(len(files))

    # Build Dir Tree
    root_node = DirTreeNode("", "", 0)
    for fn in files:
        dirs = [x for x in fn.split("/") if x != ""]
        build_dir_tree(root_node, dirs)

    visit_to_compute_bcsize(root_node, kernel_build_dir)

    bcgroups = visit_to_collect(root_node, kernel_build_dir)

    # Ensure none of the "first" bc overlaps with others, as the first
    # bc will be used as the analysis name.
    names = []
    for bcs in bcgroups:
        name = bcs[0]
        if name in names:
            assert(False and "the first bc should not collide")
        names.append(name)

    return bcgroups

def visit_to_collect(pnode, kernel_build_dir):
    bcgroups = []
    #1 parent's non_builtin + current built-in

    handled = False
    opt1_size = pnode.get_opt1_size()
    if opt1_size != -1 and opt1_size < MAX_SIZE:
        print("[OPT1]       ", pnode.get_size_info())
        print("\t\t\t", pnode.get_opt1_bcs())

        bcgroups.append(pnode.get_opt1_bcs())
        handled = True


    if not handled:
        handled = True
        for cnode in pnode.child_nodes:
            bcs = visit_to_collect(cnode, kernel_build_dir)
            bcgroups.extend(bcs)
            if len(bcs) == 0:
                handled = False

        if not handled:
            #2 fallback scheme: just current built-in

            opt2_size = pnode.get_opt2_size()
            if opt2_size != -1 and opt2_size < MAX_SIZE:
                print("[OPT2]     ", pnode.get_size_info(False))
                print("\t\t\t", pnode.get_opt2_bcs())
                bcgroups.append(pnode.get_opt2_bcs())
    return bcgroups

def visit_to_compute_bcsize(pnode, kernel_build_dir):
    for cnode in pnode.child_nodes:
        visit_to_compute_bcsize(cnode, kernel_build_dir)

    # compute sum of bc files
    non_builtin_size = 0
    for bc in pnode.get_non_builtin_bcs():
        fn = os.path.join(kernel_build_dir, bc)
        non_builtin_size += os.path.getsize(fn)

    pnode.non_builtin_size = non_builtin_size
    builtin_fn = pnode.get_builtin_bc()
    if builtin_fn != None:
        pnode.builtin_size = os.path.getsize(os.path.join(kernel_build_dir, pnode.get_builtin_bc()))

    child_size = 0
    for cnode in pnode.child_nodes:
        if cnode.builtin_size != -1:
            child_size += cnode.builtin_size
        elif cnode.non_builtin_size != -1:
            child_size += cnode.non_builtin_size
        else:
            print(cnode)
            assert(False and "something wrong")
    pnode.child_size = child_size

if __name__ == "__main__":
    kver = get_kver()

    print("[*] kernel version: (%s)" % kver)

    # Automatically collect target bc files to analyze
    bcgroups = auto_collect_bcs(kver)
    print("total # groups %d" % len(bcgroups))

    # Use pre-defined bc file list
    analyze(bcgroups)
