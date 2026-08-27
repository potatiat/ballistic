#ifndef BALLISTIC_BAL_ASSEMBLER_FIXTURE_H
#define BALLISTIC_BAL_ASSEMBLER_FIXTURE_H

#include "bal_assembler.h"

#define TEST_BUFFER_CAPACITY 128

extern bal_assembler_t bal_test_assembler;
extern uint32_t        bal_test_code_buffer[TEST_BUFFER_CAPACITY];
extern void           *bal_test_unaligned_pointer;

bal_error_t bal_test_assembler_init_valid(void);

#endif // BALLISTIC_BAL_ASSEMBLER_FIXTURE_H

/*** end of file ***/
