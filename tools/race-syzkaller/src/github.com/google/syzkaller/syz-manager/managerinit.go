package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"time"

	"github.com/google/syzkaller/dashboard/dashapi"
	. "github.com/google/syzkaller/pkg/common"
	. "github.com/google/syzkaller/pkg/log"
	"github.com/google/syzkaller/pkg/osutil"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/prog"
	"github.com/google/syzkaller/syz-manager/mgrconfig"
	"github.com/google/syzkaller/vm"
	"bufio"
	"strconv"
)

var (
	flagBench = flag.String("bench", "", "write execution statistics into this file periodically")
)

func managerInit(cfg *mgrconfig.Config, syscalls map[int]bool, target *prog.Target) *Manager {

	Logf(0, "Suppress  option: %v", *flagSuppOption)
	Logf(0, "RootCause  option: %v", *flagRootCause)

	createVMPool := func(debug, sched bool) *vm.Pool {
		if cfg.Type != "none" {
			env := mgrconfig.CreateVMEnv(cfg, debug, sched)
			pool, err := vm.Create(cfg.Type, env)
			if err != nil {
				Fatalf("%v", err)
			}
			return pool
		}
		return nil
	}

	vmPool := createVMPool(*flagFuzzerDebug, false)
	racePool := createVMPool(*flagRaceDebug, true)

	crashdir := filepath.Join(cfg.Workdir, "crashes")
	osutil.MkdirAll(crashdir)

	var enabledSyscalls []int
	for c := range syscalls {
		enabledSyscalls = append(enabledSyscalls, c)
	}

	/*
		mgr := &Manager{
			cfg:                 cfg,
			cfgFilename:         *flagConfig,
			flagGuide:           *flagGuide,
			vmPool:              vmPool,
			racePool:            racePool,
			crashdir:            crashdir,
			startTime:           time.Now(),
			firstStart:          true,
			managerDB:           &ManagerDB{},
			stats:               make(map[string]uint64),
			histStats:           make(map[string]*HistStat),
			crashTypes:          make(map[string]bool),
			enabledSyscalls:     enabledSyscalls,
			corpus:              make(map[string]RpcInput),
			raceCorpus:          make(map[string]RpcRaceInput),
			disabledHashes:      make(map[string]struct{}),
			corpusSignal:        make(map[uint32]struct{}),
			maxSignal:           make(map[uint32]struct{}),
			corpusCover:         make(map[uint32]struct{}),
			maxSyncSignal:       make(map[uint64]struct{}),
			rcSyncSignal:        make(map[uint64]struct{}),
			mempairToRaceCorpus: make(map[MempairHash][]string),
			fuzzers:             make(map[string]*Fuzzer),
			schedulers:          make(map[string]*Scheduler),
			fresh:               true,
			vmStop:              make(chan bool),
			vmRaceStop:          make(chan bool),
			srcBBtoPC:           make(map[string][]ItemTy),
			locToBB:             make(map[LocTy][]uint32),
			likelyRaceCorpus:    make(map[MempairHash]LikelyRaceInput),
			mempairHash:         make(map[MempairHash]struct{}),
			mempairHashToStr:    make(map[MempairHash]string),
			raceCorpusSignal:    make(map[uint32]struct{}),
			raceMaxSignal:       make(map[uint32]struct{}),
			trueRaceHashes:      make(map[MempairHash]struct{}),
			sparseRaceCandPairs: make(map[uint32][]EntryTy),
			suppressedPairs:     make(map[MempairHash]struct{}),
			mempairExecInfo:     make(map[MempairHash]RaceExecInfo),
			covLenCount:         make(map[int]uint64),
			multiCovCount:       make(map[int]uint64),
		}
	*/
	mgr := &Manager{
		cfg:             cfg,
		vmPool:          vmPool,
		target:          target,
		crashdir:        crashdir,
		startTime:       time.Now(),
		stats:           make(map[string]uint64),
		crashTypes:      make(map[string]bool),
		enabledSyscalls: enabledSyscalls,
		corpus:          make(map[string]RPCInput),
		disabledHashes:  make(map[string]struct{}),
		fuzzers:         make(map[string]*Fuzzer),
		fresh:           true,
		vmStop:          make(chan bool),
		hubReproQueue:   make(chan *Crash, 10),
		needMoreRepros:  make(chan chan bool),
		reproRequest:    make(chan chan map[string]bool),
		usedFiles:       make(map[string]time.Time),

		// Race fuzzer
		raceCorpus:          make(map[string]RPCRaceInput),
		schedulers:          make(map[string]*Scheduler),
		racePool:            racePool,
		histStats:           make(map[string]*HistStat),
		managerDB:           &ManagerDB{},
		mempairHash:         make(map[MempairHash]struct{}),
		mempairHashToStr:    make(map[MempairHash]string),
		mempairToRaceCorpus: make(map[MempairHash][]string),
		suppressedPairs:     make(map[MempairHash]struct{}),
		locToBB:             make(map[LocTy][]uint32),
		sparseRaceCandPairs: make(map[uint32][]EntryTy),
		srcBBtoPC:           make(map[string][]ItemTy),
		firstStart:          true,
		vmRaceStop:          make(chan bool),
		trueRaceHashes:      make(map[MempairHash]struct{}),
		mempairExecInfo:     make(map[MempairHash]RaceExecInfo),
		likelyRaceCorpus:    make(map[MempairHash]RPCLikelyRaceInput),

		flagRootcause: *flagRootCause,
	}

	mgr.initStaticAnalysisResult()
	mgr.initDBs(syscalls)
	mgr.initHTTP()
	mgr.initRPC()
	mgr.initDashBoard()
	mgr.collectUsedFiles()

	mgr.startLoggingSuppressedMempair()
	mgr.startTerminalOutput()
	mgr.startBench()
	mgr.startHubSync()

	osutil.HandleInterrupts(vm.Shutdown)

	return mgr
}

