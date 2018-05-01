// Copyright 2015 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

package main

import (
	"bytes"
	"flag"
	"fmt"
	"math/rand"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	"github.com/google/syzkaller/dashboard/dashapi"
	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/cover"
	"github.com/google/syzkaller/pkg/csource"
	"github.com/google/syzkaller/pkg/gce"
	"github.com/google/syzkaller/pkg/hash"
	. "github.com/google/syzkaller/pkg/log"
	"github.com/google/syzkaller/pkg/osutil"
	"github.com/google/syzkaller/pkg/report"
	"github.com/google/syzkaller/pkg/repro"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/pkg/signal"
	"github.com/google/syzkaller/prog"
	"github.com/google/syzkaller/sys"
	"github.com/google/syzkaller/syz-manager/mgrconfig"
	"github.com/google/syzkaller/vm"
)

var (
	flagConfig         = flag.String("config", "", "configuration file")
	flagDebug          = flag.Bool("debug", false, "dump all VM output to console")
	flagRaceDebug      = flag.Bool("rdebug", false, "dump all scheduler VM output to console")
	flagFuzzerDebug    = flag.Bool("fdebug", false, "dump all fuzzer VM output to console")
	flagFuzzerRepro    = flag.Bool("fuzzer-repro", false, "reproduce fuzzer crash")
	flagRaceRepro      = flag.Bool("repro", false, "reproduce race crash")
	flagDisableWarn    = flag.Bool("no-warn", false, "disable warning")
	flagRTime          = flag.Bool("rtime", false, "print scheduler time stat")
	flagFTime          = flag.Bool("ftime", false, "print fuzzer time stat")
	flagSuppOption     = flag.Int("supp", 1, "memapri suppresion (0: both, 1: freq, 2: signal)")
	flagRootCause      = flag.Bool("rootcause", false, "rootcause analysis using program logs")
	flagMinimizeCorpus = flag.Bool("minimizecorpus", false, "Minimize corpus into minimal corpus that have the same signal set")
)

type LocTy struct {
	SourceLoc string
	Tag       string
}

type ItemTy struct {
	Item uint32
	Tag  string
}

type Manager struct {
	cfg            *mgrconfig.Config
	vmPool         *vm.Pool
	target         *prog.Target
	reporter       report.Reporter
	crashdir       string
	port           int
	startTime      time.Time
	firstConnect   time.Time
	lastPrioCalc   time.Time
	fuzzingTime    time.Duration
	stats          map[string]uint64
	crashTypes     map[string]bool
	vmStop         chan bool
	vmChecked      bool
	fresh          bool
	numFuzzing     uint32
	numReproducing uint32

	dash *dashapi.Dashboard

	mu              sync.Mutex
	phase           int
	enabledSyscalls []int
	enabledCalls    []string // as determined by fuzzer

	rpcCands       []RPCCandidate // untriaged inputs from corpus and hub
	disabledHashes map[string]struct{}
	corpus         map[string]RPCInput
	corpusCover    cover.Cover
	corpusSignal   signal.Signal
	maxSignal      signal.Signal
	prios          [][]float32
	newRepros      [][]byte

	fuzzers        map[string]*Fuzzer
	hub            *RPCClient
	hubCorpus      map[hash.Sig]bool
	needMoreRepros chan chan bool
	hubReproQueue  chan *Crash
	reproRequest   chan chan map[string]bool

	// For checking that files that we are using are not changing under us.
	// Maps file name to modification time.
	usedFiles map[string]time.Time

	// ----- Racefuzzer -----
	schedulers    map[string]*Scheduler
	raceCorpus    map[string]RPCRaceInput
	raceMaxSignal signal.Signal
	// scheduler vm pool
	racePool *vm.Pool

	// stat history
	histStats map[string]*HistStat

	// Sent all progs in DB
	corpusDBDone     bool
	raceCorpusDBDone bool

	// All DBs
	managerDB *ManagerDB

	// Static analysis result
	mempair             []Mempair
	mapping             []Mapping
	mempairHash         map[MempairHash]struct{}
	mempairHashToStr    map[MempairHash]string
	locToBB             map[LocTy][]uint32
	sparseRaceCandPairs map[uint32][]EntryTy
	srcBBtoPC           map[string][]ItemTy

	// RaceQueue
	raceMu          sync.Mutex
	raceQueue       []RaceProgCand
	suppressedPairs map[MempairHash]struct{}

	// likely race
	likelyRaceCorpus map[MempairHash]RPCLikelyRaceInput

	// True race info
	trueRaceHashes  map[MempairHash]struct{}
	mempairExecInfo map[MempairHash]RaceExecInfo

	// Signal
	raceCorpusSignal signal.Signal
	maxRaceSignal    signal.Signal

	firstStart          bool
	vmRaceStop          chan bool
	mempairToRaceCorpus map[MempairHash][]string

	flagRootcause bool
}

const (
	// Just started, nothing done yet.
	phaseInit = iota
	// Triaged all inputs from corpus.
	// This is when we start querying hub and minimizing persistent corpus.
	phaseTriagedCorpus
	// Done the first request to hub.
	phaseQueriedHub
	// Triaged all new inputs from hub.
	// This is when we start reproducing crashes.
	phaseTriagedHub
)

const currentDBVersion = 3

type Scheduler struct {
	name             string
	raceInputs       []RPCRaceInput
	likelyRaceInputs []RPCLikelyRaceInput
	inputs           []RPCInput
	newMaxSignal     signal.Signal
	trueRaceHashes   []MempairHash
	suppPairsToAdd   []MempairHash
	suppPairsToDel   []MempairHash
	lastPollTime     time.Time
	raceCandQueueLen uint64
}

type Fuzzer struct {
	name             string
	inputs           []RPCInput
	newMaxSignal     signal.Signal
	lastPollTime     time.Time
	raceCandQueueLen uint64
	suppPairsToAdd   []MempairHash
	suppPairsToDel   []MempairHash
}

type Crash struct {
	vmIndex int
	hub     bool // this crash was created based on a repro from hub
	*report.Report
}

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

func (mgr *Manager) getAddr(loc string, bb uint32) []ItemTy {
	hshString := fmt.Sprintf("%s%x", loc, bb)
	hsh := hash.String([]byte(hshString))
	return mgr.srcBBtoPC[hsh]
}

func main() {
	if sys.GitRevision == "" {
		Fatalf("Bad syz-manager build. Build with make, run bin/syz-manager.")
	}
	flag.Parse()
	if *flagDebug == true {
		*flagFuzzerDebug = true
		*flagRaceDebug = true
	}
	EnableLogCaching(1000, 1<<20)
	cfg, err := mgrconfig.LoadFile(*flagConfig)
	if err != nil {
		Fatalf("%v", err)
	}
	target, err := prog.GetTarget(cfg.TargetOS, cfg.TargetArch)
	if err != nil {
		Fatalf("%v", err)
	}
	syscalls, err := mgrconfig.ParseEnabledSyscalls(target, cfg.Enable_Syscalls, cfg.Disable_Syscalls)
	if err != nil {
		Fatalf("%v", err)
	}
	initAllCover(cfg.TargetOS, cfg.TargetVMArch, cfg.Vmlinux)
	RunManager(cfg, target, syscalls)
}

func RunManager(cfg *mgrconfig.Config, target *prog.Target, syscalls map[int]bool) {
	mgr := managerInit(cfg, syscalls, target)
	if mgr.vmPool == nil {
		Logf(0, "no VMs started (type=none)")
		Logf(0, "you are supposed to start syz-fuzzer manually as:")
		Logf(0, "syz-fuzzer -manager=manager.ip:%v [other flags as necessary]", mgr.port)
		<-vm.Shutdown
		return
	}
	mgr.vmLoop()
}

type RunResult struct {
	idx   int
	crash *Crash
	err   error
}

type ReproResult struct {
	instances []int
	title0    string
	res       *repro.Result
	err       error
	hub       bool // repro came from hub
}

