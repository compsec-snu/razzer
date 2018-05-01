// Copyright 2015 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

package main

import (
	"flag"
	"math/rand"
	_ "net/http/pprof"
	"os"
	"runtime"
	"runtime/debug"
	"sync"
	"sync/atomic"
	"time"

	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/hash"
	"github.com/google/syzkaller/pkg/host"
	"github.com/google/syzkaller/pkg/ipc"
	. "github.com/google/syzkaller/pkg/log"
	"github.com/google/syzkaller/pkg/osutil"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/pkg/signal"
	"github.com/google/syzkaller/prog"
)

var (
	flagName       = flag.String("name", "test", "unique name for manager")
	flagArch       = flag.String("arch", runtime.GOARCH, "target arch")
	flagManager    = flag.String("manager", "", "manager rpc address")
	flagProcs      = flag.Int("procs", 1, "number of parallel test processes")
	flagLeak       = flag.Bool("leak", false, "detect memory leaks")
	flagPprof      = flag.String("pprof", "", "address to serve pprof profiles")
	flagRootCause  = flag.Bool("rootcause", false, "rootcause analysis using program logs")
	flagSuppOption = flag.Int("supp", 1, "memapri suppresion (0: both, 1: freq, 2: signal)")
)

type Fuzzer struct {
	name        string
	outputType  OutputType
	config      *ipc.Config
	execOpts    *ipc.ExecOpts
	procs       []*Proc
	gate        *ipc.Gate
	workQueue   *WorkQueue
	needPoll    chan struct{}
	choiceTable *prog.ChoiceTable
	stats       [StatCount]uint64
	manager     *RPCClient
	target      *prog.Target

	faultInjectionEnabled    bool
	comparisonTracingEnabled bool
	coverageEnabled          bool
	leakCheckEnabled         bool
	leakCheckReady           uint32

	corpusMu     sync.RWMutex
	corpus       []*prog.Prog
	corpusHashes map[hash.Sig]struct{}

	signalMu     sync.RWMutex
	corpusSignal signal.Signal // signal of inputs in corpus
	maxSignal    signal.Signal // max signal ever observed including flakes
	newSignal    signal.Signal // diff of maxSignal since last sync with master

	logMu sync.Mutex

	lastPoll time.Time

	// ----- Race fuzzer -----
	timeStat TimeStat

	// static analysis result
	sparseRaceCandPairs map[uint32][]EntryTy

	// raceprog cand from fuzzer to sched
	qMu                  sync.RWMutex
	newRaceProgCandQueue []*NewRaceProgCandArgs

	// suppression
	suppressedPairsMu sync.RWMutex
	suppressedPairs   map[MempairHash]struct{}
}

type Stat int

const (
	StatGenerate Stat = iota
	StatFuzz
	StatCandidate
	StatTriage
	StatMinimize
	StatSmash
	StatHint
	StatSeed
	StatRcPush
	StatRcMaxRaceInfo
	StatRcPop
	StatRcSuppFreq
	StatCount
)

var statNames = [StatCount]string{
	StatGenerate:      "exec gen",
	StatFuzz:          "exec fuzz",
	StatCandidate:     "exec candidate",
	StatTriage:        "exec triage",
	StatMinimize:      "exec minimize",
	StatSmash:         "exec smash",
	StatHint:          "exec hints",
	StatSeed:          "exec seeds",
	StatRcPush:        "rc push",
	StatRcMaxRaceInfo: "rc max raceinfo",
	StatRcPop:         "rc pop",
	StatRcSuppFreq:    "rc supp freq",
}

func main() {
	debug.SetGCPercent(50)

	flag.Parse()
	Logf(0, "[FUZZER] fuzzer started")

	shutdown := make(chan struct{})
	osutil.HandleInterrupts(shutdown)
	go func() {
		// Handles graceful preemption on GCE.
		<-shutdown
		Logf(0, "[FUZZER] SYZ-FUZZER: PREEMPTED")
		os.Exit(1)
	}()

	fuzzer := fuzzerInit()
	if fuzzer == nil /* *flagTest == True */ {
		return
	}

	for pid := 0; pid < *flagProcs; pid++ {
		proc, err := newProc(fuzzer, pid)
		if err != nil {
			Fatalf("failed to create proc: %v", err)
		}
		fuzzer.procs = append(fuzzer.procs, proc)
		go proc.loop()
	}

	fuzzer.pollLoop()
}

