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
	fuzzer            *Fuzzer
	pid               int
	env               *ipc.Env
	rnd               *rand.Rand
	execOpts          *ipc.ExecOpts
	execOptsCover     *ipc.ExecOpts
	execOptsComps     *ipc.ExecOpts
	execOptsNoCollide *ipc.ExecOpts
}

func newProc(fuzzer *Fuzzer, pid int) (*Proc, error) {
	env, err := ipc.MakeEnv(fuzzer.config, pid)
	if err != nil {
		return nil, err
	}
	rnd := rand.New(rand.NewSource(time.Now().UnixNano() + int64(pid)*1e12))
	execOptsNoCollide := *fuzzer.execOpts
	execOptsNoCollide.Flags &= ^ipc.FlagCollide
	execOptsNoCollide.Flags &= ^ipc.FlagThreaded
	execOptsCover := execOptsNoCollide
	execOptsCover.Flags |= ipc.FlagCollectCover
	execOptsComps := execOptsNoCollide
	execOptsComps.Flags |= ipc.FlagCollectComps
	proc := &Proc{
		fuzzer: fuzzer,
		pid:    pid,
		env:    env,
		rnd:    rnd,
		// In race-fuzzer, we always need to collect cover
		// For safety, make execOpts nil
		execOpts:          nil,
		execOptsCover:     &execOptsCover,
		execOptsComps:     &execOptsComps,
		execOptsNoCollide: &execOptsNoCollide,
	}
	return proc, nil
}

func (proc *Proc) loop() {
	for i := 0; ; i++ {
		item := proc.fuzzer.workQueue.dequeue()
		if item != nil {
			switch item := item.(type) {
			case *WorkTriage:
				proc.triageInput(item)
			case *WorkCandidate:
				proc.execute(proc.execOptsCover, item.p, item.flags, StatCandidate)
			case *WorkSmash:
				proc.smashInput(item)
			default:
				panic("unknown work type")
			}
			continue
		}

		ct := proc.fuzzer.choiceTable
		corpus := proc.fuzzer.corpusSnapshot()
		if len(corpus) == 0 || i%100 == 0 {
			// Generate a new prog.
			p := proc.fuzzer.target.Generate(proc.rnd, programLength, ct)
			Logf(1, "[FUZZER] #%v: generated", proc.pid)
			proc.execute(proc.execOptsCover, p, ProgNormal, StatGenerate)
		} else {
			// Mutate an existing prog.
			p := corpus[proc.rnd.Intn(len(corpus))].Clone()
			p.Mutate(proc.rnd, programLength, ct, corpus)
			Logf(1, "[FUZZER] #%v: mutated", proc.pid)
			proc.execute(proc.execOptsCover, p, ProgNormal, StatFuzz)
		}
	}
}