func (mgr *Manager) vmLoop() {
	Logf(0, "booting test machines...")
	Logf(0, "wait for the connection from test machine...")
	instancesPerRepro := 4
	vmCount := mgr.vmPool.Count()
	vmRaceCount := mgr.racePool.Count()

	if instancesPerRepro > vmCount {
		instancesPerRepro = vmCount
	}
	instances := make([]int, vmCount)
	for i := range instances {
		instances[i] = vmCount - i - 1
	}

	raceInstances := make([]int, vmRaceCount)
	for i := range raceInstances {
		raceInstances[i] = vmRaceCount - i - 1
	}

	runDone := make(chan *RunResult, 1)
	pendingRepro := make(map[*Crash]bool)
	reproducing := make(map[string]bool)
	reproInstances := 0
	raceReproInstances := 0
	var reproQueue []*Crash
	var raceReproQueue []*Crash
	reproDone := make(chan *ReproResult, 1)
	raceDone := make(chan *RunResult, 1)
	stopPending := false
	stopRacePending := false
	shutdown := vm.Shutdown

	for {
		mgr.mu.Lock()
		phase := mgr.phase
		mgr.mu.Unlock()

		for crash := range pendingRepro {
			if reproducing[crash.Title] {
				continue
			}
			delete(pendingRepro, crash)
			if !crash.hub {
				if mgr.dash == nil {
					if !mgr.needRepro(crash) {
						continue
					}
				} else {
					cid := &dashapi.CrashID{
						BuildID:   mgr.cfg.Tag,
						Title:     crash.Title,
						Corrupted: crash.Corrupted,
					}
					needRepro, err := mgr.dash.NeedRepro(cid)
					if err != nil {
						Logf(0, "dashboard.NeedRepro failed: %v", err)
					}
					if !needRepro {
						continue
					}
				}
			}
			Logf(1, "loop: add to repro queue '%v'", crash.Title)
			reproducing[crash.Title] = true
			reproQueue = append(reproQueue, crash)
		}

		Logf(1, "loop: phase=%v shutdown=%v instances=%v/%v %+v repro: pending=%v reproducing=%v queued=%v",
			phase, shutdown == nil, len(instances), vmCount, instances,
			len(pendingRepro), len(reproducing), len(reproQueue))

		canRepro := func() bool {
			if *flagFuzzerRepro {
				return phase >= phaseTriagedHub &&
					len(reproQueue) != 0 && reproInstances+instancesPerRepro <= vmCount
			}
			return false
		}
		canRaceRepro := func() bool {
			if *flagRaceRepro {
				return len(raceReproQueue) != 0 && raceReproInstances+instancesPerRepro <= vmRaceCount
			}
			return false
		}

		if shutdown == nil {
			if len(instances) == vmCount {
				return
			}
		} else {
			// syz-fuzzer
			for canRepro() && len(instances) >= instancesPerRepro {
				last := len(reproQueue) - 1
				crash := reproQueue[last]
				reproQueue[last] = nil
				reproQueue = reproQueue[:last]
				vmIndexes := append([]int{}, instances[len(instances)-instancesPerRepro:]...)
				instances = instances[:len(instances)-instancesPerRepro]
				reproInstances += instancesPerRepro
				atomic.AddUint32(&mgr.numReproducing, 1)
				Logf(1, "loop: starting repro of '%v' on instances %+v", crash.Title, vmIndexes)
				go func() {
					res, err := repro.Run(crash.Output, mgr.cfg, mgr.getReporter(), mgr.vmPool, vmIndexes)
					reproDone <- &ReproResult{vmIndexes, crash.Title, res, err, crash.hub}
				}()
			}
			for !canRepro() && len(instances) != 0 {
				last := len(instances) - 1
				idx := instances[last]
				instances = instances[:last]
				Logf(1, "loop: starting instance %v", idx)
				go func() {
					crash, err := mgr.runInstance(idx, false)
					runDone <- &RunResult{idx, crash, err}
				}()
			}

			// syz-scheduler
			/* Repro
			for canRaceRepro() && len(raceInstances) >= instancesPerRepro {
				last := len(raceReproQueue) - 1
				crash := raceReproQueue[last]
				raceReproQueue[last] = nil
				raceReproQueue = raceReproQueue[:last]
				vmIndexes := append([]int{}, raceInstances[len(raceInstances)-instancesPerRepro:]...)
				raceInstances = raceInstances[:len(raceInstances)-instancesPerRepro]
				raceReproInstances += instancesPerRepro
				Logf(0, "loop: starting race repro of '%v' on instances %+v", crash.desc, vmIndexes)
				go func() {
					res, err := repro.Run(crash.output, mgr.cfg, mgr.racePool, vmIndexes, false, false)
					raceReproDone <- &ReproResult{vmIndexes, crash.desc, res, err}
				}()
			}
			*/
			for !canRaceRepro() && len(raceInstances) != 0 {
				last := len(raceInstances) - 1
				idx := raceInstances[last]
				raceInstances = raceInstances[:last]
				if len(raceInstances) == 0 {
					mgr.firstStart = false
				}
				Logf(1, "loop: starting race instance %v", idx)
				go func() {
					crash, err := mgr.runInstance(idx, true)
					raceDone <- &RunResult{idx, crash, err}
				}()
			}
		}

		var stopRequest chan bool
		if !stopPending && canRepro() {
			stopRequest = mgr.vmStop
		}

		var stopRaceRequest chan bool
		if !stopRacePending && canRaceRepro() {
			stopRaceRequest = mgr.vmRaceStop
		}

		select {
		case res := <-raceDone:
			Logf(1, "loop: race instance %v finished, crash=%v", res.idx, res.crash != nil)
			if res.err != nil && shutdown != nil {
				Logf(0, "\t shutdown (sched-%v): %v", res.idx, res.err)
			}
			stopRacePending = false
			raceInstances = append(raceInstances, res.idx)
			// On shutdown qemu crashes with "qemu: terminating on signal 2",
			// which we detect as "lost connection". Don't save that as crash.
			if shutdown != nil && res.crash != nil && !mgr.isSuppressedCrash(res.crash, true) {
				mgr.saveCrash(res.crash, true)
				if *flagRaceRepro && mgr.needRepro(res.crash) {
					Logf(1, "loop: add pending repro for '%v'", res.crash)
					// pendingRaceRepro[res.crash] = true
				}
			}
		case stopRaceRequest <- true:
			Logf(1, "loop: isseud stop race request")
			stopRacePending = true
		case stopRequest <- true:
			Logf(1, "loop: issued stop request")
			stopPending = true
		case res := <-runDone:
			Logf(1, "loop: instance %v finished, crash=%v", res.idx, res.crash != nil)
			if res.err != nil && shutdown != nil {
				Logf(0, "%v", res.err)
			}
			stopPending = false
			instances = append(instances, res.idx)
			// On shutdown qemu crashes with "qemu: terminating on signal 2",
			// which we detect as "lost connection". Don't save that as crash.
			if shutdown != nil && res.crash != nil && !mgr.isSuppressedCrash(res.crash, false) {
				needRepro := mgr.saveCrash(res.crash, false)
				if needRepro {
					Logf(1, "loop: add pending repro for '%v'", res.crash.Title)
					pendingRepro[res.crash] = true
				}
			}
		case res := <-reproDone:
			atomic.AddUint32(&mgr.numReproducing, ^uint32(0))
			crepro := false
			title := ""
			if res.res != nil {
				crepro = res.res.CRepro
				title = res.res.Report.Title
			}
			Logf(1, "loop: repro on %+v finished '%v', repro=%v crepro=%v desc='%v'",
				res.instances, res.title0, res.res != nil, crepro, title)
			if res.err != nil {
				Logf(0, "repro failed: %v", res.err)
			}
			delete(reproducing, res.title0)
			instances = append(instances, res.instances...)
			reproInstances -= instancesPerRepro
			if res.res == nil {
				if !res.hub {
					mgr.saveFailedRepro(res.title0)
				}
			} else {
				mgr.saveRepro(res.res, res.hub)
			}
		case <-shutdown:
			Logf(1, "loop: shutting down...")
			shutdown = nil
		case crash := <-mgr.hubReproQueue:
			Logf(1, "loop: get repro from hub")
			pendingRepro[crash] = true
		case reply := <-mgr.needMoreRepros:
			reply <- phase >= phaseTriagedHub &&
				len(reproQueue)+len(pendingRepro)+len(reproducing) == 0
		case reply := <-mgr.reproRequest:
			repros := make(map[string]bool)
			for title := range reproducing {
				repros[title] = true
			}
			reply <- repros
		}
	}
}

func createInstance(mgr *Manager, index int, sched bool) (*vm.Instance, error) {
	var pool *vm.Pool
	if sched {
		pool = mgr.racePool
	} else {
		pool = mgr.vmPool
	}

	inst, err := pool.Create(index)
	if err != nil {
		return nil, fmt.Errorf("failed to create instance: %v", err)
	}
	return inst, err
}

func copyBinaries(mgr *Manager, inst *vm.Instance, sched bool) (string, string, error) {
	var fuzzerBinName string
	if sched {
		fuzzerBinName = mgr.cfg.SyzSchedBin
	} else {
		fuzzerBinName = mgr.cfg.SyzFuzzerBin
	}

	// Binaries
	fuzzerBin, err_ := inst.Copy(fuzzerBinName)
	if err_ != nil {
		return "", "", fmt.Errorf("failed to copy binary: %v", err_)
	}
	executorBin, err := inst.Copy(mgr.cfg.SyzExecutorBin)
	if err != nil {
		return "", "", fmt.Errorf("failed to copy binary: %v", err)
	}

	return fuzzerBin, executorBin, nil
}

