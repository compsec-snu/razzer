// Copyright 2017 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

package main

import (
	"bytes"
	"fmt"
	"math/rand"
	"os"
	"runtime/debug"
	"syscall"
	"time"

	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/cover"
	"github.com/google/syzkaller/pkg/hash"
	"github.com/google/syzkaller/pkg/ipc"
	. "github.com/google/syzkaller/pkg/log"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/pkg/signal"
	"github.com/google/syzkaller/prog"
)

const (
	programLength = 30
	doSmash       = false
)

type suppType int

const (
	suppFreq suppType = 1 << iota
	suppSignal
)

func doSupp(typ suppType) bool {
	switch typ {
	case suppFreq:
		return *flagSuppOption == 0 || *flagSuppOption == 1
	case suppSignal:
		return *flagSuppOption == 0 || *flagSuppOption == 2
	default:
		panic("Wrong suppType")
	}
}

// Proc represents a single fuzzing process (executor).
type Proc struct {
	scheduler            *Scheduler
	pid                  int
	env                  *ipc.Env
	rnd                  *rand.Rand
	execOpts             *ipc.ExecOpts // collide & ^cover
	execOptsCover        *ipc.ExecOpts // ^collide & cover
	execOptsComps        *ipc.ExecOpts //
	execOptsNoCollide    *ipc.ExecOpts // ^collide & ^cover
	execOptsCollideCover *ipc.ExecOpts // collide & cover
}

func newProc(scheduler *Scheduler, pid int) (*Proc, error) {
	env, err := ipc.MakeEnv(scheduler.config, pid)
	if err != nil {
		return nil, err
	}
	rnd := rand.New(rand.NewSource(time.Now().UnixNano() + int64(pid)*1e12))
	execOptsNoCollide := *scheduler.execOpts
	execOptsNoCollide.Flags &= ^ipc.FlagCollide
	execOptsNoCollide.Flags &= ^ipc.FlagThreaded
	execOptsCover := execOptsNoCollide
	execOptsCover.Flags |= ipc.FlagCollectCover
	execOptsComps := execOptsNoCollide
	execOptsComps.Flags |= ipc.FlagCollectComps
	execOptsCollideCover := *scheduler.execOpts
	execOptsCollideCover.Flags |= ipc.FlagCollectCover
	proc := &Proc{
		scheduler:            scheduler,
		pid:                  pid,
		env:                  env,
		rnd:                  rnd,
		execOpts:             scheduler.execOpts,
		execOptsCover:        &execOptsCover,
		execOptsComps:        &execOptsComps,
		execOptsNoCollide:    &execOptsNoCollide,
		execOptsCollideCover: &execOptsCollideCover,
	}
	return proc, nil
}

func (proc *Proc) loop() {
	for i := 0; ; i++ {
		if rand.Intn(10) < 8 || !proc.scheduler.raceCorpusDBDone {
			proc.doTriageLoop()
		} else {
			proc.doCorpusLoop()
		}
	}
}

func (proc *Proc) doTriageLoop() bool {
	Logf(0, "[SCHED] ----------- Triage loop start -----------")
	defer Logf(0, "[SCHED] ----------- Triage loop done -----------")

	item := proc.scheduler.workQueue.dequeue()
	if item != nil {
		switch item := item.(type) {
		case *WorkTriage:
			proc.triageInput(item)
		case *WorkCandidate:
			proc.executeCandidate(item)
		case *WorkSmash:
			proc.smashInput(item)
		default:
			panic("unknown work type")
		}
		return true
	}
	return false
}

func (proc *Proc) executeCandidate(item *WorkCandidate) {
	Logf(0, "[SCHED] #%v: candidate type=%x", proc.pid, item.flags)
	var wakePoll bool
	proc.scheduler.IncreaseStat(StatRcPop)
	_, isRace := proc.execute(proc.execOpts, item.p, item.flags, StatCandidate, item.RaceInfo)
	// TODO: update true race info
	if isRace {
		if proc.scheduler.updateTrueRaceInfo(item.RaceInfo.Hash, TRIAGE) {
			wakePoll = true
		}
	} else {
		proc.scheduler.sendLikelyRaceInputToManager(RPCLikelyRaceInput{
			RaceProg: item.p.Serialize(),
			RaceInfo: item.RaceInfo,
		})
	}

	proc.scheduler.execInfoMu.Lock()
	execInfo := proc.scheduler.mempairExecInfo[item.RaceInfo.Hash]
	execInfo.TriageExecs++
	if isRace {
		execInfo.TriageTrues++
	}
	proc.scheduler.mempairExecInfo[item.RaceInfo.Hash] = execInfo
	proc.scheduler.execInfoMu.Unlock()

	if wakePoll {
		select {
		case proc.scheduler.needPoll <- struct{}{}:
		default:
		}
	}
}

