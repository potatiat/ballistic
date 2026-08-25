#include "bal_assembler.h"
#include "bal_safety.h"
#include <stdbool.h>
#include <string.h>

static bool can_emit(bal_assembler_t *assembler);
static void emit_mov(
    bal_assembler_t *, const char *, bal_register_index_t, uint16_t, uint8_t, uint32_t);

bal_error_t
bal_assembler_init(bal_assembler_t   *assembler,
                   void              *buffer,
                   const size_t       size,
                   const bal_logger_t logger)
{
    if (NULL == assembler)
    {
        BAL_LOG_ERROR(&logger, "Assembler struct is NULL.");
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    assembler->buffer   = NULL;
    assembler->capacity = 0;
    assembler->offset   = 0;
    assembler->logger   = logger;
    assembler->status   = BAL_ERROR_INVALID_ARGUMENT;
    assembler->magic    = 0;

    if (NULL == buffer)
    {
        BAL_LOG_ERROR(&logger, "Aborting function: Buffer is NULL.");
        return assembler->status;
    }

    if (0 == size)
    {
        BAL_LOG_ERROR(&logger, "Aborting function: Buffer capacity is 0.");
        return assembler->status;
    }

    if ((uintptr_t)buffer % 4 != 0)
    {
        BAL_LOG_ERROR(&logger, "Aborting function: Buffer %p is not 4-byte aligned.", buffer);
        assembler->status = BAL_ERROR_MEMORY_ALIGNMENT;
        return assembler->status;
    }

    if (size > (SIZE_MAX / sizeof(uint32_t)))
    {
        BAL_LOG_ERROR(&logger,
                      "Aborting function: Buffer capacity %zu is too large and would "
                      "cause integer overflow.",
                      size);
        assembler->status = BAL_ERROR_CAPACITY_TOO_BIG;
        return assembler->status;
    }

    assembler->buffer   = (uint32_t *)buffer;
    assembler->capacity = size;
    assembler->offset   = 0;
    assembler->logger   = logger;
    assembler->status   = BAL_SUCCESS;
    assembler->magic    = BAL_ASSEMBLER_MAGIC_ALIVE;

    BAL_LOG_INFO(
        &logger, "Assembler initialized. Buffer: %p, Capacity: %zu instructions.", buffer, size);
    return BAL_SUCCESS;
}

void
bal_assembler_reset(bal_assembler_t *assembler)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (BAL_UNLIKELY(NULL == assembler->buffer))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->buffer == NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(0 == assembler->capacity))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->capacity == 0");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    assembler->offset = 0;
    assembler->status = BAL_SUCCESS;
    (void)memset(assembler->buffer, 0, assembler->capacity * sizeof(uint32_t));
}

void
bal_assembler_destroy(bal_assembler_t *assembler)
{
    if (NULL == assembler)
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    BAL_LOG_INFO(&assembler->logger, "Destroying assembler context. Buffer memory is NOT freed.");
    assembler->magic    = BAL_ASSEMBLER_MAGIC_DEAD;
    assembler->buffer   = NULL;
    assembler->capacity = 0;
    assembler->offset   = 0;
    assembler->status   = BAL_ERROR_STRUCT_CORRUPTED;
}

void
bal_emit_add_immediate(bal_assembler_t           *assembler,
                       const bal_register_index_t rd,
                       const bal_register_index_t rn,
                       const uint16_t             imm12,
                       const uint8_t              shift)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->status != BAL_SUCCESS.");
        return;
    }

    if (BAL_UNLIKELY(NULL == assembler->buffer))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->buffer is NULL.");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rd > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rd X%u out of range (0-31).", rd);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rn > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rn X%u out of range (0-31).", rd);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((imm12 > 0xFFF)))
    {
        BAL_LOG_ERROR(&assembler->logger, "Immediate 0x%X exceeds 12-bit limit (0xFFF).", imm12);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
    }

    if (shift != 0 && shift != 1)
    {
        BAL_LOG_ERROR(&assembler->logger, "%u is not a valid shift amount (0-1).", shift);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const bool can_emit_return_value = can_emit(assembler);

    if (false == can_emit_return_value)
    {
        return;
    }

    const uint32_t hard_coded_bits = 0x22U;
    const uint32_t sf              = 1U;

    uint32_t instruction = 0;
    instruction |= sf << 31;
    instruction |= hard_coded_bits << 23;
    instruction |= (uint32_t)shift << 22;
    instruction |= (uint32_t)imm12 << 10;
    instruction |= (uint32_t)rn << 5;
    instruction |= (uint32_t)rd;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0x%04zx] %08x ADD (Imm) X%u, X%u, #0x%03x, LSL #%u",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  rd,
                  rn,
                  imm12,
                  shift * 12);

    assembler->buffer[assembler->offset++] = instruction;
}