func (mgr *Manager) runInstance(index int, sched bool) (*Crash, error) {
	mgr.checkUsedFiles()
	var err error
	var collide, name string
	var debugFlag bool

	// Leak detection significantly slows down fuzzing, so detect leaks only on the first instance.
	leak := mgr.cfg.Leak && index == 0
	fuzzerV := 0
	procs := mgr.cfg.Procs
	if sched {
		debugFlag = *flagRaceDebug
		name = fmt.Sprintf("sched-%v", index)
		collide = " -collide"
	} else {
		debugFlag = *flagFuzzerDebug
		name = fmt.Sprintf("fuzzer-%v", index)
	}

	if debugFlag {
		fuzzerV = 100
		procs = 1
	}

	// Create instance
	inst, err := createInstance(mgr, index, sched)
	if err != nil {
		return nil, err
	}
	defer inst.Close()

	fwdAddr, err := inst.Forward(mgr.port)
	if err != nil {
		return nil, fmt.Errorf("failed to setup port forwarding: %v", err)
	}

	// Copy Binaries
	fuzzerBin, executorBin, err := copyBinaries(mgr, inst, sched)

	// Command
	cmd := fmt.Sprintf("%v -executor=%v -name=%v -arch=%v -manager=%v -procs=%v"+
		" -leak=%v -cover=%v -sandbox=%v -debug=%v -v=%d -rootcause=%v -supp=%v"+collide,
		fuzzerBin, executorBin, name, mgr.cfg.TargetArch, fwdAddr, procs,
		leak, mgr.cfg.Cover, mgr.cfg.Sandbox, debugFlag, fuzzerV, *flagRootCause, *flagSuppOption)

	// Run the fuzzer binary.
	start := time.Now()
	atomic.AddUint32(&mgr.numFuzzing, 1)
	defer atomic.AddUint32(&mgr.numFuzzing, ^uint32(0))
	outc, errc, err := inst.Run(time.Hour, mgr.vmStop, cmd)
	if err != nil {
		return nil, fmt.Errorf("failed to run fuzzer: %v", err)
	}

	rep := vm.MonitorExecution(outc, errc, mgr.getReporter(), false)
	if rep == nil {
		// This is the only "OK" outcome.
		Logf(0, "fuzzer-%v: running for %v, restarting", index, time.Since(start))
		return nil, nil
	}
	cash := &Crash{
		vmIndex: index,
		hub:     false,
		Report:  rep,
	}
	return cash, nil
}

func (mgr *Manager) isSuppressedCrash(crash *Crash, sched bool) bool {
	for _, re := range mgr.cfg.ParsedSuppressions {
		if !re.Match(crash.Output) {
			continue
		}
		if sched {
			Logf(0, "sched-%v: suppressing '%v' with '%v'", crash.vmIndex, crash.Title, re.String())
		} else {
			Logf(0, "fuzzer-%v: suppressing '%v' with '%v'", crash.vmIndex, crash.Title, re.String())
		}
		mgr.mu.Lock()
		mgr.stats["suppressed"]++
		mgr.mu.Unlock()
		return true
	}
	return false
}

func (mgr *Manager) emailCrash(crash *Crash) {
	if len(mgr.cfg.Email_Addrs) == 0 {
		return
	}
	args := []string{"-s", "syzkaller: " + crash.Title}
	args = append(args, mgr.cfg.Email_Addrs...)
	Logf(0, "sending email to %v", mgr.cfg.Email_Addrs)

	cmd := exec.Command("mailx", args...)
	cmd.Stdin = bytes.NewReader(crash.Report.Report)
	if _, err := osutil.Run(10*time.Minute, cmd); err != nil {
		Logf(0, "failed to send email: %v", err)
	}
}

func (mgr *Manager) saveCrash(crash *Crash, sched bool) bool {
	corrupted := ""
	if crash.Corrupted {
		corrupted = " [corrupted]"
	}
	if sched {
		Logf(0, "sched-%v: crash: %v%v", crash.vmIndex, crash.Title, corrupted)
	} else {
		Logf(0, "fuzzer-%v: crash: %v%v", crash.vmIndex, crash.Title, corrupted)
	}
	if err := mgr.getReporter().Symbolize(crash.Report); err != nil {
		Logf(0, "failed to symbolize report: %v", err)
	}

	mgr.mu.Lock()
	mgr.stats["crashes"]++
	if !mgr.crashTypes[crash.Title] {
		mgr.crashTypes[crash.Title] = true
		mgr.stats["crash types"]++
	}
	mgr.mu.Unlock()

	if mgr.dash != nil {
		dc := &dashapi.Crash{
			BuildID:     mgr.cfg.Tag,
			Title:       crash.Title,
			Corrupted:   crash.Corrupted,
			Maintainers: crash.Maintainers,
			Log:         crash.Output,
			Report:      crash.Report.Report,
		}
		resp, err := mgr.dash.ReportCrash(dc)
		if err != nil {
			Logf(0, "failed to report crash to dashboard: %v", err)
		} else {
			// Don't store the crash locally, if we've successfully
			// uploaded it to the dashboard. These will just eat disk space.
			return resp.NeedRepro
		}
	}

	sig := hash.Hash([]byte(crash.Title))
	id := sig.String()
	dir := filepath.Join(mgr.crashdir, id)
	osutil.MkdirAll(dir)
	if err := osutil.WriteFile(filepath.Join(dir, "description"), []byte(crash.Title+"\n")); err != nil {
		Logf(0, "failed to write crash: %v", err)
	}
	// Save up to 100 reports. If we already have 100, overwrite the oldest one.
	// Newer reports are generally more useful. Overwriting is also needed
	// to be able to understand if a particular bug still happens or already fixed.
	oldestI := 0
	var oldestTime time.Time
	for i := 0; i < 100; i++ {
		info, err := os.Stat(filepath.Join(dir, fmt.Sprintf("log%v", i)))
		if err != nil {
			oldestI = i
			if i == 0 {
				go mgr.emailCrash(crash)
			}
			break
		}
		if oldestTime.IsZero() || info.ModTime().Before(oldestTime) {
			oldestI = i
			oldestTime = info.ModTime()
		}
	}
	osutil.WriteFile(filepath.Join(dir, fmt.Sprintf("log%v", oldestI)), crash.Output)
	if len(mgr.cfg.Tag) > 0 {
		osutil.WriteFile(filepath.Join(dir, fmt.Sprintf("tag%v", oldestI)), []byte(mgr.cfg.Tag))
	}
	if len(crash.Report.Report) > 0 {
		osutil.WriteFile(filepath.Join(dir, fmt.Sprintf("report%v", oldestI)), crash.Report.Report)
	}

	return mgr.needRepro(crash)
}

const maxReproAttempts = 3

func (mgr *Manager) needRepro(crash *Crash) bool {
	if !mgr.cfg.Reproduce || crash.Corrupted {
		return false
	}
	sig := hash.Hash([]byte(crash.Title))
	dir := filepath.Join(mgr.crashdir, sig.String())
	if osutil.IsExist(filepath.Join(dir, "repro.prog")) {
		return false
	}
	for i := 0; i < maxReproAttempts; i++ {
		if !osutil.IsExist(filepath.Join(dir, fmt.Sprintf("repro%v", i))) {
			return true
		}
	}
	return false
}

func (mgr *Manager) saveFailedRepro(desc string) {
	if mgr.dash != nil {
		cid := &dashapi.CrashID{
			BuildID: mgr.cfg.Tag,
			Title:   desc,
		}
		if err := mgr.dash.ReportFailedRepro(cid); err != nil {
			Logf(0, "failed to report failed repro to dashboard: %v", err)
		}
	}
	dir := filepath.Join(mgr.crashdir, hash.String([]byte(desc)))
	osutil.MkdirAll(dir)
	for i := 0; i < maxReproAttempts; i++ {
		name := filepath.Join(dir, fmt.Sprintf("repro%v", i))
		if !osutil.IsExist(name) {
			osutil.WriteFile(name, nil)
			break
		}
	}
}

func (mgr *Manager) saveRepro(res *repro.Result, hub bool) {
	rep := res.Report
	if err := mgr.getReporter().Symbolize(rep); err != nil {
		Logf(0, "failed to symbolize repro: %v", err)
	}
	dir := filepath.Join(mgr.crashdir, hash.String([]byte(rep.Title)))
	osutil.MkdirAll(dir)

	if err := osutil.WriteFile(filepath.Join(dir, "description"), []byte(rep.Title+"\n")); err != nil {
		Logf(0, "failed to write crash: %v", err)
	}
	opts := fmt.Sprintf("# %+v\n", res.Opts)
	prog := res.Prog.Serialize()
	osutil.WriteFile(filepath.Join(dir, "repro.prog"), append([]byte(opts), prog...))
	if len(mgr.cfg.Tag) > 0 {
		osutil.WriteFile(filepath.Join(dir, "repro.tag"), []byte(mgr.cfg.Tag))
	}
	if len(rep.Output) > 0 {
		osutil.WriteFile(filepath.Join(dir, "repro.log"), rep.Output)
	}
	if len(rep.Report) > 0 {
		osutil.WriteFile(filepath.Join(dir, "repro.report"), rep.Report)
	}
	osutil.WriteFile(filepath.Join(dir, "repro.stats.log"), res.Stats.Log)
	stats := fmt.Sprintf("Extracting prog: %s\nMinimizing prog: %s\nSimplifying prog options: %s\nExtracting C: %s\nSimplifying C: %s\n",
		res.Stats.ExtractProgTime, res.Stats.MinimizeProgTime, res.Stats.SimplifyProgTime, res.Stats.ExtractCTime, res.Stats.SimplifyCTime)
	osutil.WriteFile(filepath.Join(dir, "repro.stats"), []byte(stats))
	var cprogText []byte
	if res.CRepro {
		cprog, err := csource.Write(res.Prog, res.Opts)
		if err == nil {
			formatted, err := csource.Format(cprog)
			if err == nil {
				cprog = formatted
			}
			osutil.WriteFile(filepath.Join(dir, "repro.cprog"), cprog)
			cprogText = cprog
		} else {
			Logf(0, "failed to write C source: %v", err)
		}
	}

	// Append this repro to repro list to send to hub if it didn't come from hub originally.
	if !hub {
		progForHub := []byte(fmt.Sprintf("# %+v\n# %v\n# %v\n%s",
			res.Opts, res.Report.Title, mgr.cfg.Tag, prog))
		mgr.mu.Lock()
		mgr.newRepros = append(mgr.newRepros, progForHub)
		mgr.mu.Unlock()
	}

	if mgr.dash != nil {
		// Note: we intentionally don't set Corrupted for reproducers:
		// 1. This is reproducible so can be debugged even with corrupted report.
		// 2. Repro re-tried 3 times and still got corrupted report at the end,
		//    so maybe corrupted report detection is broken.
		// 3. Reproduction is expensive so it's good to persist the result.
		dc := &dashapi.Crash{
			BuildID:     mgr.cfg.Tag,
			Title:       res.Report.Title,
			Maintainers: res.Report.Maintainers,
			Log:         res.Report.Output,
			Report:      res.Report.Report,
			ReproOpts:   res.Opts.Serialize(),
			ReproSyz:    res.Prog.Serialize(),
			ReproC:      cprogText,
		}
		if _, err := mgr.dash.ReportCrash(dc); err != nil {
			Logf(0, "failed to report repro to dashboard: %v", err)
		}
	}
}

