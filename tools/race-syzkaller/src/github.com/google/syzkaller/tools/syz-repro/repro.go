// Copyright 2015 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

package main

import (
	"flag"
	"fmt"
	"io/ioutil"
	"os"

	"github.com/google/syzkaller/pkg/csource"
	"github.com/google/syzkaller/pkg/log"
	"github.com/google/syzkaller/pkg/osutil"
	"github.com/google/syzkaller/pkg/report"
	"github.com/google/syzkaller/pkg/repro"
	"github.com/google/syzkaller/prog"
	"github.com/google/syzkaller/syz-manager/mgrconfig"
	"github.com/google/syzkaller/vm"
)

var (
	flagConfig = flag.String("config", "", "configuration file")
	flagCount  = flag.Int("count", 0, "number of VMs to use (overrides config count param)")
)

func main() {
	os.Args = append(append([]string{}, os.Args[0], "-v=10"), os.Args[1:]...)
	flag.Parse()
	cfg, err := mgrconfig.LoadFile(*flagConfig)
	if err != nil {
		log.Fatalf("%v", err)
	}
	if len(flag.Args()) != 1 {
		log.Fatalf("usage: syz-repro -config=config.file execution.log")
	}
	data, err := ioutil.ReadFile(flag.Args()[0])
	if err != nil {
		log.Fatalf("failed to open log file: %v", err)
	}
	if _, err := prog.GetTarget(cfg.TargetOS, cfg.TargetArch); err != nil {
		log.Fatalf("%v", err)
	}
	env := mgrconfig.CreateVMEnv(cfg, false, false)
	vmPool, err := vm.Create(cfg.Type, env)
	if err != nil {
		log.Fatalf("%v", err)
	}
	vmCount := vmPool.Count()
	if *flagCount > 0 && *flagCount < vmCount {
		vmCount = *flagCount
	}
	if vmCount > 4 {
		vmCount = 4
	}
	vmIndexes := make([]int, vmCount)
	for i := range vmIndexes {
		vmIndexes[i] = i
	}
	reporter, err := report.NewReporter(cfg.TargetOS, cfg.Kernel_Src, "", nil, cfg.ParsedIgnores)
	if err != nil {
		log.Fatalf("%v", err)
	}
	osutil.HandleInterrupts(vm.Shutdown)

	res, err := repro.Run(data, cfg, reporter, vmPool, vmIndexes)
	if err != nil {
		log.Logf(0, "reproduction failed: %v", err)
	}
	if res == nil {
		return
	}

	fmt.Printf("opts: %+v crepro: %v\n\n", res.Opts, res.CRepro)
	fmt.Printf("%s\n", res.Prog.Serialize())
	if res.CRepro {
		src, err := csource.Write(res.Prog, res.Opts)
		if err != nil {
			log.Fatalf("failed to generate C repro: %v", err)
		}
		if formatted, err := csource.Format(src); err == nil {
			src = formatted
		}
		fmt.Printf("%s\n", src)
	}
}
