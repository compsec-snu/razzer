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

type Scheduler struct {
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
	newSignal    signal.Signal // diff of maxSignal since last sync with master

	logMu sync.Mutex

	lastPoll time.Time

	// ----- Race fuzzer -----
	mempairs []Mempair

	trueRaceMu        sync.RWMutex
	trueRaceHashes    []MempairHash
	trueRaceHashesMap map[MempairHash]struct{}

	raceCorpusMu         sync.RWMutex
	raceCorpusSignal     signal.Signal
	raceMaxSignal        signal.Signal
	raceCorpusHashes     map[hash.Sig]struct{}
	raceCorpusPerMempair map[MempairHash][]RaceCandidate
	suppressedPairs      map[MempairHash]struct{}
	suppressedPairsMu    sync.RWMutex

	foundRaceToUpdate []FoundRaceInfo

	execInfoMu      sync.RWMutex
	mempairExecInfo map[MempairHash]RaceExecInfo

	raceCorpusDBDone bool

	likelyCorpusMu   sync.RWMutex
	likelyRaceCorpus map[MempairHash]RaceCandidate

	timeStat TimeStat
}

type RaceInput struct {
	p         *prog.Prog
	signal    []uint32
	minimized bool
	call      int
	RaceInfo
}

// race program candidate
type RaceCandidate struct {
	p         *prog.Prog
	minimized bool
	RaceInfo
}

type Stat int

const (
	NUM_PROG_CANDS = 20000
)

const (
	StatFuzz Stat = iota
	StatCandidate
	StatTriage
	StatMinimize
	StatSmash
	StatHint
	StatSeed
	StatRcPush
	StatRcPop
	StatRcMinimized
	StatRcNotMinimized
	StatRcLikelyPush
	StatNotRace
	StatOrderChanged
	StatExecRaceCorpus
	StatExecRaceLikely
	StatRcSoftCleanup
	StatRcHardCleanup
	StatRcDrop
	StatRcDropSurv
	StatSupp
	StatCount
)

var statNames = [StatCount]string{
	StatFuzz:           "exec fuzz",
	StatCandidate:      "exec candidate",
	StatTriage:         "exec triage",
	StatMinimize:       "exec minimize",
	StatSmash:          "exec smash",
	StatHint:           "exec hints",
	StatSeed:           "exec seeds",
	StatRcPush:         "rc push",
	StatRcPop:          "rc pop",
	StatRcMinimized:    "rc minimized",
	StatRcNotMinimized: "rc not minimized",
	StatRcLikelyPush:   "rc likely push",
	StatNotRace:        "exec not race",
	StatOrderChanged:   "order changed",
	StatExecRaceCorpus: "exec corpus",
	StatExecRaceLikely: "exec likely",
	StatRcSoftCleanup:  "rc soft cleanup",
	StatRcHardCleanup:  "rc hard cleanup",
	StatRcDrop:         "rc drop",
	StatRcDropSurv:     "rc drop surv",
	StatSupp:           "supped",
}

func main() {
	debug.SetGCPercent(50)

	flag.Parse()
	Logf(0, "[SCHED] scheduler started")

	shutdown := make(chan struct{})
	osutil.HandleInterrupts(shutdown)
	go func() {
		// Handles graceful preemption on GCE.
		<-shutdown
		Logf(0, "[SCHED] SYZ-SCHEDULER: PREEMPTED")
		os.Exit(1)
	}()

	scheduler := schedulerInit()
	if scheduler == nil /* *flagTest == True */ {
		return
	}

	// Create only 1 proc for now
	*flagProcs = 1
	for pid := 0; pid < *flagProcs; pid++ {
		proc, err := newProc(scheduler, pid)
		if err != nil {
			Fatalf("failed to create proc: %v", err)
		}
		scheduler.procs = append(scheduler.procs, proc)
		go proc.loop()
	}

	scheduler.pollLoop()
}

