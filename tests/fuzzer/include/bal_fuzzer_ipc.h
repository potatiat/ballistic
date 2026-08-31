#ifndef BALLISTIC_BAL_FUZZER_IPC_H
#define BALLISTIC_BAL_FUZZER_IPC_H

#include "bal_errors.h"
#include "bal_fuzzer_protocol.h"
#include <stdint.h>

typedef struct
{
    int     input_file_descriptor;
    int     output_file_descriptor;
    int32_t child_pid;
} bal_fuzzer_worker_handle_t;

/// Spawns a worker executable via an anonymous pipe.
bal_error_t bal_fuzzer_ipc_spawn(bal_fuzzer_worker_handle_t *BAL_RESTRICT handle,
                                 const char *BAL_RESTRICT                 worker_path);

void bal_fuzzer_ipc_destroy(bal_fuzzer_worker_handle_t *BAL_RESTRICT handle);

#endif // BALLISTIC_BAL_FUZZER_IPC_H

/*** end of file ***/