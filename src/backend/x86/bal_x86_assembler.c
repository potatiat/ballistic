#include "backend/x86/bal_x86_assembler.h"
#include <stdbool.h>
#include <string.h>

BAL_HOT static bool can_emit(bal_x86_assembler_t *assembler, size_t size);
BAL_HOT static void emit8(bal_x86_assembler_t *assembler, uint8_t value);
BAL_HOT static void emit32(bal_x86_assembler_t *assembler, uint32_t value);
BAL_HOT static void emit64(bal_x86_assembler_t *assembler, uint64_t value);
BAL_HOT static void emit_rex(bal_x86_assembler_t *assembler, uint8_t w, uint8_t r, uint8_t b);
BAL_HOT static void emit8(uint8_t **cursor, uint8_t value);

/// Emits the ModR/M byte for Memory Addressing: [RBP + disp32].
BAL_HOT static void emit_modrm_memory_disp32_rbp(bal_x86_assembler_t *assembler,
                                                 bal_x86_register_t   reg);

bal_error_t
bal_x86_assembler_init(bal_x86_assembler_t *assembler,
                       void                *executable_buffer,
                       const size_t         size,
                       const bal_logger_t   logger)
{
    const bal_error_t error = BAL_ERROR_INVALID_ARGUMENT;

    if (NULL == assembler)
    {
        BAL_LOG_ERROR(&logger, "Assembler is NULL, aborting initialization");
        return error;
    }

    if (NULL == executable_buffer)
    {
        BAL_LOG_ERROR(&logger, "Buffer is NULL, aborting initialization");
        return error;
    }

    if (0 == size)
    {
        BAL_LOG_ERROR(&logger, "Size is 0, aborting initialization");
        return error;
    }

    assembler->buffer   = executable_buffer;
    assembler->capacity = size;
    assembler->offset   = 0;
    assembler->logger   = logger;
    assembler->status   = BAL_SUCCESS;

    BAL_LOG_INFO(&logger,
                 "x86 Assembler initialized. Buffer: %p, Capacity: %zu bytes",
                 executable_buffer,
                 size);
    return BAL_SUCCESS;
}

void
bal_x86_emit_load_r64_rbp_offset(bal_x86_assembler_t     *assembler,
                                 const bal_x86_register_t destination,
                                 const int32_t            offset)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler status != BAL_SUCCESS");
        return;
    }

    const bool can_emit_status = can_emit(assembler, 7);

    if (BAL_UNLIKELY(false == can_emit_status))
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger,
                  "[0x%04zx] mov r%d, [rbp + 0x%X]",
                  assembler->offset,
                  destination,
                  offset);

    const uint8_t w      = 1;
    const uint8_t r      = (uint8_t)destination >> 3;
    const uint8_t b      = 0;
    const uint8_t opcode = 0X8B;
    emit_rex(assembler, w, r, b);
    emit8(assembler, opcode);
    emit_modrm_memory_disp32_rbp(assembler, destination);
    emit32(assembler, (uint32_t)offset);
}

void
bal_x86_emit_store_r64_rbp_offset(bal_x86_assembler_t     *assembler,
                                  const bal_x86_register_t source,
                                  const int32_t            offset)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler status != BAL_SUCCESS");
        return;
    }

    const bool can_emit_status = can_emit(assembler, 7);

    if (BAL_UNLIKELY(false == can_emit_status))
    {
        return;
    }

    BAL_LOG_DEBUG(
        &assembler->logger, "[0x%04zx] mov[rbp + 0x%X], r%d", assembler->offset, offset, source);
    const uint8_t w      = 1;
    const uint8_t r      = (uint8_t)source >> 3;
    const uint8_t b      = 0;
    const uint8_t opcode = 0X89;
    emit_rex(assembler, w, r, b);
    emit8(assembler, opcode);
    emit_modrm_memory_disp32_rbp(assembler, source);
    emit32(assembler, (uint32_t)offset);
}

