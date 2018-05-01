package main

import (
	"bufio"
	"encoding/json"
	"io/ioutil"
	"os"
	"strings"

	. "github.com/google/syzkaller/pkg/common"
	. "github.com/google/syzkaller/pkg/log"
	. "github.com/google/syzkaller/pkg/rpctype"
	"github.com/google/syzkaller/syz-manager/mgrconfig"
)

func removeDisabledMempair(mempair []Mempair, disabledMempair []Mempair) []Mempair {
	tmpHash := make(map[MempairHash]struct{})
	singleLoc := make(map[string]struct{})
	for _, m := range disabledMempair {
		if len(m.Locs) < 2 {
			// disable one loc "n_hdlc.c:216:0"
			singleLoc[m.Locs[0]] = struct{}{}
		} else {
			// MempairHash for "n_hdlc.c:216:0 n_hdlc.c:440:0"
			tmpHash[GetMempairHashFromLocs(m.Locs)] = struct{}{}
		}
	}

	newMempair := []Mempair{}
	for _, m := range mempair {
		_, ok1 := tmpHash[GetMempairHashFromLocs(m.Locs)]
		_, ok2 := singleLoc[m.Locs[0]]
		_, ok3 := singleLoc[m.Locs[1]]
		if !ok1 && !ok2 && !ok3 {
			newMempair = append(newMempair, m)
		} else {
			Logf(2, "[*] Mempair %+v is disabled", m)
		}
	}
	return newMempair
}

func initRaceCandPairs(cfg *mgrconfig.Config) ([]Mempair, []Mapping, error) {
	allMempair, err0 := loadMempair(cfg.Mempair)
	if err0 != nil {
		return nil, nil, err0
	}
	disabledMempair, err2 := loadMempair(cfg.Disable_Mempair)
	if err2 != nil && !strings.HasPrefix(err2.Error(), "open : no such file or directory") {
		// It's okay the disable mempair file doesn't exist
		return nil, nil, err2
	}
	if len(disabledMempair) != 0 {
		for _, m := range disabledMempair {
			Logf(1, "[*] Disable mempair: %+v", m.Locs)
		}
	}

	mempair := removeDisabledMempair(allMempair, disabledMempair)

	mapping, err1 := loadMapping(cfg.Mapping)
	if err1 != nil {
		return nil, nil, err1
	}
	return mempair, mapping, nil
}

func loadMempair(mempairFile string) ([]Mempair, error) {
	var mempair []Mempair

	mempairFileContents, err := os.Open(mempairFile)
	if err != nil {
		return nil, err
	}
	defer mempairFileContents.Close()

	scanner := bufio.NewScanner(mempairFileContents)
	for scanner.Scan() {
		line := scanner.Text()
		if len(line) == 0 || strings.HasPrefix(line, "#") {
			continue
		}
		toks := strings.Split(line, " ")

		// TODO: this code is ugly, but we will rarely (almost never) touch this code again. just let it ugly for now.
		var memp Mempair
		if len(toks) < 2 || toks[1] == "R" || toks[1] == "W" {
			memp = Mempair{
				Locs: append([]string{}, toks[0]),
			}
		} else {
			memp = Mempair{
				Locs: append([]string{}, toks[:2]...),
				Tags: append([]string{}, toks[2:]...),
			}
		}

		if len(memp.Tags) == 0 {
			// If previous analysis contains no tags,
			memp.Tags = []string{"w", "w"}
		}

		for i := 0; i < len(memp.Tags); i++ {
			memp.Tags[i] = strings.ToUpper(memp.Tags[i])
		}
		mempair = append(mempair, memp)
	}
	if err := scanner.Err(); err != nil {
		return nil, err
	}

	return mempair, nil
}

func loadMapping(mappingFile string) ([]Mapping, error) {
	var mapping []Mapping

	mappingFileContents, err := ioutil.ReadFile(mappingFile)
	if err != nil {
		return nil, err
	}
	err = json.Unmarshal(mappingFileContents, &mapping)
	if err != nil {
		return nil, err
	}

	for _, mapp := range mapping {
		if mapp.Tag == "" {
			mapp.Tag = "w"
		}
	}

	return mapping, nil
}
