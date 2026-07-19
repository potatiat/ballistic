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

TEST_F(JitDebug, Init_Success)
{
    EXPECT_EQ(bal_jit_debug_init(&allocator, &context, logger), BAL_SUCCESS);
    EXPECT_NE(context.entries, nullptr);
    EXPECT_NE(context.metadata_arena, nullptr);
    EXPECT_EQ(context.entry_capacity, BAL_JIT_DEBUG_ENTRY_CAPACITY);
    EXPECT_EQ(context.arena_capacity, BAL_JIT_DEBUG_ARENA_CAPACITY_BYTES);
    EXPECT_EQ(context.magic, BAL_JIT_DEBUG_MAGIC_ALIVE);
    bal_jit_debug_destroy(&allocator, &context);
}

TEST_F(JitDebug, Destroy_Success)
{
    bal_jit_debug_init(&allocator, &context, logger);
    bal_jit_debug_destroy(&allocator, &context);
    EXPECT_EQ(context.entries, nullptr);
    EXPECT_EQ(context.metadata_arena, nullptr);
    EXPECT_EQ(context.magic, BAL_JIT_DEBUG_MAGIC_DEAD);
}

TEST_F(JitDebug, AddBlock_Success)
{
    bal_jit_debug_init(&allocator, &context, logger);
    bal_jit_instruction_map_t map      = { 0, 0 };
    void                     *dummy_rx = (void *)0x1000;

    EXPECT_EQ(bal_jit_debug_add_block(&context, dummy_rx, 64, 0x2000, &map, 1), BAL_SUCCESS);
    EXPECT_EQ(context.entry_count, 1);
    EXPECT_EQ(context.entries[0].rx_start, dummy_rx);
    EXPECT_EQ(context.entries[0].rx_size, 64);
    EXPECT_EQ(context.entries[0].metadata->base_guest_pc, 0x2000);
    EXPECT_EQ(context.entries[0].metadata->instruction_count, 1);
    bal_jit_debug_destroy(&allocator, &context);
}