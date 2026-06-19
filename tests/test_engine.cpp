#include "gtest/gtest.h"
extern "C"
{
#include "../src/bal_engine.c"
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