void
bal_emit_add_shifted_register(bal_assembler_t           *assembler,
                              const bal_register_index_t rd,
                              const bal_register_index_t rn,
                              const bal_register_index_t rm,
                              const uint8_t              shift,
                              const uint8_t              shift_type)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (BAL_UNLIKELY(NULL == assembler->buffer))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->buffer is NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->status != BAL_SUCCESS");
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rd > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rd X%u out of range (0-31).", rd);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rn > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rn X%u out of range (0-31).", rn);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rm > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rm X%u out of range (0-31).", rm);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(shift > 63U))
    {
        BAL_LOG_ERROR(&assembler->logger, "%u is not a valid shift amount (0-63).", shift);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(shift_type > 2U))
    {
        BAL_LOG_ERROR(&assembler->logger, "%u is not a valid shift type (0-2).", shift_type);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const bool can_emit_return_value = can_emit(assembler);

    if (BAL_UNLIKELY(false == can_emit_return_value))
    {
        return;
    }

    const uint32_t sf          = 1U;
    const uint32_t opcode      = 0x0BU;
    uint32_t       instruction = 0U;

    instruction |= sf << 31U;
    instruction |= opcode << 24U;
    instruction |= (uint32_t)shift_type << 22U;
    instruction |= (uint32_t)rm << 16U;
    instruction |= (uint32_t)shift << 10U;
    instruction |= (uint32_t)rn << 5U;
    instruction |= (uint32_t)rd;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0X%04zx] %08x Add (Shifted Register) X%u, X%u, X%u, shift %u",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  rd,
                  rn,
                  rm,
                  shift);

    assembler->buffer[assembler->offset++] = instruction;
}

void
bal_emit_b(bal_assembler_t *assembler, const int32_t offset)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (BAL_UNLIKELY(NULL == assembler->buffer))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->buffer is NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((offset & 0x3) != 0))
    {
        BAL_LOG_ERROR(&assembler->logger,
                      "Aborting function: Branch offset %d is not 4-byte aligned.",
                      offset);
        assembler->status = BAL_ERROR_PC_ALIGNMENT;
        return;
    }

    const int32_t imm26_signed = offset / 4;

    if (BAL_UNLIKELY(imm26_signed < -33554432 || imm26_signed > 33554431))
    {
        BAL_LOG_ERROR(&assembler->logger,
                      "Aborting function: Branch offset %d (imm26: %d) exceeds signed 26-bit "
                      "displacement limits.",
                      offset,
                      imm26_signed);
        assembler->status = BAL_ERROR_BRANCH_OFFSET_OVERFLOW;
        return;
    }

    const bool can_emit_return_value = can_emit(assembler);

    if (false == can_emit_return_value)
    {
        return;
    }

    if (assembler->status != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->status != BAL_SUCCESS");
        return;
    }

    const uint32_t hard_coded_bits = 0x14000000U;

    const uint32_t imm26       = (uint32_t)imm26_signed & 0x03FFFFFFU;
    const uint32_t instruction = hard_coded_bits | imm26;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0x%04zx] %08x B #%d",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  offset);

    assembler->buffer[assembler->offset++] = instruction;
}

void
bal_emit_br(bal_assembler_t *BAL_RESTRICT assembler, const bal_register_index_t rn)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (BAL_UNLIKELY(NULL == assembler->buffer))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->buffer is NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->status != BAL_SUCCESS");
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rn > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "X%u out of range (0-31)", rn);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const bool can_emit_return_status = can_emit(assembler);

    if (BAL_UNLIKELY(false == can_emit_return_status))
    {
        return;
    }

    const uint32_t hard_coded_bits = 0xD61F0000U;
    const uint32_t rn_shift        = 5U;
    const uint32_t instruction     = hard_coded_bits | rn << rn_shift;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0x%04zx] %08x BR X%u",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  rn);

    assembler->buffer[assembler->offset++] = instruction;
}

void
bal_emit_sub_immediate(bal_assembler_t           *assembler,
                       const bal_register_index_t rd,
                       const bal_register_index_t rn,
                       const uint16_t             imm12,
                       const uint8_t              shift)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (assembler->status != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->status != BAL_SUCCESS.");
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rd > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rd X%u out of range (0-31).", rd);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rn > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rn X%u out of range (0-31).", rn);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(imm12 > 0xFFFU))
    {
        BAL_LOG_ERROR(&assembler->logger, "Immediate 0x%X exceeds 12-bit limit (0xFFF).", imm12);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (shift != 0U && shift != 1U)
    {
        BAL_LOG_ERROR(&assembler->logger, "%u is not a valid shift amount (0-1).", shift);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const bool can_emit_return_value = can_emit(assembler);

    if (false == can_emit_return_value)
    {
        return;
    }

    const uint32_t hard_coded_bits = 0xA2U;
    const uint32_t sf              = 1U;

    uint32_t instruction = 0;
    instruction |= sf << 31;
    instruction |= hard_coded_bits << 23;
    instruction |= (uint32_t)shift << 22;
    instruction |= (uint32_t)imm12 << 10;
    instruction |= (uint32_t)rn << 5;
    instruction |= (uint32_t)rd;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0x%04zx] %08x SUB (Imm) X%u, #0x%04x, LSL #%u",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  rd,
                  imm12,
                  shift);

    assembler->buffer[assembler->offset++] = instruction;
}