func (mgr *Manager) getReporter() report.Reporter {
	if mgr.reporter == nil {
		<-allSymbolsReady
		var err error
		// TODO(dvyukov): we should introduce cfg.Kernel_Obj dir instead of Vmlinux.
		// This will be more general taking into account modules and other OSes.
		kernelSrc, kernelObj := "", ""
		if mgr.cfg.Vmlinux != "" {
			kernelSrc = mgr.cfg.Kernel_Src
			kernelObj = filepath.Dir(mgr.cfg.Vmlinux)
		}
		mgr.reporter, err = report.NewReporter(mgr.cfg.TargetOS, kernelSrc, kernelObj,
			allSymbols, mgr.cfg.ParsedIgnores)
		if err != nil {
			Fatalf("%v", err)
		}
	}
	return mgr.reporter
}

func (mgr *Manager) minimizeCorpus() {
	if mgr.cfg.Cover && len(mgr.corpus) != 0 {
		inputs := make([]signal.Context, 0, len(mgr.corpus))
		for _, inp := range mgr.corpus {
			inputs = append(inputs, signal.Context{
				Signal:  inp.Signal.Deserialize(),
				Context: inp,
			})
		}
		newCorpus := make(map[string]RPCInput)
		for _, ctx := range signal.Minimize(inputs) {
			inp := ctx.(RPCInput)
			newCorpus[hash.String(inp.Prog)] = inp
		}
		Logf(1, "minimized corpus: %v -> %v", len(mgr.corpus), len(newCorpus))
		mgr.corpus = newCorpus
	}

	// Don't minimize persistent corpus until fuzzers have triaged all inputs from it.
	if mgr.corpusDBDone && time.Until(mgr.startTime) > 10*time.Minute {
		mgr.clearDB(CORPUSDB, mgr.corpus)
	}
}

func (mgr *Manager) calculatePrios() {
	// Deserializing all programs is slow, so we do it episodically and without holding the mutex.
	mgr.lastPrioCalc = time.Now()
	inputs := make([][]byte, 0, len(mgr.corpus))
	for _, inp := range mgr.corpus {
		inputs = append(inputs, inp.Prog)
	}
	mgr.mu.Unlock()

	corpus := make([]*prog.Prog, 0, len(inputs))
	for _, inp := range inputs {
		p, err := mgr.target.Deserialize(inp)
		if err != nil {
			panic(err)
		}
		corpus = append(corpus, p)
	}
	prios := mgr.target.CalculatePriorities(corpus)

	mgr.mu.Lock()
	mgr.prios = prios
}

func (mgr *Manager) SchedulerConnect(a *ConnectArgs, r *SchedulerConnectRes) error {
	Logf(1, "scheduler %v connected", a.Name)
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	mgr.stats["sched restarts"]++
	s := &Scheduler{
		name: a.Name,
	}
	mgr.schedulers[a.Name] = s
	mgr.minimizeRaceCorpus()

	// Carefully send raceprog cand from raceCorpusDB.
	numToPop := 1
	r.RaceProgCands = PopFromRaceQueue(mgr, numToPop)

	if mgr.prios == nil || time.Since(mgr.lastPrioCalc) > 30*time.Minute {
		mgr.calculatePrios()
	}

	for _, inp := range mgr.corpus {
		r.Corpus = append(r.Corpus, inp)
	}
	for _, rinp := range mgr.raceCorpus {
		r.RaceInputs = append(r.RaceInputs, rinp)
	}
	r.RaceMaxSignal = mgr.raceMaxSignal.Serialize()

	cnt := 0
	for _, likelyRaceInput := range mgr.likelyRaceCorpus {
		// Send only 100 likely inputs when conencted. The rest will
		// be sent during the poll.
		if cnt++; cnt < 100 {
			r.LikelyRaceInputs = append(r.LikelyRaceInputs, likelyRaceInput)
		} else {
			s.likelyRaceInputs = append(s.likelyRaceInputs, likelyRaceInput)
		}
	}

	r.SuppressedPairs = make(map[MempairHash]struct{})
	for hsh, _ := range mgr.suppressedPairs {
		r.SuppressedPairs[hsh] = struct{}{}
	}

	r.Prios = mgr.prios
	r.EnabledCalls = mgr.enabledSyscalls

	r.Mempair = append([]Mempair{}, mgr.mempair...)

	// TODO: what if mgr.trueRaces is too big? it seems it's find until now.
	for hsh, _ := range mgr.trueRaceHashes {
		r.TrueRaceHashes = append(r.TrueRaceHashes, hsh)
	}

	return nil
}

func (mgr *Manager) Connect(a *ConnectArgs, r *ConnectRes) error {
	Logf(1, "fuzzer %v connected", a.Name)
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	if mgr.firstConnect.IsZero() {
		mgr.firstConnect = time.Now()
		Logf(0, "received first connection from test machine %v", a.Name)
	}

	mgr.stats["vm restarts"]++
	f := &Fuzzer{
		name: a.Name,
	}
	mgr.fuzzers[a.Name] = f
	mgr.minimizeCorpus()

	if mgr.prios == nil || time.Since(mgr.lastPrioCalc) > 30*time.Minute {
		mgr.calculatePrios()
	}

	for _, inp := range mgr.corpus {
		r.Inputs = append(r.Inputs, inp)
	}
	r.Prios = mgr.prios
	r.EnabledCalls = mgr.enabledSyscalls
	r.NeedCheck = !mgr.vmChecked
	r.MaxSignal = mgr.maxSignal.Serialize()
	for i := 0; i < mgr.cfg.Procs && len(mgr.rpcCands) > 0; i++ {
		last := len(mgr.rpcCands) - 1
		r.Candidates = append(r.Candidates, mgr.rpcCands[last])
		mgr.rpcCands = mgr.rpcCands[:last]
	}
	if len(mgr.rpcCands) == 0 {
		mgr.rpcCands = nil
	}

	// Static analysis result
	r.Mempair = append([]Mempair{}, mgr.mempair...)
	r.Mapping = append([]Mapping{}, mgr.mapping...)
	r.MempairHash = make(map[MempairHash]struct{})
	for k, _ := range mgr.mempairHash {
		r.MempairHash[k] = struct{}{}
	}
	r.SparseRaceCandPairs = make(map[uint32][]EntryTy)
	for k, v := range mgr.sparseRaceCandPairs {
		r.SparseRaceCandPairs[k] = append(r.SparseRaceCandPairs[k], v...)
	}

	// Suppressd mempair
	r.SuppressedPairs = make(map[MempairHash]struct{})
	for hsh := range mgr.suppressedPairs {
		r.SuppressedPairs[hsh] = struct{}{}
	}
	return nil
}

