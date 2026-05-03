//! Holds the state of the ARM guest CPU.

#ifndef BALLISTIC_BAL_CPU_H
#define BALLISTIC_BAL_CPU_H

#include "bal_attributes.h"
#include <stdint.h>

BAL_ALIGNED(64) typedef struct
{
    uint64_t x[32];
    uint64_t pc;
} bal_cpu_t;

#endif // BALLISTIC_BAL_CPU_H

/*** end of file ***/
