package common

import (
	"flag"
	"fmt"
	"sync"
	"time"
)

var (
	flagTimeStat = flag.Bool("time", false, "Print time stat")
)

type TimeStat struct {
	jobTimeMap map[string][]float64

	beginTime time.Time
	jobName   string
	sync.Mutex
}

func (ts *TimeStat) Init() {
	if *flagTimeStat {
		ts.jobTimeMap = make(map[string][]float64)
	}
}

func (ts *TimeStat) Begin() {
	if *flagTimeStat {
		ts.beginTime = time.Now()
	}
}

func (ts *TimeStat) SetJobName(name string) {
	if *flagTimeStat {
		ts.jobName = name
	}
}

func (ts *TimeStat) End() {
	if *flagTimeStat {
		now := time.Now()
		elapsed := now.Sub(ts.beginTime)

		ts.Lock()
		ts.jobTimeMap[ts.jobName] = append(ts.jobTimeMap[ts.jobName], elapsed.Seconds())
		ts.Unlock()
	}
}

func (ts *TimeStat) SummaryAndFlush() string {
	s := ""
	if *flagTimeStat {
		ts.Lock()
		defer ts.Unlock()
		for k, vs := range ts.jobTimeMap {
			sum := 0.0
			for _, v := range vs {
				sum += v
			}
			s += fmt.Sprintf("(%v,%v,%vs) ", k, len(vs), uint64(sum))
		}

		if s == "" {
			s = "NA"
		}

		ts.jobTimeMap = make(map[string][]float64)
	}
	return s
}
