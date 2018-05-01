package main

import (
	"flag"
	"fmt"
	"net/http"
	"os"
	"runtime"
	"runtime/debug"

	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/hash"
	"github.com/google/syzkaller/pkg/ipc"
	. "github.com/google/syzkaller/pkg/log"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/prog"
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

func schedulerInit() *Scheduler {
	var corpus []*prog.Prog

	target, err := prog.GetTarget(runtime.GOOS, *flagArch)
	if err != nil {
		Fatalf("%v", err)
	}

	config, execOpts, err := ipc.DefaultConfig(true)
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

	Logf(0, "[SCHED] dialing manager at %v", *flagManager)
	a := &ConnectArgs{*flagName}
	r := &SchedulerConnectRes{}
	if err := RPCCall(*flagManager, "Manager.SchedulerConnect", a, r); err != nil {
		panic(err)
	}

	calls, _ := buildCallList(target, r.EnabledCalls, sandbox)
	ct := target.BuildChoiceTable(r.Prios, calls)

	if calls[target.SyscallMap["syz_emit_ethernet"]] ||
		calls[target.SyscallMap["syz_extract_tcp_res"]] {
		config.Flags |= ipc.FlagEnableTun
	}
	coverageEnabled := config.Flags&ipc.FlagSignal != 0

	kcov, comparisonTracingEnabled := checkCompsSupported()
	Logf(0, "[SCHED] kcov=%v, comps=%v", kcov, comparisonTracingEnabled)

	// ----- Race fuzzer related -----
	mempairs := append([]Mempair{}, r.Mempair...)

	for _, inp := range r.Corpus {
		p, err := target.Deserialize(inp.Prog)
		if err != nil {
			panic(err)
		}
		corpus = append(corpus, p)
	}

	// Manager.Connect reply can ve very large and that memory will be permanently cached in the connection.
	// So we do the call on a transient connection, free all memory and reconnect.
	// The rest of rpc requests have bounded size.
	debug.FreeOSMemory()
	manager, err := NewRPCClient(*flagManager)
	if err != nil {
		panic(err)
	}

	// kmemleakInit(*flagLeak)

	needPoll := make(chan struct{}, 1)
	needPoll <- struct{}{}
	scheduler := &Scheduler{
		name:        *flagName,
		outputType:  outputType,
		config:      config,
		execOpts:    execOpts,
		workQueue:   newWorkQueue(*flagProcs, needPoll),
		needPoll:    needPoll,
		choiceTable: ct,
		manager:     manager,
		target:      target,
		comparisonTracingEnabled: comparisonTracingEnabled,
		coverageEnabled:          coverageEnabled,
		leakCheckEnabled:         *flagLeak,
		corpusHashes:             make(map[hash.Sig]struct{}),

		mempairs:          mempairs,
		trueRaceHashesMap: make(map[MempairHash]struct{}),
		mempairExecInfo:   make(map[MempairHash]RaceExecInfo),
		suppressedPairs:   make(map[MempairHash]struct{}),

		likelyRaceCorpus:     make(map[MempairHash]RaceCandidate),
		raceCorpusPerMempair: make(map[MempairHash][]RaceCandidate),
		raceCorpusHashes:     make(map[hash.Sig]struct{}),
	}

	for _, raceProg := range r.RaceProgCands {
		p, err := target.Deserialize(raceProg.Prog)
		if err != nil {
			panic(err)
		}
		for _, raceinfo := range raceProg.RaceInfos {
			var rc *WorkCandidate
			if raceProg.FromDB {
				rc = &WorkCandidate{p: p, RaceInfo: raceinfo, flags: ProgMinimized}
			} else {
				rc = &WorkCandidate{p: p, RaceInfo: raceinfo, flags: ProgCandidate}
			}
			scheduler.workQueue.enqueue(rc)
		}
	}
	Logf(1, "[SCHED] size of raceProgCandidates: %v", len(scheduler.workQueue.candidate))

	scheduler.gate = ipc.NewGate(2**flagProcs, scheduler.leakCheckCallback)

	for _, rinp := range r.RaceInputs {
		scheduler.addRaceInputFromScheduler(rinp)
	}

	scheduler.addRaceMaxSignal(r.RaceMaxSignal.Deserialize())

	for _, hsh := range r.TrueRaceHashes {
		scheduler.trueRaceHashesMap[hsh] = struct{}{}
		scheduler.trueRaceHashes = append(scheduler.trueRaceHashes, hsh)
	}

	for _, rinp := range r.LikelyRaceInputs {
		scheduler.addToLikelyRaceCorpus(rinp)
	}

	r = nil

	return scheduler
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
