#include "setup.h"
#include "gtest/gtest.h"

TEST(Translation, RetAsFirstInstruction)
{
    test_context_t context = {};
    test_setup(&context);
    constexpr bal_register_index_t rn = BAL_REGISTER_X31;
    bal_emit_ret(&context.assembler, rn);
    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(
        &context.engine, &context.interface, &entry_point, context.assembler.offset);
    const bal_instruction_t *BAL_RESTRICT instructions = context.engine.instructions;
    const auto                            opcode_get_register
        = static_cast<bal_opcode_t>(instructions[0] >> BAL_OPCODE_SHIFT_POSITION);

    if (opcode_get_register != OPCODE_GET_REGISTER)
    {
        fprintf(stderr, "FAIL: IR Inst 0 is not OPCODE_GET_REGISTER\n");
        GTEST_FAIL();
    }

    const auto opcode_return
        = static_cast<bal_opcode_t>(instructions[1] >> BAL_OPCODE_SHIFT_POSITION);

    if (opcode_return != OPCODE_RETURN)
    {
        fprintf(stderr, "FAIL: IR Inst 1 is not OPCODE_RETURN\n");
        GTEST_FAIL();
    }

    if (context.engine.instruction_count != 2)
    {
        fprintf(
            stderr, "FAIL: Expected 2 instructions, found %u\n", context.engine.instruction_count);
        GTEST_FAIL();
    }

    test_teardown(&context);
}

TEST(Translation, RetAsSecondInstruction)
{
    test_context_t context = {};
    test_setup(&context);
    bal_emit_movz(&context.assembler, BAL_REGISTER_X30, 0x1234, 0);
    bal_emit_ret(&context.assembler, BAL_REGISTER_X30);
    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(
        &context.engine, &context.interface, &entry_point, context.assembler.offset);
    const bal_instruction_t *BAL_RESTRICT instructions = context.engine.instructions;
    const auto                            opcode_const
        = static_cast<bal_opcode_t>(instructions[0] >> BAL_OPCODE_SHIFT_POSITION);

    if (opcode_const != OPCODE_CONST)
    {
        fprintf(stderr, "FAIL: IR Inst 0 is not OPCODE_CONST\n");
        GTEST_FAIL();
    }

    const auto opcode_return
        = static_cast<bal_opcode_t>(instructions[1] >> BAL_OPCODE_SHIFT_POSITION);

    if (opcode_return != OPCODE_RETURN)
    {
        fprintf(stderr, "FAIL: IR Inst 1 is not OPCODE_RETURN\n");
        GTEST_FAIL();
    }

    if (context.engine.instruction_count != 2)
    {
        fprintf(
            stderr, "FAIL: Expected 2 instructions, found %u\n", context.engine.instruction_count);
        GTEST_FAIL();
    }

    test_teardown(&context);
}

/*** end of file ***/