func (mgr *Manager) initStaticAnalysisResult() {
	mgr.loadStaticAnalysisResult()
	mgr.initMempair()
	mgr.initMapping()
	mgr.initSparseRaceCandPairs()
}

func (mgr *Manager) startHubSync() {
	if mgr.cfg.Hub_Client != "" {
		go func() {
			for {
				time.Sleep(time.Minute)
				mgr.hubSync()
			}
		}()
	}

}

func (mgr *Manager) startBench() {
	if *flagBench != "" {
		benchDir := *flagBench
		if benchDir == "0" {
			benchDir = "bench"
		}
		benchDir = filepath.Join(mgr.cfg.Workdir, benchDir)
		osutil.MkdirAll(benchDir)

		go func() {
			count := 0
			for {
				mgr.mu.Lock()
				if mgr.firstConnect.IsZero() {
					mgr.mu.Unlock()
					continue
				}

				vals := make(map[string]uint64)
				f, err := os.OpenFile(filepath.Join(benchDir, fmt.Sprintf("bench-%s", time.Now().Format("0102-1504"))), os.O_WRONLY|os.O_CREATE|os.O_EXCL, osutil.DefaultFilePerm)
				if err != nil {
					Fatalf("failed to open bench file: %v", err)
				}

				// TODO: do we need to minimize Corpus here?
				mgr.minimizeCorpus()
				mgr.minimizeRaceCorpus()
				vals["uptime"] = uint64(time.Since(mgr.firstConnect)) / 1e9
				vals["fuzzing"] = uint64(mgr.fuzzingTime) / 1e9
				vals["corpus"] = uint64(len(mgr.corpus))
				vals["race corpus"] = uint64(len(mgr.raceCorpus))
				vals["likely corpus"] = uint64(len(mgr.likelyRaceCorpus))
				vals["corpusDB done"] = 0
				if mgr.corpusDBDone {
					vals["corpusDB done"] = 1
				}
				vals["raceCorpusDB done"] = 0
				if mgr.raceCorpusDBDone {
					vals["raceCorpusDB done"] = 1
				}
				vals["triage queue"] = uint64(len(mgr.rpcCands))
				vals["race queue"] = uint64(len(mgr.raceQueue))
				vals["cover"] = uint64(len(mgr.corpusCover))
				vals["signal"] = uint64(len(mgr.corpusSignal))
				//vals["sync signal"] = uint64(len(mgr.maxSyncSignal))

				for k, v := range mgr.stats {
					vals[k] = v
				}
				mgr.mu.Unlock()

				data, err := json.MarshalIndent(vals, "", "  ")
				if err != nil {
					Fatalf("failed to serialize bench data")
				}
				if _, err := f.Write(append(data, '\n')); err != nil {
					Fatalf("failed to write bench data")
				}
				count++
				f.Close()
				time.Sleep(time.Minute * 5)
			}
		}()
	}
}

