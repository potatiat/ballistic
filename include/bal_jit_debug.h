#ifndef BALLISTIC_BAL_JIT_DEBUG_H
#define BALLISTIC_BAL_JIT_DEBUG_H

#include "bal_attributes.h"
#include "bal_errors.h"
#include "bal_log.h"
#include "bal_memory.h"

#include <assert.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define BAL_JIT_DEBUG_ENTRY_CAPACITY       8192
#define BAL_JIT_DEBUG_ARENA_CAPACITY_BYTES (4 * 1024 * 1024) // 4 MiB

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

    /// Callback when a crash occurs inside a JIT block.
    typedef void (*bal_jit_crash_callback_t)(void       *user_data,
                                             uint64_t    guest_pc,
                                             uint64_t    host_rip,
                                             uint32_t    jit_offset,
                                             const void *jit_block_start,
                                             uint32_t    jit_block_size);

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

        /// Memory Layout of the arena:
        ///
        /// Offset 0x0000:          bal_jit_block_metadata_t (Block 0).
        /// Offset 0x0020:          Array of bal_jit_instruction_map_t (N * 8 bytes).
        /// Offset 0x0020 + (N*8):  bal_jit_block_metadata_t (Block 1).
        /// Offset ....:            Array of bal_jit_instruction_map_t (M * 8 bytes).
        /// etc...
        uint8_t     *metadata_arena;
        bal_logger_t logger;
        size_t       entry_count;

        // The entry list capacity. This is NOT in bytes.
        size_t entry_capacity;
        size_t arena_offset;

        // Cold data.

        // The metadata arena capacity in bytes.
        size_t arena_capacity;

        void                    *jit_buffer_start;
        void                    *jit_buffer_end;
        bal_jit_crash_callback_t crash_callback;
        void                    *crash_callback_user_data;
        bal_error_t              status;

        /// Integrity check.
        uint32_t magic;

        uint8_t pad[16];
    } bal_jit_debug_context_t;

    static_assert(128 == sizeof(bal_jit_debug_context_t), "Struct size mismatch");

    BAL_COLD bal_error_t bal_jit_debug_init(const bal_allocator_t   *allocator,
                                            bal_jit_debug_context_t *context,
                                            bal_logger_t             logger);

    BAL_COLD void bal_jit_debug_destroy(const bal_allocator_t   *allocator,
                                        bal_jit_debug_context_t *context);

    BAL_HOT bal_error_t bal_jit_debug_add_block(bal_jit_debug_context_t         *context,
                                                void                            *rx_start,
                                                uint32_t                         rx_size,
                                                uint64_t                         base_guest_pc,
                                                const bal_jit_instruction_map_t *mapping,
                                                uint32_t                         instruction_count);

    BAL_COLD bal_error_t bal_jit_debug_register_signal_handler(bal_jit_debug_context_t *context,
                                                               void  *jit_buffer_start,
                                                               size_t jit_buffer_size);

    BAL_COLD void bal_jit_debug_unregister_signal_handler(bal_jit_debug_context_t *context);

#ifdef BALLISTIC_BUILD_TESTS

    /// This functions is exposed for testing purposes only.
    bool handle_jit_fault(uint64_t rip, uint64_t rbp);

#endif // BALLISTIC_BUILD_TESTS

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // BALLISTIC_BAL_JIT_DEBUG_H
