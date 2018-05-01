// Copyright 2015 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

// Package rpctype contains types of message passed via net/rpc connections
// between various parts of the system.
package rpctype

import (
	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/signal"
)

type RPCInput struct {
	Call   string
	Prog   []byte
	Signal signal.Serial
	Cover  []uint32
}

type RPCCandidate struct {
	Prog      []byte
	Minimized bool
	Smashed   bool
}

type ConnectArgs struct {
	Name string
}

type ConnectRes struct {
	Prios        [][]float32
	Inputs       []RPCInput
	MaxSignal    signal.Serial
	Candidates   []RPCCandidate
	EnabledCalls []int
	NeedCheck    bool

	Mempair             []Mempair
	Mapping             []Mapping
	MempairHash         map[MempairHash]struct{}
	SparseRaceCandPairs map[uint32][]EntryTy
	SuppressedPairs     map[MempairHash]struct{}
}

type CheckArgs struct {
	Name           string
	Kcov           bool
	Leak           bool
	Fault          bool
	UserNamespaces bool
	CompsSupported bool
	Calls          []string
	DisabledCalls  []SyscallReason
	FuzzerGitRev   string
	FuzzerSyzRev   string
	ExecutorGitRev string
	ExecutorSyzRev string
	ExecutorArch   string
}

type SyscallReason struct {
	Name   string
	Reason string
}

type NewInputArgs struct {
	Name string
	RPCInput
}

type PollArgs struct {
	Name             string
	NeedCandidates   bool
	MaxSignal        signal.Serial
	Stats            map[string]uint64
	TimeSummary      string
	RaceCandQueueLen uint64

	NewRaceProgCand []*NewRaceProgCandArgs
}

type PollRes struct {
	Candidates []RPCCandidate
	NewInputs  []RPCInput
	MaxSignal  signal.Serial

	SuppPairsToAdd []MempairHash
	SuppPairsToDel []MempairHash
}

type HubConnectArgs struct {
	// Client/Key are used for authentication.
	Client string
	Key    string
	// Manager name, must start with Client.
	Manager string
	// Manager has started with an empty corpus and requests whole hub corpus.
	Fresh bool
	// Set of system call names supported by this manager.
	// Used to filter out programs with unsupported calls.
	Calls []string
	// Current manager corpus.
	Corpus [][]byte
}

type HubSyncArgs struct {
	// see HubConnectArgs.
	Client     string
	Key        string
	Manager    string
	NeedRepros bool
	// Programs added to corpus since last sync or connect.
	Add [][]byte
	// Hashes of programs removed from corpus since last sync or connect.
	Del []string
	// Repros found since last sync.
	Repros [][]byte
}

type HubSyncRes struct {
	// Set of programs from other managers.
	Progs [][]byte
	// Set of repros from other managers.
	Repros [][]byte
	// Number of remaining pending programs,
	// if >0 manager should do sync again.
	More int
}

type Mempair struct {
	Locs []string
	Tags []string
}

type Mapping struct {
	Loc  string
	Tag  string
	Func []string
	Item []uint64
}

type EntryTy struct {
	Cover   uint32
	Hash    MempairHash
	Mempair []string
}

// From fuzzer to scheduler
type NewRaceProgCandArgs struct {
	Name string
	RaceProgCand
}

// From fuzzer to scheduler
type RaceProgCand struct {
	Prog      []byte
	RaceInfos []RaceInfo
	FromDB    bool
}

type SchedulerConnectRes struct {
	RaceProgCands    []RaceProgCand
	RaceInputs       []RPCRaceInput
	EnabledCalls     []int
	Prios            [][]float32
	Corpus           []RPCInput
	RaceMaxSignal    signal.Serial
	Mempair          []Mempair
	TrueRaceHashes   []MempairHash
	SuppressedPairs  map[MempairHash]struct{}
	LikelyRaceInputs []RPCLikelyRaceInput
}

type RPCRaceInput struct {
	RaceProg  []byte
	Call      string
	CallIndex int
	Signal    signal.Serial
	Cover     []uint32
	RaceInfo
}

type SchedulerPollArgs struct {
	Name             string
	MaxSignal        signal.Serial
	Stats            map[string]uint64
	NeedCandidates   bool
	FoundRaceInfos   []FoundRaceInfo
	TimeSummary      string
	MempairExecInfo  map[MempairHash]RaceExecInfo
	RaceCandQueueLen uint64
}

type SchedulerPollRes struct {
	NewInputs           []RPCInput
	MaxSignal           signal.Serial
	RaceProgs           []RaceProgCand
	NewRaceInputs       []RPCRaceInput
	NewLikelyRaceInputs []RPCLikelyRaceInput
	TrueRaceHashes      []MempairHash
	SuppPairsToAdd      []MempairHash
	SuppPairsToDel      []MempairHash
	RaceCorpusDBDone    bool
}

// From scheduler to manager
type NewRaceInputArgs struct {
	Name string
	RPCRaceInput
}

type FoundRaceInfo struct {
	MempairHash
	RaceRunKind
}

// From scheduler to manager
type NewLikelyRaceInputArgs struct {
	Name string
	RPCLikelyRaceInput
}

type RPCLikelyRaceInput struct {
	RaceProg []byte
	RaceInfo
}
