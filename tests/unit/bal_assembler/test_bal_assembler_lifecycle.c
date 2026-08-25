#include "bal_assembler.h"
#include "unity.h"
#include <string.h>

#define TEST_BUFFER_CAPACITY 128

static bal_assembler_t assembler;
static uint32_t        code_buffer[TEST_BUFFER_CAPACITY];
static bal_logger_t    silent_logger;

void
setUp(void)
{
    memset(&assembler, 0, sizeof(assembler));
    memset(&code_buffer, 0, sizeof(code_buffer));
    memset(&silent_logger, 0, sizeof(silent_logger));
    silent_logger.min_level = BAL_LOG_LEVEL_NONE;
}

void
tearDown(void)
{
}

int
main(void)
{
    UNITY_BEGIN();
    return UNITY_END();
}