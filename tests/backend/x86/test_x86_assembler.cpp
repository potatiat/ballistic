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