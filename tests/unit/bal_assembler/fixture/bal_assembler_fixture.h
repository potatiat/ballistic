#ifndef BALLISTIC_BAL_ASSEMBLER_FIXTURE_H
#define BALLISTIC_BAL_ASSEMBLER_FIXTURE_H

#include "bal_assembler.h"

#define TEST_BUFFER_CAPACITY 128

extern bal_assembler_t assembler;
extern uint32_t        code_buffer[TEST_BUFFER_CAPACITY];
extern void           *unaligned_pointer;

#endif // BALLISTIC_BAL_ASSEMBLER_FIXTURE_H

/*** end of file ***/
