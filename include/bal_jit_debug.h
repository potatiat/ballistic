#ifndef BALLISTIC_BAL_JIT_DEBUG_H
#define BALLISTIC_BAL_JIT_DEBUG_H

#include "bal_attributes.h"
#include "bal_errors.h"
#include "bal_log.h"
#include "bal_memory.h"

#include <assert.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{

#endif // __cplusplus

    typedef struct
    {
        /// Byte offset from the start of the JIT block.
        uint32_t x86_offset;

        /// Offset from the JIT block's base Guest PC.
        uint32_t guest_pc_offset;
    } bal_jit_instruction_map_t;

    static_assert(8 == sizeof(bal_jit_instruction_map_t), "Struct size mismatch");

    /// Metadata for a single compiled JIT block.
    typedef struct
    {
        uint64_t                   base_guest_pc;
        uint32_t                   instruction_count;
        uint32_t                   pad0;
        bal_jit_instruction_map_t *mappings;
        uint64_t                   pad1;
    } bal_jit_block_metadata_t;

    static_assert(32 == sizeof(bal_jit_block_metadata_t), "Struct size mismatch");

    typedef struct
    {
        void                     *rx_start;
        uint32_t                  rx_size;
        uint32_t                  pad0;
        bal_jit_block_metadata_t *metadata;
        uint64_t                  pad1;
    } bal_jit_block_entry_t;

    static_assert(32 == sizeof(bal_jit_block_entry_t), "Struct size mismatch");

    BAL_ALIGNED(64) typedef struct
    {
        bal_jit_block_entry_t *entries;
        uint8_t               *metadata_arena;
        bal_logger_t           logger;
        size_t                 entry_count;

        // The entry list capacity. This is NOT in bytes.
        size_t entry_capacity;
        size_t arena_offset;

        // Cold data.

        // The metadata arena capacity in bytes.
        size_t  arena_capacity;
        uint8_t pad[56];
    } bal_jit_debug_context_t;

    static_assert(128 == sizeof(bal_jit_debug_context_t), "Struct size mismatch");

    BAL_COLD bal_error_t bal_jit_debug_init(const bal_allocator_t   *allocator,
                                            bal_jit_debug_context_t *context,
                                            bal_logger_t             logger);

    BAL_COLD void bal_jit_debug_destroy(const bal_allocator_t   *allocator,
                                        bal_jit_debug_context_t *context);

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // BALLISTIC_BAL_JIT_DEBUG_H
