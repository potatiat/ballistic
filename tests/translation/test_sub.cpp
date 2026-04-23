#include "setup.h"
#include <cinttypes>
#include <cstdio>
#include <cstdlib>
#include <gtest/gtest.h>

TEST(Translation, SubImmediate)
{
    test_context_t context;
    test_setup(&context);
    constexpr bal_register_index_t rds[] = {
        BAL_REGISTER_X0,
        BAL_REGISTER_X1,
        BAL_REGISTER_X15,
        BAL_REGISTER_X30,
    };

    constexpr uint8_t  rn           = BAL_REGISTER_X5;
    constexpr uint16_t immediates[] = { 0U, 1U, 0xAAAU, 0xFFFU };
    constexpr uint8_t  shifts[]     = { 0U, 1U };

    constexpr size_t rds_count = std::size(rds);

    for (const bal_register_index_t rd : rds)
    {
        for (const unsigned short immediate : immediates)
        {
            for (const unsigned char shift : shifts)
            {
                bal_emit_sub_immediate(&context.assembler, rd, rn, immediate, shift);
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

    // First IR instruction: GET_REGISTER v0 = X5 (lazy load of Rn on its
    // first read by the first SUB).
    //
    {
        const auto opcode = static_cast<bal_opcode_t>(ir[ir_index] >> BAL_OPCODE_SHIFT_POSITION);

        if (opcode != OPCODE_GET_REGISTER)
        {
            fprintf(
                stderr, "FAIL: IR Inst %zu is not GET_REGISTER (opcode=%d)\n", ir_index, opcode);
            GTEST_FAIL();
        }

        ++ir_index;
    }

    constexpr uint32_t rn_ssa_expected = 0U;

    for (size_t r = 0; r < rds_count; ++r)
    {
        for (const unsigned short immediate : immediates)
        {
            for (const unsigned char shift : shifts)
            {
                const bal_instruction_t inst = ir[ir_index];
                const auto opcode = static_cast<bal_opcode_t>(inst >> BAL_OPCODE_SHIFT_POSITION);

                if (opcode != OPCODE_SUB)
                {
                    fprintf(stderr, "FAIL: IR Inst %zu is not SUB (opcode=%d)\n", ir_index, opcode);
                    GTEST_FAIL();
                }

                const uint32_t src1
                    = inst >> BAL_SOURCE1_SHIFT_POSITION & BAL_SOURCE_MASK_WITH_FLAG;

                if (src1 & BAL_IS_CONSTANT_BIT_POSITION)
                {
                    fprintf(stderr,
                            "FAIL: IR Inst %zu src1 flagged as constant (expected SSA)\n",
                            ir_index);
                    GTEST_FAIL();
                }

                if (src1 != rn_ssa_expected)
                {
                    fprintf(stderr,
                            "FAIL: IR Inst %zu src1 mismatch. Expected v%u, got v%u\n",
                            ir_index,
                            rn_ssa_expected,
                            src1);
                    GTEST_FAIL();
                }

                const uint32_t src2_with_flag
                    = inst >> BAL_SOURCE2_SHIFT_POSITION & BAL_SOURCE_MASK_WITH_FLAG;

                if (!(src2_with_flag & BAL_IS_CONSTANT_BIT_POSITION))
                {
                    fprintf(stderr, "FAIL: IR Inst %zu src2 not flagged as constant\n", ir_index);
                    GTEST_FAIL();
                }

                const uint32_t pool_index   = src2_with_flag & BAL_SOURCE_MASK;
                const uint64_t expected_val = static_cast<uint64_t>(immediate) << (shift * 12U);
                const uint64_t actual_val   = context.engine.constants[pool_index];

                if (actual_val != expected_val)
                {
                    fprintf(stderr,
                            "FAIL: IR Inst %zu constant c%u mismatch. Expected 0x%" PRIX64
                            ", Got 0x%" PRIX64 "\n",
                            ir_index,
                            pool_index,
                            expected_val,
                            actual_val);
                    GTEST_FAIL();
                }
                ++ir_index;
            }
        }
    }

    test_teardown(&context);
}

/*** end of file ***/