func (mgr *Manager) initDashBoard() {
	if mgr.cfg.Dashboard_Addr != "" {
		mgr.dash = dashapi.New(mgr.cfg.Dashboard_Client, mgr.cfg.Dashboard_Addr, mgr.cfg.Dashboard_Key)
		if mgr.dash != nil {
			go mgr.dashboardReporter()
		}
	}
}

func (mgr *Manager) initRPC() {
	// Create RPC server for fuzzers.
	s, err := NewRPCServer(mgr.cfg.RPC, mgr)
	if err != nil {
		Fatalf("failed to create rpc server: %v", err)
	}
	Logf(0, "serving rpc on tcp://%v", s.Addr())
	mgr.port = s.Addr().(*net.TCPAddr).Port
	go s.Serve()

}

func (mgr *Manager) loadStaticAnalysisResult() {
	Logf(0, "Loading race candidate pairs...")
	// Race candidates
	mempair, mapping, err := initRaceCandPairs(mgr.cfg)
	if err != nil {
		Fatalf("%v", err)
	}
	
	mgr.mempair = mempair
	mgr.mapping = mapping
	mgr.removeSuppMempair()

	mgr.stats["Mempair"] = uint64(len(mgr.mempair))
	mgr.stats["Mapping"] = uint64(len(mgr.mapping))
	Logf(0, "Total # of mempair: %d", len(mgr.mempair))
	Logf(0, "Total # of mapping: %d", len(mgr.mapping))
}

func (mgr *Manager) initMempair() {
	for _, pair := range mgr.mempair {
		hsh := GetMempairHashFromLocs(pair.Locs)
		mgr.mempairHash[hsh] = struct{}{}
		mgr.mempairHashToStr[hsh] = SortedConcate(pair.Locs)
	}

	for _, mempair := range mgr.mempair {
		Logf(2, "Locs: %+v, Tags: %+v", mempair.Locs, mempair.Tags)
	}
}

func (mgr *Manager) initMapping() {
	Logf(0, "Initializing cover per mapping...")
	for _, mapping_ := range mgr.mapping {
		locToBB, srcBBtoPC, err := getCoverPerMapping(mapping_.Loc, mapping_.Tag, mapping_.Item)
		if err != nil {
			Fatalf("%v", err)
		}
		for k, v := range srcBBtoPC {
			mgr.srcBBtoPC[k] = append(mgr.srcBBtoPC[k], v...)
		}
		for k, v := range locToBB {
			mgr.locToBB[k] = append(mgr.locToBB[k], v...)
		}
	}

	for k, v := range mgr.locToBB {
		Logf(2, "%+v", k)
		for _, i := range v {
			Logf(2, "\t%d", i)
		}
	}

	for _, mapping := range mgr.mapping {
		Logf(2, "%+v", mapping)
	}
}

func (mgr *Manager) initSparseRaceCandPairs() {
	Logf(0, "Building Sparse race candidates...")
	getLocTy := func(sourceLoc, tag string) LocTy {
		return LocTy{SourceLoc: sourceLoc, Tag: tag}
	}
	count := 0
	for _, mempair := range mgr.mempair {
		if len(mempair.Locs) != 2 {
			panic("Broken static analysis result")
		}
		Logf(2, "Mempair: %+v", mempair)
		for i := 0; i < 2; i++ {
			for _, bb := range mgr.locToBB[getLocTy(mempair.Locs[i], mempair.Tags[i])] {
				for _, bb2 := range mgr.locToBB[getLocTy(mempair.Locs[1-i], mempair.Tags[1-i])] {
					Logf(2, "\tCover0: %x\tCover1: %x", bb, bb2)
					mgr.sparseRaceCandPairs[bb] = append(mgr.sparseRaceCandPairs[bb],
						EntryTy{
							Cover:   bb2,
							Hash:    GetMempairHashFromLocs(mempair.Locs),
							Mempair: []string{mempair.Locs[i], mempair.Locs[1-i]},
						})
					count++
				}
			}
			if mempair.Locs[0] == mempair.Locs[1] && mempair.Tags[0] == mempair.Tags[1] {
				break
			}
		}
	}

	Logf(0, "Total # of sparseRaceCandPairs: %v (%v)", len(mgr.sparseRaceCandPairs), count)

	Logf(2, "Sparse race candidates:")
	for cov, ents := range mgr.sparseRaceCandPairs {
		Logf(2, "%x", cov)
		for _, ent := range ents {
			Logf(2, "\t%v: %x", ent.Mempair, ent.Cover)
		}
	}
}

