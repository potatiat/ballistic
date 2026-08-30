#ifndef BALLISTIC_BAL_FUZZER_STATE_H
#define BALLISTIC_BAL_FUZZER_STATE_H

#include "bal_fuzzer_protocol.h"
#include <stdbool.h>

typedef struct
{
    /// Value from Unicorn.
    uint64_t expected_value;

    /// Value from Ballistic.
    uint64_t actual_value;

    /// X register index.
    uint32_t first_mismatch_register;

    /// True if states are identical.
    bool     match;
    char     pad0[3];
    uint64_t pad1;
} bal_fuzzer_comparison_result_t;

void bal_fuzzer_state_capture(bal_fuzzer_cpu_snapshot_t *BAL_RESTRICT snapshot,
                              const bal_cpu_t *BAL_RESTRICT           cpu);

#endif // BALLISTIC_BAL_FUZZER_STATE_H

/*** end of file ***/