func (fuzzer *Fuzzer) pollLoop() {
	ticker := time.NewTicker(3 * time.Second).C
	for {
		poll := false
		select {
		case <-ticker:
		case <-fuzzer.needPoll:
			poll = true
		}
		fuzzer.pingManager()
		if poll || time.Since(fuzzer.lastPoll) > 10*time.Second {
			needCandidates := fuzzer.workQueue.wantCandidates()
			if poll && !needCandidates {
				continue
			}

			a, r := fuzzer.initPoll(needCandidates)
			if err := fuzzer.manager.Call("Manager.FuzzerPoll", a, r); err != nil {
				panic(err)
			}
			fuzzer.finishPoll(r)

		}
	}
}

var lastPrint time.Time
var execTotal uint64

func (fuzzer *Fuzzer) pingManager() {
	if fuzzer.outputType != OutputStdout && time.Since(lastPrint) > 10*time.Second {
		// Keep-alive for manager.
		Logf(0, "[FUZZER] alive, executed %v", execTotal)
		lastPrint = time.Now()
	}
}

func (fuzzer *Fuzzer) updateStats(a *PollArgs) {
	for _, proc := range fuzzer.procs {
		a.Stats["fuzzer exec total"] += atomic.SwapUint64(&proc.env.StatExecs, 0)
		a.Stats["fuzzer executor restarts"] += atomic.SwapUint64(&proc.env.StatRestarts, 0)
	}

	for stat := Stat(0); stat < StatCount; stat++ {
		v := atomic.SwapUint64(&fuzzer.stats[stat], 0)
		a.Stats["fuzzer "+statNames[stat]] = v
		execTotal += v
	}
}

func (fuzzer *Fuzzer) popFromNewRaceCandQueue(numToPop int) []*NewRaceProgCandArgs {
	fuzzer.qMu.Lock()
	defer fuzzer.qMu.Unlock()

	if numToPop >= len(fuzzer.newRaceProgCandQueue) {
		numToPop = len(fuzzer.newRaceProgCandQueue)
	}
	if numToPop == 0 {
		return []*NewRaceProgCandArgs{}
	}

	// popTurn = (popTurn+1)%3
	popTurn := 0
	idx := 0
	switch popTurn {
	case 0:
		// FIFO. Do nothing
	case 1:
		// LIFO
		idx = len(fuzzer.newRaceProgCandQueue) - numToPop
	case 2:
		// Random
		idx = len(fuzzer.newRaceProgCandQueue) - numToPop
		if idx != 0 {
			idx = rand.Intn(idx)
		}
	default:
		panic("Wrong popTurn")
	}

	popedCands := make([]*NewRaceProgCandArgs, numToPop)
	copy(popedCands, fuzzer.newRaceProgCandQueue[idx:idx+numToPop])
	fuzzer.newRaceProgCandQueue = append(fuzzer.newRaceProgCandQueue[:idx],
		fuzzer.newRaceProgCandQueue[idx+numToPop:]...)
	fuzzer.AddStat(StatRcPop, uint64(numToPop))
	return popedCands
}

func (fuzzer *Fuzzer) initPoll(needCandidates bool) (*PollArgs, *PollRes) {
	a := &PollArgs{
		Name:           *flagName,
		NeedCandidates: needCandidates,
		Stats:          make(map[string]uint64),
	}

	a.MaxSignal = fuzzer.grabNewSignal().Serialize()

	fuzzer.qMu.RLock()
	a.RaceCandQueueLen = uint64(len(fuzzer.newRaceProgCandQueue))
	fuzzer.qMu.RUnlock()

	/*
		signalMu.Lock()
		// Sending new syncSignals
		a.MaxSyncSignal = make([]uint64, 0, len(newSyncSignal))
		for s := range newSyncSignal {
			a.MaxSyncSignal = append(a.MaxSyncSignal, s)
		}
		newSyncSignal = make(map[uint64]struct{})

		// Sending cover length count
		a.CovLenCount = make(map[int]uint64)
		for k, v := range covLenCount {
			a.CovLenCount[k] = v
		}
		covLenCount = make(map[int]uint64)

		a.MultiCovCount = make(map[int]uint64)
		for k, v := range multiCovCount {
			a.MultiCovCount[k] = v
		}
		multiCovCount = make(map[int]uint64)
		signalMu.Unlock()
	*/

	// Update statistics
	fuzzer.updateStats(a)

	summary := fuzzer.timeStat.SummaryAndFlush()
	a.TimeSummary = summary

	// Sending new found race prog cand
	a.NewRaceProgCand = fuzzer.popFromNewRaceCandQueue(1000)
	return a, &PollRes{}
}

