#include "gtest/gtest.h"

extern "C"
{
#include "../src/backend/x86/bal_x86_assembler.c"
}

class Backendx86Assembler : public testing::Test
{
protected:
    uint8_t             buffer[1024] = {};
    bal_logger_t        logger       = {};
    bal_x86_assembler_t assembler    = {};

    void SetUp() override
    {
        memset(buffer, 0, sizeof(buffer));
        memset(&logger, 0, sizeof(bal_logger_t));
        memset(&assembler, 0, sizeof(bal_x86_assembler_t));
        const bal_error_t error
            = bal_x86_assembler_init(&assembler, buffer, sizeof(buffer), logger);
        ASSERT_EQ(error, error);
    }
};

TEST_F(Backendx86Assembler, Init_NullAssembler)
{
    EXPECT_EQ(bal_x86_assembler_init(nullptr, buffer, 100, logger), BAL_ERROR_INVALID_ARGUMENT);
}

TEST_F(Backendx86Assembler, Init_NullBuffer)
{
    bal_x86_assembler_t local_assembler;
    EXPECT_EQ(bal_x86_assembler_init(&local_assembler, nullptr, 100, logger),
              BAL_ERROR_INVALID_ARGUMENT);
}

TEST_F(Backendx86Assembler, Init_ZeroSize)
{
    bal_x86_assembler_t local_assembler;
    EXPECT_EQ(bal_x86_assembler_init(&local_assembler, buffer, 0, logger),
              BAL_ERROR_INVALID_ARGUMENT);
}

TEST_F(Backendx86Assembler, Init_Success)
{
    bal_x86_assembler_t local_assembler;
    EXPECT_EQ(bal_x86_assembler_init(&local_assembler, buffer, 100, logger), BAL_SUCCESS);
    EXPECT_EQ(local_assembler.capacity, 100);
    EXPECT_EQ(local_assembler.offset, 0);
    EXPECT_EQ(local_assembler.status, BAL_SUCCESS);
    EXPECT_EQ(local_assembler.buffer, buffer);
}

TEST_F(Backendx86Assembler, Internal_IsValidRegister)
{
    EXPECT_TRUE(is_valid_register(BAL_X86_RAX));
    EXPECT_TRUE(is_valid_register(BAL_X86_R15));
    EXPECT_FALSE(is_valid_register((bal_x86_register_t)(BAL_X86_RAX - 1)));
    EXPECT_FALSE(is_valid_register((bal_x86_register_t)(BAL_X86_R15 + 1)));
    EXPECT_FALSE(is_valid_register((bal_x86_register_t)999));
}

TEST_F(Backendx86Assembler, Internal_CanEmit_NullCheck)
{
    EXPECT_FALSE(can_emit(nullptr, 1));
}

TEST_F(Backendx86Assembler, Internal_CanEmit_BadStatus)
{
    assembler.status = BAL_ERROR_INVALID_ARGUMENT;
    EXPECT_FALSE(can_emit(&assembler, 1));
}

TEST_F(Backendx86Assembler, Internal_CanEmit_IntegerOverflow)
{
    assembler.offset = SIZE_MAX;
    EXPECT_FALSE(can_emit(&assembler, 1)); // Would wrap to 0
    EXPECT_EQ(assembler.status, BAL_ERROR_INSTRUCTION_OVERFLOW);
}

TEST_F(Backendx86Assembler, Internal_CanEmit_BufferExhausted)
{
    assembler.offset   = 1000;
    assembler.capacity = 1000;
    EXPECT_FALSE(can_emit(&assembler, 1));
}

// Test pass incorrect data to modrm/rex generators.
TEST_F(Backendx86Assembler, Internal_BitwiseMasking)
{
    emit_rex(&assembler.buffer, 0xFF, 0xFF, 0xFF);

    // w=1, r=1, b=1 -> 0x40 | 8 | 4 | 1 = 0x4D
    //
    EXPECT_EQ(buffer[0], 0x4D);
    assembler.offset = 0;
    emit_modrm_register(&assembler.buffer, (bal_x86_register_t)0xFF, (bal_x86_register_t)0xFF);

    // reg=7, rm=7 -> 0xC0 | 7 << 3 | 7 = 0xC0 | 0x38 | 0x07 = 0xFF
    //
    EXPECT_EQ(buffer[1], 0xFF);
    assembler.offset = 0;
    emit_modrm_memory_disp32_rbp(&assembler.buffer, (bal_x86_register_t)0xFF);

    // reg=7 -> 0x8D | 7 >> 3 | 0x05 = 0x80 | 0x38 | 0x05 = 0xBD
    //
    EXPECT_EQ(buffer[2], 0xBD);
}

/*** end of file ***/
