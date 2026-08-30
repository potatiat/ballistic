#include "bal_fuzzer_state.h"

#include <string.h>

void
bal_fuzzer_state_capture(bal_fuzzer_cpu_snapshot_t *snapshot, const bal_cpu_t *cpu)
{
    (void)memcpy(snapshot, cpu->x, sizeof(snapshot->x));
    snapshot->pc                = cpu->pc;
    snapshot->flag_c            = cpu->flag_c;
    snapshot->flag_z            = cpu->flag_z;
    snapshot->flag_n            = cpu->flag_n;
    snapshot->flag_v            = cpu->flag_v;
    snapshot->instruction_count = cpu->instruction_count;
}

/*** end of file ***/