#include <sys/syscall.h>
#include <linux/futex.h>
#include <stdlib.h>

#include "hypercall.h"
#include "sysemu/kvm.h"
#include "qemu-common.h"
#include "race/log.h"
#include "race/utils.h"

QemuMutex qemu_race_mutex;

#define gettid() \
	syscall(SYS_gettid)

#define _NONZERO(v) ({\
        if (!v) \
            panic("zero value\n"); \
        v; \
    })

extern QemuCond qemu_race_cond;
int phase[2];
uint64_t addr[2];
int can_go;

static uint64_t writing_addr[2];
static uint64_t reading_addr[2];
static uint64_t race_addr[2];

static inline bool is_same_address(void) {
	if(writing_addr[0] && writing_addr[1] && writing_addr[0] == writing_addr[1]) {
		race_addr[0] = writing_addr[0];
		race_addr[1] = writing_addr[1];
        return true;
    } else if(writing_addr[0] && reading_addr[1] && writing_addr[0] == reading_addr[1]) {
        race_addr[0] = writing_addr[0];
        race_addr[1] = reading_addr[1];
        return true;
    } else if(reading_addr[0] && writing_addr[1] && reading_addr[0] == writing_addr[1]) {
        race_addr[0] = reading_addr[0];
        race_addr[1] = writing_addr[1];
        return true;
    }
    race_addr[0] = 0;
    race_addr[1] = 0;
    return false;
}

static const char* mem_type_read = "read";
static const char* mem_type_write = "write";
static const char* mem_type_NA = "N/A";
static inline const char* accessType(int cpu_index) {
    if (race_addr[cpu_index] == reading_addr[cpu_index]) {
        return mem_type_read;
    } else if (race_addr[cpu_index] == writing_addr[cpu_index]) {
        return mem_type_write;
    } else {
        return mem_type_NA;
    }
}

static tid_t guest_gettid(CPUState* cpu) {
    struct kvm_regs *regs = _NONZERO(cpu->regs);

    // I assume that kernel's current_thread_info and stack location is
    // permant
    // If not, I need some other way

#define THREAD_SIZE ((1<<12) << 3) // true only if KASAN is enabled, if not,
                                   // THREAD_SIZE will be (1<<12) << 2
    void* stack_top =
        (void*)(regs->rsp & ~(THREAD_SIZE - 1));

    return (tid_t)stack_top;

    /*
    struct kvm_regs regs;
    struct kvm_sregs sregs;
    unsigned long long gcr3;
    unsigned long pid_offset;

    ret = kvm_vcpu_ioctl(CPU(cpu), KVM_GET_SREGS, &sregs);
    if (ret < 0) {
        return -1;
    }
    gcr3 = sregs.cr3;


    // Top of the kernel stack
    // https://stackoverflow.com/questions/43176500/linux-kernel-current-thread-info-inline-function-code-can-be-understood
    
    // In x86_64, task_struct is the first element of thread_info
    void* current_thread = current_thread_info;

    // Currently, just calculated pid_offset manually
    // TODO: fix it
    pid_offset = 0x460;
    void* pid_address = current_thread + pid_offset;

    return 0;
    */
}

int status[2];
bool is_refresh[2];

