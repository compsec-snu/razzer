#ifndef __SYNC_H
#define __SYNC_H

#include "pthread.h"
#include "qemu/thread-posix.h"

struct QemuBarrier {
    pthread_barrier_t barrier;
};

extern struct QemuBarrier qemu_race_barrier;

void qemu_barrier_init(struct QemuBarrier *sync, int nthreads);
void qemu_barrier_wait(struct QemuBarrier *sync);

#endif