func (mgr *Manager) Check(a *CheckArgs, r *int) error {
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	if mgr.vmChecked {
		return nil
	}
	Logf(0, "machine check: %v calls enabled, kcov=%v, kleakcheck=%v, faultinjection=%v, comps=%v",
		len(a.Calls), a.Kcov, a.Leak, a.Fault, a.CompsSupported)
	if mgr.cfg.Cover && !a.Kcov {
		Fatalf("/sys/kernel/debug/kcov is missing on target machine. Enable CONFIG_KCOV and mount debugfs")
	}
	if mgr.cfg.Sandbox == "namespace" && !a.UserNamespaces {
		Fatalf("/proc/self/ns/user is missing on target machine or permission is denied. Can't use requested namespace sandbox. Enable CONFIG_USER_NS")
	}
	if mgr.vmPool != nil {
		if mgr.target.Arch != a.ExecutorArch {
			Fatalf("mismatching target/executor arch: target=%v executor=%v",
				mgr.target.Arch, a.ExecutorArch)
		}
		if sys.GitRevision != a.FuzzerGitRev || sys.GitRevision != a.ExecutorGitRev {
			Fatalf("syz-manager, syz-fuzzer and syz-executor binaries are built on different git revisions\n"+
				"manager= %v\nfuzzer=  %v\nexecutor=%v\n"+
				"this is not supported, rebuild all binaries with make",
				sys.GitRevision, a.FuzzerGitRev, a.ExecutorGitRev)
		}
		if mgr.target.Revision != a.FuzzerSyzRev || mgr.target.Revision != a.ExecutorSyzRev {
			Fatalf("syz-manager, syz-fuzzer and syz-executor binaries have different versions of system call descriptions compiled in\n"+
				"manager= %v\nfuzzer=  %v\nexecutor=%v\n"+
				"this is not supported, rebuild all binaries with make",
				mgr.target.Revision, a.FuzzerSyzRev, a.ExecutorSyzRev)
		}
	}
	if len(mgr.cfg.Enable_Syscalls) != 0 && len(a.DisabledCalls) != 0 {
		disabled := make(map[string]string)
		for _, dc := range a.DisabledCalls {
			disabled[dc.Name] = dc.Reason
		}
		for _, id := range mgr.enabledSyscalls {
			name := mgr.target.Syscalls[id].Name
			if reason := disabled[name]; reason != "" {
				Logf(0, "disabling %v: %v", name, reason)
			}
		}
	}
	if len(a.Calls) == 0 {
		Fatalf("all system calls are disabled")
	}
	mgr.vmChecked = true
	mgr.enabledCalls = a.Calls
	return nil
}

func (mgr *Manager) NewInput(a *NewInputArgs, r *int) error {
	inputSignal := a.Signal.Deserialize()
	Logf(4, "new input from %v for syscall %v (signal=%v, cover=%v)",
		a.Name, a.Call, inputSignal.Len(), len(a.Cover))
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	f := mgr.fuzzers[a.Name]
	if f == nil {
		Fatalf("fuzzer %v is not connected", a.Name)
	}

	if _, err := mgr.target.Deserialize(a.RPCInput.Prog); err != nil {
		// This should not happen, but we see such cases episodically, reason unknown.
		Logf(0, "failed to deserialize program from fuzzer: %v\n%s", err, a.RPCInput.Prog)
		return nil
	}
	if mgr.corpusSignal.Diff(inputSignal).Empty() {
		return nil
	}
	mgr.stats["manager new inputs"]++
	mgr.corpusSignal.Merge(inputSignal)
	mgr.corpusCover.Merge(a.Cover)
	sig := hash.String(a.RPCInput.Prog)
	if inp, ok := mgr.corpus[sig]; ok {
		// The input is already present, but possibly with diffent signal/coverage/call.
		inputSignal.Merge(inp.Signal.Deserialize())
		inp.Signal = inputSignal.Serialize()
		var inputCover cover.Cover
		inputCover.Merge(inp.Cover)
		inputCover.Merge(a.RPCInput.Cover)
		inp.Cover = inputCover.Serialize()
		mgr.corpus[sig] = inp
	} else {
		mgr.corpus[sig] = a.RPCInput
		mgr.saveToDB(a.RPCInput)
		for _, f1 := range mgr.fuzzers {
			if f1 == f {
				continue
			}
			inp := a.RPCInput
			inp.Cover = nil // Don't send coverage back to all fuzzers.
			f1.inputs = append(f1.inputs, inp)
		}
	}
	return nil
}

func (mgr *Manager) FuzzerPoll(a *PollArgs, r *PollRes) error {
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	for k, v := range a.Stats {
		mgr.stats[k] += v
	}

	f := mgr.fuzzers[a.Name]
	if f == nil {
		Fatalf("fuzzer %v is not connected", a.Name)
	}
	newMaxSignal := mgr.maxSignal.Diff(a.MaxSignal.Deserialize())
	if !newMaxSignal.Empty() {
		mgr.maxSignal.Merge(newMaxSignal)
		for _, f1 := range mgr.fuzzers {
			if f1 == f {
				continue
			}
			f1.newMaxSignal.Merge(newMaxSignal)
		}
	}
	if !f.newMaxSignal.Empty() {
		r.MaxSignal = f.newMaxSignal.Serialize()
		f.newMaxSignal = nil
	}
	for i := 0; i < 100 && len(f.inputs) > 0; i++ {
		last := len(f.inputs) - 1
		r.NewInputs = append(r.NewInputs, f.inputs[last])
		f.inputs = f.inputs[:last]
	}
	if len(f.inputs) == 0 {
		f.inputs = nil
	}

	if a.NeedCandidates {
		for i := 0; i < mgr.cfg.Procs && len(mgr.rpcCands) > 0; i++ {
			last := len(mgr.rpcCands) - 1
			r.Candidates = append(r.Candidates, mgr.rpcCands[last])
			mgr.rpcCands = mgr.rpcCands[:last]
		}
	}
	if len(mgr.rpcCands) == 0 {
		mgr.rpcCands = nil
		if mgr.phase == phaseInit {
			if mgr.cfg.Hub_Client != "" {
				mgr.phase = phaseTriagedCorpus
			} else {
				mgr.phase = phaseTriagedHub
			}
		}
	}

	// ----- Race fuzzer -----
	f.raceCandQueueLen = a.RaceCandQueueLen

	for _, arg := range a.NewRaceProgCand {
		mgr.addRaceProgCand(arg, nil)
	}

	r.SuppPairsToAdd = append([]MempairHash(nil), f.suppPairsToAdd...)
	f.suppPairsToAdd = nil

	r.SuppPairsToDel = append([]MempairHash(nil), f.suppPairsToDel...)
	f.suppPairsToDel = nil

	if !mgr.corpusDBDone && len(mgr.rpcCands) == 0 {
		Logf(0, "[*] Sent all cands from corpusDB")
		mgr.corpusDBDone = true
	}

	f.lastPollTime = time.Now()
	Logf(4, "poll from %v: candidates=%v inputs=%v", a.Name, len(r.Candidates), len(r.NewInputs))
	return nil
}

func (mgr *Manager) hubSync() {
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	switch mgr.phase {
	case phaseInit:
		return
	case phaseTriagedCorpus:
		mgr.phase = phaseQueriedHub
	case phaseQueriedHub:
		if len(mgr.rpcCands) == 0 {
			mgr.phase = phaseTriagedHub
		}
	case phaseTriagedHub:
	default:
		panic("unknown phase")
	}

	mgr.minimizeCorpus()
	if mgr.hub == nil {
		a := &HubConnectArgs{
			Client:  mgr.cfg.Hub_Client,
			Key:     mgr.cfg.Hub_Key,
			Manager: mgr.cfg.Name,
			Fresh:   mgr.fresh,
			Calls:   mgr.enabledCalls,
		}
		hubCorpus := make(map[hash.Sig]bool)
		for _, inp := range mgr.corpus {
			hubCorpus[hash.Hash(inp.Prog)] = true
			a.Corpus = append(a.Corpus, inp.Prog)
		}
		mgr.mu.Unlock()
		// Hub.Connect request can be very large, so do it on a transient connection
		// (rpc connection buffers never shrink).
		// Also don't do hub rpc's under the mutex -- hub can be slow or inaccessible.
		if err := RPCCall(mgr.cfg.Hub_Addr, "Hub.Connect", a, nil); err != nil {
			mgr.mu.Lock()
			Logf(0, "Hub.Connect rpc failed: %v", err)
			return
		}
		conn, err := NewRPCClient(mgr.cfg.Hub_Addr)
		if err != nil {
			mgr.mu.Lock()
			Logf(0, "failed to connect to hub at %v: %v", mgr.cfg.Hub_Addr, err)
			return
		}
		mgr.mu.Lock()
		mgr.hub = conn
		mgr.hubCorpus = hubCorpus
		mgr.fresh = false
		Logf(0, "connected to hub at %v, corpus %v", mgr.cfg.Hub_Addr, len(mgr.corpus))
	}

	a := &HubSyncArgs{
		Client:  mgr.cfg.Hub_Client,
		Key:     mgr.cfg.Hub_Key,
		Manager: mgr.cfg.Name,
	}
	corpus := make(map[hash.Sig]bool)
	for _, inp := range mgr.corpus {
		sig := hash.Hash(inp.Prog)
		corpus[sig] = true
		if mgr.hubCorpus[sig] {
			continue
		}
		mgr.hubCorpus[sig] = true
		a.Add = append(a.Add, inp.Prog)
	}
	for sig := range mgr.hubCorpus {
		if corpus[sig] {
			continue
		}
		delete(mgr.hubCorpus, sig)
		a.Del = append(a.Del, sig.String())
	}
	for {
		a.Repros = mgr.newRepros

		mgr.mu.Unlock()

		if mgr.cfg.Reproduce && mgr.dash != nil {
			needReproReply := make(chan bool)
			mgr.needMoreRepros <- needReproReply
			a.NeedRepros = <-needReproReply
		}

		r := new(HubSyncRes)
		if err := mgr.hub.Call("Hub.Sync", a, r); err != nil {
			mgr.mu.Lock()
			Logf(0, "Hub.Sync rpc failed: %v", err)
			mgr.hub.Close()
			mgr.hub = nil
			return
		}

		reproDropped := 0
		for _, repro := range r.Repros {
			_, err := mgr.target.Deserialize(repro)
			if err != nil {
				reproDropped++
				continue
			}
			mgr.hubReproQueue <- &Crash{
				vmIndex: -1,
				hub:     true,
				Report: &report.Report{
					Title:  "external repro",
					Output: repro,
				},
			}
		}

		mgr.mu.Lock()
		mgr.newRepros = nil
		dropped := 0
		for _, inp := range r.Progs {
			_, err := mgr.target.Deserialize(inp)
			if err != nil {
				dropped++
				continue
			}
			mgr.rpcCands = append(mgr.rpcCands, RPCCandidate{
				Prog:      inp,
				Minimized: false, // don't trust programs from hub
				Smashed:   false,
			})
		}
		mgr.stats["hub add"] += uint64(len(a.Add))
		mgr.stats["hub del"] += uint64(len(a.Del))
		mgr.stats["hub drop"] += uint64(dropped)
		mgr.stats["hub new"] += uint64(len(r.Progs) - dropped)
		mgr.stats["hub sent repros"] += uint64(len(a.Repros))
		mgr.stats["hub recv repros"] += uint64(len(r.Repros) - reproDropped)
		Logf(0, "hub sync: send: add %v, del %v, repros %v; recv: progs: drop %v, new %v, repros: drop: %v, new %v; more %v",
			len(a.Add), len(a.Del), len(a.Repros), dropped, len(r.Progs)-dropped, reproDropped, len(r.Repros)-reproDropped, r.More)
		if len(r.Progs)+r.More == 0 {
			break
		}
		a.Add = nil
		a.Del = nil
	}
}