func (proc *Proc) triageInput(item *WorkTriage) {
	triageFailed := true
	defer func() {
		if triageFailed {
			execInfo := proc.scheduler.mempairExecInfo[item.RaceInfo.Hash]
			execInfo.TriageFailed++
			proc.scheduler.mempairExecInfo[item.RaceInfo.Hash] = execInfo
		}
	}()

	Logf(0, "[SCHED] #%v: triaging type=%x", proc.pid, item.flags)
	if !proc.scheduler.coverageEnabled {
		panic("should not be called when coverage is disabled")
	}

	call := item.p.Calls[item.call]
	inputSignal := signal.FromRaw(item.info.Signal, signalPrio(item.p.Target, call, &item.info))
	newSignal := proc.scheduler.raceCorpusSignalDiff(inputSignal)
	if newSignal.Empty() {
		Logf(0, "[SCHED] triaging: no new signal (input's signal=%v)", inputSignal.Len())
		return
	}
	Logf(0, "[SCHED] triaging input for %v (new signal=%v)", call.Meta.CallName, newSignal.Len())
	var inputCover cover.Cover
	const (
		signalRuns       = 3
		minimizeAttempts = 3
	)
	// Compute input coverage and non-flaky signal for minimization.
	notexecuted := 0
	for i := 0; i < signalRuns; i++ {
		info, isRace := proc.executeRaw(proc.execOptsCollideCover, item.p, StatTriage, item.RaceInfo)
		if len(info) == 0 || len(info[item.call].Signal) == 0 ||
			item.info.Errno == 0 && info[item.call].Errno != 0 ||
			isRace == false {
			// The call was not executed or failed.
			notexecuted++
			if notexecuted > signalRuns/2+1 {
				return // if happens too often, give up
			}
			continue
		}
		inf := info[item.call]
		inf.Signal = xor(inf.Signal, item.RaceInfo.Hash)

		thisSignal := signal.FromRaw(inf.Signal, signalPrio(item.p.Target, call, &inf))
		newSignal = newSignal.Intersection(thisSignal)
		// Without !minimized check manager starts losing some considerable amount
		// of coverage after each restart. Mechanics of this are not completely clear.
		if newSignal.Empty() && item.flags&ProgMinimized == 0 {
			// We want to focus on race, not signal. It is possible that newSignal is empty
			// but still race corpus doesn't have the program with the corresponding mempair hash
			// In that case, we just push the input to the race corpus.
			if len(proc.scheduler.raceCorpusPerMempair[item.RaceInfo.Hash]) == 0 {
				newSignal = proc.scheduler.raceCorpusSignalDiff(inputSignal)
				break
			}
			return
		}
		inputCover.Merge(inf.Cover)
	}
	if item.flags&ProgMinimized == 0 {
		item.p, item.call, item.RaceInfo.Idx = prog.MinimizeRace(item.p, item.call, false,
			func(p1 *prog.Prog, call1 int, index [2]int) bool {
				for i := 0; i < minimizeAttempts; i++ {
					rinfo := item.RaceInfo
					rinfo.Idx = index

					info, isRace := proc.execute(proc.execOpts, p1, ProgNormal, StatMinimize, rinfo)
					if len(info) == 0 || len(info[call1].Signal) == 0 || isRace == false {
						continue // The call was not executed or no race.
					}
					inf := info[call1]
					if item.info.Errno == 0 && inf.Errno != 0 {
						// Don't minimize calls from successful to unsuccessful.
						// Successful calls are much more valuable.
						return false
					}
					prio := signalPrio(p1.Target, p1.Calls[call1], &inf)
					inf.Signal = xor(inf.Signal, item.RaceInfo.Hash)

					thisSignal := signal.FromRaw(inf.Signal, prio)
					if newSignal.Intersection(thisSignal).Len() == newSignal.Len() {
						return true
					}
				}
				return false
			}, item.RaceInfo.Idx)
	}

	data := item.p.Serialize()
	sig := hash.Hash(append(data, item.RaceInfo.ToBytes()...))
	triageFailed = false

	Logf(2, "[SCHED] added new input for %v to corpus:\n", call.Meta.CallName)
	LogLines(2, "[SCHED]", string(data))
	proc.scheduler.sendRaceInputToManager(RPCRaceInput{
		Call:     call.Meta.CallName,
		RaceProg: data,
		Signal:   inputSignal.Serialize(),
		Cover:    inputCover.Serialize(),
		RaceInfo: item.RaceInfo,
	})

	proc.scheduler.addRaceInputToRaceCorpus(item.p, item.RaceInfo, inputSignal, sig)

	if item.flags&ProgSmashed == 0 && doSmash {
		proc.scheduler.workQueue.enqueue(&WorkSmash{item.p, item.call})
	}
}

