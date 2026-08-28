#include "fixture/bal_assembler_fixture.h"
#include "unity.h"

static void
test_BalAssemblerEmitB_NullAssemblerDoesNotCrash(void)
{
    bal_emit_b(NULL, 16);
    TEST_PASS();
}

static void
test_BalAssemblerEmitB_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;
    bal_emit_b(&bal_test_assembler, 16);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitB_DeadMagicReturnsErrorStructCorrupted(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    bal_emit_b(&bal_test_assembler, 16);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitB_PoisonedStatusDoesNotEmit(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    bal_emit_b(&bal_test_assembler, 16);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitB_UnalignedOffsetReturnsErrorPcAlignment(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_b(&bal_test_assembler, 1);
    TEST_ASSERT_EQUAL(BAL_ERROR_PC_ALIGNMENT, bal_test_assembler.status);

    bal_test_assembler.status = BAL_SUCCESS;
    bal_emit_b(&bal_test_assembler, 2);
    TEST_ASSERT_EQUAL(BAL_ERROR_PC_ALIGNMENT, bal_test_assembler.status);

    bal_test_assembler.status = BAL_SUCCESS;
    bal_emit_b(&bal_test_assembler, -2);
    TEST_ASSERT_EQUAL(BAL_ERROR_PC_ALIGNMENT, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitB_OffsetOverflowPositiveReturnsErrorBranchOffsetOverflow(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_b(&bal_test_assembler, 1234217728);
    TEST_ASSERT_EQUAL(BAL_ERROR_BRANCH_OFFSET_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitB_OffsetOverflowNegativeReturnsErrorBranchOffsetOverflow(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_b(&bal_test_assembler, -134217732);
    TEST_ASSERT_EQUAL(BAL_ERROR_BRANCH_OFFSET_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
}

static void
test_BalAssemblerEmitB_FullBufferReturnsErrorInstructionOverflow(void)
{
    (void)bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 1U);
    bal_emit_b(&bal_test_assembler, 16);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);

    bal_emit_b(&bal_test_assembler, 16);
    TEST_ASSERT_EQUAL(BAL_ERROR_INSTRUCTION_OVERFLOW, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalAssemblerEmitB_NullAssemblerDoesNotCrash);
    RUN_TEST(test_BalAssemblerEmitB_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerEmitB_DeadMagicReturnsErrorStructCorrupted);
    RUN_TEST(test_BalAssemblerEmitB_PoisonedStatusDoesNotEmit);
    RUN_TEST(test_BalAssemblerEmitB_UnalignedOffsetReturnsErrorPcAlignment);
    RUN_TEST(test_BalAssemblerEmitB_OffsetOverflowPositiveReturnsErrorBranchOffsetOverflow);
    RUN_TEST(test_BalAssemblerEmitB_OffsetOverflowNegativeReturnsErrorBranchOffsetOverflow);
    RUN_TEST(test_BalAssemblerEmitB_FullBufferReturnsErrorInstructionOverflow);
    return UNITY_END();
}

/*** end of file ***/