func (scheduler *Scheduler) pollLoop() {
	ticker := time.NewTicker(3 * time.Second).C
	count := 0
	for {
		poll := false
		select {
		case <-ticker:
		case <-scheduler.needPoll:
			poll = true
		}
		scheduler.pingManager()
		if poll || time.Since(scheduler.lastPoll) > 10*time.Second {
			needCandidates := scheduler.workQueue.wantCandidates()
			if poll && !needCandidates {
				continue
			}

			if count%6 == 1 {
				// Too frequent cleanup may degrade perf. There's no point
				// of doing the frequenty cleanup anyway, because the
				// soft-cleanup would only remove the candidates in the
				// updated suppression mempairs.
				if scheduler.workQueue.shouldSoftCleanupRaceCands() {
					if scheduler.workQueue.shouldHardCleanupRaceCands() {
						scheduler.workQueue.hardCleanupRaceCands()
					} else {
						scheduler.workQueue.softCleanupRaceCands()
					}
				}
			}

			a, r := scheduler.initPoll(needCandidates)
			if err := scheduler.manager.Call("Manager.SchedulerPoll", a, r); err != nil {
				panic(err)
			}
			scheduler.finishPoll(r)
			count++
		}
	}
}

var lastPrint time.Time
var execTotal uint64

func (scheduler *Scheduler) pingManager() {
	if scheduler.outputType != OutputStdout && time.Since(lastPrint) > 10*time.Second {
		// Keep-alive for manager.
		Logf(0, "[SCHED] alive, executed %v", execTotal)
		lastPrint = time.Now()
	}
}

func (scheduler *Scheduler) updateStats(a *SchedulerPollArgs) {
	for _, proc := range scheduler.procs {
		a.Stats["sched exec total"] += atomic.SwapUint64(&proc.env.StatExecs, 0)
		a.Stats["sched executor restarts"] += atomic.SwapUint64(&proc.env.StatRestarts, 0)
	}

	for stat := Stat(0); stat < StatCount; stat++ {
		v := atomic.SwapUint64(&scheduler.stats[stat], 0)
		a.Stats["sched "+statNames[stat]] = v
		execTotal += v
	}
}

func (scheduler *Scheduler) initPoll(needCandidates bool) (*SchedulerPollArgs, *SchedulerPollRes) {
	a := &SchedulerPollArgs{
		Name:           *flagName,
		NeedCandidates: needCandidates,
		Stats:          make(map[string]uint64),
	}

	scheduler.raceCorpusMu.RLock()
	a.RaceCandQueueLen = uint64(len(scheduler.workQueue.candidate))
	scheduler.raceCorpusMu.RUnlock()

	a.FoundRaceInfos = scheduler.grabFoundRace()

	a.MaxSignal = scheduler.grabNewSignal().Serialize()

	a.MempairExecInfo = scheduler.grabExecInfo()

	scheduler.updateStats(a)

	summary := scheduler.timeStat.SummaryAndFlush()
	a.TimeSummary = summary
	return a, &SchedulerPollRes{}
}

func (scheduler *Scheduler) updateSuppressedPairs(addList, delList []MempairHash) {
	scheduler.suppressedPairsMu.Lock()
	defer scheduler.suppressedPairsMu.Unlock()

	for _, hsh := range addList {
		scheduler.suppressedPairs[hsh] = struct{}{}
	}
	for _, hsh := range delList {
		delete(scheduler.suppressedPairs, hsh)
	}
}

func (scheduler *Scheduler) isSuppressedPairs(hsh MempairHash) bool {
	scheduler.suppressedPairsMu.Lock()
	defer scheduler.suppressedPairsMu.Unlock()

	_, ok := scheduler.suppressedPairs[hsh]
	return ok
}

