package main

import (
	"bytes"
	"regexp"
	"strings"
)

var lockFunc = [...]string{
	// TODO: Some of them are not synchronizatino primitives (e.g., wrappers or something).
	//       They can make race-fuzzer slow down since race-fuzzer would handle unnecessary singals
	//       But still race-fuzzer can find bugs
	// spin lock
	"<do_raw_spin_lock>",
	"<do_raw_spin_trylock>",
	"<do_raw_spin_unlock>",
	"<_raw_spin_lock>",
	"<_raw_spin_lock_nested>",
	"<_raw_spin_lock_nest_lock>",
	"<_raw_spin_lock_bh_nested>",
	"<_raw_spin_lock_bh>",
	"<_raw_spin_lock_irq>",
	"<_raw_spin_lock_irqsave_nested>",
	"<_raw_spin_trylock>",
	"<_raw_spin_trylock_bh>",
	"<_raw_spin_unlock>",
	"<_raw_spin_unlock_bh>",
	"<_raw_spin_unlock_irq>",
	"<_raw_spin_unlock_irqrestore>",
	"<_raw_spin_lock_irqsave>",
	// queued spinlock
	"<queued_spin_unlock_wait>",
	"<queued_spin_lock_slowpath>",
	// semaphore
	"<down>",
	"<up>",
	"<down_interruptible>",
	"<down_killable>",
	"<down_trylock>",
	"<down_timeout>",
	// mutex
	"<mutex_trylock>",
	"<mutex_lock_killable_nested>",
	"<mutex_lock_nested>",
	"<mutex_lock_interruptible_nested>",
	"<_mutex_lock_nest_lock>",
	"<__ww_mutex_lock>",
	"<__mutex_unlock_slowpath>",
	"<mutex_unlock>",
	"<ww_mutex_unlock>",
	"<__ww_mutex_lock_interruptible>",
	"<rt_mutex_slowunlock>",
	"<rt_mutex_trylock>",
	"<__rt_mutex_slowlock>",
	"<rt_mutex_slowlock>",
	"<rt_mutex_lock>",
	"<rt_mutex_lock_interruptible>",
	"<rt_mutex_unlock>",
	"<rt_mutex_futex_unlock>",
	"<rt_mutex_timed_lock>",
	"<rt_mutex_timed_futex_lock>",
	"<rt_mutex_proxy_unlock>",
	"<rt_mutex_start_proxy_lock>",
	"<rt_mutex_next_owner>",
	"<rt_mutex_finish_proxy_lock>",
	// read/write lock
	"<do_raw_read_lock>",
	"<do_raw_write_lock>",
	"<queued_read_lock_slowpath>",
	"<queued_write_lock_slowpath>",
	"<_raw_read_lock>",
	"<_raw_read_lock_bh>",
	"<_raw_read_lock_irq>",
	"<_raw_write_lock>",
	"<_raw_write_lock_bh>",
	"<_raw_write_lock_irq>",
	"<_raw_read_lock_irqsave>",
	"<_raw_write_lock_irqsave>",
}

var (
	regex *regexp.Regexp
)

func initSyncFunc() {
	str := strings.Join(lockFunc[:], "|")
	_regex, err := regexp.Compile(str)
	if err != nil {
		panic(err)
	}
	regex = _regex
}

func finishSyncFunc() {
	regex = nil
}

func getFunc(ln []byte) string {
	// TODO: better way?
	idx1 := bytes.IndexByte(ln, '<') + 1
	idx2 := bytes.IndexByte(ln, '>')
	return string(ln[idx1:idx2])
}

func isSyncFunc(ln []byte) bool {
	return regex.Find(ln) != nil
}
