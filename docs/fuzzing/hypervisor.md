# Hypervisor

Razzer leverages the modified hypervisor to schedule vCPUs
deterministically.

## Deterministic scheduler

KVM is designed such that a host thread serves a virtual CPU in a
guest machine. Therefore, scheduling vCPUs instead of guest threads is
possible and this is how Razzer works. Razzer’s modified hypervisor
provides the following features for the guest userprogram: (i) setting
up a breakpoint per CPU core (more precisely, per virtual CPU core as
they run on a virtual machine); (ii) resuming the execution of kernel
threads after the guest kernel hits breakpoints; and (iii) checking
whether a race truly occurred due to a guest kernel.

All of these features are provided through hypercall interfaces used
by syz-scheduler.