func (mgr *Manager) collectUsedFiles() {
	if mgr.vmPool == nil {
		return
	}
	addUsedFile := func(f string) {
		if f == "" {
			return
		}
		stat, err := os.Stat(f)
		if err != nil {
			Fatalf("failed to stat %v: %v", f, err)
		}
		mgr.usedFiles[f] = stat.ModTime()
	}
	cfg := mgr.cfg
	addUsedFile(cfg.SyzFuzzerBin)
	addUsedFile(cfg.SyzExecprogBin)
	addUsedFile(cfg.SyzExecutorBin)
	addUsedFile(cfg.SSHKey)
	addUsedFile(cfg.Vmlinux)
	if cfg.Image != "9p" {
		addUsedFile(cfg.Image)
	}
}

func (mgr *Manager) checkUsedFiles() {
	for f, mod := range mgr.usedFiles {
		stat, err := os.Stat(f)
		if err != nil {
			Fatalf("failed to stat %v: %v", f, err)
		}
		if mod != stat.ModTime() {
			Fatalf("file %v that syz-manager uses has been modified by an external program\n"+
				"this can lead to arbitrary syz-manager misbehavior\n"+
				"modification time has changed: %v -> %v\n"+
				"don't modify files that syz-manager uses. exiting to prevent harm",
				f, mod, stat.ModTime())
		}
	}
}

func (mgr *Manager) dashboardReporter() {
	webAddr := publicWebAddr(mgr.cfg.HTTP)
	var lastFuzzingTime time.Duration
	var lastCrashes, lastExecs uint64
	for {
		time.Sleep(time.Minute)
		mgr.mu.Lock()
		if mgr.firstConnect.IsZero() {
			mgr.mu.Unlock()
			continue
		}
		crashes := mgr.stats["crashes"]
		execs := mgr.stats["exec total"]
		req := &dashapi.ManagerStatsReq{
			Name:        mgr.cfg.Name,
			Addr:        webAddr,
			UpTime:      time.Since(mgr.firstConnect),
			Corpus:      uint64(len(mgr.corpus)),
			Cover:       uint64(mgr.corpusSignal.Len()),
			FuzzingTime: mgr.fuzzingTime - lastFuzzingTime,
			Crashes:     crashes - lastCrashes,
			Execs:       execs - lastExecs,
		}
		mgr.mu.Unlock()

		if err := mgr.dash.UploadManagerStats(req); err != nil {
			Logf(0, "faield to upload dashboard stats: %v", err)
			continue
		}
		mgr.mu.Lock()
		lastFuzzingTime += req.FuzzingTime
		lastCrashes += req.Crashes
		lastExecs += req.Execs
		mgr.mu.Unlock()
	}
}

func publicWebAddr(addr string) string {
	_, port, err := net.SplitHostPort(addr)
	if err == nil && port != "" {
		if host, err := os.Hostname(); err == nil {
			addr = net.JoinHostPort(host, port)
		}
		if GCE, err := gce.NewContext(); err == nil {
			addr = net.JoinHostPort(GCE.ExternalIP, port)
		}
	}
	return "http://" + addr
}

func (mgr *Manager) startTerminalOutput() {
	go func() {
		loopCount := 0
		for lastTime := time.Now(); ; {
			time.Sleep(10 * time.Second)
			now := time.Now()
			diff := now.Sub(lastTime)
			lastTime = now
			mgr.mu.Lock()
			if mgr.firstConnect.IsZero() {
				mgr.mu.Unlock()
				continue
			}
			mgr.fuzzingTime += diff * time.Duration(atomic.LoadUint32(&mgr.numFuzzing))

			mgr.stats["fuzzer signal"] = uint64(len(mgr.corpusSignal))
			mgr.stats["fuzzer cover"] = uint64(len(mgr.corpusCover))
			mgr.stats["sched signal"] = uint64(len(mgr.raceCorpusSignal))

			for k, v := range mgr.stats {
				if mgr.histStats[k] == nil {
					mgr.histStats[k] = new(HistStat)
					mgr.histStats[k].SetKey(k)
				}
				mgr.histStats[k].Add(v)
			}

			getStatAndAvg := func(key string) (uint64, uint64) {
				stat := mgr.stats[key]
				var avgStat uint64
				if stat > 0 {
					avgStat = mgr.histStats[key].GetAvg()
				}
				return stat, avgStat
			}

			execFuzzer, avgExecFuzzer := getStatAndAvg("fuzzer exec total")
			execSched, avgExecSched := getStatAndAvg("sched exec total")
			signalFuzz, avgSignalFuzz := getStatAndAvg("fuzzer signal")
			signalSched, avgSignalSched := getStatAndAvg("sched signal")
			syncSignal, avgSyncSignal := getStatAndAvg("sync signal")

			crashes := mgr.stats["crashes"]
			numRaceFound := len(mgr.trueRaceHashes)
			numRaceTried := len(mgr.mempairExecInfo)

			loopCount++

			if (mgr.raceCorpusDBDone || loopCount >= 180) && doSupp(suppFreq) {
				if loopCount%6 == 1 {
					mgr.updateSuppPairs(0.75)
					if len(mgr.raceQueue) > LIMIT_RACE_QUEUE_LEN {
						// TODO: Depending on the race queue pressure, we may
						// adjust the limit rate parameter
						mgr.softCleanupRaceQueue()
						if len(mgr.raceQueue) > LIMIT_RACE_QUEUE_LEN*10 {
							mgr.hardCleanupRaceQueue()
						}
					}
				}
			}

			Logf(0, "#%v Fuzzer: exe %v (%v), sig %v (%v), syncSig %v (%v)| Sched: exe %v (%v), sig %v (%v)| Race: %v| Crash: %v",
				loopCount, execFuzzer, avgExecFuzzer, signalFuzz, avgSignalFuzz, syncSignal, avgSyncSignal,
				execSched, avgExecSched, signalSched, avgSignalSched,
				numRaceFound, crashes)

			schedRaceQueueLen := uint64(0)
			for _, s := range mgr.schedulers {
				schedRaceQueueLen += s.raceCandQueueLen
			}

			fuzzerRaceQueueLen := uint64(0)
			for _, f := range mgr.fuzzers {
				fuzzerRaceQueueLen += f.raceCandQueueLen
			}

			Logf(0, "\t fuzzer rq %v, manager rq: %v, sched rq: %v, supp: %v/%v",
				fuzzerRaceQueueLen, len(mgr.raceQueue), schedRaceQueueLen, len(mgr.suppressedPairs), numRaceTried)

			mgr.mu.Unlock()

			if *flagDisableWarn != true {
				mgr.mu.Lock()
				for name, f := range mgr.fuzzers {
					diff := now.Sub(f.lastPollTime)
					diffSecs := diff.Seconds()

					if diffSecs >= 60 {
						Logf(0, "\t [WARN] (fuzzer) %v is not responding (last poll was %.1f secs before)",
							name, diffSecs)
					}
				}
				for name, f := range mgr.schedulers {
					diff := now.Sub(f.lastPollTime)
					diffSecs := diff.Seconds()

					if diffSecs >= 60 {
						Logf(0, "\t [WARN] (sched) %v is not responding (last poll was %.1f secs before)",
							name, diffSecs)
					}
				}
				mgr.mu.Unlock()
			}
		}
	}()
}

