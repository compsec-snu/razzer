package common

import (
	"fmt"
	"testing"
)

func checkEq(s1, s2 string, t *testing.T) {
	if s1 != s2 {
		t.Error("hash doesn't match: %v != %v\n", s1, s2)
	}
}

func TestHash(t *testing.T) {
	loc0 := "net/foo.c:10:0"
	loc1 := "net/bar.c:21:0"

	var locs []string

	locs = []string{loc0, loc1}
	mh1 := GetMempairHashFromLocs(locs)
	fmt.Printf("mh1: %v\n", mh1.ToString())

	locs = []string{loc1, loc0}
	mh2 := GetMempairHashFromLocs(locs)
	fmt.Printf("mh2: %v\n", mh2.ToString())

	mh3 := GetMempairHashFromStr(loc0 + " " + loc1)
	fmt.Printf("mh3: %v\n", mh3.ToString())

	mh4 := GetMempairHashFromStr(loc1 + " " + loc0)
	fmt.Printf("mh4: %v\n", mh4.ToString())

	checkEq(mh1.ToString(), mh2.ToString(), t)
	checkEq(mh1.ToString(), mh3.ToString(), t)
	checkEq(mh1.ToString(), mh4.ToString(), t)

}