func (proc *Proc) triageInput(item *WorkTriage) {
	Logf(0, "[FUZZER] #%v: triaging type=%x", proc.pid, item.flags)
	if !proc.fuzzer.coverageEnabled {
		panic("should not be called when coverage is disabled")
	}

	call := item.p.Calls[item.call]
	inputSignal := signal.FromRaw(item.info.Signal, signalPrio(item.p.Target, call, &item.info))
	newSignal := proc.fuzzer.corpusSignalDiff(inputSignal)
	if newSignal.Empty() {
		return
	}
	Logf(3, "[FUZZER] triaging input for %v (new signal=%v)", call.Meta.CallName, newSignal.Len())
	var inputCover cover.Cover
	const (
		signalRuns       = 3
		minimizeAttempts = 3
	)
	// Compute input coverage and non-flaky signal for minimization.
	notexecuted := 0
	for i := 0; i < signalRuns; i++ {
		info := proc.executeRaw(proc.execOptsCover, item.p, StatTriage)
		if len(info) == 0 || len(info[item.call].Signal) == 0 ||
			item.info.Errno == 0 && info[item.call].Errno != 0 {
			// The call was not executed or failed.
			notexecuted++
			if notexecuted > signalRuns/2+1 {
				return // if happens too often, give up
			}
			continue
		}
		inf := info[item.call]
		thisSignal := signal.FromRaw(inf.Signal, signalPrio(item.p.Target, call, &inf))
		newSignal = newSignal.Intersection(thisSignal)
		// Without !minimized check manager starts losing some considerable amount
		// of coverage after each restart. Mechanics of this are not completely clear.
		if newSignal.Empty() && item.flags&ProgMinimized == 0 {
			return
		}
		inputCover.Merge(inf.Cover)
	}
	if item.flags&ProgMinimized == 0 {
		item.p, item.call = prog.Minimize(item.p, item.call, false,
			func(p1 *prog.Prog, call1 int) bool {
				for i := 0; i < minimizeAttempts; i++ {
					info := proc.execute(proc.execOptsNoCollide, p1, ProgNormal, StatMinimize)
					if len(info) == 0 || len(info[call1].Signal) == 0 {
						continue // The call was not executed.
					}
					inf := info[call1]
					if item.info.Errno == 0 && inf.Errno != 0 {
						// Don't minimize calls from successful to unsuccessful.
						// Successful calls are much more valuable.
						return false
					}
					prio := signalPrio(p1.Target, p1.Calls[call1], &inf)
					thisSignal := signal.FromRaw(inf.Signal, prio)
					if newSignal.Intersection(thisSignal).Len() == newSignal.Len() {
						return true
					}
				}
				return false
			})
	}

	data := item.p.Serialize()
	sig := hash.Hash(data)

	Logf(2, "[FUZZER] added new input for %v to corpus:\n%s", call.Meta.CallName, data)
	proc.fuzzer.sendInputToManager(RPCInput{
		Call:   call.Meta.CallName,
		Prog:   data,
		Signal: inputSignal.Serialize(),
		Cover:  inputCover.Serialize(),
	})

	proc.fuzzer.addInputToCorpus(item.p, inputSignal, sig)

	if item.flags&ProgSmashed == 0 {
		proc.fuzzer.workQueue.enqueue(&WorkSmash{item.p, item.call})
	}
}

func (proc *Proc) smashInput(item *WorkSmash) {
	if proc.fuzzer.faultInjectionEnabled {
		proc.failCall(item.p, item.call)
	}
	if proc.fuzzer.comparisonTracingEnabled {
		proc.executeHintSeed(item.p, item.call)
	}
	corpus := proc.fuzzer.corpusSnapshot()
	for i := 0; i < 100; i++ {
		p := item.p.Clone()
		p.Mutate(proc.rnd, programLength, proc.fuzzer.choiceTable, corpus)
		Logf(1, "[FUZZER] #%v: smash mutated", proc.pid)
		proc.execute(proc.execOptsCover, p, ProgNormal, StatSmash)
	}
}

func (proc *Proc) failCall(p *prog.Prog, call int) {
	for nth := 0; nth < 100; nth++ {
		Logf(1, "[FUZZER] #%v: injecting fault into call %v/%v", proc.pid, call, nth)
		opts := *proc.execOptsCover
		opts.Flags |= ipc.FlagInjectFault
		opts.FaultCall = call
		opts.FaultNth = nth
		info := proc.executeRaw(&opts, p, StatSmash)
		if info != nil && len(info) > call && !info[call].FaultInjected {
			break
		}
	}
}

func (proc *Proc) executeHintSeed(p *prog.Prog, call int) {
	Logf(1, "[FUZZER] #%v: collecting comparisons", proc.pid)
	// First execute the original program to dump comparisons from KCOV.
	info := proc.execute(proc.execOptsComps, p, ProgNormal, StatSeed)
	if info == nil {
		return
	}

	// Then mutate the initial program for every match between
	// a syscall argument and a comparison operand.
	// Execute each of such mutants to check if it gives new coverage.
	p.MutateWithHints(call, info[call].Comps, func(p *prog.Prog) {
		Logf(1, "[FUZZER] #%v: executing comparison hint", proc.pid)
		proc.execute(proc.execOptsCover, p, ProgNormal, StatHint)
	})
}