func (mgr *Manager) initDBs(syscalls map[int]bool) {
	db_prefix := ""

	if *flagRootCause {
		Logf(0, "preparing rootcause db...")
		db_prefix += "rootcause-"
		logdir := filepath.Join(mgr.cfg.Workdir, "rootcause")
		entries := collectRootCauseLogs(logdir)
		Logf(0, "loaded %v rootcause programs to be analyzed", len(entries))

		dbfn := filepath.Join(mgr.cfg.Workdir, db_prefix+"corpus.db")
		setupRootcauseDB(dbfn, entries)
	}

	// corpus
	mgr.corpusDBDone = mgr.loadDB(CORPUSDB, "corpus.db", "", syscalls, db_prefix, mgr.__pushToRPCCand)

	var raceCorpusEmpty, likelyCorpusEmpty bool
	// race corpus
	raceCorpusEmpty = mgr.loadDB(RACECORPUSDB, "raceCorpus.db", "raceInfo.db", syscalls, db_prefix, mgr.__pushToRaceQueue)

	// likely corpus
	likelyCorpusEmpty = mgr.loadDB(LIKELYCORPUSDB, "likelyCorpus.db", "likelyRaceInfo.db", syscalls, db_prefix, mgr.__pushToRaceQueue)
	mgr.raceCorpusDBDone = raceCorpusEmpty && likelyCorpusEmpty
}

func (mgr *Manager) getSuppMempairFileName() string {
	return filepath.Join(mgr.cfg.Workdir, "suppMempair")
}

func (mgr *Manager) removeSuppMempair() {
	suppMempair := mgr.loadSuppMempair()
	Logf(0, "Loading suppressed mempair: %d", len(suppMempair))

	newMempair := []Mempair{}
	cnt := 0
	for _, mempair := range mgr.mempair {
		hsh := GetMempairHashFromLocs(mempair.Locs)
		if _, ok := suppMempair[hsh]; !ok {
			newMempair = append(newMempair, mempair)
		} else {
			cnt++
		}
	}

	Logf(0, "Removed supp-ed mempair: %d", cnt)
	Logf(0, "Remaining mempair: %d", len(newMempair))
	mgr.mempair = newMempair
}

func (mgr *Manager) loadSuppMempair() map[MempairHash]struct{} {
	suppMempairFile := mgr.getSuppMempairFileName()

	f, err := os.OpenFile(suppMempairFile, os.O_RDONLY, osutil.DefaultFilePerm)
    if err == nil {
		defer f.Close()
	}

	suppMempair := make(map[MempairHash]struct{})
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		i, err := strconv.ParseUint(line, 10, 64)
		if err != nil {
			panic(err)
		}
		suppMempair[MempairHash(i)] = struct{}{}
	}
	return suppMempair
}

func (mgr *Manager) startLoggingSuppressedMempair() {

	suppMempairFile := mgr.getSuppMempairFileName()
	go func() {
		for ; ; {
			// For every 1 minute, logging suppressed mempair in workdir/suppMempair
			time.Sleep(time.Minute)

			f, err := os.OpenFile(suppMempairFile, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, osutil.DefaultFilePerm)
			if err != nil {
				fmt.Errorf(err.Error())
				continue
			}

			mgr.mu.Lock()
			for hsh := range mgr.mempairHash {
				if mgr.isSuppressedPairByFreq(hsh) != false {
					continue
				}
				_, err := f.WriteString(fmt.Sprintf("%d\n", uint64(hsh)))
				if err != nil {
					fmt.Errorf(err.Error())
					break
				}
			}
			mgr.mu.Unlock()
			f.Close()
		}
	}()
}
