package main

import (
	"path/filepath"
	"reflect"

	. "github.com/google/syzkaller/pkg/common"
	"github.com/google/syzkaller/pkg/db"
	"github.com/google/syzkaller/pkg/hash"
	. "github.com/google/syzkaller/pkg/log"
	. "github.com/google/syzkaller/pkg/rpctype"
)

type DBTy struct {
	primaryDB   *db.DB
	auxiliaryDB *db.DB
	name        string
}

type ManagerDB struct {
	dbs []*DBTy
}

func (mgrDB *ManagerDB) addDB(newDB *DBTy) {
	mgrDB.dbs = append(mgrDB.dbs, newDB)
}

func (mgr *Manager) loadDB(dbName, primaryDBName, auxiliaryDBName string, syscalls map[int]bool, db_prefix string, f func([]byte, RaceInfo)) (empty bool) {
	Logf(0, "[*] loading %v", dbName)
	primaryDB := mgr.dbOpen(db_prefix, primaryDBName)
	auxiliaryDB := mgr.dbOpen(db_prefix, auxiliaryDBName)

	loaded := 0
	deleted := 0
	for key, rec := range primaryDB.Records {
		p, err := mgr.target.Deserialize(rec.Val)
		if err != nil {
			if deleted < 10 {
				Logf(0, "deleting broken program: %v\n%s", err, rec.Val)
			}
			primaryDB.Delete(key)
			auxiliaryDB.Delete(key)
			deleted++
			continue
		}
		disabled := false
		for _, c := range p.Calls {
			if !syscalls[c.Meta.ID] {
				disabled = true
				break
			}
		}
		if disabled {
			// TODO: This is needed only for corpusDB.
			// But in this work, we don't use this.
			mgr.disabledHashes[hash.String(rec.Val)] = struct{}{}
			continue
		}

		var ri RaceInfo
		if auxiliaryDB != nil {
			infoRec, ok := auxiliaryDB.Records[key]
			if !ok {
				panic("Broken DB")
			}
			ri = FromBytes(infoRec.Val)

			Logf(2, "Prog: %s", rec.Val)
			Logf(2, "RaceInfo: %+v", ri)

			if _, ok := mgr.mempairHash[ri.Hash]; !ok {
				if hsh := GetMempairHashFromLocs(ri.Mempair[:]); hsh == ri.Hash {
					// TODO: Delete it?
					Logf(1, "[WARN] Mempair %+v in raceCorpusDB is not in the %s", ri.Mempair, mgr.cfg.Mempair)
				} else {
					// Broken DB
					Logf(0, "[ERR] Broken DB")
					Logf(0, "\traceInfo: %+v", ri)
				}
				continue
			}
		}

		f(rec.Val, ri)
		loaded++
	}

	if loaded == 0 {
		empty = true
		Logf(0, "[-] No raceprog cand loaded from %s", dbName)
	} else {
		empty = false
		Logf(0, "[+] loaded %v %s programs (%v total, %v deleted)", loaded, dbName, len(primaryDB.Records), deleted)
	}

	mgr.managerDB.addDB(&DBTy{
		primaryDB:   primaryDB,
		auxiliaryDB: auxiliaryDB,
		name:        dbName,
	})

	return empty
}

func (mgr *Manager) getAuxiliaryDB(name string) *db.DB {
	return mgr.getDB(name).auxiliaryDB
}

func (mgr *Manager) getPrimaryDB(name string) *db.DB {
	return mgr.getDB(name).primaryDB
}

func (mgr *Manager) getDB(name string) *DBTy {
	return mgr.managerDB.getDB(name)
}

func (mgrDB *ManagerDB) getDB(name string) *DBTy {
	for _, database := range mgrDB.dbs {
		if database.name == name {
			return database
		}
	}

	Fatalf("Wrong db name")
	return nil
}

func (DB *DBTy) Save(sig string, prog, raceinfo []byte) {
	DB.primaryDB.Save(sig, prog, 0)
	if err := DB.primaryDB.Flush(); err != nil {
		Fatalf("failed to save prog into DB (%s): %v", DB.name, err)
	}
	if raceinfo != nil {
		Assert(DB.auxiliaryDB != nil, "Trying to save raceinfo into nil auxiliaryDB (%s)", DB.name)
		DB.auxiliaryDB.Save(sig, raceinfo, 0)
		if err := DB.auxiliaryDB.Flush(); err != nil {
			Fatalf("failed to save raceinfo into DB (%s): %v", DB.name, err)
		}
	}
}