func (proc *Proc) smashInput(item *WorkSmash) {
	if proc.scheduler.faultInjectionEnabled {
		proc.failCall(item.p, item.call)
	}
	if proc.scheduler.comparisonTracingEnabled {
		proc.executeHintSeed(item.p, item.call)
	}
	corpus := proc.scheduler.corpusSnapshot()
	for i := 0; i < 100; i++ {
		p := item.p.Clone()
		p.Mutate(proc.rnd, programLength, proc.scheduler.choiceTable, corpus)
		Logf(1, "[SCHED] #%v: smash mutated", proc.pid)
		proc.execute(proc.execOpts, p, ProgNormal, StatSmash, RaceInfo{})
	}
}

func (proc *Proc) failCall(p *prog.Prog, call int) {
	for nth := 0; nth < 100; nth++ {
		Logf(1, "[SCHED] #%v: injecting fault into call %v/%v", proc.pid, call, nth)
		opts := *proc.execOptsCover
		opts.Flags |= ipc.FlagInjectFault
		opts.FaultCall = call
		opts.FaultNth = nth
		info, _ /*isRace*/ := proc.executeRaw(&opts, p, StatSmash, RaceInfo{})
		if info != nil && len(info) > call && !info[call].FaultInjected {
			break
		}
	}
}

func (proc *Proc) executeHintSeed(p *prog.Prog, call int) {
	Logf(1, "[SCHED] #%v: collecting comparisons", proc.pid)
	// First execute the original program to dump comparisons from KCOV.
	info, isRace := proc.execute(proc.execOptsComps, p, ProgNormal, StatSeed, RaceInfo{})
	if info == nil || isRace == false {
		return
	}

	// Then mutate the initial program for every match between
	// a syscall argument and a comparison operand.
	// Execute each of such mutants to check if it gives new coverage.
	p.MutateWithHints(call, info[call].Comps, func(p *prog.Prog) {
		Logf(1, "[SCHED] #%v: executing comparison hint", proc.pid)
		proc.execute(proc.execOptsCover, p, ProgNormal, StatHint, RaceInfo{})
	})
}

func (proc *Proc) execute(execOpts *ipc.ExecOpts, p *prog.Prog, flags ProgTypes, stat Stat, raceInfo RaceInfo) ([]ipc.CallInfo, bool) {
	info, isRace := proc.executeRaw(execOpts, p, stat, raceInfo)

	if !isRace {
		proc.scheduler.IncreaseStat(StatNotRace)
		return nil, false
	}

	for _, callIndex := range proc.scheduler.checkNewRaceSignal(p, info, raceInfo) {
		info := info[callIndex]
		// info.Signal points to the output shmem region, detach it before queueing.
		info.Signal = append([]uint32{}, info.Signal...)
		info.Signal = xor(info.Signal, raceInfo.Hash)
		// None of the caller use Cover, so just nil it instead of detaching.
		// Note: triage input uses executeRaw to get coverage.
		info.Cover = nil
		proc.scheduler.workQueue.enqueue(&WorkTriage{
			p:        p.Clone(),
			call:     callIndex,
			info:     info,
			flags:    flags,
			RaceInfo: raceInfo,
		})
	}
	return info, isRace
}

func (proc *Proc) executeRaw(opts *ipc.ExecOpts, p *prog.Prog, stat Stat, raceInfo RaceInfo) ([]ipc.CallInfo, bool) {
	if opts.Flags&ipc.FlagDedupCover == 0 {
		panic("dedup cover is not enabled")
	}

	// Limit concurrency window and do leak checking once in a while.
	ticket := proc.scheduler.gate.Enter()
	defer proc.scheduler.gate.Leave(ticket)

	proc.logProgram(opts, p, raceInfo)
	try := 0
retry:
	proc.scheduler.IncreaseStat(stat)
	output, info, failed, hanged, isRace, err := proc.env.ExecRace(opts, p, raceInfo)
	if failed {
		// BUG in output should be recognized by manager.
		Logf(0, "[SCHED] BUG: executor-detected bug:\n")
		LogLines(0, "[SCHED]", string(output))
		// Don't return any cover so that the input is not added to corpus.
		return nil, false
	}
	if err != nil {
		if _, ok := err.(ipc.ExecutorFailure); ok || try > 10 {
			panic(err)
		}
		try++
		Logf(0, "[SCHED] scheduler detected executor failure='%v', retrying #%d\n", err, (try + 1))
		debug.FreeOSMemory()
		time.Sleep(time.Second)
		goto retry
	}
	Logf(0, "[SCHED] scheduler result failed=%v hanged=%v isRace=%v:", failed, hanged, isRace)
	LogLines(0, "[SCHED]", string(output))
	return info, isRace
}

