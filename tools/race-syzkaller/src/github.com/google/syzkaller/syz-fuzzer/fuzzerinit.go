package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"runtime/debug"
	"strings"
	"syscall"
	"time"

	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/hash"
	"github.com/google/syzkaller/pkg/ipc"
	. "github.com/google/syzkaller/pkg/log"
	"github.com/google/syzkaller/pkg/osutil"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/prog"
	"github.com/google/syzkaller/sys"
)

var (
	flagOutput = flag.String("output", "stdout", "write programs to none/stdout/dmesg/file")
	flagTest   = flag.Bool("test", false, "enable image testing mode") // used by syz-ci
)

type OutputType int

const (
	OutputNone OutputType = iota
	OutputStdout
	OutputDmesg
	OutputFile
)

func fuzzerInit() *Fuzzer {
	target, err := prog.GetTarget(runtime.GOOS, *flagArch)
	if err != nil {
		Fatalf("%v", err)
	}

	config, execOpts, err := ipc.DefaultConfig(false)
	if err != nil {
		panic(err)
	}

	outputType := getOutputType()
	sandbox := getSandbox(config)

	if *flagTest {
		testImage(*flagManager, target, sandbox)
		return nil
	}

	if *flagPprof != "" {
		go func() {
			err := http.ListenAndServe(*flagPprof, nil)
			Fatalf("failed to serve pprof profiles: %v", err)
		}()
	} else {
		runtime.MemProfileRate = 0
	}

	Logf(0, "dialing manager at %v", *flagManager)
	a := &ConnectArgs{*flagName}
	r := &ConnectRes{}
	if err := RPCCall(*flagManager, "Manager.Connect", a, r); err != nil {
		panic(err)
	}

	calls, disabled := buildCallList(target, r.EnabledCalls, sandbox)
	ct := target.BuildChoiceTable(r.Prios, calls)

	// This requires "fault-inject: support systematic fault injection" kernel commit.
	// TODO(dvykov): also need to check presence of /sys/kernel/debug/failslab/ignore-gfp-wait
	// and /sys/kernel/debug/fail_futex/ignore-private, they can be missing if
	// CONFIG_FAULT_INJECTION_DEBUG_FS is not enabled.
	// Also need to move this somewhere else (to linux-specific part).
	faultInjectionEnabled := false
	if fd, err := syscall.Open("/proc/self/fail-nth", syscall.O_RDWR, 0); err == nil {
		syscall.Close(fd)
		faultInjectionEnabled = true
	}

	if calls[target.SyscallMap["syz_emit_ethernet"]] ||
		calls[target.SyscallMap["syz_extract_tcp_res"]] {
		config.Flags |= ipc.FlagEnableTun
	}
	if faultInjectionEnabled {
		config.Flags |= ipc.FlagEnableFault
	}
	coverageEnabled := config.Flags&ipc.FlagSignal != 0

	kcov, comparisonTracingEnabled := checkCompsSupported()
	Logf(0, "kcov=%v, comps=%v", kcov, comparisonTracingEnabled)
	if r.NeedCheck {
		out, err := osutil.RunCmd(time.Minute, "", config.Executor, "version")
		if err != nil {
			panic(err)
		}
		vers := strings.Split(strings.TrimSpace(string(out)), " ")
		if len(vers) != 4 {
			panic(fmt.Sprintf("bad executor version: %q", string(out)))
		}
		a := &CheckArgs{
			Name:           *flagName,
			UserNamespaces: osutil.IsExist("/proc/self/ns/user"),
			FuzzerGitRev:   sys.GitRevision,
			FuzzerSyzRev:   target.Revision,
			ExecutorGitRev: vers[3],
			ExecutorSyzRev: vers[2],
			ExecutorArch:   vers[1],
			DisabledCalls:  disabled,
		}
		a.Kcov = kcov
		if fd, err := syscall.Open("/sys/kernel/debug/kmemleak", syscall.O_RDWR, 0); err == nil {
			syscall.Close(fd)
			a.Leak = true
		}
		a.Fault = faultInjectionEnabled
		a.CompsSupported = comparisonTracingEnabled
		for c := range calls {
			a.Calls = append(a.Calls, c.Name)
		}
		if err := RPCCall(*flagManager, "Manager.Check", a, nil); err != nil {
			panic(err)
		}
	}

	sparseRaceCandPairs := make(map[uint32][]EntryTy)
	for k, v := range r.SparseRaceCandPairs {
		sparseRaceCandPairs[k] = append(sparseRaceCandPairs[k], v...)
	}

	// Manager.Connect reply can ve very large and that memory will be permanently cached in the connection.
	// So we do the call on a transient connection, free all memory and reconnect.
	// The rest of rpc requests have bounded size.
	debug.FreeOSMemory()
	manager, err := NewRPCClient(*flagManager)
	if err != nil {
		panic(err)
	}

	kmemleakInit(*flagLeak)

	needPoll := make(chan struct{}, 1)
	needPoll <- struct{}{}
	fuzzer := &Fuzzer{
		name:                     *flagName,
		outputType:               outputType,
		config:                   config,
		execOpts:                 execOpts,
		workQueue:                newWorkQueue(*flagProcs, needPoll),
		needPoll:                 needPoll,
		choiceTable:              ct,
		manager:                  manager,
		target:                   target,
		faultInjectionEnabled:    faultInjectionEnabled,
		comparisonTracingEnabled: comparisonTracingEnabled,
		coverageEnabled:          coverageEnabled,
		leakCheckEnabled:         *flagLeak,
		corpusHashes:             make(map[hash.Sig]struct{}),

		sparseRaceCandPairs: sparseRaceCandPairs,
		suppressedPairs:     make(map[MempairHash]struct{}),
	}
	fuzzer.gate = ipc.NewGate(2**flagProcs, fuzzer.leakCheckCallback)

	for _, inp := range r.Inputs {
		fuzzer.addInputFromAnotherFuzzer(inp)
	}
	fuzzer.addMaxSignal(r.MaxSignal.Deserialize())
	for _, candidate := range r.Candidates {
		p, err := fuzzer.target.Deserialize(candidate.Prog)
		if err != nil {
			panic(err)
		}
		if coverageEnabled {
			flags := ProgCandidate
			if candidate.Minimized {
				flags |= ProgMinimized
			}
			if candidate.Smashed {
				flags |= ProgSmashed
			}
			fuzzer.workQueue.enqueue(&WorkCandidate{
				p:     p,
				flags: flags,
			})
		} else {
			fuzzer.addInputToCorpus(p, nil, hash.Hash(candidate.Prog))
		}
	}

	return fuzzer
}

func getOutputType() OutputType {
	var outputType OutputType
	switch *flagOutput {
	case "none":
		outputType = OutputNone
	case "stdout":
		outputType = OutputStdout
	case "dmesg":
		outputType = OutputDmesg
	case "file":
		outputType = OutputFile
	default:
		fmt.Fprintf(os.Stderr, "-output flag must be one of none/stdout/dmesg/file\n")
		os.Exit(1)
	}
	return outputType
}

func getSandbox(config *ipc.Config) string {
	sandbox := "none"
	if config.Flags&ipc.FlagSandboxSetuid != 0 {
		sandbox = "setuid"
	} else if config.Flags&ipc.FlagSandboxNamespace != 0 {
		sandbox = "namespace"
	}
	return sandbox
}
