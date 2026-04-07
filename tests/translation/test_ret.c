#include "setup.h"
#include "stdlib.h"

static int
test_ret_as_first_instruction(test_context_t *context)
{
    int                        return_code = EXIT_SUCCESS;
    const bal_register_index_t rn          = BAL_REGISTER_X31;
    bal_emit_ret(&context->assembler, rn);
    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(
        &context->engine, &context->interface, &entry_point, context->assembler.offset);
    const bal_instruction_t *BAL_RESTRICT instructions = context->engine.instructions;
    const bal_opcode_t opcode_get_register = instructions[0] >> BAL_OPCODE_SHIFT_POSITION;

    if (opcode_get_register != OPCODE_GET_REGISTER)
    {
        fprintf(stderr, "FAIL: IR Inst 0 is not OPCODE_GET_REGISTER\n");
        return_code = EXIT_FAILURE;
        goto end;
    }

    const bal_opcode_t opcode_return = instructions[1] >> BAL_OPCODE_SHIFT_POSITION;

    if (opcode_return != OPCODE_RETURN)
    {
        fprintf(stderr, "FAIL: IR Inst 1 is not OPCODE_RETURN\n");
        return_code = EXIT_FAILURE;
        goto end;
    }

    if (context->engine.instruction_count != 2)
    {
        fprintf(
            stderr, "FAIL: Expected 2 instructions, found %u\n", context->engine.instruction_count);
        return_code = EXIT_FAILURE;
    }

end:
    return return_code;
}

static int
test_ret_as_second_instruction(test_context_t *context)
{
    int return_code = EXIT_SUCCESS;
    bal_emit_movz(&context->assembler, BAL_REGISTER_X30, 0x1234, 0);
    bal_emit_ret(&context->assembler, BAL_REGISTER_X30);
    bal_guest_address_t entry_point = 0x0;
    bal_engine_translate(
        &context->engine, &context->interface, &entry_point, context->assembler.offset);
    const bal_instruction_t *BAL_RESTRICT instructions = context->engine.instructions;
    const bal_opcode_t opcode_const = instructions[0] >> BAL_OPCODE_SHIFT_POSITION;

    if (opcode_const != OPCODE_CONST)
    {
        fprintf(stderr, "FAIL: IR Inst 0 is not OPCODE_CONST\n");
        return_code = EXIT_FAILURE;
        goto end;
    }

    const bal_opcode_t opcode_return = instructions[1] >> BAL_OPCODE_SHIFT_POSITION;

    if (opcode_return != OPCODE_RETURN)
    {
        fprintf(stderr, "FAIL: IR Inst 1 is not OPCODE_RETURN\n");
        return_code = EXIT_FAILURE;
        goto end;
    }

    if (context->engine.instruction_count != 2)
    {
        fprintf(
            stderr, "FAIL: Expected 2 instructions, found %u\n", context->engine.instruction_count);
        return_code = EXIT_FAILURE;
    }

end:
    return return_code;
}

int
main(void)
{
    test_context_t context      = { 0 };
    int            return_value = 0;
    BAL_TEST_FUNCTION(test_ret_as_first_instruction);
    BAL_TEST_FUNCTION(test_ret_as_second_instruction);
    return return_value;
}
