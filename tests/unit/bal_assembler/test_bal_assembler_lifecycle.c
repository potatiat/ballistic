#include "bal_safety.h"
#include "fixture/bal_assembler_fixture.h"
#include "unity.h"

static void
test_BalAssemblerInit_NullAssemblerReturnsErrorInvalidArgument(void)
{
    const bal_error_t error = bal_assembler_init(NULL, bal_test_code_buffer, TEST_BUFFER_CAPACITY);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, error);
}

static void
test_BalAssemblerInit_NullBufferReturnsErrorInvalidArgument(void)
{
    const bal_error_t error = bal_assembler_init(&bal_test_assembler, NULL, TEST_BUFFER_CAPACITY);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, error);
    TEST_ASSERT_NULL(bal_test_assembler.buffer);
    TEST_ASSERT_EQUAL_UINT32(BAL_MAGIC_UNINITIALIZED, bal_test_assembler.magic);
}

static void
test_BalAssemblerInit_InvalidBufferSizeReturnsErrorInvalidArgument(void)
{
    const bal_error_t error = bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, 0U);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, error);
    TEST_ASSERT_NULL(bal_test_assembler.buffer);
}

static void
test_BalAssemblerInit_UnalignedBufferReturnsErrorInvalidArgument(void)
{
    const bal_error_t error
        = bal_assembler_init(&bal_test_assembler, bal_test_unaligned_pointer, TEST_BUFFER_CAPACITY);
    TEST_ASSERT_EQUAL(BAL_ERROR_MEMORY_ALIGNMENT, error);
    TEST_ASSERT_NULL(bal_test_assembler.buffer);
}

static void
test_BalAssemblerInit_FullBufferReturnsErrorCapacityTooBig(void)
{
    const size_t      huge_size = SIZE_MAX / sizeof(uint32_t) + 1U;
    const bal_error_t error
        = bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, huge_size);
    TEST_ASSERT_EQUAL(BAL_ERROR_CAPACITY_TOO_BIG, error);
}

static void
test_BalAssemblerInit_Success(void)
{
    const bal_error_t error = bal_test_assembler_init_valid();
    TEST_ASSERT_EQUAL(BAL_SUCCESS, error);
    TEST_ASSERT_EQUAL_PTR(bal_test_code_buffer, bal_test_assembler.buffer);
    TEST_ASSERT_EQUAL_size_t(TEST_BUFFER_CAPACITY, bal_test_assembler.capacity);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_ALIVE, bal_test_assembler.magic);
}

static void
test_BalAssemblerReset_NullAssemblerNoCrash(void)
{
    bal_assembler_reset(NULL);
    TEST_PASS();
}

static void
test_BalAssemblerReset_NullBufferReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.buffer = NULL;
    bal_assembler_reset(&bal_test_assembler);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerReset_ZeroCapacityReturnsErrorInvalidArgument(void)
{
    (void)bal_test_assembler_init_valid();
    bal_test_assembler.capacity = 0U;
    bal_assembler_reset(&bal_test_assembler);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, bal_test_assembler.status);
}

static void
test_BalAssemblerReset_FreedAssemblerSetsDeadMagicNumber(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_DEAD, bal_test_assembler.magic);

    bal_assembler_reset(&bal_test_assembler);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
}

static void
test_BalAssemblerReset_Success(void)
{
    (void)bal_test_assembler_init_valid();
    bal_emit_ret(&bal_test_assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL_size_t(1, bal_test_assembler.offset);
    TEST_ASSERT_NOT_EQUAL(0, bal_test_code_buffer[0]);

    bal_assembler_reset(&bal_test_assembler);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_UINT32(0, bal_test_code_buffer[0]);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_ALIVE, bal_test_assembler.magic);
}

static void
test_BalAssemblerDestroy_NoCrash(void)
{
    bal_assembler_destroy(NULL);
    TEST_PASS();
}

static void
test_BalAssemblerDestroy_FreedAssemblerSetsDeadMagicNumber(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    bal_assembler_destroy(&bal_test_assembler);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_DEAD, bal_test_assembler.magic);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
}

static void
test_BalAssemblerDestroy_Success(void)
{
    (void)bal_test_assembler_init_valid();
    bal_assembler_destroy(&bal_test_assembler);
    TEST_ASSERT_NULL(bal_test_assembler.buffer);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.capacity);
    TEST_ASSERT_EQUAL_size_t(0, bal_test_assembler.offset);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, bal_test_assembler.status);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_DEAD, bal_test_assembler.magic);
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalAssemblerInit_NullAssemblerReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerInit_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerInit_InvalidBufferSizeReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerInit_UnalignedBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerInit_FullBufferReturnsErrorCapacityTooBig);
    RUN_TEST(test_BalAssemblerInit_Success);
    RUN_TEST(test_BalAssemblerReset_NullAssemblerNoCrash);
    RUN_TEST(test_BalAssemblerReset_NullBufferReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerReset_ZeroCapacityReturnsErrorInvalidArgument);
    RUN_TEST(test_BalAssemblerReset_FreedAssemblerSetsDeadMagicNumber);
    RUN_TEST(test_BalAssemblerReset_Success);
    RUN_TEST(test_BalAssemblerDestroy_NoCrash);
    RUN_TEST(test_BalAssemblerDestroy_FreedAssemblerSetsDeadMagicNumber);
    RUN_TEST(test_BalAssemblerDestroy_Success);
    return UNITY_END();
}