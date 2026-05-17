//! Holds the state of the ARM guest CPU.

#ifndef BALLISTIC_BAL_CPU_H
#define BALLISTIC_BAL_CPU_H

#include "bal_attributes.h"
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

    BAL_ALIGNED(64) typedef struct
    {
        uint64_t x[32];
        uint64_t pc;
    } bal_cpu_t;

    /// The function signature of a JIT-compiled basic block.
    typedef void (*bal_jit_block_t)(bal_cpu_t *cpu);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // BALLISTIC_BAL_CPU_H

/*** end of file ***/
