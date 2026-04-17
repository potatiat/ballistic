#include "setup.h"
#include <cinttypes>
#include <gtest/gtest.h>

TEST(Translation, Movz)
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
                bal_emit_movz(&context.assembler, r, immediate, shift);
            }
        }
    }

    bal_emit_ret(&context.assembler, BAL_REGISTER_X0);
    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(&context.engine,
                         &context.interface,
                         &entry_point,
                         context.assembler.offset * sizeof(uint32_t));
    const bal_instruction_t *BAL_RESTRICT ir       = context.engine.instructions;
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
                const uint64_t expected_immediate = static_cast<uint64_t>(immediate) << shift;
                const uint64_t actual_immediate   = context.engine.constants[pool_index];

                if (expected_immediate != actual_immediate)
                {
                    fprintf(stderr,
                            "FAIL: ARM Inst %08X value mismatch. Expected %" PRIX64 ", Got %" PRIX64
                            "\n",
                            context.assembler.buffer[ir_index],
                            expected_immediate,
                            actual_immediate);
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