func (DB *DBTy) Remove(sig string) {
	DB.primaryDB.Delete(sig)
	if err := DB.primaryDB.Flush(); err != nil {
		Fatalf("failed to remove prog from DB (%s): %v", DB.name, err)
	}
	if DB.auxiliaryDB != nil {
		if _, ok := DB.auxiliaryDB.Records[sig]; ok {
			DB.auxiliaryDB.Delete(sig)
			if err := DB.auxiliaryDB.Flush(); err != nil {
				Fatalf("failed to save raceinfo into DB (%s): %v", DB.name, err)
			}
		} else {
			Fatalf("Trying to remove the wrong raceinfo from auxilityDB (%s)", DB.name)
		}
	}
}

const (
	CORPUSDB       = "corpus"
	RACECORPUSDB   = "racecorpus"
	LIKELYCORPUSDB = "likelycorpus"
)

func (mgr *Manager) getDBAndInput(_inp interface{}) (*DBTy, []byte, []byte) {
	switch inp := _inp.(type) {
	case RPCLikelyRaceInput:
		//likely corpus
		return mgr.getDB(LIKELYCORPUSDB), inp.RaceProg, inp.RaceInfo.ToBytes()
	case RPCRaceInput:
		//Race corpus
		return mgr.getDB(RACECORPUSDB), inp.RaceProg, inp.RaceInfo.ToBytes()
	case RPCInput:
		// Corpus
		return mgr.getDB(CORPUSDB), inp.Prog, nil
	default:
		// Wrong type
		panic("Wrong type!")
	}
}

func computeSig(p, ri []byte) string {
	return hash.String(append(p, ri...))
}

func (mgr *Manager) saveToDB(_inp interface{}) {
	DB, p, ri := mgr.getDBAndInput(_inp)
	sig := computeSig(p, ri)
	DB.Save(sig /* key */, p, ri /* values*/)
}

func (mgr *Manager) removeFromDB(_inp interface{}) {
	DB, p, ri := mgr.getDBAndInput(_inp)
	sig := computeSig(p, ri)
	DB.Remove(sig /* key*/)
}

func (mgr *Manager) dbOpen(db_prefix, db_name string) *db.DB {
	if db_name == "" {
		return nil
	}
	db, err := db.Open(filepath.Join(mgr.cfg.Workdir, db_prefix+db_name))
	if err != nil {
		Fatalf("failed to open corpus database: %v", err)
	}
	return db
}

func (mgr *Manager) getSavedProgCount() ([]string /* db name */, []int /* prog count */) {
	names := make([]string, len(mgr.managerDB.dbs))
	counts := make([]int, len(mgr.managerDB.dbs))

	for i, DB := range mgr.managerDB.dbs {
		names[i] = DB.name
		counts[i] = len(DB.primaryDB.Records)
	}

	return names, counts
}

func (mgr *Manager) clearDB(dbName string, m interface{}) {
	corpus := reflect.ValueOf(m)

	if corpus.Kind() == reflect.Map {
		primaryDB := mgr.getPrimaryDB(dbName)
		auxiliaryDB := mgr.getAuxiliaryDB(dbName)

		for key, rec := range primaryDB.Records {

			// corpus, raceCorpus: key
			// likelyCorpus: mempairHash
			// TODO: So ugly. we may need to change the type of likely race corpus or change likely corpus DB
			var ok1 bool
			if dbName == LIKELYCORPUSDB {
				p := rec.Val
				rawRaceInfo := auxiliaryDB.Records[key].Val
				ri := FromBytes(rawRaceInfo)

				ok := corpus.MapIndex(reflect.ValueOf(ri.Hash)).IsValid()
				if ok {
					val := corpus.MapIndex(reflect.ValueOf(ri.Hash))
					likelyRinp := val.Interface().(RPCLikelyRaceInput)

					sig1 := computeSig(p, rawRaceInfo)
					sig2 := computeSig(likelyRinp.RaceProg, likelyRinp.RaceInfo.ToBytes())
					ok1 = (sig1 == sig2)
				} else {
					ok1 = false
				}
			} else {
				ok1 = corpus.MapIndex(reflect.ValueOf(key)).IsValid()
			}

			_, ok2 := mgr.disabledHashes[key]
			if !ok1 && !ok2 {
				primaryDB.Delete(key)
				if auxiliaryDB != nil {
					auxiliaryDB.Delete(key)
				}
			}
		}

		primaryDB.Flush()
		if auxiliaryDB != nil {
			auxiliaryDB.Flush()
		}
	} else {
		Fatalf("Given corpus is not map")
	}
}

// helper functions
func (mgr *Manager) __pushToRPCCand(data []byte, _ RaceInfo) {
	mgr.rpcCands = append(mgr.rpcCands, RPCCandidate{
		Prog:      data,
		Minimized: true, // don't reminimize programs from corpus, it takes lots of time on start
	})
}

func (mgr *Manager) __pushToRaceQueue(data []byte, ri RaceInfo) {
	corpusRaceCand := RaceProgCand{
		Prog:      data,
		RaceInfos: []RaceInfo{ri},
		FromDB:    true,
	}
	mgr.pushToRaceQueue(corpusRaceCand)
}
