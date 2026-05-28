#include "backend/x86/bal_x86_sliding_window.h"
#include <string.h>

#define ASSEMBLER_TEMPORARY_REGISTER BAL_X86_R11

BAL_HOT static void flush_single_macro(bal_x86_assembler_t   *assembler,
                                       const bal_x86_macro_t *macro);
BAL_HOT static void run_peephole_optimizer(bal_sliding_window_t *window);

bal_error_t
bal_sliding_window_init(bal_sliding_window_t *BAL_RESTRICT window,
                        bal_x86_assembler_t *BAL_RESTRICT  assembler)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    if (BAL_UNLIKELY(NULL == window))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: window is NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return assembler->status;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler status != BAL_SUCCESS");
        return assembler->status;
    }

    BAL_LOG_INFO(&assembler->logger, "Initializing sliding window");
    memset(window, 0, sizeof(*window));
    window->assembler = assembler;
    return BAL_SUCCESS;
}

void
bal_sliding_window_push(bal_sliding_window_t *window, const bal_x86_macro_t macro)
{
    if (BAL_UNLIKELY(NULL == window))
    {
        return;
    }

    bal_x86_assembler_t *BAL_RESTRICT assembler = window->assembler;

    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    size_t window_count = window->count;

    if (BAL_UNLIKELY(window_count == BAL_SLIDING_WINDOW_CAPACITY))
    {
        BAL_LOG_DEBUG(&assembler->logger,
                      "Sliding window capacity reached (%d), flushing macros",
                      BAL_SLIDING_WINDOW_CAPACITY);
        const bal_x86_macro_t *BAL_RESTRICT macro_cursor = window->macros;

        for (size_t i = 0; i < window_count; ++i)
        {
            flush_single_macro(assembler, macro_cursor++);
        }

        window_count = 0;
    }

    BAL_LOG_DEBUG(&assembler->logger,
                  "Pushing macro opcode id %d (dest: r%d, src: r%d, imm/off: 0x%llX)",
                  macro.opcode,
                  macro.destination,
                  macro.source,
                  (unsigned long long)macro.immediate_or_offset);
    window->macros[window_count++] = macro;
    window->count                  = window_count;
    run_peephole_optimizer(window);
}

void
bal_sliding_window_flush_all(bal_sliding_window_t *window)
{
    if (NULL == window)
    {
        return;
    }

    bal_x86_assembler_t *BAL_RESTRICT assembler = window->assembler;

    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    const size_t           window_count = window->count;
    const bal_x86_macro_t *macro_cursor = window->macros;

    for (size_t i = 0; i < window_count; ++i)
    {
        flush_single_macro(assembler, macro_cursor++);
    }

    window->count = 0;
}

void
flush_single_macro(bal_x86_assembler_t *BAL_RESTRICT   assembler,
                   const bal_x86_macro_t *BAL_RESTRICT macro)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    if (BAL_UNLIKELY(NULL == macro))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: macro is NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler status != BAL_SUCCESS");
        return;
    }

    const bal_x86_macro_opcode_t opcode              = macro->opcode;
    const bal_x86_register_t     destination         = macro->destination;
    const bal_x86_register_t     source              = macro->source;
    const uint64_t               immediate_or_offset = macro->immediate_or_offset;

    switch (opcode)
    {
        case BAL_X86_MACRO_NOP:
            BAL_LOG_DEBUG(&assembler->logger, "Flush skipped: NOP macro");
            break;
        case BAL_X86_MACRO_MOV_REGISTER_IMMEDIATE:
            bal_x86_emit_mov_r64_imm64(assembler, destination, immediate_or_offset);
            break;
        case BAL_X86_MACRO_LOAD:
            bal_x86_emit_load_r64_rbp_offset(assembler, destination, (int32_t)immediate_or_offset);
            break;
        case BAL_X86_MACRO_STORE:
            bal_x86_emit_store_r64_rbp_offset(assembler, source, (int32_t)immediate_or_offset);
            break;
        case BAL_X86_MACRO_AND_REGISTER_IMMEDIATE:
            bal_x86_emit_mov_r64_imm64(
                assembler, ASSEMBLER_TEMPORARY_REGISTER, immediate_or_offset);
            bal_x86_emit_and_r64_r64(assembler, destination, ASSEMBLER_TEMPORARY_REGISTER);
            break;
        case BAL_X86_MACRO_OR_REGISTER_IMMEDIATE:
            bal_x86_emit_mov_r64_imm64(
                assembler, ASSEMBLER_TEMPORARY_REGISTER, immediate_or_offset);
            bal_x86_emit_or_r64_r64(assembler, destination, ASSEMBLER_TEMPORARY_REGISTER);
            break;
        default:
            BAL_LOG_ERROR(
                &assembler->logger, "Aborting function: Unknown x86 macro opcode: %d", opcode);
            break;
    }
}

void
run_peephole_optimizer(bal_sliding_window_t *window)
{
    if (BAL_UNLIKELY(NULL == window) || BAL_UNLIKELY(NULL == window->assembler))
    {
        return;
    }

    const size_t count = window->count;

    if (0 == count)
    {
        BAL_LOG_WARN(&window->assembler->logger, "Aborting function: window is empty");
        return;
    }

    if (BAL_UNLIKELY(window->assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&window->assembler->logger,
                      "Aborting function: Assembler status != BAL_SUCCESS");
        return;
    }

    const bal_logger_t *BAL_RESTRICT logger             = &window->assembler->logger;
    bal_x86_macro_t *BAL_RESTRICT    macro1             = &window->macros[window->count - 1];
    const bal_x86_macro_opcode_t     macro1_opcode      = macro1->opcode;
    const bal_x86_register_t         macro1_destination = macro1->destination;
    const bal_x86_register_t         macro1_source      = macro1->source;

    // PEEPHOLE 1: Identity Move (mov rax, rax).
    if (BAL_UNLIKELY(BAL_X86_MACRO_MOV_REGISTER_REGISTER == macro1_opcode
                     && macro1_destination == macro1_source))
    {
        (void)logger;
        BAL_LOG_DEBUG(logger,
                      "Peephole: Killed identity MOV (r%d -> r%d)",
                      macro1_source,
                      macro1_destination);
        macro1->opcode = BAL_X86_MACRO_NOP;
        return;
    }

    if (count < 2)
    {
        return;
    }

    bal_x86_macro_t *BAL_RESTRICT macro2             = &window->macros[window->count - 2];
    const bal_x86_macro_opcode_t  macro2_opcode      = macro2->opcode;
    const bal_x86_register_t      macro2_destination = macro2->destination;
    const bal_x86_register_t      macro2_source      = macro2->source;

    // PEEPHOLE 2: Redundant MOV (1: mov rax, rbx. 2: mov rax, rbx).
    if (BAL_UNLIKELY(BAL_X86_MACRO_MOV_REGISTER_REGISTER == macro1_opcode
                     && BAL_X86_MACRO_MOV_REGISTER_REGISTER == macro2_opcode))
    {
        if (macro1_destination == macro2_destination && macro1_source == macro2_source)
        {
            BAL_LOG_DEBUG(logger,
                          "Peephole: Killed redundant MOV (r%d -> r%d)",
                          macro1_source,
                          macro1_destination);
            macro2->opcode = BAL_X86_MACRO_NOP;
        }
    }
}