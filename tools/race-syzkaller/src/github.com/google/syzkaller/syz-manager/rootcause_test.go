package main

import (
	. "github.com/google/syzkaller/pkg/log"
	"testing"
)

func TestRootCause(t *testing.T) {
	logdir := "../../../../../tools/syzrepro"
	entries := collectRootCauseLogs(logdir)

	if len(entries) == 0 {
		t.Error("failed to parse crash log")
	}
	Logf(0, "Loaded %v rootcause logs", len(entries))
}
