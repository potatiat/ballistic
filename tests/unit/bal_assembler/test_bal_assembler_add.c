#include "fixture/bal_assembler_fixture.h"
#include "unity.h"

static void
test_BalAssemblerEmitAddImmediate_NullAssemblerDoesNotCrash(void)
{
    bal_emit_add_immediate(NULL, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 0U);
    TEST_PASS();
}

static void
test_BalAssemblerEmitAddImmediate_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 42U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_DeadMagicReturnsErrorStructCorrupted(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 42U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_PoisonedStatusDoesNotEmit(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 42U, 0U);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_RdOutOfRangeErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_immediate(&bal_test_assembler, 32U, BAL_REGISTER_X0, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_RnOutOfRangeErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, 32U, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_ImmOutOfRangeErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 0x1000U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_ShiftOutOfRangeErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 0U, 2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_FullBufferReturnsErrorInstructionOverflow(void)
{
    (void)bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 1U);
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X31, BAL_REGISTER_X0, 42U, 0U);
    TEST_ASSERT_EQUAL(1, bal_test_assembler.offset);

    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 42U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INSTRUCTION_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddImmediate_Success(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 42U, 1U);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL_HEX32(0x9140A820, bal_test_code_buffer[0]);
}

static void
test_BalAssemblerEmitAddShiftRegister_NullAssemblerDoesNotCrash(void)
{
    bal_emit_add_shifted_register(NULL, BAL_REGISTER_X0, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 0U);
    TEST_PASS();
}

static void
test_BalAssemblerEmitAddShiftRegister_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, BAL_REGISTER_X2, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddShiftedRegister_DeadMagicReturnsErrorStructCorrupted(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, BAL_REGISTER_X2, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddShifted_PoisonedStatusDoesNotEmit(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, BAL_REGISTER_X2, 0U, 0U);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitAddShifted_RdOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_shifted_register(
        &bal_test_assembler, 32U, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerEmitAddShifted_RnOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X1, 32U, BAL_REGISTER_X0, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerEmitAddShifted_RmOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X1, BAL_REGISTER_X0, 32U, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerEmitAddShifted_ShiftOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X1, BAL_REGISTER_X0, BAL_REGISTER_X0, 64U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerEmitAddShifted_ShiftTypeOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X1, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 3U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerEmitAddShifted_FullBufferReturnsErrorInstructionOverflow(void)
{
    (void)bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 1U);
    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X1, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 0U);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);

    bal_emit_add_shifted_register(
        &bal_test_assembler, BAL_REGISTER_X1, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INSTRUCTION_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalAssemblerEmitAddImmediate_NullAssemblerDoesNotCrash);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_DeadMagicReturnsErrorStructCorrupted);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_PoisonedStatusDoesNotEmit);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_RdOutOfRangeErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_RnOutOfRangeErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_ImmOutOfRangeErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_ShiftOutOfRangeErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_FullBufferReturnsErrorInstructionOverflow);
    RUN_TEST(test_BalAssemblerEmitAddImmediate_Success);
    RUN_TEST(test_BalAssemblerEmitAddShiftRegister_NullAssemblerDoesNotCrash);
    RUN_TEST(test_BalAssemblerEmitAddShiftRegister_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddShiftedRegister_DeadMagicReturnsErrorStructCorrupted);
    RUN_TEST(test_BalAssemblerEmitAddShifted_PoisonedStatusDoesNotEmit);
    RUN_TEST(test_BalAssemblerEmitAddShifted_RdOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddShifted_RnOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddShifted_RmOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddShifted_ShiftOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddShifted_ShiftTypeOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitAddShifted_FullBufferReturnsErrorInstructionOverflow);
    return UNITY_END();
}

/*** end of file ***/