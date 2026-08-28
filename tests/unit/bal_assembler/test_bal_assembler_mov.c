#include "fixture/bal_assembler_fixture.h"
#include "unity.h"

static void
test_BalAssemblerEmitMov_NullAssemblerDoesNotCrash(void)
{
    emit_mov(NULL, NULL, BAL_REGISTER_X0, 0U, 0U, 0x2U);
    TEST_PASS();
}

static void
test_BalAssemblerEmitMov_DeadMagicReturnsErrorStructCorrupted(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 0U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitMov_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;

    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 0U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitMov_PoisonedStatusDoesNotEmit(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 42U, 0U, 0x2U);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL_UINT32(0, bal_test_code_buffer[0]);
}

static void
test_BalAssemblerEmitMov_RdOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    emit_mov(&bal_test_assembler, NULL, 32U, 0U, 0U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitMov_ShiftOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 8U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitMov_FullBufferReturnsErrorInstructionOverflow(void)
{
    (void)bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 1U);
    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 0U, 0x2U);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);

    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 0U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INSTRUCTION_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitMov_CorrectShiftTypeReturnsSuccess(void)
{
    (void)bal_test_assembler_init_valid();
    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 16U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, bal_test_assembler.status);

    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 32U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, bal_test_assembler.status);

    emit_mov(&bal_test_assembler, NULL, BAL_REGISTER_X0, 0U, 48U, 0x2U);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, bal_test_assembler.status);
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalAssemblerEmitMov_NullAssemblerDoesNotCrash);
    RUN_TEST(test_BalAssemblerEmitMov_DeadMagicReturnsErrorStructCorrupted);
    RUN_TEST(test_BalAssemblerEmitMov_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitMov_PoisonedStatusDoesNotEmit);
    RUN_TEST(test_BalAssemblerEmitMov_RdOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitMov_ShiftOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitMov_FullBufferReturnsErrorInstructionOverflow);
    RUN_TEST(test_BalAssemblerEmitMov_CorrectShiftTypeReturnsSuccess);
    return UNITY_END();
}

/*** end of file ***/