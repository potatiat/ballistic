#include "gtest/gtest.h"
extern "C"
{
#include "../src/bal_engine.c"
}

TEST(EngineIntegration, WhileLoop)
{
    bal_cpu_t       cpu       = {};
    bal_allocator_t allocator = {};
    bal_allocator_default_init(&allocator);

    bal_logger_t logger = {};
    bal_logger_init_default(&logger);

    const size_t guest_memory_size = 4096;
    uint32_t    *guest_memory
        = (uint32_t *)allocator.allocate(allocator.context, 16, guest_memory_size);
    ASSERT_NE(guest_memory, nullptr);
    memset(guest_memory, 0, guest_memory_size);

    bal_memory_interface_t memory_interface = {};
    bal_error_t            error            = bal_flat_translation_interface_init(
        &allocator, &memory_interface, guest_memory, guest_memory_size, logger);
    ASSERT_EQ(error, BAL_SUCCESS);

    bal_engine_t engine = {};
    error               = bal_engine_init(&engine, &cpu, &allocator, &memory_interface, logger);
    ASSERT_EQ(error, BAL_SUCCESS);

    guest_memory[0] = 0xD292D000; // MOVZ X0, #0x9680
    guest_memory[1] = 0xF2A01300; // MOVK X0, #0x98, LSL #16 (X0 = 10,000,000)
    guest_memory[2] = 0xD2800010; // MOVZ X1, #0
    // .loop:
    guest_memory[3] = 0xF1000400; // SUBS X0, X0, #1
    guest_memory[4] = 0x8B000021; // ADD X1, X1, X0
    guest_memory[5] = 0x54FFFFC1; // B.NE .loop
    guest_memory[6] = 0xD65F03C0; // RET (X30)

    cpu.pc    = 0;
    cpu.x[30] = BAL_ENGINE_SENTINEL;
    error     = bal_engine_run_thread(&engine);
    EXPECT_EQ(error, BAL_SUCCESS);

    // Sum = N * (N - 1) / 2 where N = 10,000,000
    const uint64_t expected_sum = 49999995000000ULL;
    EXPECT_EQ(cpu.x[1], expected_sum);
    EXPECT_EQ(cpu.x[0], 0);
    // .loop:

    bal_engine_destroy(&engine);
    bal_flat_translation_interface_destroy(&allocator, &memory_interface);
    allocator.free(allocator.context, guest_memory, guest_memory_size);
}

class EngineBlockCache : public testing::Test
{
protected:
    BAL_ALIGNED(64) block_cache_set_t cache[BLOCK_CACHE_SETS] = {};

    void SetUp() override
    {
        memset(cache, 0, sizeof(cache));
    }
};

TEST_F(EngineBlockCache, CacheArray_Stride_MatchesHardwareCacheLine)
{
    const uintptr_t base = reinterpret_cast<uintptr_t>(&cache[0]);
    const uintptr_t next = reinterpret_cast<uintptr_t>(&cache[1]);
    EXPECT_EQ(next - base, 64U);
}

TEST_F(EngineBlockCache, Regression_Hash_IndexMask_UseMaskNotSize)
{
    // Ensure the maximum index is 4095.
    const bal_guest_address_t pc        = 0xFFFFFFFFFFFFFFFFULL;
    const uint32_t            set_index = (uint32_t)(pc >> 2) & BLOCK_CACHE_MASK;
    EXPECT_EQ(set_index, 4095U);
}

TEST_F(EngineBlockCache, Hash_PC_ShiftRightBy2Bits_Success)
{
    // PC = 0x1000. Shifted by 2 = 0x400. Masked = 0x400.
    const bal_guest_address_t pc        = 0x1000;
    void                     *dummy_ptr = reinterpret_cast<void *>(0xDEADBEEF);
    block_cache_insert(cache, pc, dummy_ptr);

    EXPECT_EQ(cache[0x400].ways[0].guest_address, pc);
    EXPECT_EQ(cache[0x400].ways[0].host_code, dummy_ptr);
}

TEST_F(EngineBlockCache, Hash_PC_MaxUint64_DoesNotOverflowIndex)
{
    const bal_guest_address_t pc        = 0xFFFFFFFFFFFFFFFFULL;
    void                     *dummy_ptr = reinterpret_cast<void *>(0xDEADBEEF);
    block_cache_insert(cache, pc, dummy_ptr);

    // 0x3FFFFFFFFFFFFFFF & 0xFFF = 0xFFF (4095)
    const uint32_t expected_set = 4095;
    EXPECT_EQ(cache[expected_set].ways[0].guest_address, pc);
    EXPECT_EQ(cache[expected_set].ways[0].host_code, dummy_ptr);
}

TEST_F(EngineBlockCache, Hash_PC_Lower2Bits_IgnoredCorrectly)
{
    // ARM64 instructions are 4-byte aligned. The lower 2 bits should be ignored by the hash.
    const bal_guest_address_t pc_aligned   = 0x1000;
    const bal_guest_address_t pc_unaligned = 0x1001;
    void                     *dummy_ptr    = reinterpret_cast<void *>(0xDEADBEEF);
    block_cache_insert(cache, pc_aligned, dummy_ptr);

    EXPECT_EQ(block_cache_lookup(cache, pc_aligned), dummy_ptr);
    EXPECT_EQ(block_cache_lookup(cache, pc_unaligned), nullptr);
}

TEST_F(EngineBlockCache, Hash_PC_UnalignedGuestAddress_HandledSafely)
{
    // Cache should still function without crashing if a user passes an unaligned address.
    const bal_guest_address_t pc        = 0x1001;
    void                     *dummy_ptr = reinterpret_cast<void *>(0xDEADBEEF);
    block_cache_insert(cache, pc, dummy_ptr);

    EXPECT_EQ(block_cache_lookup(cache, pc), dummy_ptr);
    EXPECT_EQ(block_cache_lookup(cache, 0x1000), nullptr);
}

TEST_F(EngineBlockCache, Hash_IndexCalculation_CoverAllSets)
{
    for (uint32_t i = 0; i < BLOCK_CACHE_SETS; ++i)
    {
        const bal_guest_address_t pc        = (bal_guest_address_t)i << 2;
        void                     *dummy_ptr = reinterpret_cast<void *>(0x1000 + i);
        block_cache_insert(cache, pc, dummy_ptr);

        EXPECT_EQ(block_cache_lookup(cache, pc), dummy_ptr) << "Failed to map to set " << i;
    }
}