#include "bal_assembler_fixture.h"
#include "bal_assembler.h"
#include <string.h>

bal_assembler_t bal_test_assembler                         = { 0 };
uint32_t        bal_test_code_buffer[TEST_BUFFER_CAPACITY] = { 0 };
void           *bal_test_unaligned_pointer                 = NULL;

void
setUp(void)
{
    memset(&bal_test_assembler, 0, sizeof(bal_test_assembler));
    memset(&bal_test_code_buffer, 0, sizeof(bal_test_code_buffer));
    bal_test_unaligned_pointer  = bal_test_code_buffer;
    bal_thread_logger.min_level = BAL_LOG_LEVEL_NONE;

    if (0 == (uintptr_t)bal_test_unaligned_pointer % 4)
    {
        bal_test_unaligned_pointer += 1;
    }
}

void
tearDown(void)
{
}

bal_error_t
bal_test_assembler_init_valid(void)
{
    return bal_assembler_init(&bal_test_assembler, bal_test_code_buffer, TEST_BUFFER_CAPACITY);
}

/*** end of file ***/
