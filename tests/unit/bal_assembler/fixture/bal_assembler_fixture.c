#include "bal_assembler_fixture.h"
#include "bal_assembler.h"
#include <string.h>

bal_assembler_t assembler                         = { 0 };
uint32_t        code_buffer[TEST_BUFFER_CAPACITY] = { 0 };
void           *unaligned_pointer                 = NULL;

void
setUp(void)
{
    memset(&assembler, 0, sizeof(assembler));
    memset(&code_buffer, 0, sizeof(code_buffer));
    unaligned_pointer           = code_buffer;
    bal_thread_logger.min_level = BAL_LOG_LEVEL_NONE;

    if (0 == (uintptr_t)unaligned_pointer % 4)
    {
        unaligned_pointer += 1;
    }
}

void
tearDown(void)
{
}

/*** end of file ***/