void
bal_x86_emit_mov_r64_imm64(bal_x86_assembler_t     *assembler,
                           const bal_x86_register_t destination,
                           const uint64_t           immediate)
{
    if (NULL == assembler)
    {
        return;
    }

    if (assembler->status != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&assembler->logger, "Assembler status != BAL_SUCCESS, aborting function");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const size_t instruction_size_bytes = 10;
    const bool   can_emit_status        = can_emit(assembler, instruction_size_bytes);

    if (false == can_emit_status)
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger,
                  "[+0x%04zx] mov r%d, 0x%llX",
                  assembler->offset,
                  destination,
                  (unsigned long long)immediate);
    const uint8_t w = 1;
    const uint8_t r = 0;
    const uint8_t b = (uint8_t)destination >> 3;
    emit_rex(assembler, w, r, b);
    emit8(assembler, 0xB8 + (destination & 7));
    emit64(assembler, immediate);
}

void
bal_x86_emit_ret(bal_x86_assembler_t *assembler)
{
    if (NULL == assembler)
    {
        return;
    }

    if (assembler->status != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&assembler->logger, "Assembler status != BAL_SUCCESS, aborting function");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const size_t instruction_size_bytes = 1;
    const bool   can_emit_status        = can_emit(assembler, instruction_size_bytes);

    if (false == can_emit_status)
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger, "[+0x%04zx] ret", assembler->offset);
    emit8(assembler, 0XC3);
}

void
bal_x86_emit_push_r64(bal_x86_assembler_t *assembler, const bal_x86_register_t reg)
{
    if (NULL == assembler)
    {
        return;
    }

    if (assembler->status != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&assembler->logger, "Assembler status != BAL_SUCCESS, aborting function");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const size_t instruction_size_bytes = 10;
    const bool   can_emit_status        = can_emit(assembler, instruction_size_bytes);

    if (false == can_emit_status)
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger, "[+0x%04zx] push r%d", assembler->offset, reg);

    if (reg > 7)
    {
        const uint8_t w = 0;
        const uint8_t r = 0;
        const uint8_t b = (uint8_t)reg >> 3;
        emit_rex(assembler, w, r, b);
    }

    const uint8_t opcode = 0x50;
    emit8(assembler, opcode + (reg & 7));
}

static bool
can_emit(bal_x86_assembler_t *assembler, const size_t size)
{
    const size_t assembler_size = assembler->offset * size;

    if (assembler_size > assembler->capacity)
    {
        BAL_LOG_ERROR(&assembler->logger,
                      "x86 Assembler Overflow. Capacity %zu reached",
                      assembler->capacity);
        assembler->status = BAL_ERROR_INSTRUCTION_OVERFLOW;
        return false;
    }

    return true;
}

static void
emit8(uint8_t **cursor, uint8_t const value)
{
    *(*cursor)++ = value;
}

static void
emit32(bal_x86_assembler_t *assembler, const uint32_t value)
{
    memcpy(&assembler->buffer[assembler->offset], &value, sizeof(uint32_t));
    assembler->offset += sizeof(uint32_t);
}

static void
emit64(bal_x86_assembler_t *assembler, uint64_t const value)
{
    memcpy(&assembler->buffer[assembler->offset], &value, sizeof(value));
    assembler->offset += sizeof(uint64_t);
}

/// Emits the REX prefix.
/// w = 1 for 64-bit operands.
/// r = extension for the ModR/W `reg` field.
/// b = extension for the ModR/W `r/m` field or opcode register.
static void
emit_rex(bal_x86_assembler_t *assembler, const uint8_t w, const uint8_t r, const uint8_t b)
{
    const uint8_t rex = (uint8_t)(0x40U | (unsigned)w << 3U | (unsigned)r << 2U | b);
    emit8(assembler, rex);
}

void
emit_modrm_memory_disp32_rbp(bal_x86_assembler_t *assembler, const bal_x86_register_t reg)
{
    uint8_t const modrm = (uint8_t)(0x80U | ((uint8_t)reg & 7U) << 3U | 0x05U);
    emit8(assembler, modrm);
}

/*** end of file ***/
