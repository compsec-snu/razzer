#include "qemu/thread-posix.h"
#include <stdlib.h>
#include "pthread.h"
#include "race/sync.h"

struct QemuBarrier qemu_race_barrier;

void qemu_barrier_wait(struct QemuBarrier *sync)
{
    int err;

    err = pthread_barrier_wait(&sync->barrier);
    if (err)
        abort();
}


void qemu_barrier_init(struct QemuBarrier *sync, int nthreads)
{
    int err;

    err = pthread_barrier_init(&sync->barrier, NULL, nthreads);
    if (err)
        abort();
}