void wait_race(CPUState *cpu) {
    target_ulong paddr;
    int insn_size;
	uint32_t tid __attribute__((unused)) = gettid();
    struct kvm_regs *regs = cpu->regs;
    if (regs == NULL)
        return;

#define MAX_OPERANDS 4
    char param[MAX_OPERANDS][100];

#ifndef TIME_LIMIT
#define TIME_LIMIT 20
#endif
    qemu_mutex_lock(&qemu_race_mutex);
	if (is_refresh[cpu->cpu_index]) {
		is_refresh[cpu->cpu_index] = false;
		race_addr[cpu->cpu_index] = writing_addr[cpu->cpu_index] = reading_addr[cpu->cpu_index] = 0;
		phase[cpu->cpu_index] = PHASE_UNREACHED;
        cpu->done = false;
	}

    if(cpu->wait_race) {
        // Decide they access the same memory location

        // read mem
#define MAX_INSN_LEN 15
        int len = MAX_INSN_LEN;
        uint8_t buf[16];
        paddr = get_phys_addr(regs->rip);
        cpu_physical_memory_read(paddr, buf, len);

        // disas, print the result and determine the address
        insn_size = disas_get_mem(regs->rip, buf, /* out */param);

        int i;
        for(i=0;i<MAX_OPERANDS;i++) {
            DAEPRINTF("[%d] %d: (rip: 0x%llx) get_mem_addr() on [%s] (inst_size: %d)\n",
                      tid, i, regs->rip, param[i], insn_size);
            uint64_t addr = get_mem_addr(param[i], regs, insn_size);
            DAEPRINTF("[%d] \t -> addr: %lx\n", tid, addr);
            if(addr) {
				if (i != MAX_OPERANDS - 1) {
					reading_addr[cpu->cpu_index] = addr;
					writing_addr[cpu->cpu_index] = 0;
				} else {
					writing_addr[cpu->cpu_index] = addr;
					reading_addr[cpu->cpu_index] = 0;
				}
                break;
            }
        }
        DAEPRINTF("[%d] reading_addr: %lx\n", tid, reading_addr[cpu->cpu_index]);
        DAEPRINTF("[%d] writing_addr: %lx\n", tid, writing_addr[cpu->cpu_index]);

        bool same_addr = false;
        bool is_race = false;
        bool both_bp_hit = false;
        int opponent = !(cpu->cpu_index);

        Logf("--------------------------------------------\n");
        if(phase[opponent] == PHASE_SLEEPING) {
            // This is the second thread
            // Okay race, keep going
            Logf("[Thread %d] triggered second bp (sleeping)", cpu->cpu_index);
            both_bp_hit = true;
			same_addr = is_same_address();
            phase[cpu->cpu_index] = PHASE_PASSED;
            qemu_cond_broadcast(&qemu_race_cond);
            can_go = 0;
        } else if(phase[opponent] == PHASE_PASSED) {
            Logf("[Thread %d] triggered second bp (passed)", cpu->cpu_index);

            phase[cpu->cpu_index] = PHASE_PASSED;
            both_bp_hit = false;
            same_addr = is_same_address();
        } else {
            // Waiting for others until (TIME_LIMIT)ms
            phase[cpu->cpu_index] = PHASE_SLEEPING;
            Logf("[Thread %d] triggered first bp", cpu->cpu_index);

            both_bp_hit = qemu_cond_timedwait(&qemu_race_cond, &qemu_race_mutex, TIME_LIMIT);
            if(phase[opponent] == PHASE_PASSED)
                // It is possible that qemu_cond_timedwait is timed out,
                // and second thread triggers bp before qemu_cond_timedwait acuires the lock.
                // This if statement handles that case.
                both_bp_hit = true;

            same_addr = is_same_address();
            phase[cpu->cpu_index] = PHASE_PASSED;
        }
        is_race = both_bp_hit & same_addr;
        Logf("[Thread %d] is race: %d", cpu->cpu_index, (int)is_race);
        Logf("[Thread %d]     Access type: %s", cpu->cpu_index, accessType(cpu->cpu_index));
        Logf("[Thread %d]     Access addr: %lx", cpu->cpu_index, race_addr[cpu->cpu_index]);
        Logf("[Thread %d]     Both bp hit simultaneously: %d", cpu->cpu_index, (int)both_bp_hit);
        Logf("[Thread %d]     Both access same memory: %d", cpu->cpu_index, (int)same_addr);
        assert(cpu);
        // This is the only location that falsify wait_race
        assert(cpu->wait_race);
        cpu->wait_race = false;
        cpu->done = false;
        cpu->is_race = (int)is_race;
        DAEPRINTF("[%d] bp[%d]: done , is_race %d\n", cpu->cpu_index, cpu->bp_count, is_race);
        DAEPRINTF("[%d] bp[%d]: addr0 %lx , addr1 %lx\n", cpu->cpu_index, cpu->bp_count, race_addr[0], race_addr[1]);
    }
    qemu_mutex_unlock(&qemu_race_mutex);

    if(cpu->is_race && !cpu->go_first && !cpu->done) {
		struct timespec ts = {.tv_sec = 0, .tv_nsec = 1000000ull /* 1ms */};
        DAEPRINTF("[%d] %d Waiting\n", cpu->cpu_index, cpu->thread_id);
        syscall(SYS_futex, &can_go, FUTEX_WAIT, 0, &ts, 0, 0);
        cpu->done = true;
    }

    if(cpu->is_race && cpu->go_first && cpu->wake_up && !cpu->done) {
        can_go = 1;
        DAEPRINTF("[%d] %d Waking up\n", cpu->cpu_index, cpu->thread_id);
        syscall(SYS_futex, &can_go, FUTEX_WAKE, INT_MAX, NULL, 0, 0);
        cpu->done = true;
    }
}

void init_hypercall(CPUState *cpu) {
	Logf("HYPERCALL_ADDR: %lx\n", _HYPERCALL_ADDR);
	kvm_init_hypercall(cpu);
    cpu->bp_count = 0;

    status[cpu->cpu_index] = STATUS_READY;
    DAEPRINTF("(main) status[%d] = STATUS_READY\n", cpu->cpu_index);
	is_refresh[cpu->cpu_index] = false;

    cpu->inserted_breakpoint = 0;
}

