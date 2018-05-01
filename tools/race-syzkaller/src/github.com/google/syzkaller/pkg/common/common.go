package common

import (
	"fmt"
	"hash/fnv"
	"sort"
	"strings"

	. "github.com/google/syzkaller/pkg/log"
)

type MempairHash uint64

func Assert(cond bool, msg string, args ...interface{}) {
	if !cond {
		Fatalf(msg, args)
	}
}

func GetMempairHashFromHashStr(hashStr string) MempairHash {
	var hashVal uint64
	fmt.Sscanf(hashStr, "%x", &hashVal)
	return MempairHash(hashVal)
}

func (mh MempairHash) ToString() string {
	hashStr := fmt.Sprintf("%x", mh)
	return hashStr
}

func GetMempairHashFromStr(s string) MempairHash {
	locs := strings.Split(s, " ")
	sorted := SortedConcate(locs)

	h := fnv.New64a()
	h.Write([]byte(sorted))
	return MempairHash(h.Sum64())
}

func GetMempairHashFromLocs(locs []string) MempairHash {
	sorted := SortedConcate(locs)
	h := fnv.New64a()
	h.Write([]byte(sorted))
	return MempairHash(h.Sum64())
}

func SortedConcate(s []string) string {
	var d []string
	d = make([]string, len(s))
	copy(d, s)

	sort.Strings(d)
	return d[0] + " " + d[1]
}
