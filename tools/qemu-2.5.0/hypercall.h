#ifndef __HYPERCALL_H
#define __HYPERCALL_H

#include "qemu-common.h"

#ifndef _HYPERCALL_ADDR
ERROR
#endif

typedef enum {
    HYPERCALL_IOCTL_ERR=-0x10000,
    HYPERCALL_UNEXPECTED,
    HYPERCALL_BREAKPOINT,
    HYPERCALL_COMMAND,
    HYPERCALL_NOPE,
} hcall_type_t;

typedef enum {
    CMD_START = 0,
    CMD_END,
    CMD_REFRESH,
} hcall_cmd_t;

typedef enum {
    CPU0,
    CPU1,
} race_id_t;

struct hcall_arg {
    unsigned long addr;
    hcall_cmd_t cmd;
    race_id_t sched;
    race_id_t race_id;
};

enum STATE {
    PHASE_UNREACHED = 0, // not yet reached
    PHASE_SLEEPING,
    PHASE_PASSED,
};

enum STATUS {
    STATUS_READY = 0,
    STATUS_RUNNING,
};

void init_hypercall(CPUState *cpu);
hcall_type_t check_hypercall(CPUState *cpu);
void handle_hypercall_breakpoint(CPUState *cpu);
void handle_hypercall_command(CPUState *cpu);
void get_command(CPUState *cpu, struct hcall_arg *arg);
void wait_race(CPUState *cpu);

#endif /* __HYPERCALL_H */