hcall_type_t check_hypercall(CPUState *cpu) {

    struct kvm_regs *regs = cpu->regs;
    hcall_cmd_t cmd;

    if (regs == NULL) {
        return HYPERCALL_NOPE;
    }

    // TODO: This address is the address of nop instruction in sys_hypercall of
    // modified kernel
    //
    // ffffffff8117e7c0 <sys_hypercall>:
    // ffffffff8117e7c0:       push   %rbp
    // ffffffff8117e7c1:       mov    %rsp,%rbp
    // ffffffff8117e7c4:       push   %rbx
    // ffffffff8117e7c5:       mov    %rdi,%rbx
    // ffffffff8117e7c8:       callq  ffffffff8132eb50
    // <__sanitizer_cov_trace_pc>
    // ffffffff8117e7cd:       push   %rax
    // ffffffff8117e7ce:       mov    %rbx,%rax
    // ffffffff8117e7d1:       nop                      <<== This
    // ffffffff8117e7d2:       pop    %rax
    //
    // Of course the address different for every kernel builds
    // I really need to fix it

    if (regs->rip == _HYPERCALL_ADDR) {
        regs->rip += 1;
        cpu->update_regs = true;

        cmd = (hcall_cmd_t)(regs->rbx);
        if(cmd == CMD_START || cmd == CMD_END || cmd == CMD_REFRESH) {
            return HYPERCALL_COMMAND;
        } else {
            DAEPRINTF("[ERR] HYPERCALL_UNEXPECTED (in check_hypercall)\n");
            return HYPERCALL_UNEXPECTED;
        }
    }
    return HYPERCALL_BREAKPOINT;
}

void get_command(CPUState *cpu, struct hcall_arg *arg) {
    // TODO: getting register values is redundant
    struct kvm_regs *regs = _NONZERO(cpu->regs);

    arg->race_id = regs->rax;
    arg->cmd = regs->rbx;
    arg->addr = regs->rcx;
    arg->sched = regs->rdx;
}

static void hypercall_command_start(CPUState *cpu, struct hcall_arg *arg) {
    struct kvm_regs *regs = _NONZERO(cpu->regs);
    uint32_t tid __attribute__((unused)) = gettid();
    int err;

    /* hcall args */
    long addr = arg->addr;
    race_id_t sched = arg->sched;
    race_id_t race_id = arg->race_id;

    if(status[cpu->cpu_index] != STATUS_READY) {
        DAEPRINTF("[%u] [ERR] (CMD_START) vcpu is not ready to run a program\n", tid);
        regs->rax = (uint64_t)(-1);
        cpu->update_regs = true;
    } else {
        cpu->is_race = false;

        addr |= 0xffffffff00000000;

        DAEPRINTF("[%u] Hypercall CMD_START\n", tid);
        DAEPRINTF("[%u] \t thread_id      : %d\n", tid, cpu->thread_id);
        DAEPRINTF("[%u] \t guest_tid      : %ld\n", tid, cpu->guest_tid);
        DAEPRINTF("[%u] \t rc's addr      : 0x%lx\n", tid, addr);

        err = kvm_insert_breakpoint_per_cpu(cpu, addr);
        if (err) {
            DAEPRINTF("[ERR] kvm_insert_breakpoint : %d\n", err);
        }

        phase[cpu->cpu_index] = PHASE_UNREACHED;
        cpu->inserted_breakpoint = addr;
        cpu->race_id = race_id;
        cpu->sched = sched;
        status[cpu->cpu_index] = STATUS_RUNNING;
    }
}

static void hypercall_command_end(CPUState *cpu, struct hcall_arg __attribute__((unused)) *arg) {
    struct kvm_regs *regs = _NONZERO(cpu->regs);
    uint32_t tid __attribute__((unused)) = gettid();
    int err;

    if(status[cpu->cpu_index] != STATUS_RUNNING) {
        DAEPRINTF("[%u] vcpu is not running a program status[%d] = %d",
                tid, cpu->cpu_index, status[cpu->cpu_index]);
        regs->rax = (uint64_t)(-1);
    } else {
        DAEPRINTF("[%u] Hypercall CMD_END\n", tid);
        DAEPRINTF("[%u] \t thread_id      : %d\n", tid, cpu->thread_id);
        DAEPRINTF("[%u] \t guest_tid      : %ld\n", tid, cpu->guest_tid);
        DAEPRINTF("[%u] \t rc's addr      : 0x%lx\n", tid, cpu->inserted_breakpoint);

        err = kvm_remove_breakpoint_per_cpu(cpu, cpu->inserted_breakpoint);
        if (err && err != -ENOENT) {
            DAEPRINTF("[ERR] [%u] kvm_remove_breakpoint : %d\n", tid, err);
        }
        cpu->inserted_breakpoint = 0;

        regs->rax = cpu->is_race;
        status[cpu->cpu_index] = STATUS_READY;
    }
    cpu->update_regs = true;
}

