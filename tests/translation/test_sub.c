#include "setup.h"
#include <inttypes.h>
#include <stdlib.h>

static int
test_sub_immediate(test_context_t *context)
{
    int                        return_code = EXIT_FAILURE;
    const bal_register_index_t rds[]       = {
        BAL_REGISTER_X0,
        BAL_REGISTER_X1,
        BAL_REGISTER_X15,
        BAL_REGISTER_X30,
    };

    // Fixed Rn so the engine emits a single GET_REGISTER at the head of the
    // IR stream. Every subsequent SUB reuses that SSA index for its src1,
    // which keeps the test's expected IR shape trivial to describe.
    //
    const uint8_t  rn           = BAL_REGISTER_X5;
    const uint16_t immediates[] = { 0U, 1U, 0xAAAU, 0xFFFU };
    const uint8_t  shifts[]     = { 0U, 1U };

    const size_t rds_count        = sizeof(rds) / sizeof(rds[0]);
    const size_t immediates_count = sizeof(immediates) / sizeof(immediates[0]);
    const size_t shifts_count     = sizeof(shifts) / sizeof(shifts[0]);

    for (size_t r = 0; r < rds_count; ++r)
    {
        for (size_t i = 0; i < immediates_count; ++i)
        {
            for (size_t s = 0; s < shifts_count; ++s)
            {
                bal_emit_sub_immediate(&context->assembler, rds[r], rn, immediates[i], shifts[s]);
            }
        }
    }

    bal_emit_ret(&context->assembler, BAL_REGISTER_X0);

    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(&context->engine,
                         &context->interface,
                         &entry_point,
                         context->assembler.offset * sizeof(uint32_t));

    const bal_instruction_t *BAL_RESTRICT ir       = context->engine.instructions;
    size_t                                ir_index = 0;

    // First IR instruction: GET_REGISTER v0 = X5 (lazy load of Rn on its
    // first read by the first SUB).
    //
    {
        bal_opcode_t opcode = ir[ir_index] >> BAL_OPCODE_SHIFT_POSITION;

        if (opcode != OPCODE_GET_REGISTER)
        {
            fprintf(
                stderr, "FAIL: IR Inst %zu is not GET_REGISTER (opcode=%d)\n", ir_index, opcode);
            goto end;
        }

        ++ir_index;
    }

    const uint32_t rn_ssa_expected = 0U;

    for (size_t r = 0; r < rds_count; ++r)
    {
        for (size_t i = 0; i < immediates_count; ++i)
        {
            for (size_t s = 0; s < shifts_count; ++s)
            {
                const bal_instruction_t inst   = ir[ir_index];
                bal_opcode_t            opcode = inst >> BAL_OPCODE_SHIFT_POSITION;

                if (opcode != OPCODE_SUB)
                {
                    fprintf(stderr, "FAIL: IR Inst %zu is not SUB (opcode=%d)\n", ir_index, opcode);
                    goto end;
                }

                const uint32_t src1
                    = (inst >> BAL_SOURCE1_SHIFT_POSITION) & BAL_SOURCE_MASK_WITH_FLAG;

                if (src1 & BAL_IS_CONSTANT_BIT_POSITION)
                {
                    fprintf(stderr,
                            "FAIL: IR Inst %zu src1 flagged as constant (expected SSA)\n",
                            ir_index);
                    goto end;
                }

                if (src1 != rn_ssa_expected)
                {
                    fprintf(stderr,
                            "FAIL: IR Inst %zu src1 mismatch. Expected v%u, got v%u\n",
                            ir_index,
                            rn_ssa_expected,
                            src1);
                    goto end;
                }

                const uint32_t src2_with_flag
                    = (inst >> BAL_SOURCE2_SHIFT_POSITION) & BAL_SOURCE_MASK_WITH_FLAG;

                if (!(src2_with_flag & BAL_IS_CONSTANT_BIT_POSITION))
                {
                    fprintf(stderr, "FAIL: IR Inst %zu src2 not flagged as constant\n", ir_index);
                    goto end;
                }

                const uint32_t pool_index   = src2_with_flag & BAL_SOURCE_MASK;
                const uint64_t expected_val = (uint64_t)immediates[i] << (shifts[s] * 12U);
                const uint64_t actual_val   = context->engine.constants[pool_index];

                if (actual_val != expected_val)
                {
                    fprintf(stderr,
                            "FAIL: IR Inst %zu constant c%u mismatch. Expected 0x%" PRIX64
                            ", Got 0x%" PRIX64 "\n",
                            ir_index,
                            pool_index,
                            expected_val,
                            actual_val);
                    goto end;
                }

                ++ir_index;
            }
        }
    }

    return_code = EXIT_SUCCESS;

end:
    return return_code;
}

int
main(void)
{
    test_context_t context      = { 0 };
    int            return_value = 0;
    BAL_TEST_FUNCTION(test_sub_immediate);
    return return_value;
}

/*** end of file ***/
