#include "../../src/generated/decoder_table.h"
#include "unity.h"
#include <string.h>

#define LOOKUP_TABLE_SIZE     2048U
#define INSTRUCTION_COUNT     BAL_DECODER_ARM64_INSTRUCTIONS_SIZE
#define MAX_OPERAND_BIT_WIDTH 32U
#define MAX_OPERANDS          BAL_OPERANDS_SIZE

void
setUp(void)
{
}

void
tearDown(void)
{
}

static void
test_BalDecoderGeneratedTable_AllBucketCandidatePointersAreWithinTheInstructionsArray(void)
{
    const bal_decoder_instruction_metadata_t *BAL_RESTRICT lo
        = &g_bal_decoder_arm64_instructions[0];
    const bal_decoder_instruction_metadata_t *BAL_RESTRICT hi
        = &g_bal_decoder_arm64_instructions[INSTRUCTION_COUNT];

    for (uint32_t i = 0U; i < LOOKUP_TABLE_SIZE; ++i)
    {
        const decoder_bucket_t bucket = g_decoder_lookup_table[i];

        for (uint8_t count = 0U; count < bucket.count; ++count)
        {
            const bal_decoder_instruction_metadata_t *BAL_RESTRICT candidate
                = g_decoder_hash_candidates[bucket.index + count];

            TEST_ASSERT_NOT_NULL(candidate);
            TEST_ASSERT_TRUE(candidate >= lo);
            TEST_ASSERT_TRUE(candidate < hi);
        }
    }
}

static void
test_BalDecoderGeneratedTable_AllInstructionsHaveValidMnemonic(void)
{
    for (uint32_t i = 0U; i < INSTRUCTION_COUNT; ++i)
    {
        const bal_decoder_instruction_metadata_t *BAL_RESTRICT metadata
            = &g_bal_decoder_arm64_instructions[i];
        TEST_ASSERT_NOT_NULL(metadata->name);
        TEST_ASSERT_TRUE(strlen(metadata->name) > 0);
    }
}

static void
test_BalDecoderGeneratedTable_AllOperandsBitFieldsFitWithin32Bits(void)
{
    for (uint32_t i = 0U; i < INSTRUCTION_COUNT; ++i)
    {
        const bal_decoder_instruction_metadata_t *BAL_RESTRICT metadata
            = &g_bal_decoder_arm64_instructions[i];

        for (uint32_t ii = 0U; ii < MAX_OPERANDS; ++ii)
        {
            const bal_decoder_operand_t operand = metadata->operands[ii];

            if (operand.type == BAL_OPERAND_TYPE_NONE)
            {
                continue;
            }

            const uint32_t bit_end = (uint32_t)operand.bit_position + operand.bit_width;
            TEST_ASSERT_LESS_OR_EQUAL_UINT32(MAX_OPERAND_BIT_WIDTH, bit_end);
        }
    }
}

static void
test_BalDecoderGeneratedTable_AllOperandTypesAreValidEnumValued(void)
{
    for (uint32_t i = 0U; i < INSTRUCTION_COUNT; ++i)
    {
        const bal_decoder_instruction_metadata_t *BAL_RESTRICT metadata
            = &g_bal_decoder_arm64_instructions[i];

        for (uint32_t ii = 0U; ii < MAX_OPERANDS; ++ii)
        {
            const uint16_t type = metadata->operands[ii].type;
            const int      valid
                = (type == BAL_OPERAND_TYPE_NONE) || (type == BAL_OPERAND_TYPE_REGISTER_32)
                  || (type == BAL_OPERAND_TYPE_REGISTER_64)
                  || (type == BAL_OPERAND_TYPE_REGISTER_128) || (type == BAL_OPERAND_TYPE_IMMEDIATE)
                  || (type == BAL_OPERAND_TYPE_CONDITION);
            TEST_ASSERT_TRUE_MESSAGE(valid, metadata->name);
        }
    }
}

/// A zero mask matches everything.
static void
test_BalDecoderGeneratedTable_AllInstructionsHaveNonZeroMask(void)
{
    for (uint32_t i = 0U; i < INSTRUCTION_COUNT; ++i)
    {
        TEST_ASSERT_NOT_EQUAL_UINT32_MESSAGE(
            0, g_bal_decoder_arm64_instructions[i].mask, g_bal_decoder_arm64_instructions[i].name);
    }
}

static void
test_BalDecoderGeneratedTable_ExpectedValueConsistentWithMask(void)
{
    for (uint32_t i = 0U; i < INSTRUCTION_COUNT; ++i)
    {
        const bal_decoder_instruction_metadata_t *BAL_RESTRICT metadata
            = &g_bal_decoder_arm64_instructions[i];
        const uint32_t masked = metadata->expected & metadata->mask;
        TEST_ASSERT_EQUAL_HEX32_MESSAGE(metadata->expected, masked, metadata->name);
    }
}

static void
test_BalDecoder_MaskMatchOnFirstCandidateReturnsMetadata(void)
{
    const bal_decoder_instruction_metadata_t *metadata = bal_decode_arm64(0x04000000U);
    TEST_ASSERT_NOT_NULL(metadata);
    TEST_ASSERT_EQUAL_STRING("ADD", metadata->name);
    TEST_ASSERT_EQUAL_HEX32(0xFF3FE000U, metadata->mask);
    TEST_ASSERT_EQUAL_HEX32(0x04000000U, metadata->expected);
}

static void
test_BalDecoder_MaskMismatchThenMatchReturnsLaterCandidate(void)
{
    const bal_decoder_instruction_metadata_t *BAL_RESTRICT metadata = bal_decode_arm64(0x0416A000U);
    TEST_ASSERT_NOT_NULL(metadata);
    TEST_ASSERT_EQUAL_STRING("ABS", metadata->name);
    TEST_ASSERT_EQUAL_HEX32(0x0416A000U, metadata->expected);
}

static void
test_BalDecoder_MaskMismatchAllCandidatesReturnsNull(void)
{
    TEST_ASSERT_NULL_MESSAGE(bal_decode_arm64(0x00200000U),
                             "0x00200000U should have returned "
                             "NULL.");
}

int
main(void)
{
    UNITY_BEGIN();
    RUN_TEST(test_BalDecoderGeneratedTable_AllBucketCandidatePointersAreWithinTheInstructionsArray);
    RUN_TEST(test_BalDecoderGeneratedTable_AllInstructionsHaveValidMnemonic);
    RUN_TEST(test_BalDecoderGeneratedTable_AllOperandsBitFieldsFitWithin32Bits);
    RUN_TEST(test_BalDecoderGeneratedTable_AllOperandTypesAreValidEnumValued);
    RUN_TEST(test_BalDecoderGeneratedTable_AllInstructionsHaveNonZeroMask);
    RUN_TEST(test_BalDecoderGeneratedTable_ExpectedValueConsistentWithMask);
    RUN_TEST(test_BalDecoder_MaskMatchOnFirstCandidateReturnsMetadata);
    RUN_TEST(test_BalDecoder_MaskMismatchThenMatchReturnsLaterCandidate);
    RUN_TEST(test_BalDecoder_MaskMismatchAllCandidatesReturnsNull);
    return UNITY_END();
}

/*** end of file ***/