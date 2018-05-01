package main

import (
	"io/ioutil"
	"os"
	"path/filepath"

	"github.com/google/syzkaller/pkg/db"
	"github.com/google/syzkaller/pkg/hash"
	. "github.com/google/syzkaller/pkg/log"
	"github.com/google/syzkaller/prog"
)

func readRootCauseLog(fn string) []byte {
	logf, err := os.Open(fn)
	if err != nil {
		return nil
	}
	defer logf.Close()
	logbyte, err := ioutil.ReadAll(logf)
	if err != nil || len(logbyte) == 0 {
		return nil
	}
	return logbyte
}

func collectRootCauseLogs(logdir string) []*prog.LogEntry {
	dirs, err := readdirnames(logdir)
	if err != nil {
		panic("failed to read rootcause log directory")
	}

	entries := []*prog.LogEntry{}
	for _, dir := range dirs {
		logfn := filepath.Join(logdir, dir)
		Logf(0, "Loading crash log: %v", logfn)
		logbyte := readRootCauseLog(logfn)

		if len(logbyte) == 0 {
			Logf(0, "[WARN] No file contents on %v", logfn)
			continue
		}
		target, err := prog.GetTarget("linux", "amd64")
		if err != nil {
			Logf(0, "[WARN] Failed to get program target")
			continue
		}
		thisEntries := target.ParseLog(logbyte)

		if len(thisEntries) == 0 {
			Logf(0, "[WARN] Failed to load rootcause log: %v", logfn)
			continue
		}
		// only store the last program.
		entries = append(entries, thisEntries[len(thisEntries)-1])
	}
	return entries
}

func setupRootcauseDB(dbfn string, entries []*prog.LogEntry) {
	rootcauseDB, err := db.Open(dbfn)
	if err != nil {
		Fatalf("failed to open rootcause database: %v", err)
	}
	// empty the DB
	for key, _ := range rootcauseDB.Records {
		rootcauseDB.Delete(key)
	}

	// each program is saved back to rootcause corpus db
	for _, entry := range entries {
		data := entry.P.Serialize()
		sig := hash.String(data)
		rootcauseDB.Save(sig, data, 0)
		if err := rootcauseDB.Flush(); err != nil {
			Logf(0, "failed to save rootcause corpus database: %v", err)
		}
	}

}