func foreachRacyBasicBlock(sparseRaceCandPairs map[uint32][]EntryTy, cov1, cov2 cover.RawCover, f func(bb1, bb2 uint32, entry EntryTy) bool) bool {
	// For each racy basic blocks in cov1, cov2, call f
	// If f return false, return false

	for _, c1 := range cov1 {
		entries := sparseRaceCandPairs[c1]
		if entries == nil {
			continue
		}

		for _, entry := range entries {
			if cover.RawCoverContains(cov2, entry.Cover) {
				if keepGoing := f(c1, entry.Cover, entry); !keepGoing {
					return false
				}
			}
		}
	}
	return true
}

func (proc *Proc) mayRace(callIndex1, callIndex2 int, canoniCovers []cover.RawCover) ([]RaceInfo, bool) {
	// This function checks syscallIndex1-th syscall and syscallIndex2-th syscall may race
	// We need cover.RawCover instead of cover.Cover to use binary search
	var raceInfos []RaceInfo

	thold := 100
	if *flagRootCause {
		// Do not limit when performing rootcause analysis.
		thold = 100000
	}

	cov1 := canoniCovers[callIndex1]
	cov2 := canoniCovers[callIndex2]

	shuffled_cov1 := cover.Shuffle(cov1, proc.rnd)

	MaxRaceInfo := false
	appendRaceInfo := func(bb1, bb2 uint32, entry EntryTy) bool {
		if proc.fuzzer.IsSupp(entry) {
			return !MaxRaceInfo
		}

		raceInfos = append(raceInfos, RaceInfo{
			Cov:     [...]uint32{bb1, bb2},
			Idx:     [...]int{callIndex1, callIndex2},
			Hash:    entry.Hash,
			Mempair: [...]string{entry.Mempair[0], entry.Mempair[1]},
			// Addr will be filled by syz-manager
		})

		if len(raceInfos) > thold {
			return MaxRaceInfo
		}
		return !MaxRaceInfo
	}

	if foreachRacyBasicBlock(proc.fuzzer.sparseRaceCandPairs, shuffled_cov1, cov2, appendRaceInfo) == MaxRaceInfo {
		proc.fuzzer.IncreaseStat(StatRcMaxRaceInfo)
	}

	return raceInfos, (len(raceInfos) != 0)
}

func (proc *Proc) checkRaceRelatedCov(rawCover []uint32) bool {
	for _, cov := range rawCover {
		entries := proc.fuzzer.sparseRaceCandPairs[cov]
		if entries != nil {
			return true
		}
	}
	return false
}

func (proc *Proc) isFullNewRaceProgCand() bool {
	// if doSupp(suppSignal) {
	// 	return false
	// }
	const thold = 10000
	fuzzer := proc.fuzzer

	fuzzer.qMu.RLock()
	defer fuzzer.qMu.RUnlock()

	if len(fuzzer.newRaceProgCandQueue) > thold {
		return true
	}
	return false
}

func foreachRawCover(covers []cover.RawCover, f func(i, j int)) {
	for i := 0; i < len(covers) && covers[i] != nil; i++ {
		for j := i + 1; j < len(covers) && covers[j] != nil; j++ {
			f(i, j)
		}
	}
}

