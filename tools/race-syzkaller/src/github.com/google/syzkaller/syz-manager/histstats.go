package main

import (
	"strings"
	// . "github.com/google/syzkaller/pkg/log"
)

const (
	NUM_TO_HIST = 10
)

type HistStat struct {
	diffs     []uint64
	lastValue uint64
	maxAvg    uint64
	curAvg    uint64
	key       string
	segment   string
}

func (hs *HistStat) Add(v uint64) {
	diff := v - hs.GetLastValue()
	hs.lastValue = v
	hs.diffs = append(hs.diffs, diff)

	if len(hs.diffs) > NUM_TO_HIST {
		hs.diffs = hs.diffs[len(hs.diffs)-NUM_TO_HIST:]
	}

	hs.curAvg = hs.ComputeAvg()

	if hs.curAvg > hs.maxAvg {
		hs.maxAvg = hs.curAvg
	}
}

func (hs *HistStat) GetLastValue() uint64 {
	return hs.lastValue
}

func (hs *HistStat) SetKey(key string) {
	hs.key = key

	if strings.HasPrefix(key, "fuzzer") {
		hs.segment = "fuzzer"
	} else if strings.HasPrefix(key, "sched") {
		hs.segment = "sched"
	} else {
		hs.segment = ""
	}
}

func (hs *HistStat) GetSegment() string {
	return hs.segment
}

func (hs *HistStat) GetMaxAvg() uint64 {
	return hs.maxAvg
}

func (hs *HistStat) GetAvg() uint64 {
	return hs.curAvg
}

func (hs *HistStat) ComputeAvg() uint64 {
	if len(hs.diffs) == 0 {
		return 0
	}

	sum := uint64(0)
	for _, v := range hs.diffs {
		sum += v
	}
	return uint64(1.0 * sum / uint64(len(hs.diffs)))
}
