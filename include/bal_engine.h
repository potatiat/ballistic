#ifndef BALLISTIC_ENGINE_H
#define BALLISTIC_ENGINE_H

#include "backend/bal_cpu.h"
#include "bal_attributes.h"
#include "bal_errors.h"
#include "bal_logging.h"
#include "bal_memory.h"
#include "bal_types.h"
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

/// A byte pattern written to memory during initialization, poisoning allocated
/// regions. This is mainly used for detecting reads from uninitialized memory.
#define BAL_POISON_UNINITIALIZED_MEMORY 0xFF

/// Ballistic will safely terminate execution if the Program Counter matches this value.
#define BAL_ENGINE_SENTINEL 0xFFFFFFFFFFFFFFFFULL

    BAL_ALIGNED(64) typedef struct
    {
        /// The guest CPU state.
        bal_cpu_t *cpu;

        /// The allocator used for all internal engine memory.
        const bal_allocator_t *allocator;

        /// The memory interface for all guest-to-host address translation.
        const bal_memory_interface_t *memory_interface;

        /// Opaque pointer to the internal engine's state.
        void *engine_state;

        /// Handles logging for this engine.
        bal_logger_t logger;

        /// The current error state of the engine.
        ///
        /// If an operation fails, this field is set to a specific error code.
        /// See [`bal_error_t`]. Once set to an error state, subsequent operation
        /// on this engine will silently fail until [`bal_engine_reset`] is called.
        bal_error_t status;

        /// Execution flags (e.g., `BAL_ENGINE_FLAG_RUNNING`).
        uint32_t flags;
    } bal_engine_t;

    static_assert(sizeof(bal_engine_t) <= 64, "Engine must fit in a L1 Cache line");

    /// Initializes a Ballistic engine.
    ///
    /// # Errors
    ///
    /// * Returns [`BAL_SUCCESS`] if the engine is ready for use.
    /// * Returns [`BAL_ERROR_INVALID_ARGUMENT`] if the pointers are `NULL`.
    /// * Returns [`BAL_ERROR_ALLOCATION_FAILED`] if the allocator cannot allocate a memory buffer.
    BAL_COLD bal_error_t bal_engine_init(bal_engine_t                 *engine,
                                         bal_cpu_t                    *cpu,
                                         const bal_allocator_t        *allocator,
                                         const bal_memory_interface_t *memory_interface,
                                         bal_logger_t                  logger);

    /// The sole entry point for executing guest code.
    ///
    /// # Errors
    ///
    /// Returns [`BAL_ERROR_ENGINE_ALREADY_RUNNING`] if the thread is still running.
    BAL_HOT bal_error_t bal_engine_run_thread(bal_engine_t *engine);

    /// Stops the engine execution asynchronously.
    ///
    /// This function is thread-safe and can be called from any thread.
    BAL_HOT void bal_engine_stop_thread(bal_engine_t *engine);

    /// Resets `engine` for the next compilation unit. This is a low-cost memory
    /// operation designed to be called between translation units.
    ///
    /// Returns [`BAL_SUCCESS`] on success.
    ///
    /// # Errors
    ///
    /// Returns [`BAL_ERROR_INVALID_ARGUMENT`] if `engine` is `NULl`.
    BAL_HOT bal_error_t bal_engine_reset(bal_engine_t *engine);

    /// Checks if the engine is currently executing guest code.
    ///
    /// This function is thread-safe and can be called from any thread.
    BAL_HOT bool bal_engine_is_running(bal_engine_t *engine);

    /// Requests the engine to clear its compiled code cache and JIT buffers.
    ///
    /// This function is completely lock-free and thread-safe.
    BAL_HOT void bal_engine_clear_cache(bal_engine_t *engine);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* BALLISTIC_ENGINE_H */

/*** end of file ***/
