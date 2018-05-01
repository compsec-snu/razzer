#ifndef __RACE_LOG_H
#define __RACE_LOG_H

#include <execinfo.h>

#define panic(fmt, ...) \
    do { \
        fprintf(stderr, fmt, ## __VA_ARGS__); \
        void* callstack[128]; \
        int frames = backtrace(callstack, 128); \
        backtrace_symbols_fd(callstack, frames, 2); \
        exit(1); \
    } while(0)

extern int race_debug;

#define DAEPRINTF(fmt, ...)                     \
  do {                                          \
    if (race_debug) {                           \
      fprintf(stderr, "#[KVM DBG] ");           \
      fprintf(stderr, fmt, ## __VA_ARGS__);     \
    }                                           \
  } while (0)

#define Logf(fmt, ...) \
    do { fprintf(stderr, "#[QEMU]" fmt "\n", ## __VA_ARGS__); } while (0)

#endif
