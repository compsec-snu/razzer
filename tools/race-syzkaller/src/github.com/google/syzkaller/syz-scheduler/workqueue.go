// Copyright 2017 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

package main

import (
	"sync"

	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/ipc"
	"github.com/google/syzkaller/prog"
)

// WorkQueue holds global non-fuzzing work items (see the Work* structs below).
// WorkQueue also does prioritization among work items, for example, we want
// to triage and send to manager new inputs before we smash programs
// in order to not permanently lose interesting programs in case of VM crash.
type WorkQueue struct {
	mu        sync.RWMutex
	candidate []*WorkCandidate
	triage    []*WorkTriage
	smash     []*WorkSmash

	procs          int
	needCandidates chan struct{}

	// For cleanup
	scheduler *Scheduler
}

type ProgTypes int

const (
	ProgCandidate ProgTypes = 1 << iota
	ProgMinimized
	ProgSmashed
	ProgNormal ProgTypes = 0
)

// WorkTriage are programs for which we noticed potential new coverage during
// first execution. But we are not sure yet if the coverage is real or not.
// During triage we understand if these programs in fact give new coverage,
// and if yes, minimize them and add to corpus.
type WorkTriage struct {
	p     *prog.Prog
	call  int
	info  ipc.CallInfo
	flags ProgTypes
	RaceInfo
}

// WorkCandidate are programs from hub.
// We don't know yet if they are useful for this fuzzer or not.
// A proc handles them the same way as locally generated/mutated programs.
type WorkCandidate struct {
	p     *prog.Prog
	flags ProgTypes
	RaceInfo
}

// WorkSmash are programs just added to corpus.
// During smashing these programs receive a one-time special attention
// (emit faults, collect comparison hints, etc).
type WorkSmash struct {
	p    *prog.Prog
	call int
}

func newWorkQueue(procs int, needCandidates chan struct{}) *WorkQueue {
	return &WorkQueue{
		procs:          procs,
		needCandidates: needCandidates,
	}
}

func (wq *WorkQueue) enqueue(item interface{}) {
	wq.mu.Lock()
	defer wq.mu.Unlock()
	switch item := item.(type) {
	case *WorkTriage:
		wq.triage = append(wq.triage, item)
	case *WorkCandidate:
		wq.candidate = append(wq.candidate, item)
	case *WorkSmash:
		wq.smash = append(wq.smash, item)
	default:
		panic("unknown work type")
	}
}

func (wq *WorkQueue) dequeue() (item interface{}) {
	wq.mu.RLock()
	if len(wq.candidate)+len(wq.triage)+len(wq.smash) == 0 {
		wq.mu.RUnlock()
		return nil
	}
	wq.mu.RUnlock()
	wq.mu.Lock()
	wantCandidates := false
	if len(wq.triage) != 0 {
		last := len(wq.triage) - 1
		item = wq.triage[last]
		wq.triage = wq.triage[:last]
	} else if len(wq.candidate) != 0 {
		last := len(wq.candidate) - 1
		item = wq.candidate[last]
		wq.candidate = wq.candidate[:last]
		wantCandidates = len(wq.candidate) < wq.procs
	} else if len(wq.smash) != 0 {
		last := len(wq.smash) - 1
		item = wq.smash[last]
		wq.smash = wq.smash[:last]
	}
	wq.mu.Unlock()
	if wantCandidates {
		select {
		case wq.needCandidates <- struct{}{}:
		default:
		}
	}
	return item
}

func (wq *WorkQueue) wantCandidates() bool {
	wq.mu.RLock()
	defer wq.mu.RUnlock()
	return len(wq.candidate) < wq.procs
}

func (wq *WorkQueue) shouldCleanup(thold int) bool {
	wq.mu.RLock()
	defer wq.mu.RUnlock()
	if len(wq.candidate) > thold {
		return true
	}
	return false
}

func (wq *WorkQueue) shouldSoftCleanupRaceCands() bool {
	const thold = 10000
	return wq.shouldCleanup(thold)
}

func (wq *WorkQueue) shouldHardCleanupRaceCands() bool {
	const thold = 50000
	return wq.shouldCleanup(thold)
}

func (wq *WorkQueue) hardCleanupRaceCands() {
	wq.mu.Lock()
	defer wq.mu.Unlock()

	numToDrop := int(float32(len(wq.candidate)) * 0.9)
	wq.candidate = append([]*WorkCandidate{}, wq.candidate[numToDrop:]...)

	wq.scheduler.IncreaseStat(StatRcHardCleanup)
	wq.scheduler.AddStat(StatRcDrop, uint64(numToDrop))
}

func (wq *WorkQueue) softCleanupRaceCands() {
	wq.scheduler.IncreaseStat(StatRcSoftCleanup)

	wq.mu.RLock()
	// Pre-allocate updatedRaceCands as its possible max length to
	// avoid annoying slice re-allocation.
	updatedRaceCands := make([]*WorkCandidate, 0, len(wq.candidate)*2)
	// Cleanup based on suppress info
	for _, rc := range wq.candidate {
		raceinfo := rc.RaceInfo
		hsh := raceinfo.Hash
		if ok := wq.scheduler.isSuppressedPairs(hsh); !ok {
			updatedRaceCands = append(updatedRaceCands, rc)
			wq.scheduler.IncreaseStat(StatRcDropSurv)
		} else {
			wq.scheduler.IncreaseStat(StatRcDrop)
		}
	}
	wq.mu.RUnlock()

	wq.mu.Lock()
	// Replace the race cand queue
	wq.candidate = updatedRaceCands
	wq.mu.Unlock()
}
