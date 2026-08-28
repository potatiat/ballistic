#include "fixture/bal_assembler_fixture.h"
#include "unity.h"

static void
test_BalAssemblerEmitRet_NullAssemblerDoesNotCrash(void)
{
    bal_emit_ret(NULL, BAL_REGISTER_X30);
    TEST_PASS();
}

static void
test_BalAssemblerEmitRet_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;
    bal_emit_ret(&bal_test_assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitRet_DeadMagicReturnsErrorStructCorrupted(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    bal_emit_ret(&bal_test_assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitRet_RnOutOfRangeReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_ret(&bal_test_assembler, 32U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL_UINT32(0, bal_test_code_buffer[0]);
}

static void
test_BalAssemblerEmitRet_PoisonedStatusDoesNotEmit(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    bal_emit_ret(&bal_test_assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL_UINT32(0, bal_test_code_buffer[0]);
}

static void
test_BalAssemblerEmitRet_FullBufferReturnsErrorInstructionOverflow(void)
{
    (void)bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 1U);
    bal_emit_ret(&bal_test_assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);

    bal_emit_ret(&bal_test_assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL(BAL_ERROR_INSTRUCTION_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalAssemblerEmitRet_NullAssemblerDoesNotCrash);
    RUN_TEST(test_BalAssemblerEmitRet_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitRet_DeadMagicReturnsErrorStructCorrupted);
    RUN_TEST(test_BalAssemblerEmitRet_RnOutOfRangeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitRet_PoisonedStatusDoesNotEmit);
    RUN_TEST(test_BalAssemblerEmitRet_FullBufferReturnsErrorInstructionOverflow);
    return UNITY_END();
}

/*** end of file ***/