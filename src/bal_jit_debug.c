#include "bal_jit_debug.h"
#include <string.h>

#define BLOCK_CAPACITY 8192

bal_error_t
bal_jit_debug_init(const bal_allocator_t *BAL_RESTRICT   allocator,
                   bal_jit_debug_context_t *BAL_RESTRICT context,
                   const bal_logger_t                    logger)
{
    if (BAL_UNLIKELY(NULL == context))
    {
        BAL_LOG_ERROR(&logger, "Aborting function: context is NULL");
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    if (BAL_UNLIKELY(NULL == allocator))
    {
        BAL_LOG_ERROR(&logger, "Aborting function: allocator is NULL.");
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    bal_jit_debug_context_t c       = { 0 };
    c.entry_capacity                = BLOCK_CAPACITY;
    const size_t total_entries_size = c.entry_capacity * sizeof(bal_jit_block_entry_t);
    const size_t memory_alignment   = 64;
    c.entries                       = (bal_jit_block_entry_t *)allocator->allocate(
        allocator->context, memory_alignment, total_entries_size);

    if (BAL_UNLIKELY(NULL == c.entries))
    {
        BAL_LOG_ERROR(&logger, "Aborting function: failed to allocate JIT debug block entries");
        return BAL_ERROR_ALLOCATION_FAILED;
    }

    c.arena_capacity = 4 * 1024 * 1024; // 4 MB
    c.metadata_arena
        = (uint8_t *)allocator->allocate(allocator->context, memory_alignment, c.arena_capacity);

    if (BAL_UNLIKELY(NULL == c.metadata_arena))
    {
        BAL_LOG_ERROR(&logger, "Failed to allocate JIT debug metadata arena.");
        allocator->free(allocator->context, c.entries, total_entries_size);
        return BAL_ERROR_ALLOCATION_FAILED;
    }

    memset(context, 0, sizeof(bal_jit_debug_context_t));
    context->entries        = c.entries;
    context->metadata_arena = c.metadata_arena;
    context->logger         = c.logger;
    context->entry_capacity = c.entry_capacity;
    context->arena_capacity = c.arena_capacity;

    BAL_LOG_INFO(&logger,
                 "JIT Debug Context initialized. Entries Capacity: %zu, Arena: %zu bytes.",
                 context->entry_capacity,
                 context->arena_capacity);
    return BAL_SUCCESS;
}

void
bal_jit_debug_destroy(const bal_allocator_t *BAL_RESTRICT   allocator,
                      bal_jit_debug_context_t *BAL_RESTRICT context)
{
    if (BAL_UNLIKELY(NULL == context))
    {
        return;
    }

    if (BAL_UNLIKELY(NULL == allocator))
    {
        BAL_LOG_ERROR(&context->logger, "Aborting function: allocator is NULL.");
        return;
    }

    if (context->entries != NULL)
    {
        allocator->free(allocator->context,
                        context->entries,
                        context->entry_capacity * sizeof(bal_jit_block_entry_t));
        context->entries = NULL;
    }

    if (context->metadata_arena != NULL)
    {
        allocator->free(allocator->context, context->metadata_arena, context->arena_capacity);
        context->metadata_arena = NULL;
    }

    memset(context, 0, sizeof(bal_jit_block_entry_t));
}