func (fuzzer *Fuzzer) updateSuppressedPairs(addList, delList []MempairHash) {
	fuzzer.suppressedPairsMu.Lock()
	defer fuzzer.suppressedPairsMu.Unlock()

	for _, hsh := range addList {
		fuzzer.suppressedPairs[hsh] = struct{}{}
	}
	for _, hsh := range delList {
		delete(fuzzer.suppressedPairs, hsh)
	}
}

func (fuzzer *Fuzzer) finishPoll(r *PollRes) {
	maxSignal := r.MaxSignal.Deserialize()
	Logf(1, "[FUZZER] poll: candidates=%v inputs=%v signal=%v",
		len(r.Candidates), len(r.NewInputs), maxSignal.Len())
	fuzzer.addMaxSignal(maxSignal)
	/*
		for _, s := range r.MaxSyncSignal {
			maxSyncSignal[s] = struct{}{}
		}
	*/
	fuzzer.updateSuppressedPairs(r.SuppPairsToAdd, r.SuppPairsToDel)

	for _, inp := range r.NewInputs {
		fuzzer.addInputFromAnotherFuzzer(inp)
	}
	for _, candidate := range r.Candidates {
		p, err := fuzzer.target.Deserialize(candidate.Prog)
		if err != nil {
			panic(err)
		}
		if fuzzer.coverageEnabled {
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
	if len(r.Candidates) == 0 && fuzzer.leakCheckEnabled &&
		atomic.LoadUint32(&fuzzer.leakCheckReady) == 0 {
		kmemleakScan(false) // ignore boot leaks
		atomic.StoreUint32(&fuzzer.leakCheckReady, 1)
	}
	if len(r.NewInputs) == 0 && len(r.Candidates) == 0 {
		fuzzer.lastPoll = time.Now()
	}
}

func buildCallList(target *prog.Target, enabledCalls []int, sandbox string) (map[*prog.Syscall]bool, []SyscallReason) {
	calls := make(map[*prog.Syscall]bool)
	for _, n := range enabledCalls {
		if n >= len(target.Syscalls) {
			Fatalf("invalid enabled syscall: %v", n)
		}
		calls[target.Syscalls[n]] = true
	}

	var disabled []SyscallReason
	_, unsupported, err := host.DetectSupportedSyscalls(target, sandbox)
	if err != nil {
		Fatalf("failed to detect host supported syscalls: %v", err)
	}
	for c := range calls {
		if reason, ok := unsupported[c]; ok {
			Logf(1, "[FUZZER] unsupported syscall: %v: %v", c.Name, reason)
			disabled = append(disabled, SyscallReason{
				Name:   c.Name,
				Reason: reason,
			})
			delete(calls, c)
		}
	}
	_, unsupported = target.TransitivelyEnabledCalls(calls)
	for c := range calls {
		if reason, ok := unsupported[c]; ok {
			Logf(1, "[FUZZER] transitively unsupported: %v: %v", c.Name, reason)
			disabled = append(disabled, SyscallReason{
				Name:   c.Name,
				Reason: reason,
			})
			delete(calls, c)
		}
	}
	return calls, disabled
}

func (fuzzer *Fuzzer) sendInputToManager(inp RPCInput) {
	a := &NewInputArgs{
		Name:     fuzzer.name,
		RPCInput: inp,
	}
	if err := fuzzer.manager.Call("Manager.NewInput", a, nil); err != nil {
		panic(err)
	}
}

func (fuzzer *Fuzzer) addInputFromAnotherFuzzer(inp RPCInput) {
	if !fuzzer.coverageEnabled {
		panic("should not be called when coverage is disabled")
	}
	p, err := fuzzer.target.Deserialize(inp.Prog)
	if err != nil {
		panic(err)
	}
	sig := hash.Hash(inp.Prog)
	sign := inp.Signal.Deserialize()
	fuzzer.addInputToCorpus(p, sign, sig)
}

func (fuzzer *Fuzzer) addInputToCorpus(p *prog.Prog, sign signal.Signal, sig hash.Sig) {
	fuzzer.corpusMu.Lock()
	if _, ok := fuzzer.corpusHashes[sig]; !ok {
		fuzzer.corpus = append(fuzzer.corpus, p)
		fuzzer.corpusHashes[sig] = struct{}{}
	}
	fuzzer.corpusMu.Unlock()

	if !sign.Empty() {
		fuzzer.signalMu.Lock()
		fuzzer.corpusSignal.Merge(sign)
		fuzzer.maxSignal.Merge(sign)
		fuzzer.signalMu.Unlock()
	}
}

func (fuzzer *Fuzzer) corpusSnapshot() []*prog.Prog {
	fuzzer.corpusMu.RLock()
	defer fuzzer.corpusMu.RUnlock()
	return fuzzer.corpus
}

func (fuzzer *Fuzzer) addMaxSignal(sign signal.Signal) {
	if sign.Len() == 0 {
		return
	}
	fuzzer.signalMu.Lock()
	defer fuzzer.signalMu.Unlock()
	fuzzer.maxSignal.Merge(sign)
}

func (fuzzer *Fuzzer) grabNewSignal() signal.Signal {
	fuzzer.signalMu.Lock()
	defer fuzzer.signalMu.Unlock()
	sign := fuzzer.newSignal
	if sign.Empty() {
		return nil
	}
	fuzzer.newSignal = nil
	return sign
}

func (fuzzer *Fuzzer) corpusSignalDiff(sign signal.Signal) signal.Signal {
	fuzzer.signalMu.RLock()
	defer fuzzer.signalMu.RUnlock()
	return fuzzer.corpusSignal.Diff(sign)
}

func (fuzzer *Fuzzer) checkNewSignal(p *prog.Prog, info []ipc.CallInfo) (calls []int) {
	fuzzer.signalMu.RLock()
	defer fuzzer.signalMu.RUnlock()
	for i, inf := range info {
		diff := fuzzer.maxSignal.DiffRaw(inf.Signal, signalPrio(p.Target, p.Calls[i], &inf))
		if diff.Empty() {
			continue
		}
		calls = append(calls, i)
		fuzzer.signalMu.RUnlock()
		fuzzer.signalMu.Lock()
		fuzzer.maxSignal.Merge(diff)
		fuzzer.newSignal.Merge(diff)
		fuzzer.signalMu.Unlock()
		fuzzer.signalMu.RLock()
	}
	return
}

func signalPrio(target *prog.Target, c *prog.Call, ci *ipc.CallInfo) (prio uint8) {
	if ci.Errno == 0 {
		prio |= 1 << 1
	}
	if !target.CallContainsAny(c) {
		prio |= 1 << 0
	}
	return
}

func (fuzzer *Fuzzer) leakCheckCallback() {
	if atomic.LoadUint32(&fuzzer.leakCheckReady) != 0 {
		// Scan for leaks once in a while (it is damn slow).
		kmemleakScan(true)
	}
}

func (fuzzer *Fuzzer) AddStat(stat Stat, n uint64) {
	atomic.AddUint64(&fuzzer.stats[stat], n)
}

func (fuzzer *Fuzzer) IncreaseStat(stat Stat) {
	fuzzer.AddStat(stat, 1)
}

func (fuzzer *Fuzzer) isSuppressedByFreq(hsh MempairHash) bool {
	if _, ok := fuzzer.suppressedPairs[hsh]; ok {
		return true
	}
	return false
}

func (fuzzer *Fuzzer) IsSupp(entry EntryTy) bool {
	fuzzer.suppressedPairsMu.Lock()
	defer fuzzer.suppressedPairsMu.Unlock()

	if doSupp(suppFreq) && fuzzer.isSuppressedByFreq(entry.Hash) {
		fuzzer.IncreaseStat(StatRcSuppFreq)
		return true
	}
	return false
}

func (fuzzer *Fuzzer) pushNewRaceProgCand(a *NewRaceProgCandArgs) {
	fuzzer.qMu.Lock()
	defer fuzzer.qMu.Unlock()

	fuzzer.newRaceProgCandQueue = append(fuzzer.newRaceProgCandQueue, a)
	fuzzer.IncreaseStat(StatRcPush)
}