func (proc *Proc) logProgram(opts *ipc.ExecOpts, p *prog.Prog, raceInfo RaceInfo) {
	if proc.scheduler.outputType == OutputNone {
		return
	}

	data := p.Serialize()
	strOpts := ""
	if opts.Flags&ipc.FlagInjectFault != 0 {
		strOpts = fmt.Sprintf(" (fault-call:%v fault-nth:%v)", opts.FaultCall, opts.FaultNth)
	}

	// The following output helps to understand what program crashed kernel.
	// It must not be intermixed.
	switch proc.scheduler.outputType {
	case OutputStdout:
		proc.scheduler.logMu.Lock()
		Logf(0, "[SCHED] scheduler executing program")
		LogLines(0, "[SCHED]", string(raceInfo.ToBytes()))
		LogLines(0, "[SCHED]", string(data))
		proc.scheduler.logMu.Unlock()
	case OutputDmesg:
		fd, err := syscall.Open("/dev/kmsg", syscall.O_WRONLY, 0)
		if err == nil {
			buf := new(bytes.Buffer)
			fmt.Fprintf(buf, "syzkaller: executing program %v%v:\n%s\n",
				proc.pid, strOpts, data)
			syscall.Write(fd, buf.Bytes())
			syscall.Close(fd)
		}
	case OutputFile:
		f, err := os.Create(fmt.Sprintf("%v-%v.prog", proc.scheduler.name, proc.pid))
		if err == nil {
			if strOpts != "" {
				fmt.Fprintf(f, "#%v\n", strOpts)
			}
			f.Write(data)
			f.Close()
		}
	default:
		panic("unknown output type")
	}
}

func (proc *Proc) doCorpusFuzz(rp RaceCandidate, isLikelyCorpus bool) {
	p := rp.p.Clone()
	raceInfo := rp.RaceInfo
	if rand.Intn(10) == 0 {
		// 10%
		raceInfo.Sched = 1 - raceInfo.Sched
		proc.scheduler.IncreaseStat(StatOrderChanged)
	}
	raceInfo.Idx = p.MutateRace(proc.rnd, programLength, proc.scheduler.choiceTable, proc.scheduler.corpusSnapshot(), raceInfo.Idx)
	Logf(0, "[SCHED] #%v: mutated (%v): %s", proc.pid, len(p.Calls), p)

	statCounter := StatExecRaceCorpus
	if isLikelyCorpus {
		statCounter = StatExecRaceLikely
	}

	_, isRace := proc.execute(proc.execOpts, p, ProgNormal, statCounter, raceInfo)

	proc.scheduler.updateExecInfo(raceInfo.Hash, isLikelyCorpus, isRace)
}

func (proc *Proc) doCorpusLoop() {
	isLikelyCorpus := (rand.Intn(2) == 0)

	Logf(0, "[SCHED] ----------- Corpus loop start (Likely: %v) -----------", isLikelyCorpus)
	defer Logf(0, "[SCHED] ----------- Corpus loop done -----------")

	rc := RaceCandidate{}

	if isLikelyCorpus {
		rc = proc.scheduler.pickFromLikelyRaceCorpus()
	} else {
		rc = proc.scheduler.pickFromRaceCorpus()
	}

	// Check it is suppressed
	if proc.scheduler.isSuppressedPairs(rc.RaceInfo.Hash) {
		Logf(0, "[SCHED] Suppressed RaceCandidate")
		return
	}

	if rc == (RaceCandidate{}) {
		// This may happen at the early stage of scheduler running.
		Logf(0, "[SCHED] Warning: Failed to pick race corpus (Likely: %v)", isLikelyCorpus)
		return
	}

	proc.doCorpusFuzz(rc, isLikelyCorpus)
}

// Temporary fix
// TODO: I want to collect signals of racy syscalls for each mempair where true race occurs.
// This fix simply generate new signal based on signal and mempair hash
// Hopefully, not too many new signals are same.
func xor(signals []uint32, hash MempairHash) []uint32 {
	newSignal := make([]uint32, len(signals))
	highHash := uint32((hash >> 32) << 32)
	lowHash := uint32((hash << 32) >> 32)
	// Isn't it too bad?

	for i, signal := range signals {
		newSignal[i] = (signal ^ highHash) ^ lowHash
	}
	return newSignal
}
