package common

import (
	"fmt"
	"strings"
)

type RaceInfo struct {
	// Execution info
	Cov   [2]uint32 // basic block
	Addr  [2]uint32 // instruction address
	Idx   [2]int    // syscall index
	Sched int

	// Mempair info
	Hash    MempairHash
	Mempair [2]string
}

type RaceExecInfo struct {
	TriageExecs     uint64      // Number of triage executions
	TriageTrues     uint64      // Number of true races out of triage executions
	TriageTrueFound uint64      // Number of triage executions when true race found
	TriageFailed    uint64      // Number of traige failed
	CorpusExecs     uint64      // Number of corpus fuzzing execution
	CorpusTrues     uint64      // Number of true races out of corpus executions
	CorpusTrueFound uint64      // Number of corpus executions when true race found
	LikelyExecs     uint64      // Number of likely corpus fuzzing execution
	LikelyTrues     uint64      // Number of true races out of likely corpus executions
	LikelyTrueFound uint64      // Number of likely corpus executions when true race found
	FirstFoundBy    RaceRunKind // Which race run method first found the true race
}

type RaceRunKind uint

const (
	NONE RaceRunKind = iota
	TRIAGE
	CORPUS
	LIKELY
)

func (raceInfo RaceInfo) ToBytes() []byte {
	res := []byte{}
	for i := 0; i < 2; i++ {
		str := fmt.Sprintf("Cov %x , Addr %x , Idx %d\n", raceInfo.Cov[i], raceInfo.Addr[i], raceInfo.Idx[i])
		res = append(res, []byte(str)...)
	}
	str := fmt.Sprintf("Loc0 %s , Loc1 %s\n", raceInfo.Mempair[0], raceInfo.Mempair[1])
	res = append(res, []byte(str)...)
	str = fmt.Sprintf("Hash %s , Sched %d\n", raceInfo.Hash.ToString(), raceInfo.Sched)
	res = append(res, []byte(str)...)
	return res
}

func FromBytes(bytes []byte) RaceInfo {
	raceInfo := RaceInfo{}
	strs := strings.Split(string(bytes), "\n")
	for i := 0; i < 2; i++ {
		_, err := fmt.Sscanf(strs[i], "Cov %x , Addr %x , Idx %d", &raceInfo.Cov[i], &raceInfo.Addr[i], &raceInfo.Idx[i])
		if err != nil {
			panic(err)
		}
	}
	_, err := fmt.Sscanf(strs[2], "Loc0 %s , Loc1 %s", &raceInfo.Mempair[0], &raceInfo.Mempair[1])
	if err != nil {
		panic(err)
	}
	// TODO: It is better to remove ','
	// Ugly.
	l := len(raceInfo.Mempair[0])
	if raceInfo.Mempair[0][l-1] == ',' {
		raceInfo.Mempair[0] = raceInfo.Mempair[0][:l]
	}

	var hashStr string
	_, err = fmt.Sscanf(strs[3], "Hash %s , Sched %d", &hashStr, &raceInfo.Sched)

	if err != nil {
		panic(err)
	}
	// Ugly.
	l = len(hashStr)
	if hashStr[l-1] == ',' {
		hashStr = hashStr[:l]
	}
	raceInfo.Hash = GetMempairHashFromHashStr(hashStr)
	return raceInfo
}