func (mgr *Manager) addRaceProgCand(a *NewRaceProgCandArgs, r *int) {
	// RYONG: RPC function that called when syz-fuzzer find a prog executing a race candidate

	candidate := RaceProgCand{Prog: a.Prog, FromDB: false}
	for _, raceinfo := range a.RaceProgCand.RaceInfos {
		if mgr.raceCorpusDBDone {
			if doSupp(suppFreq) && mgr.isSuppressedPairByFreq(raceinfo.Hash) {
				continue
			}
		}

		// TODO: Fill in RacInfos Loc1, Loc2 & Addr1, Addr2
		Addrs0 := mgr.getAddr(raceinfo.Mempair[0], raceinfo.Cov[0])
		Addrs1 := mgr.getAddr(raceinfo.Mempair[1], raceinfo.Cov[1])

		for _, addr0 := range Addrs0 {
			for _, addr1 := range Addrs1 {
				if addr0.Tag == "R" && addr1.Tag == "R" {
					continue
				}
				ri := RaceInfo{
					Cov:     raceinfo.Cov,
					Addr:    [...]uint32{addr0.Item, addr1.Item},
					Idx:     raceinfo.Idx,
					Hash:    raceinfo.Hash,
					Mempair: raceinfo.Mempair,
				}
				candidate.RaceInfos = append(candidate.RaceInfos, ri)
			}
		}
	}

	mgr.stats["manager rc all"] += uint64(len(candidate.RaceInfos))
	if len(candidate.RaceInfos) != 0 {
		mgr.pushToRaceQueue(candidate)
	} else {
		mgr.stats["manager rc suppressed"]++
	}
}

func (mgr *Manager) pushToRaceQueue(cand RaceProgCand) {
	mgr.stats["manager rc push"]++
	mgr.raceQueue = append(mgr.raceQueue, cand)
}

const (
	SUPP_MIN_EXEC_COUNT  = 100
	LIMIT_RACE_QUEUE_LEN = 100000 // 0.1 M
	SUPP_THRESHOLD       = 500
)

func (mgr *Manager) updateSuppPairs(suppMempairRate float32) error {
	// if *flagRootCause {
	// 	// No suppression during the rootcause analysis
	// 	return nil
	// }

	// get the sorted rank on race execution count
	_, data := getSortedExecCandCount(mgr)

	// numToSupp := int(float32(len(data)) * suppMempairRate)

	// DR: Simpler and more aggressive algorithm
	//     If certain mempair is tested more than SUPP_THRESHOLD,
	//     just ignored the mempair at all
	newSuppPairs := map[MempairHash]bool{}
	for _, d := range data {
		/*
			if d.Count < SUPP_MIN_EXEC_COUNT {
				// If it's executed not many times, we don't suppress it.
				// Break out the loop here as we are searching through the
				// list ordered by the count.
				break
			}
			newSuppPairs[d.Hash] = true
			if len(newSuppPairs) >= numToSupp {
				break
			}
		*/
		if d.Count > SUPP_THRESHOLD {
			newSuppPairs[d.Hash] = true
		}
	}

	// Fallback: Changed scheme will suppress a lot of mempairs
	//           If too many mempairs are suppressed, randomly picking them and allowing them
	excess := len(newSuppPairs) - int(float32(len(data))*suppMempairRate)
	for i := 0; i < excess && len(newSuppPairs) > 0; i++ {
		idx := rand.Intn(len(newSuppPairs))
		var k MempairHash
		for k = range newSuppPairs {
			if idx == 0 {
				break
			}
			idx--
		}
		delete(newSuppPairs, k)
	}

	for hsh, _ := range mgr.suppressedPairs {
		if _, ok := newSuppPairs[hsh]; !ok {
			// drop
			delete(mgr.suppressedPairs, hsh)
			for _, f := range mgr.fuzzers {
				f.suppPairsToDel = append(f.suppPairsToDel, hsh)
			}
			for _, s := range mgr.schedulers {
				s.suppPairsToDel = append(s.suppPairsToDel, hsh)
			}
		}
	}

	for hsh, _ := range newSuppPairs {
		if _, ok := mgr.suppressedPairs[hsh]; !ok {
			// add
			mgr.suppressedPairs[hsh] = struct{}{}
			for _, f := range mgr.fuzzers {
				f.suppPairsToAdd = append(f.suppPairsToAdd, hsh)
			}
			for _, s := range mgr.schedulers {
				s.suppPairsToAdd = append(s.suppPairsToAdd, hsh)
			}
		}
	}
	return nil
}

func (mgr *Manager) isSuppressedPairByFreq(hsh MempairHash) bool {
	if _, ok := mgr.suppressedPairs[hsh]; ok {
		return true
	}
	return false
}

func (mgr *Manager) hardCleanupRaceQueue() {
	// Drop 50%
	numToDrop := int(float32(len(mgr.raceQueue)) * 0.5)
	mgr.raceQueue = append([]RaceProgCand{}, mgr.raceQueue[numToDrop:]...)

	mgr.stats["manager rc cleanup hard"]++
	mgr.stats["manager rc drop"] += uint64(numToDrop)

	Logf(0, "\t hardCleanupRaceQueue() dropped %v candidates", numToDrop)
}

func (mgr *Manager) softCleanupRaceQueue() {
	// Pre-allocate updatedRaceCands as its possible max length to
	// avoid annoying slice re-allocation.
	updatedRaceCands := make([]RaceProgCand, 0, len(mgr.raceQueue)*2)
	// Cleanup based on suppress info
	for _, rc := range mgr.raceQueue {
		if !mgr.isSuppressedRaceCand(rc) {
			updatedRaceCands = append(updatedRaceCands, rc)
			mgr.stats["manager rc drop surv"]++
		} else {
			mgr.stats["manager rc drop"]++
		}
	}
	// Replace the race cand queue
	mgr.raceQueue = updatedRaceCands

	mgr.stats["manager rc cleanup soft"]++
}

func (mgr *Manager) isSuppressedRaceCand(rc RaceProgCand) bool {
	for _, raceinfo := range rc.RaceInfos {
		if !mgr.isSuppressedPairByFreq(raceinfo.Hash) {
			// If any of raceinfo is not in the suppressed pair, we
			// won't suppress this race candidate
			return false
		}
	}
	return true
}

var popTurn int

func PopFromRaceQueue(mgr *Manager, numToPop int) []RaceProgCand {
	// TODO: Suppression while popping.
	if numToPop >= len(mgr.raceQueue) {
		numToPop = len(mgr.raceQueue)
	}
	if numToPop == 0 {
		return []RaceProgCand{}
	}

	if *flagRootCause || mgr.raceCorpusDBDone {
		// We don't need to worry about slicing performance here
		// during the rootcause analysis.
		popTurn = (popTurn + 1) % 3
	} else {
		// Always FIFO.

		// TODO: We should implement queue management algorithm back
		// to the manager as much as possible. Scheduler may get
		// crashed, which will lose all the information at once.
		popTurn = 0
	}

	idx := 0
	if popTurn == 0 {
		// FIFO
	} else if popTurn == 1 {
		// LIFO
		idx = len(mgr.raceQueue) - numToPop
	} else {
		// Random
		idx = len(mgr.raceQueue) - numToPop
		if idx != 0 {
			idx = rand.Intn(idx)
		}
	}

	popedCandidates := make([]RaceProgCand, numToPop)
	copy(popedCandidates, mgr.raceQueue[idx:idx+numToPop])
	mgr.raceQueue = append(mgr.raceQueue[:idx], mgr.raceQueue[idx+numToPop:]...)

	// TODO: this only works popTurn is FIFO
	if !mgr.raceCorpusDBDone && (len(mgr.raceQueue) == 0 || !mgr.raceQueue[0].FromDB) {
		Logf(0, "[*] Sent all raceprog cands from raceCorpusDB")
		mgr.raceCorpusDBDone = true
		mgr.minimizeRaceCorpus()
	}

	mgr.stats["manager rc pop"] += uint64(numToPop)
	return popedCandidates
}

func (mgr *Manager) foundNewTrueRace(hsh MempairHash) bool {
	_, ok := mgr.trueRaceHashes[hsh]
	return !ok
}

func (mgr *Manager) updateNewTrueRace(finfo FoundRaceInfo) {
	// Newly found true race.

	hsh := finfo.MempairHash

	execInfo := mgr.mempairExecInfo[hsh]
	execInfo.TriageTrueFound = execInfo.TriageExecs
	execInfo.CorpusTrueFound = execInfo.CorpusExecs
	execInfo.LikelyTrueFound = execInfo.LikelyExecs
	execInfo.FirstFoundBy = finfo.RaceRunKind
	mgr.mempairExecInfo[hsh] = execInfo

	mempairStr, _ := mgr.mempairHashToStr[hsh]
	Logf(0, "\t Race detected: (%s) (triage %v, corpus %v, likely %v)",
		mempairStr, execInfo.TriageTrueFound,
		execInfo.CorpusTrueFound, execInfo.LikelyTrueFound)

	mgr.trueRaceHashes[hsh] = struct{}{}

	if _, ok := mgr.likelyRaceCorpus[hsh]; ok {
		// No need to hold likely input anymore
		delete(mgr.likelyRaceCorpus, hsh)
	}

}

