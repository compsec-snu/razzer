// Copyright 2015 syzkaller project authors. All rights reserved.
// Use of this source code is governed by Apache 2 LICENSE that can be found in the LICENSE file.

// Package cover provides types for working with coverage information (arrays of covered PCs).
package cover

import (
	"sort"
	"math/rand"
)

type Cover map[uint32]struct{}
type RawCover []uint32

func (cov *Cover) Merge(raw RawCover) {
	c := *cov
	if c == nil {
		c = make(Cover)
		*cov = c
	}
	for _, pc := range raw {
		c[pc] = struct{}{}
	}
}

func (cov Cover) Serialize() []uint32 {
	res := make([]uint32, 0, len(cov))
	for pc := range cov {
		res = append(res, pc)
	}
	return res
}

func RestorePC(pc uint32, base uint32) uint64 {
	return uint64(base)<<32 + uint64(pc)
}

func foreachRawCover(covers []RawCover, f func(c1, c2 RawCover)) {
	for i := 0; i < len(covers) && covers[i] != nil; i++ {
		for j := i + 1; j < len(covers) && covers[j] != nil; j++ {
			f(covers[i], covers[j])
		}
	}
}

func RawCoverContains(cov RawCover, c uint32) bool {
	i := sort.Search(len(cov), func(i int) bool {
		return cov[i] >= c
	})
	return (i < len(cov) && cov[i] == c)
}

func Shuffle(cov RawCover, rnd *rand.Rand) RawCover {
  newCov := make(RawCover, len(cov))
  perm := rnd.Perm(len(cov))
  for i, randIndex := range perm {
    newCov[i] = cov[randIndex]
  }
  return newCov
}
