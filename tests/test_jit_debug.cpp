#include "bal_jit_debug.h"
#include "bal_memory.h"
#include "bal_safety.h"
#include "gtest/gtest.h"

class JitDebug : public testing::Test
{
protected:
    bal_allocator_t         allocator = {};
    char                    pad0[56]  = {};
    bal_jit_debug_context_t context   = {};
    bal_logger_t            logger    = {};
    char                    pad1[40]  = {};

    void SetUp() override
    {
        bal_allocator_default_init(&allocator);
        bal_logger_init_default(&logger);
    }
};

TEST_F(JitDebug, InitSuccess)
{
    EXPECT_EQ(bal_jit_debug_init(&allocator, &context, logger), BAL_SUCCESS);
    EXPECT_NE(context.entries, nullptr);
    EXPECT_NE(context.metadata_arena, nullptr);
    EXPECT_EQ(context.entry_capacity, BAL_JIT_DEBUG_ENTRY_CAPACITY);
    EXPECT_EQ(context.arena_capacity, BAL_JIT_DEBUG_ARENA_CAPACITY_BYTES);
    EXPECT_EQ(context.magic, BAL_JIT_DEBUG_MAGIC_ALIVE);
    bal_jit_debug_destroy(&allocator, &context);
}