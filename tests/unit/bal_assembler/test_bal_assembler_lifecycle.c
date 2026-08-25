#include "bal_assembler.h"
#include "bal_safety.h"
#include "unity.h"
#include <string.h>

#define TEST_BUFFER_CAPACITY 128

static bal_assembler_t assembler;
static uint32_t        code_buffer[TEST_BUFFER_CAPACITY];
static bal_logger_t    silent_logger;
static void           *unaligned_pointer;

void
setUp(void)
{
    memset(&assembler, 0, sizeof(assembler));
    memset(&code_buffer, 0, sizeof(code_buffer));
    memset(&silent_logger, 0, sizeof(silent_logger));
    silent_logger.min_level = BAL_LOG_LEVEL_NONE;
    unaligned_pointer       = code_buffer;

    if (0 == (uintptr_t)unaligned_pointer % 4)
    {
        unaligned_pointer += 1;
    }
}

void
tearDown(void)
{
}

static inline bal_error_t
init_valid(void)
{
    return bal_assembler_init(&assembler, code_buffer, TEST_BUFFER_CAPACITY, silent_logger);
}

static void
test_BalAssemblerInit_NullAssemblerReturnsErrorInvalidArgument(void)
{
    const bal_error_t error
        = bal_assembler_init(NULL, code_buffer, TEST_BUFFER_CAPACITY, silent_logger);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, error);
}

static void
test_BalAssemblerInit_NullBufferReturnsErrorInvalidArgument(void)
{
    const bal_error_t error
        = bal_assembler_init(&assembler, NULL, TEST_BUFFER_CAPACITY, silent_logger);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, error);
    TEST_ASSERT_NULL(assembler.buffer);
    TEST_ASSERT_EQUAL_UINT32(BAL_MAGIC_UNINITIALIZED, assembler.magic);
}

static void
test_BalAssemblerInit_InvalidBufferSizeReturnsErrorInvalidArgument(void)
{
    const bal_error_t error = bal_assembler_init(&assembler, code_buffer, 0, silent_logger);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, error);
    TEST_ASSERT_NULL(assembler.buffer);
}

static void
test_BalAssemblerInit_UnalignedBufferReturnsErrorInvalidArgument(void)
{
    const bal_error_t error
        = bal_assembler_init(&assembler, unaligned_pointer, TEST_BUFFER_CAPACITY, silent_logger);
    TEST_ASSERT_EQUAL(BAL_ERROR_MEMORY_ALIGNMENT, error);
    TEST_ASSERT_NULL(assembler.buffer);
}

static void
test_BalAssemblerInit_FullBufferReturnsErrorCapacityTooBig(void)
{
    const size_t      huge_size = SIZE_MAX / sizeof(uint32_t) + 1;
    const bal_error_t error = bal_assembler_init(&assembler, code_buffer, huge_size, silent_logger);
    TEST_ASSERT_EQUAL(BAL_ERROR_CAPACITY_TOO_BIG, error);
}

static void
test_BalAssemblerInit_Success(void)
{
    const bal_error_t error = init_valid();
    TEST_ASSERT_EQUAL(BAL_SUCCESS, error);
    TEST_ASSERT_EQUAL_PTR(code_buffer, assembler.buffer);
    TEST_ASSERT_EQUAL_size_t(TEST_BUFFER_CAPACITY, assembler.capacity);
    TEST_ASSERT_EQUAL_size_t(0, assembler.offset);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, assembler.status);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_ALIVE, assembler.magic);
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
    (void)init_valid();
    assembler.buffer = NULL;
    bal_assembler_reset(&assembler);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, assembler.status);
}

static void
test_BalAssemblerReset_ZeroCapacityReturnsErrorInvalidArgument(void)
{
    (void)init_valid();
    assembler.capacity = 0;
    bal_assembler_reset(&assembler);
    TEST_ASSERT_EQUAL(BAL_ERROR_INVALID_ARGUMENT, assembler.status);
}

static void
test_BalAssemblerReset_FreedAssemblerSetsDeadMagicNumber(void)
{
    (void)init_valid();
    bal_assembler_destroy(&assembler);
    TEST_ASSERT_EQUAL_UINT32(BAL_ASSEMBLER_MAGIC_DEAD, assembler.magic);

    bal_assembler_reset(&assembler);
    TEST_ASSERT_EQUAL(BAL_ERROR_STRUCT_CORRUPTED, assembler.status);
}

static void
test_BalAssemblerReset_Success(void)
{
    (void)init_valid();
    bal_emit_ret(&assembler, BAL_REGISTER_X30);
    TEST_ASSERT_EQUAL_size_t(1, assembler.offset);
    TEST_ASSERT_NOT_EQUAL(0, code_buffer[0]);

    bal_assembler_reset(&assembler);
    TEST_ASSERT_EQUAL_size_t(0, assembler.offset);
    TEST_ASSERT_EQUAL(BAL_SUCCESS, assembler.status);
    TEST_ASSERT_EQUAL_UINT32(0, code_buffer[0]);
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
    return UNITY_END();
}