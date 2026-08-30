#ifndef BALLISTIC_BAL_FUZZER_STATE_H
#define BALLISTIC_BAL_FUZZER_STATE_H

#include "bal_fuzzer_protocol.h"
#include <stdbool.h>

#define BAL_FUZZER_MAX_DIVERGENCES 40U

typedef enum
{
    BAL_FUZZER_FIELD_REGISTER = 0,
    BAL_FUZZER_FIELD_PC,
    BAL_FUZZER_FIELD_FLAG_C,
    BAL_FUZZER_FIELD_FLAG_Z,
    BAL_FUZZER_FIELD_FLAG_N,
    BAL_FUZZER_FIELD_FLAG_V,
} bal_fuzzer_field_t;

typedef struct
{

    /// Value from Unicorn.
    uint64_t expected_value;

    /// Value from Ballistic.
    uint64_t actual_value;

    /// X register index, or UINT32_MAX if not a GPR.
    uint32_t register_index;

    /// Which field diverged.
    bal_fuzzer_field_t field;

    uint64_t pad1;
} bal_fuzzer_divergence_t;

typedef struct
{
    bool                    match;
    bal_fuzzer_divergence_t divergences[BAL_FUZZER_MAX_DIVERGENCES];
    uint32_t                divergence_count;
} bal_fuzzer_comparison_result_t;

void bal_fuzzer_state_capture(bal_fuzzer_cpu_snapshot_t *BAL_RESTRICT snapshot,
                              const bal_cpu_t *BAL_RESTRICT           cpu);

#endif // BALLISTIC_BAL_FUZZER_STATE_H

/*** end of file ***/