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

bal_error_t
bal_jit_debug_add_block(bal_jit_debug_context_t *BAL_RESTRICT         context,
                        void *BAL_RESTRICT                            rx_start,
                        uint32_t                                      rx_size,
                        uint64_t                                      base_guest_pc,
                        const bal_jit_instruction_map_t *BAL_RESTRICT mapping,
                        uint32_t                                      instruction_count)
{
    const bal_error_t invalid_argument = BAL_ERROR_INVALID_ARGUMENT;

    if (BAL_UNLIKELY(NULL == context))
    {
        return invalid_argument;
    }

    if (BAL_UNLIKELY(NULL == rx_start))
    {
        BAL_LOG_ERROR(&context->logger, "Aborting function: rx_start is NULL.");
        return invalid_argument;
    }

    if (BAL_UNLIKELY(NULL == mapping))
    {
        BAL_LOG_ERROR(&context->logger, "Aborting function: mapping is NULL.");
        return invalid_argument;
    }

    if (BAL_UNLIKELY(0 == instruction_count))
    {
        BAL_LOG_ERROR(&context->logger, "Aborting function: instruction_count == 0");
        return invalid_argument;
    }

    if (BAL_UNLIKELY(context->entry_count >= context->entry_capacity))
    {
        BAL_LOG_WARN(&context->logger,
                     "Aborting function: JIT debug entries full, block tracking skipped.");
        return BAL_ERROR_CAPACITY_TOO_BIG;
    }

    const size_t total_mapping_size    = instruction_count * sizeof(bal_jit_instruction_map_t);
    const size_t total_memory_required = total_mapping_size + sizeof(bal_jit_block_metadata_t);

    if (BAL_UNLIKELY(context->arena_offset + total_memory_required > context->arena_capacity))
    {
        BAL_LOG_WARN(&context->logger,
                     "Aborting function: JIT debug arena full, block tracking skipped.");
        return BAL_ERROR_CAPACITY_TOO_BIG;
    }

    uint8_t *arena_cursor = context->metadata_arena + context->arena_offset;
    bal_jit_block_metadata_t *BAL_RESTRICT metadata = (bal_jit_block_metadata_t *)arena_cursor;
    metadata->base_guest_pc                         = base_guest_pc;
    metadata->instruction_count                     = instruction_count;
    bal_jit_instruction_map_t *arena_mapping
        = (bal_jit_instruction_map_t *)(arena_cursor + sizeof(bal_jit_block_metadata_t));
    metadata->mappings = arena_mapping;
    memcpy(arena_mapping, mapping, total_mapping_size);
    context->arena_offset += total_memory_required;

    bal_jit_block_entry_t *BAL_RESTRICT entry = &context->entries[context->entry_count];
    entry->rx_start                           = rx_start;
    entry->rx_size                            = rx_size;
    entry->metadata                           = metadata;
    context->entry_count++;
    return BAL_SUCCESS;
}