func (mgr *Manager) SchedulerPoll(a *SchedulerPollArgs, r *SchedulerPollRes) error {
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	s := mgr.schedulers[a.Name]
	if s == nil {
		Fatalf("scheduler %v is not connected", a.Name)
	}

	for hsh, schedExecInfo := range a.MempairExecInfo {
		mgrExecInfo := mgr.mempairExecInfo[hsh]
		mgrExecInfo.TriageExecs += schedExecInfo.TriageExecs
		mgrExecInfo.TriageTrues += schedExecInfo.TriageTrues
		mgrExecInfo.CorpusExecs += schedExecInfo.CorpusExecs
		mgrExecInfo.CorpusTrues += schedExecInfo.CorpusTrues
		mgrExecInfo.LikelyExecs += schedExecInfo.LikelyExecs
		mgrExecInfo.LikelyTrues += schedExecInfo.LikelyTrues
		mgrExecInfo.TriageFailed += schedExecInfo.TriageFailed

		mgr.mempairExecInfo[hsh] = mgrExecInfo
	}

	s.raceCandQueueLen = a.RaceCandQueueLen

	var newFoundRaceHashes []MempairHash
	for _, foundRaceInfo := range a.FoundRaceInfos {
		hsh := foundRaceInfo.MempairHash
		if mgr.foundNewTrueRace(hsh) {
			mgr.updateNewTrueRace(foundRaceInfo)
			newFoundRaceHashes = append(newFoundRaceHashes)
		}
	}

	for _, s1 := range mgr.schedulers {
		if s != s1 {
			s1.trueRaceHashes = append(s1.trueRaceHashes, newFoundRaceHashes...)
		}
	}

	r.TrueRaceHashes = append(r.TrueRaceHashes, s.trueRaceHashes...)
	s.trueRaceHashes = nil

	for k, v := range a.Stats {
		if strings.Contains(k, "memory consumption") {
			mgr.stats[k] = v / 1024 /*KB*/ / 1024 /*MB*/
		} else {
			mgr.stats[k] += v
		}
	}

	newMaxSignal := mgr.maxRaceSignal.Diff(a.MaxSignal.Deserialize())
	if !newMaxSignal.Empty() {
		mgr.maxRaceSignal.Merge(newMaxSignal)
		for _, s1 := range mgr.schedulers {
			if s1 == s {
				continue
			}
			s1.newMaxSignal.Merge(newMaxSignal)
		}
	}
	if !s.newMaxSignal.Empty() {
		r.MaxSignal = s.newMaxSignal.Serialize()
		s.newMaxSignal = nil
	}

	for i := 0; i < 100 && len(s.raceInputs) > 0; i++ {
		last := len(s.raceInputs) - 1
		r.NewRaceInputs = append(r.NewRaceInputs, s.raceInputs[last])
		s.raceInputs = s.raceInputs[:last]
	}
	if len(s.raceInputs) == 0 {
		s.raceInputs = nil
	}

	for i := 0; i < 100 && len(s.likelyRaceInputs) > 0; i++ {
		last := len(s.likelyRaceInputs) - 1
		r.NewLikelyRaceInputs = append(r.NewLikelyRaceInputs, s.likelyRaceInputs[last])
		s.likelyRaceInputs = s.likelyRaceInputs[:last]
	}
	if len(s.likelyRaceInputs) == 0 {
		s.likelyRaceInputs = nil
	}

	// TODO: adjust numToPop
	var numToPop int
	const maxRaceQueueThold = 1000
	if s.raceCandQueueLen < maxRaceQueueThold {
		// Wait until progs in race queue being handled enough
		if mgr.raceCorpusDBDone {
			// After sending all raceprog cand from DB, pop many progs
			numToPop = 10
		} else {
			numToPop = mgr.cfg.Procs
		}
		r.RaceProgs = PopFromRaceQueue(mgr, numToPop)
	}

	for i := 0; i < 100 && len(s.inputs) > 0; i++ {
		last := len(s.inputs) - 1
		r.NewInputs = append(r.NewInputs, s.inputs[last])
		s.inputs = s.inputs[:last]
	}

	summary := a.TimeSummary
	if summary != "" {
		Logf(0, "  %v", summary)
	}

	// option 1
	r.SuppPairsToAdd = append([]MempairHash(nil), s.suppPairsToAdd...)
	s.suppPairsToAdd = nil

	r.SuppPairsToDel = append([]MempairHash(nil), s.suppPairsToDel...)
	s.suppPairsToDel = nil

	r.RaceCorpusDBDone = mgr.raceCorpusDBDone

	mgr.stats["sched poll"] += 1
	s.lastPollTime = time.Now()
	return nil
}

func (mgr *Manager) NewRaceInput(a *NewRaceInputArgs, r *int) error {
	inputSignal := a.Signal.Deserialize()
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	s := mgr.schedulers[a.Name]
	if s == nil {
		Fatalf("scheduler %v is not connected", a.Name)
	}

	if mgr.raceCorpusSignal.Diff(inputSignal).Empty() {
		return nil
	}

	mgr.stats["manager new race inputs"]++
	mgr.raceCorpusSignal.Merge(inputSignal)
	sig := computeSig(a.RPCRaceInput.RaceProg, a.RaceInfo.ToBytes())
	if inp, ok := mgr.raceCorpus[sig]; ok {
		// The input is already present, but possibly with diffent signal/coverage/call.
		inputSignal.Merge(inp.Signal.Deserialize())
		inp.Signal = inputSignal.Serialize()
		var inputCover cover.Cover
		inputCover.Merge(inp.Cover)
		inputCover.Merge(a.RPCRaceInput.Cover)
		inp.Cover = inputCover.Serialize()
		mgr.raceCorpus[sig] = inp
	} else {
		mgr.raceCorpus[sig] = a.RPCRaceInput
		mgr.saveToDB(a.RPCRaceInput)

		for _, s1 := range mgr.schedulers {
			if s1 == s {
				continue
			}
			rinp := a.RPCRaceInput
			rinp.Cover = nil
			s1.raceInputs = append(s1.raceInputs, rinp)
		}
		hsh := a.RPCRaceInput.RaceInfo.Hash
		mgr.mempairToRaceCorpus[hsh] = append(mgr.mempairToRaceCorpus[hsh], sig)
	}
	return nil
}

func (mgr *Manager) NewLikelyRaceInput(a *NewLikelyRaceInputArgs, r *int) error {
	mgr.mu.Lock()
	defer mgr.mu.Unlock()

	s := mgr.schedulers[a.Name]
	if s == nil {
		Fatalf("scheduler %v is not connected", a.Name)
	}

	hsh := a.RPCLikelyRaceInput.RaceInfo.Hash

	if _, ok := mgr.trueRaceHashes[hsh]; ok {
		// Already identified as true hash, so we don't store this.
		return nil
	}

	shouldUpdate := false
	shouldReplaceDB := false
	if _, ok := mgr.likelyRaceCorpus[hsh]; ok {
		// The input is already present.
		// TODO: better to determine whether this should be updated.
		if rand.Intn(2) == 0 {
			shouldUpdate = true
			shouldReplaceDB = true
		}
	} else {
		mgr.stats["manager num likelyRaceCorpus"]++
		shouldUpdate = true
	}

	if shouldUpdate {
		// Save likely race corpus into DB
		if shouldReplaceDB {
			mgr.removeFromDB(mgr.likelyRaceCorpus[hsh])
		}
		mgr.saveToDB(a.RPCLikelyRaceInput)
		mgr.likelyRaceCorpus[hsh] = a.RPCLikelyRaceInput

		for _, s1 := range mgr.schedulers {
			if s1 == s {
				continue
			}
			s1.likelyRaceInputs = append(s1.likelyRaceInputs, a.RPCLikelyRaceInput)
		}
	}
	return nil
}

func (mgr *Manager) minimizeRaceCorpus() {
	// TODO: just copy&paste-ed. need refactoring.
	if !*flagMinimizeCorpus {
		return
	}
	if mgr.cfg.Cover && len(mgr.raceCorpus) != 0 {
		inputs := make([]signal.Context, 0, len(mgr.corpus))
		for _, inp := range mgr.raceCorpus {
			inputs = append(inputs, signal.Context{
				Signal:  inp.Signal.Deserialize(),
				Context: inp,
			})
		}
		newCorpus := make(map[string]RPCRaceInput)
		for _, ctx := range signal.Minimize(inputs) {
			inp := ctx.(RPCRaceInput)
			newCorpus[computeSig(inp.RaceProg, inp.RaceInfo.ToBytes())] = inp
		}
		Logf(1, "minimized race corpus: %v -> %v", len(mgr.raceCorpus), len(newCorpus))
		mgr.raceCorpus = newCorpus
	}

	// likely corpus
	if len(mgr.likelyRaceCorpus) != 0 {
		newCorpus := make(map[MempairHash]RPCLikelyRaceInput)
		for k, v := range mgr.likelyRaceCorpus {
			if _, ok := mgr.trueRaceHashes[k]; ok {
				continue
			}
			if _, ok := newCorpus[k]; !ok || rand.Intn(2) == 0 {
				newCorpus[k] = v
			}
		}
		Logf(1, "minimized likley race corpus: %v -> %v", len(mgr.likelyRaceCorpus), len(newCorpus))
		mgr.likelyRaceCorpus = newCorpus
	}

	if mgr.raceCorpusDBDone && time.Until(mgr.startTime) > 30*time.Minute {
		// I don't want to lose any meaningful program. It is possible that
		// raceCorpusDBDone is true but some programs are still being triaged.
		// So flush minimized raceCorpus at least 30 minutes later.
		mgr.clearDB(RACECORPUSDB, mgr.raceCorpus)
		mgr.clearDB(LIKELYCORPUSDB, mgr.likelyRaceCorpus)
	}
}

