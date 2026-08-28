#include "fixture/bal_assembler_fixture.h"
#include "unity.h"

static void
test_BalAssemblerEmitSubImmediate_NullAssemblerDoesNotCrash(void)
{
    bal_emit_sub_immediate(NULL, BAL_REGISTER_X0, BAL_REGISTER_X0, 0U, 0U);
    TEST_PASS();
}

static void
test_BalAssemblerEmitSubImmediate_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 10U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitSubImmediate_DeadMagicReturnsErrorStructCorrupted(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 10U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitSubImmediate_PoisonedStatusDoesNotEmit(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 10U, 0U);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL_UINT32(0, bal_test_code_buffer[0]);
}

static void
test_BalAssemblerEmitSubImmediate_RdOutOfRangeReturnsInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_sub_immediate(&bal_test_assembler, 32U, BAL_REGISTER_X0, 10U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitSubImmediate_RnOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, 32U, 10U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitSubImmediate_ImmOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 0x1000U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitSubImmediate_ShiftOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 0U, 2U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitSubImmediate_FullBufferReturnsErrorInstructionOverflow(void)
{
    (void)bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 1U);
    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 10U, 1U);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);

    bal_emit_sub_immediate(&bal_test_assembler, BAL_REGISTER_X0, BAL_REGISTER_X1, 10U, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INSTRUCTION_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalAssemblerEmitSubImmediate_NullAssemblerDoesNotCrash);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_DeadMagicReturnsErrorStructCorrupted);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_PoisonedStatusDoesNotEmit);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_RdOutOfRangeReturnsInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_RnOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_ImmOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_ShiftOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitSubImmediate_FullBufferReturnsErrorInstructionOverflow);
    return UNITY_END();
}

/*** end of file ***/