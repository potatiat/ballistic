#include "setup.h"
#include <cinttypes>
#include <cstdlib>
#include <gtest/gtest.h>

TEST(Translation, Movn)
{
    test_context_t context = {};
    test_setup(&context);
    constexpr bal_register_index_t registers[] = {
        BAL_REGISTER_X0, BAL_REGISTER_X1, BAL_REGISTER_X15, BAL_REGISTER_X30, BAL_REGISTER_X31,
    };
    const uint16_t    immediates[] = { 0, 1, 0xFFFF, 0xAAAA, 0x5555, 0x1234 };
    constexpr uint8_t shifts[]     = { 0, 16, 32, 48 };

    constexpr size_t registers_count        = std::size(registers);
    size_t           assembler_buffer_index = 0;

    for (const bal_register_index_t r : registers)
    {
        for (const unsigned short immediate : immediates)
        {
            for (const unsigned char shift : shifts)
            {
                bal_emit_movn(&context.assembler, r, immediate, shift);
                ++assembler_buffer_index;
            }
        }
    }

    bal_emit_ret(&context.assembler, BAL_REGISTER_X0);

    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate_tier2(
        &context.engine, &context.interface, &entry_point, context.assembler.offset);
    const bal_instruction_t *BAL_RESTRICT ir = bal_engine_get_ir_instructions(&context.engine);
    size_t                                ir_index = 0;

    for (size_t r = 0; r < registers_count; ++r)
    {
        for (const unsigned short immediate : immediates)
        {
            for (const unsigned char shift : shifts)
            {
                const auto opcode
                    = static_cast<bal_opcode_t>(ir[ir_index] >> BAL_OPCODE_SHIFT_POSITION);

                if (opcode != OPCODE_CONST)
                {
                    fprintf(stderr, "FAIL: IR Inst %zu is not CONST\n", ir_index);
                    GTEST_FAIL();
                }

                const uint32_t pool_index
                    = ir[ir_index] >> BAL_SOURCE1_SHIFT_POSITION & BAL_SOURCE_MASK;

                // We inverse the expected immediate. This is the only important difference
                // between test_movz.c and test_movn.cpp.
                //
                const bal_constant_t expected_immediate
                    = ~(static_cast<uint64_t>(immediate) << shift);
                const bal_constant_t *actual_immediate
                    = bal_engine_get_constant(&context.engine, pool_index);

                GTEST_ASSERT_NE(actual_immediate, nullptr);

                if (expected_immediate != *actual_immediate)
                {
                    fprintf(stderr,
                            "FAIL: ARM Inst %08X value mismatch. Expected %" PRIX64 ", Got %" PRIX64
                            "\n",
                            context.assembler.buffer[assembler_buffer_index],
                            expected_immediate,
                            *actual_immediate);
                    fprintf(stderr, "   Pool Index: %u\n", pool_index);
                    GTEST_FAIL();
                }
                ++ir_index;
            }
        }
    }

    test_teardown(&context);
}

/*** end of file ***/
