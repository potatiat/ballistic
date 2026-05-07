#include "backend/x86/bal_x86_assembler.h"
#include <stdbool.h>
#include <string.h>

BAL_HOT static bool can_emit(bal_x86_assembler_t *assembler, size_t size);
BAL_HOT static void emit8(uint8_t **cursor, uint8_t value);
BAL_HOT static void emit32(uint8_t **cursor, uint32_t value);
BAL_HOT static void emit64(uint8_t **cursor, uint64_t value);
BAL_HOT static void emit_rex(uint8_t **cursor, uint8_t w, uint8_t r, uint8_t b);

/// Emits the ModR/M byte for Register-to-Register operations.
BAL_HOT static void emit_modrm_register(uint8_t          **cursor,
                                        bal_x86_register_t reg,
                                        bal_x86_register_t rm);

/// Emits the ModR/M byte for Memory Addressing: [RBP + disp32].
BAL_HOT static void emit_modrm_memory_disp32_rbp(uint8_t **cursor, bal_x86_register_t reg);

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

    const size_t instruction_size = 7;
    const bool   can_emit_status  = can_emit(assembler, instruction_size);

    if (BAL_UNLIKELY(false == can_emit_status))
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger,
                  "[0x%04zx] mov r%d, [rbp + 0x%X]",
                  assembler->offset,
                  destination,
                  offset);

    uint8_t      *cursor        = assembler->buffer + assembler->offset;
    const uint8_t w             = 1;
    const uint8_t r             = (uint8_t)destination >> 3;
    const uint8_t b             = 0;
    const uint8_t opcode        = 0X8B;
    uint8_t      *buffer_cursor = assembler->buffer + assembler->offset;
    emit_rex(&cursor, w, r, b);
    emit8(&cursor, opcode);
    emit_modrm_memory_disp32_rbp(&buffer_cursor, destination);
    emit32(&cursor, (uint32_t)offset);
    assembler->offset = (size_t)(cursor - assembler->buffer);
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
    const uint8_t w             = 1;
    const uint8_t r             = (uint8_t)source >> 3;
    const uint8_t b             = 0;
    const uint8_t opcode        = 0X89;
    uint8_t      *buffer_cursor = assembler->buffer + assembler->offset;
    emit_rex(&buffer_cursor, w, r, b);
    emit8(&buffer_cursor, opcode);
    emit_modrm_memory_disp32_rbp(&buffer_cursor, source);
    emit32(&buffer_cursor, (uint32_t)offset);
    assembler->offset = (size_t)(buffer_cursor - assembler->buffer);
}

void
bal_x86_emit_mov_r64_r64(bal_x86_assembler_t     *assembler,
                         const bal_x86_register_t destination,
                         const bal_x86_register_t source)
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

    const size_t instruction_size_bytes = 3;
    const bool   can_emit_status        = can_emit(assembler, instruction_size_bytes);

    if (false == can_emit_status)
    {
        return;
    }

    BAL_LOG_DEBUG(
        &assembler->logger, "[+0x%04zx] mov r%d, r%d", assembler->offset, destination, source);
    const uint8_t w             = 1;
    const uint8_t r             = (uint8_t)destination >> 3;
    const uint8_t b             = (uint8_t)source >> 3;
    const uint8_t opcode        = 0x8BU;
    uint8_t      *buffer_cursor = assembler->buffer + assembler->offset;
    emit_rex(&buffer_cursor, w, r, b);
    emit8(&buffer_cursor, opcode);
    emit_modrm_register(&buffer_cursor, destination, source);
    assembler->offset = (size_t)(buffer_cursor - assembler->buffer);
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
    const uint8_t w             = 1;
    const uint8_t r             = 0;
    const uint8_t b             = (uint8_t)destination >> 3;
    uint8_t      *buffer_cursor = assembler->buffer + assembler->offset;
    emit_rex(&buffer_cursor, w, r, b);
    emit8(&buffer_cursor, 0xB8 + (destination & 7));
    emit64(&buffer_cursor, immediate);
    assembler->offset = (size_t)(buffer_cursor - assembler->buffer);
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
    uint8_t *buffer_cursor = assembler->buffer + assembler->offset;
    emit8(&buffer_cursor, 0XC3);
    assembler->offset = (size_t)(buffer_cursor - assembler->buffer);
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

    const size_t instruction_size_bytes = 2;
    const bool   can_emit_status        = can_emit(assembler, instruction_size_bytes);

    if (false == can_emit_status)
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger, "[+0x%04zx] push r%d", assembler->offset, reg);
    uint8_t *buffer_cursor = assembler->buffer + assembler->offset;

    if (reg > 7)
    {
        const uint8_t w = 0;
        const uint8_t r = 0;
        const uint8_t b = (uint8_t)reg >> 3;
        emit_rex(&buffer_cursor, w, r, b);
    }

    const uint8_t opcode = 0x50;
    emit8(&buffer_cursor, opcode + (reg & 7));
    assembler->offset = (size_t)(buffer_cursor - assembler->buffer);
}

void
bal_x86_emit_pop_r64(bal_x86_assembler_t *assembler, const bal_x86_register_t reg)
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

    const size_t instruction_size_bytes = 2;
    const bool   can_emit_status        = can_emit(assembler, instruction_size_bytes);

    if (false == can_emit_status)
    {
        return;
    }

    BAL_LOG_DEBUG(&assembler->logger, "[+0x%04zx] pop r%d", assembler->offset, reg);
    uint8_t *buffer_cursor = assembler->buffer + assembler->offset;

    if (reg > 7)
    {
        const uint8_t w = 0;
        const uint8_t r = 0;
        const uint8_t b = (uint8_t)reg >> 3;
        emit_rex(&buffer_cursor, w, r, b);
    }

    const uint8_t opcode = 0x58;
    emit8(&buffer_cursor, opcode + (reg & 7));
    assembler->offset = (size_t)(buffer_cursor - assembler->buffer);
}

static bool
can_emit(bal_x86_assembler_t *assembler, const size_t size)
{
    const size_t assembler_size = assembler->offset + size;

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
emit32(uint8_t **cursor, const uint32_t value)
{
    memcpy(*cursor, &value, sizeof(uint32_t));
    *cursor += sizeof(uint32_t);
}

static void
emit64(uint8_t **cursor, uint64_t const value)
{
    memcpy(*cursor, &value, sizeof(uint64_t));
    *cursor += sizeof(uint64_t);
}

/// Emits the REX prefix.
/// w = 1 for 64-bit operands.
/// r = extension for the ModR/W `reg` field.
/// b = extension for the ModR/W `r/m` field or opcode register.
static void
emit_rex(uint8_t **cursor, const uint8_t w, const uint8_t r, const uint8_t b)
{
    const uint8_t rex = (uint8_t)(0x40U | (unsigned)w << 3U | (unsigned)r << 2U | b);
    emit8(cursor, rex);
}

void
emit_modrm_register(uint8_t **cursor, const bal_x86_register_t reg, const bal_x86_register_t rm)
{
    uint8_t const modrm = (uint8_t)(0xC0U | ((unsigned)reg & 7U) << 3U | (rm & 7));
    emit8(cursor, modrm);
}

void
emit_modrm_memory_disp32_rbp(uint8_t **cursor, const bal_x86_register_t reg)
{
    uint8_t const modrm = (uint8_t)(0x80U | ((uint8_t)reg & 7U) << 3U | 0x05U);
    emit8(cursor, modrm);
}

/*** end of file ***/