static void hypercall_command_refresh(CPUState *cpu, struct hcall_arg __attribute__((unused)) *arg) {
    //TODO: reinitialize
    //      does status need lock?
    DAEPRINTF("[%lu] Hypercall CMD_REFRESH\n", gettid());

    status[cpu->cpu_index] = STATUS_READY;
    cpu->guest_tid = 0;
    // TODO: Too many member variables and they are not clear in their meaning
    cpu->go_first = false;
    cpu->skipping = false;
    cpu->wait_race = false;
    cpu->wake_up = false;
    is_refresh[cpu->cpu_index] = true;

    kvm_remove_all_breakpoints_per_cpu(cpu);
    kvm_init_hypercall(cpu);
}

void handle_hypercall_command(CPUState *cpu) {
    struct hcall_arg arg;

    cpu->guest_tid = guest_gettid(cpu);
    if (cpu->guest_tid == 0) {
        panic("[ERR] [%lu] wrong guest_tid\n", gettid());
    }

    get_command(/* input */cpu, /* output */ &arg);

    qemu_mutex_lock(&qemu_race_mutex);
    switch(arg.cmd) {
        case CMD_START:
            hypercall_command_start(cpu, &arg);
            break;
        case CMD_END:
            hypercall_command_end(cpu, &arg);
            break;
        case CMD_REFRESH:
            hypercall_command_refresh(cpu, &arg);
            break;
        default:
            panic("Wrong command");
            break;
    }
    qemu_mutex_unlock(&qemu_race_mutex);
}

void handle_hypercall_breakpoint(CPUState *cpu) {
    struct kvm_regs *regs = _NONZERO(cpu->regs);
    uint32_t tid __attribute__((unused)) = gettid();
    tid_t guest_tid, guest_tid_;
    int err;

    Logf("--------------------------------------------");

    qemu_mutex_lock(&qemu_race_mutex);
    guest_tid_ = guest_gettid(cpu);
    if (guest_tid_ == 0) {
        panic("[ERR] [%u] wrong guest_tid\n", tid);
    }
    guest_tid = cpu->guest_tid;

    if(cpu->singlestep_enabled) {
        cpu->singlestep_enabled = 0;
	if (cpu->skipping) {
		// Re-install bp for the second or later bp hit
		err = kvm_insert_breakpoint_per_cpu(cpu, cpu->singlestep_enabled);
		if (err)
			DAEPRINTF("[ERR] kvm_insert_breakpoint : %d\n", err);
		cpu->skipping = false;
	} else {
		cpu->wake_up = true;
	}
        kvm_update_guest_debug_per_cpu(cpu, 0);
    } else if (cpu->inserted_breakpoint == regs->rip) {
        Logf("[%u] Hypercall BREAKPOINT", tid);
        Logf("[%u] \t thread_id      : %d", tid, cpu->thread_id);
        Logf("[%u] \t guest_tid      : %ld", tid, guest_tid);
        Logf("[%u] \t guest_tid_     : %ld", tid, guest_tid_);
        Logf("[%u] \t regs.rip       : %llx", tid, regs->rip);
        Logf("[%u] \t bp_count       : %d", tid, cpu->bp_count++);

	// Temporary implementation
	// Skip breakpoint according to the random value to give a second
	// chance to hit bp.
	// TODO: there are many flags in CPUState and they reduces readability.
	//       Need refactoring.
	cpu->skipping = (rand() % 100) >= 95;

        if(guest_tid_ == guest_tid && !cpu->skipping) {
            // This thread is the worker thread.
            // Need to wait until the other arrives.
            cpu->wait_race = true;
            cpu->go_first = (cpu->race_id == cpu->sched);
        }

        // remove breakpoint to continue executing
        err = kvm_remove_breakpoint_per_cpu(cpu, regs->rip);
        if (err) {
            fprintf(stderr, "[ERR] kvm_remove_breakpoint: %d\n", err);
            exit(1);
        }

	if (!cpu->skipping)
		cpu->inserted_breakpoint = 0;
	else
		cpu->singlestep_enabled = 1;

        // interrupt at next instruction
        if(cpu->go_first) {
            DAEPRINTF("[%u] \t enable single step\n", tid);
            cpu->singlestep_enabled = 1;
            kvm_update_guest_debug_per_cpu(cpu, 0);
            cpu->wake_up = false;
        }
    }
    qemu_mutex_unlock(&qemu_race_mutex);
}