func (scheduler *Scheduler) finishPoll(r *SchedulerPollRes) {
	maxSignal := r.MaxSignal.Deserialize()
	Logf(1, "[SCHED] poll: candidates=%v inputs=%v signal=%v",
		len(r.RaceProgs), len(r.NewInputs), maxSignal.Len())
	scheduler.addRaceMaxSignal(maxSignal)
	/*
		for _, s := range r.MaxSyncSignal {
			maxSyncSignal[s] = struct{}{}
		}
	*/

	scheduler.updateSuppressedPairs(r.SuppPairsToAdd, r.SuppPairsToDel)

	// Corpus From Fuzzer
	for _, inp := range r.NewInputs {
		scheduler.addInputFromFuzzer(inp)
	}
	for _, rinp := range r.NewRaceInputs {
		scheduler.addRaceInputFromScheduler(rinp)
	}
	for _, rinp := range r.NewLikelyRaceInputs {
		scheduler.addToLikelyRaceCorpus(rinp)
	}
	for _, raceProg := range r.RaceProgs {
		scheduler.pushToWorkQueue(raceProg)
	}

	scheduler.trueRaceMu.Lock()
	for _, hsh := range r.TrueRaceHashes {
		scheduler.trueRaceHashesMap[hsh] = struct{}{}
		scheduler.trueRaceHashes = append(scheduler.trueRaceHashes, hsh)
	}
	scheduler.trueRaceMu.Unlock()

	/*
		if len(r.Candidates) == 0 && scheduler.leakCheckEnabled &&
			atomic.LoadUint32(&scheduler.leakCheckReady) == 0 {
			kmemleakScan(false) // ignore boot leaks
			atomic.StoreUint32(&scheduler.leakCheckReady, 1)
		}
	*/
	if len(r.NewInputs) == 0 && len(r.RaceProgs) == 0 {
		scheduler.lastPoll = time.Now()
	}

	Assert(!(scheduler.raceCorpusDBDone && !r.RaceCorpusDBDone), "Wrong")
	scheduler.raceCorpusDBDone = r.RaceCorpusDBDone
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
			Logf(1, "[SCHED] unsupported syscall: %v: %v", c.Name, reason)
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
			Logf(1, "[SCHED] transitively unsupported: %v: %v", c.Name, reason)
			disabled = append(disabled, SyscallReason{
				Name:   c.Name,
				Reason: reason,
			})
			delete(calls, c)
		}
	}
	return calls, disabled
}

func (scheduler *Scheduler) sendRaceInputToManager(rinp RPCRaceInput) {
	a := &NewRaceInputArgs{
		Name:         scheduler.name,
		RPCRaceInput: rinp,
	}
	if err := scheduler.manager.Call("Manager.NewRaceInput", a, nil); err != nil {
		panic(err)
	}
}

func (scheduler *Scheduler) addInputFromFuzzer(inp RPCInput) {
	if !scheduler.coverageEnabled {
		panic("should not be called when coverage is disabled")
	}
	p, err := scheduler.target.Deserialize(inp.Prog)
	if err != nil {
		panic(err)
	}
	sig := hash.Hash(inp.Prog)
	sign := inp.Signal.Deserialize()
	scheduler.addInputToCorpus(p, sign, sig)
}

func (scheduler *Scheduler) addInputToCorpus(p *prog.Prog, sign signal.Signal, sig hash.Sig) {
	scheduler.corpusMu.Lock()
	if _, ok := scheduler.corpusHashes[sig]; !ok {
		scheduler.corpus = append(scheduler.corpus, p)
		scheduler.corpusHashes[sig] = struct{}{}
	}
	scheduler.corpusMu.Unlock()

	if !sign.Empty() {
		scheduler.signalMu.Lock()
		scheduler.corpusSignal.Merge(sign)
		scheduler.signalMu.Unlock()
	}
}

func (scheduler *Scheduler) corpusSnapshot() []*prog.Prog {
	scheduler.corpusMu.RLock()
	defer scheduler.corpusMu.RUnlock()
	return scheduler.corpus
}

func (scheduler *Scheduler) grabNewSignal() signal.Signal {
	scheduler.signalMu.Lock()
	defer scheduler.signalMu.Unlock()
	sign := scheduler.newSignal
	if sign.Empty() {
		return nil
	}
	scheduler.newSignal = nil
	return sign
}

func (scheduler *Scheduler) raceCorpusSignalDiff(sign signal.Signal) signal.Signal {
	scheduler.signalMu.RLock()
	defer scheduler.signalMu.RUnlock()
	return scheduler.raceCorpusSignal.Diff(sign)
}

