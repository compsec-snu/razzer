#ifndef __HYPERCALL_H
#define __HYPERCALL_H

#define SYS_hypercall 335

enum {
	CMD_START = 0,
	CMD_END = 1,
	CMD_REFRESH = 2,
};

#endif
