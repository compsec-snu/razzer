package main

import (
	"testing"

	. "github.com/google/syzkaller/pkg/rpctype"
)

func TestRemoveDisabledMempair(t *testing.T) {
	mempair := []Mempair{
		Mempair{
			Locs: []string{"a.c:1:0", "b.c:2:0"},
			Tags: []string{"R", "W"},
		},
		Mempair{
			Locs: []string{"aa.c:10:0", "b.c:2:0"},
			Tags: []string{"R", "W"},
		},
	}

	disabled_mempair := []Mempair{
		Mempair{
			Locs: []string{"a.c:1:0", "b.c:2:0"},
			Tags: []string{"R", "W"},
		},
		Mempair{
			Locs: []string{"foo.c:100:0", "bar.c:123:0"},
		},
	}

	mempair = removeDisabledMempair(mempair, disabled_mempair)
	if len(mempair) != 1 {
		t.Errorf("Failed to test removeDisabledMempair")
		if !(mempair[0].Locs[0] == "a.c:1:0" && mempair[0].Locs[1] == "b.c:2:0") {
			t.Errorf("Failed to test removeDisabledMempair: remove wrong mempair")
		}
	}
}