func (proc *Proc) updateRaceProgCand(info []ipc.CallInfo, p *prog.Prog) {
	// TODO: look into cover, and determines the pair of syscalls that may race
	//       Option2 is not implemented yet

	if proc.isFullNewRaceProgCand() {
		return
	}

	rawCovers := make([]cover.RawCover, len(info))
	for i := 0; i < len(info); i++ {
		// In this version, cover.Cover is already dedep-ed
		if proc.checkRaceRelatedCov(info[i].Cover) {
			rawCovers[i] = info[i].Cover
		} else {
			rawCovers[i] = nil
		}
	}

	foreachRawCover(rawCovers, func(i, j int) {
		if ri, ok := proc.mayRace(i, j, rawCovers); ok {
			// This program executes race candidates(s)
			a := &NewRaceProgCandArgs{
				Name: *flagName,
				RaceProgCand: RaceProgCand{
					Prog:      p.Serialize(),
					RaceInfos: append([]RaceInfo{}, ri...),
				},
			}
			proc.fuzzer.pushNewRaceProgCand(a)
		}
	})
}

func (proc *Proc) execute(execOpts *ipc.ExecOpts, p *prog.Prog, flags ProgTypes, stat Stat) []ipc.CallInfo {
	info := proc.executeRaw(execOpts, p, stat)

	// Update RaceProgCand
	proc.updateRaceProgCand(info, p)

	for _, callIndex := range proc.fuzzer.checkNewSignal(p, info) {
		info := info[callIndex]
		// info.Signal points to the output shmem region, detach it before queueing.
		info.Signal = append([]uint32{}, info.Signal...)
		// None of the caller use Cover, so just nil it instead of detaching.
		// Note: triage input uses executeRaw to get coverage.
		info.Cover = nil
		proc.fuzzer.workQueue.enqueue(&WorkTriage{
			p:     p.Clone(),
			call:  callIndex,
			info:  info,
			flags: flags,
		})
	}
	return info
}

func (proc *Proc) executeRaw(opts *ipc.ExecOpts, p *prog.Prog, stat Stat) []ipc.CallInfo {
	if opts.Flags&ipc.FlagDedupCover == 0 {
		panic("dedup cover is not enabled")
	}

	// Limit concurrency window and do leak checking once in a while.
	ticket := proc.fuzzer.gate.Enter()
	defer proc.fuzzer.gate.Leave(ticket)

	proc.logProgram(opts, p)
	try := 0
retry:
	proc.fuzzer.IncreaseStat(stat)
	output, info, failed, hanged, err := proc.env.Exec(opts, p)
	if failed {
		// BUG in output should be recognized by manager.
		Logf(0, "[FUZZER] BUG: executor-detected bug:\n%s", output)
		// Don't return any cover so that the input is not added to corpus.
		return nil
	}
	if err != nil {
		if _, ok := err.(ipc.ExecutorFailure); ok || try > 10 {
			panic(err)
		}
		try++
		Logf(4, "[FUZZER] fuzzer detected executor failure='%v', retrying #%d\n", err, (try + 1))
		debug.FreeOSMemory()
		time.Sleep(time.Second)
		goto retry
	}
	Logf(2, "[FUZZER] result failed=%v hanged=%v: %v\n", failed, hanged, string(output))
	return info
}

func (proc *Proc) logProgram(opts *ipc.ExecOpts, p *prog.Prog) {
	if proc.fuzzer.outputType == OutputNone {
		return
	}

	data := p.Serialize()
	strOpts := ""
	if opts.Flags&ipc.FlagInjectFault != 0 {
		strOpts = fmt.Sprintf(" (fault-call:%v fault-nth:%v)", opts.FaultCall, opts.FaultNth)
	}

	// The following output helps to understand what program crashed kernel.
	// It must not be intermixed.
	switch proc.fuzzer.outputType {
	case OutputStdout:
		proc.fuzzer.logMu.Lock()
		Logf(0, "[FUZZER] executing program %v%v:\n", proc.pid, strOpts)
		LogLines(0, "[FUZZER]", string(data))
		proc.fuzzer.logMu.Unlock()
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
		f, err := os.Create(fmt.Sprintf("%v-%v.prog", proc.fuzzer.name, proc.pid))
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
