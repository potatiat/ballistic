#include "setup.h"
#include <cinttypes>
#include <cstdlib>
#include <gtest/gtest.h>

TEST(Translation, Movk)
{
    test_context_t context = {};
    test_setup(&context);
    constexpr bal_register_index_t registers[] = {
        BAL_REGISTER_X0, BAL_REGISTER_X1, BAL_REGISTER_X15, BAL_REGISTER_X30, BAL_REGISTER_X31,
    };
    constexpr uint16_t immediates[] = { 0, 1, 0xFFFF, 0xAAAA, 0x5555, 0x1234 };
    constexpr uint8_t  shifts[]     = { 0, 16, 32, 48 };

    constexpr size_t registers_count = std::size(registers);

    for (const bal_register_index_t r : registers)
    {
        for (const unsigned short immediate : immediates)
        {
            for (const unsigned char shift : shifts)
            {
                bal_emit_movk(&context.assembler, r, immediate, shift);
            }
        }
    }

    bal_emit_ret(&context.assembler, BAL_REGISTER_X0);
    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(&context.engine,
                         &context.interface,
                         &entry_point,
                         context.assembler.offset * sizeof(uint32_t));
    bal_instruction_t *ir_start  = context.engine.instructions;
    bal_instruction_t *ir_cursor = context.engine.instructions;

    for (size_t r = 0; r < registers_count; ++r)
    {
        for (const unsigned short immediate : immediates)
        {
            for (const unsigned char shift : shifts)
            {
                // MOVK emits AND then ADD.

                auto opcode1 = static_cast<bal_opcode_t>(*ir_cursor >> BAL_OPCODE_SHIFT_POSITION);

                // The register is uninitialized so skip the instruction that loads it from memory.
                //
                if (OPCODE_GET_REGISTER == opcode1)
                {
                    ++ir_cursor;
                    opcode1 = static_cast<bal_opcode_t>(*ir_cursor >> BAL_OPCODE_SHIFT_POSITION);
                }

                if (opcode1 != OPCODE_AND)
                {
                    const size_t ir_instruction_offset = reinterpret_cast<uintptr_t>(ir_cursor)
                                                         - reinterpret_cast<uintptr_t>(ir_start);
                    fprintf(stderr,
                            "FAIL: [+0x%04zx] %08llx Expected OPCODE_AND for MOVK mask\n",
                            ir_instruction_offset,
                            static_cast<unsigned long long>(*ir_cursor));
                    GTEST_FAIL();
                }

                const uint32_t ssa_index
                    = *ir_cursor >> BAL_SOURCE2_SHIFT_POSITION & BAL_SOURCE_MASK_WITH_FLAG;

                if (!(ssa_index & BAL_IS_CONSTANT_BIT_POSITION))
                {
                    const auto ir_instruction_offset = reinterpret_cast<uintptr_t>(ir_cursor)
                                                       - reinterpret_cast<uintptr_t>(ir_start);
                    fprintf(stderr,
                            "FAIL: [+0x%04zx] %08llx AND mask operand is not a constant.\n",
                            ir_instruction_offset,
                            static_cast<unsigned long long>(*ir_cursor));
                    GTEST_FAIL();
                }

                const uint64_t actual_mask
                    = context.engine.constants[ssa_index & ~BAL_IS_CONSTANT_BIT_POSITION];
                const uint64_t expected_mask = ~(0xFFFFULL << shift);

                if (actual_mask != expected_mask)
                {
                    const size_t ir_instruction_offset = reinterpret_cast<uintptr_t>(ir_cursor)
                                                         - reinterpret_cast<uintptr_t>(ir_start);
                    fprintf(stderr,
                            "FAIL:  [+0x%04zx] %08llx Shift: %d, Expected Mask: %" PRIX64
                            ", Actual Mask: %" PRIX64 "\n",
                            ir_instruction_offset,
                            static_cast<unsigned long long>(*ir_cursor),
                            shift,
                            expected_mask,
                            actual_mask);
                    GTEST_FAIL();
                }

                ++ir_cursor;

                // Verify ADD instruction.

                const auto opcode2
                    = static_cast<bal_opcode_t>(*ir_cursor >> BAL_OPCODE_SHIFT_POSITION);

                if (opcode2 != OPCODE_ADD)
                {
                    const size_t ir_instruction_offset = reinterpret_cast<uintptr_t>(ir_cursor)
                                                         - reinterpret_cast<uintptr_t>(ir_start);
                    fprintf(stderr,
                            "FAIL: [+0x%04zx] %08llx Expected OPCODE_ADD for MOVK value.\n",
                            ir_instruction_offset,
                            static_cast<unsigned long long>(*ir_cursor));
                    GTEST_FAIL();
                }

                const uint32_t pool_index
                    = *ir_cursor >> BAL_SOURCE2_SHIFT_POSITION & BAL_SOURCE_MASK;
                const uint64_t expected_immediate = static_cast<uint64_t>(immediate) << shift;
                const uint64_t actual_immediate   = context.engine.constants[pool_index];

                if (expected_immediate != actual_immediate)
                {
                    const size_t ir_instruction_offset = reinterpret_cast<uintptr_t>(ir_cursor)
                                                         - reinterpret_cast<uintptr_t>(ir_start);
                    fprintf(stderr,
                            "FAIL: [+0x%04zx] %08llx value mismatch. Expected %" PRIX64
                            ", Got %" PRIX64 "\n",
                            ir_instruction_offset,
                            static_cast<unsigned long long>(*ir_cursor),
                            expected_immediate,
                            actual_immediate);
                    fprintf(stderr, "   Pool Index: %u\n", pool_index);
                    GTEST_FAIL();
                }
                ++ir_cursor;
            }
        }
    }

    test_teardown(&context);
}

/*** end of file ***/
