package common

import (
	"bytes"
	"fmt"
	"testing"
)

func TestRaceInfoFormat(t *testing.T) {
	loc0 := "net/foo.c:10:0"
	loc1 := "net/bar.c:21:0"
	locs := []string{loc0, loc1}

	ri1 := RaceInfo{
		Cov:     [2]uint32{0x1234, 0x5678},
		Addr:    [2]uint32{0xdead, 0xbeef},
		Idx:     [2]int{1, 5},
		Sched:   1,
		Hash:    GetMempairHashFromLocs(locs),
		Mempair: [2]string{loc0, loc1}}

	encoded1 := ri1.ToBytes()
	fmt.Printf("Raceinfo1 : [%q]\n", encoded1)

	ri2 := FromBytes(encoded1)
	encoded2 := ri2.ToBytes()
	fmt.Printf("Raceinfo2 : [%q]\n", encoded2)

	if bytes.Compare(encoded1, encoded2) != 0 {
		t.Error("Encoded RaceInfo doesn't match\n")
	}

	if ri1 != ri2 {
		t.Error("Decoded RaceInfo doesn't match\n")
	}
}
