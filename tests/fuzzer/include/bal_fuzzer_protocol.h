#ifndef BALLISTIC_BAL_FUZZER_PROTOCOL_H
#define BALLISTIC_BAL_FUZZER_PROTOCOL_H

#include "backend/bal_cpu.h"
#include "bal_attributes.h"
#include <stdint.h>

#define BAL_FUZZER_MAX_INSTRUCTIONS        60U
#define BAL_FUZZER_INSTRUCTION_BUFFER_SIZE (BAL_FUZZER_MAX_INSTRUCTIONS * 4U)

BAL_ALIGNED(64) typedef struct
{
    uint64_t x[32];
    uint64_t pc;
    uint8_t  flag_c;
    uint8_t  flag_z;
    uint8_t  flag_n;
    uint8_t  flag_v;
    uint32_t pad0;
    uint64_t instruction_count;
    uint64_t pad1[5];
} bal_fuzzer_cpu_snapshot_t;

static_assert(sizeof(bal_fuzzer_cpu_snapshot_t) == sizeof(bal_cpu_t), "Struct size mismatch");

#endif // BALLISTIC_BAL_FUZZER_PROTOCOL_H

/*** end of file ***/