void
bal_emit_movz(bal_assembler_t           *assembler,
              const bal_register_index_t rd,
              const uint16_t             imm,
              const uint8_t              shift)
{
    emit_mov(assembler, "MOVZ", rd, imm, shift, 0x2);
}

void
bal_emit_movk(bal_assembler_t           *assembler,
              const bal_register_index_t rd,
              const uint16_t             imm,
              const uint8_t              shift)
{
    emit_mov(assembler, "MOVK", rd, imm, shift, 0x3);
}

void
bal_emit_movn(bal_assembler_t           *assembler,
              const bal_register_index_t rd,
              const uint16_t             imm,
              const uint8_t              shift)
{
    emit_mov(assembler, "MOVN", rd, imm, shift, 0x0);
}

void
bal_emit_ret(bal_assembler_t *assembler, const bal_register_index_t rn)
{
    if (NULL == assembler)
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (NULL == assembler->buffer)
    {
        BAL_LOG_ERROR(&assembler->logger, "assembler->buffer is NULL, aborting emission");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if ((uint32_t)rn > 31U)
    {
        BAL_LOG_ERROR(&assembler->logger, "X%u out of range (0-31).", rn);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (assembler->status != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&assembler->logger, "assembler->status != BAL_SUCCESS, aborting emission");
        return;
    }

    const bool can_emit_return_value = can_emit(assembler);

    if (false == can_emit_return_value)
    {
        return;
    }

    const uint32_t hard_coded_bits = 0xD65F0000U;
    const uint32_t rn_shift        = 5U;
    const uint32_t instruction     = hard_coded_bits | (uint32_t)rn << rn_shift;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0x%04zx] %08x RET X%u",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  rn);

    assembler->buffer[assembler->offset++] = instruction;
}

static bool
can_emit(bal_assembler_t *assembler)
{
    if (assembler->offset >= assembler->capacity)
    {
        BAL_LOG_ERROR(&assembler->logger,
                      "Aborting function: Assembler Overflow. Capacity %zu reached.",
                      assembler->capacity);
        assembler->status = BAL_ERROR_INSTRUCTION_OVERFLOW;
        return false;
    }

    return true;
}

static void
emit_mov(bal_assembler_t *BAL_RESTRICT assembler,
         const char *BAL_RESTRICT      mnemonic,
         const bal_register_index_t    rd,
         const uint16_t                imm,
         const uint8_t                 shift,
         const uint32_t                opcode)
{
    if (BAL_UNLIKELY(NULL == assembler))
    {
        return;
    }

    BAL_CHECK_MAGIC_VOID(assembler,
                         BAL_ASSEMBLER_MAGIC_ALIVE,
                         BAL_ASSEMBLER_MAGIC_DEAD,
                         "bal_assembler_t",
                         assembler->logger);

    if (BAL_UNLIKELY(NULL == assembler->buffer))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->buffer is NULL");
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(assembler->status != BAL_SUCCESS))
    {
        BAL_LOG_ERROR(&assembler->logger, "Aborting function: assembler->status != BAL_SUCCESS");
        return;
    }

    if (BAL_UNLIKELY((uint32_t)rd > 31U))
    {
        BAL_LOG_ERROR(&assembler->logger, "Rd X%u out of range (0-31).", rd);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    if (BAL_UNLIKELY(shift != 0U && shift != 16U && shift != 32U && shift != 48U))
    {
        BAL_LOG_ERROR(&assembler->logger, "%u is not a valid shift amount (0, 16, 32, 48).", shift);
        assembler->status = BAL_ERROR_INVALID_ARGUMENT;
        return;
    }

    const bool can_emit_return_value = can_emit(assembler);

    if (BAL_UNLIKELY(false == can_emit_return_value))
    {
        return;
    }

    const uint32_t sf          = 1U;
    const uint32_t hw          = shift / 16U;
    uint32_t       instruction = 0U;
    const uint32_t imm16       = imm;
    instruction |= sf << 31U;
    instruction |= (opcode & 0x7U) << 29U;
    instruction |= 0x25 << 23U; // 0b100101
    instruction |= hw << 21U;
    instruction |= imm16 << 5U;
    instruction |= rd;

    BAL_LOG_TRACE(&assembler->logger,
                  "[+0x%04zx] %08x %s X%u, #0x%04x, LSL #%u",
                  assembler->offset * sizeof(uint32_t),
                  instruction,
                  mnemonic,
                  rd,
                  imm,
                  shift);

    // This function argument isn't used in the log trace above on release builds because the log
    // trace is optimized out, making the compiler mark this variable as unused.
    (void)mnemonic;

    assembler->buffer[assembler->offset++] = instruction;
}

/*** end of file ***/