func (scheduler *Scheduler) checkNewRaceSignal(p *prog.Prog, info []ipc.CallInfo, raceInfo RaceInfo) (calls []int) {
	scheduler.signalMu.RLock()
	defer scheduler.signalMu.RUnlock()
	for _, i := range raceInfo.Idx {
		inf := info[i]
		sign := xor(inf.Signal, raceInfo.Hash)

		diff := scheduler.raceMaxSignal.DiffRaw(sign, signalPrio(p.Target, p.Calls[i], &inf))
		if diff.Empty() {
			continue
		}
		calls = append(calls, i)
		scheduler.signalMu.RUnlock()
		scheduler.signalMu.Lock()
		scheduler.raceMaxSignal.Merge(diff)
		scheduler.newSignal.Merge(diff)
		scheduler.signalMu.Unlock()
		scheduler.signalMu.RLock()
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

func (scheduler *Scheduler) leakCheckCallback() {
	if atomic.LoadUint32(&scheduler.leakCheckReady) != 0 {
		// Scan for leaks once in a while (it is damn slow).
		kmemleakScan(true)
	}
}

func (scheduler *Scheduler) AddStat(stat Stat, n uint64) {
	atomic.AddUint64(&scheduler.stats[stat], n)
}

func (scheduler *Scheduler) IncreaseStat(stat Stat) {
	scheduler.AddStat(stat, 1)
}

func (scheduler *Scheduler) addRaceInputFromScheduler(rinp RPCRaceInput) {
	p, err := scheduler.target.Deserialize(rinp.RaceProg)
	if err != nil {
		panic(err)
	}
	sig := hash.Hash(append(rinp.RaceProg, rinp.RaceInfo.ToBytes()...))
	sign := rinp.Signal.Deserialize()
	scheduler.addRaceInputToRaceCorpus(p, rinp.RaceInfo, sign, sig)
}

func (scheduler *Scheduler) addRaceInputToRaceCorpus(p *prog.Prog, raceInfo RaceInfo, sign signal.Signal, sig hash.Sig) {
	scheduler.corpusMu.Lock()
	if _, ok := scheduler.raceCorpusHashes[sig]; !ok {
		rc := RaceCandidate{
			p:        p,
			RaceInfo: raceInfo}
		hsh := raceInfo.Hash
		scheduler.raceCorpusPerMempair[hsh] = append(scheduler.raceCorpusPerMempair[hsh], rc)
		scheduler.raceCorpusHashes[sig] = struct{}{}
	}
	scheduler.corpusMu.Unlock()

	if !sign.Empty() {
		scheduler.signalMu.Lock()
		scheduler.raceCorpusSignal.Merge(sign)
		scheduler.raceMaxSignal.Merge(sign)
		scheduler.signalMu.Unlock()
	}
}

func (scheduler *Scheduler) addRaceMaxSignal(sign signal.Signal) {
	if sign.Len() == 0 {
		return
	}
	scheduler.signalMu.Lock()
	defer scheduler.signalMu.Unlock()
	scheduler.raceMaxSignal.Merge(sign)
}

func (scheduler *Scheduler) updateTrueRaceInfo(hsh MempairHash, kind RaceRunKind) bool {
	scheduler.trueRaceMu.Lock()
	defer scheduler.trueRaceMu.Unlock()

	if _, ok := scheduler.trueRaceHashesMap[hsh]; !ok {
		// this is newly found race
		scheduler.trueRaceHashesMap[hsh] = struct{}{}
		scheduler.trueRaceHashes = append(scheduler.trueRaceHashes, hsh)

		foundRaceInfo := FoundRaceInfo{
			MempairHash: hsh,
			RaceRunKind: kind,
		}
		scheduler.foundRaceToUpdate = append(scheduler.foundRaceToUpdate, foundRaceInfo)
		return true
	}
	return false
}

func (scheduler *Scheduler) grabFoundRace() []FoundRaceInfo {
	scheduler.trueRaceMu.Lock()
	defer scheduler.trueRaceMu.Unlock()

	res := append([]FoundRaceInfo{}, scheduler.foundRaceToUpdate...)
	scheduler.foundRaceToUpdate = nil

	return res
}

func (scheduler *Scheduler) grabExecInfo() map[MempairHash]RaceExecInfo {
	scheduler.execInfoMu.RLock()
	defer scheduler.execInfoMu.RUnlock()

	res := make(map[MempairHash]RaceExecInfo)
	for hsh, execInfo := range scheduler.mempairExecInfo {
		res[hsh] = execInfo
	}
	// Reset after uploading to the manager.
	scheduler.mempairExecInfo = make(map[MempairHash]RaceExecInfo)

	return res
}

func (scheduler *Scheduler) pickFromRaceCorpus() RaceCandidate {
	// Mutate an existing prog. No generation here

	// To fairly fuzz each mempair, we first randomly pick the
	// mempair hash value. Then we randomly pick the race corpus
	// based on the mempair value. This is because some mempairs
	// may have a large number of race corpus, while others only
	// have one race corpus.
	scheduler.corpusMu.RLock()
	defer scheduler.corpusMu.RUnlock()
	scheduler.trueRaceMu.RLock()
	defer scheduler.trueRaceMu.RUnlock()

	rc := RaceCandidate{}
	if len(scheduler.raceCorpusPerMempair) == 0 {
		return rc
	}

	for i := 0; i < len(scheduler.trueRaceHashes)*2; i++ {
		hsh := scheduler.trueRaceHashes[rand.Intn(len(scheduler.trueRaceHashes))]
		rcs := scheduler.raceCorpusPerMempair[hsh]
		// while scheduler.trueRaceHashes are already updated, raceCorpus
		// may get updated late so it's possible that we don't
		// have the corpus yet.
		if len(rcs) != 0 {
			rc = rcs[rand.Intn(len(rcs))]
			break
		}
	}
	return rc
}

func (scheduler *Scheduler) sendLikelyRaceInputToManager(inp RPCLikelyRaceInput) bool {
	// Even if it is not racing, if the corresponding
	// mempair is rarely hitting, we push this back to
	// "likelyRaceCorpus" queue. Then we will give a
	// second chance on this input to be mutated.

	scheduler.likelyCorpusMu.RLock()
	_, ok := scheduler.likelyRaceCorpus[inp.RaceInfo.Hash]
	scheduler.likelyCorpusMu.RUnlock()

	if ok {
		// Already exist, so we don't upload
		return false
	}

	a := &NewLikelyRaceInputArgs{
		Name:               scheduler.name,
		RPCLikelyRaceInput: inp,
	}
	if err := scheduler.manager.Call("Manager.NewLikelyRaceInput", a, nil); err != nil {
		panic(err)
	}

	scheduler.addToLikelyRaceCorpus(a.RPCLikelyRaceInput)
	return true
}

func (scheduler *Scheduler) addToLikelyRaceCorpus(rinp RPCLikelyRaceInput) {
	// Always update

	progData, err := scheduler.target.Deserialize(rinp.RaceProg)
	if err != nil {
		Logf(0, "[SCHED] Failed to deserialize (%+v)", rinp.RaceInfo)
		return
	}

	rc := RaceCandidate{
		p:        progData,
		RaceInfo: rinp.RaceInfo,
	}

	scheduler.IncreaseStat(StatRcLikelyPush)
	scheduler.likelyCorpusMu.Lock()
	scheduler.likelyRaceCorpus[rc.RaceInfo.Hash] = rc
	scheduler.likelyCorpusMu.Unlock()
}

func (scheduler *Scheduler) pickFromLikelyRaceCorpus() RaceCandidate {
	scheduler.likelyCorpusMu.RLock()
	defer scheduler.likelyCorpusMu.RUnlock()

	rc := RaceCandidate{}

	if len(scheduler.likelyRaceCorpus) == 0 {
		return rc
	}
	idx := rand.Intn(len(scheduler.likelyRaceCorpus))

	count := 0
	for _, rc := range scheduler.likelyRaceCorpus {
		if count == idx {
			return rc
		}
		count++
	}
	Fatalf("Should not be here")
	return RaceCandidate{}
}

func (scheduler *Scheduler) pushToWorkQueue(raceProg RaceProgCand) {
	p, err := scheduler.target.Deserialize(raceProg.Prog)
	if err != nil {
		panic(err)
	}
	scheduler.raceCorpusMu.Lock()
	for _, raceinfo := range raceProg.RaceInfos {
		rc := &WorkCandidate{p: p, RaceInfo: raceinfo, flags: ProgNormal}
		scheduler.IncreaseStat(StatRcPush)
		scheduler.workQueue.enqueue(rc)
	}
	scheduler.raceCorpusMu.Unlock()
}

func (scheduler *Scheduler) updateExecInfo(hsh MempairHash, isLikelyCorpus, isRace bool) {
	scheduler.execInfoMu.RLock()
	defer scheduler.execInfoMu.RUnlock()

	execInfo := scheduler.mempairExecInfo[hsh]

	if isLikelyCorpus {
		execInfo.LikelyExecs++
		if isRace {
			execInfo.LikelyTrues++
			scheduler.updateTrueRaceInfo(hsh, LIKELY)
		}
	} else {
		execInfo.CorpusExecs++
		if isRace {
			execInfo.CorpusTrues++
			scheduler.updateTrueRaceInfo(hsh, CORPUS)
		}
	}

	scheduler.mempairExecInfo[hsh] = execInfo
}
