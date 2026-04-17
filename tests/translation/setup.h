#ifndef TEST_SETUP_H
#define TEST_SETUP_H

#include "bal_assembler.h"
#include "bal_engine.h"
#include "bal_memory.h"
#include <stdint.h>
#include <stdio.h>

#define TEST_BUFFER_SIZE 4096

typedef struct
{
    bal_allocator_t        allocator;
    bal_memory_interface_t interface;
    bal_assembler_t        assembler;
    bal_engine_t           engine;
    bal_logger_t           logger;
    uint32_t              *code_buffer;
} test_context_t;

static void
test_setup(test_context_t *context)
{
    bal_allocator_default_init(&context->allocator);
    bal_logger_init_default(&context->logger);
    context->logger.min_level = BAL_LOG_LEVEL_TRACE;

    constexpr size_t memory_alignment = 16;
    context->code_buffer              = static_cast<uint32_t *>(context->allocator.allocate(
        context->allocator.handle, memory_alignment, TEST_BUFFER_SIZE * sizeof(uint32_t)));
    bal_flat_translation_interface_init(&context->allocator,
                                        &context->interface,
                                        context->code_buffer,
                                        TEST_BUFFER_SIZE * sizeof(uint32_t),
                                        context->logger);
    bal_engine_init(&context->allocator, &context->engine, context->logger);
    bal_assembler_init(
        &context->assembler, context->code_buffer, TEST_BUFFER_SIZE, context->logger);
}

static void
test_teardown(test_context_t *context)
{
    bal_engine_destroy(&context->allocator, &context->engine);
    bal_flat_translation_interface_destroy(&context->allocator, &context->interface);
    context->allocator.free(
        context->allocator.handle, context->code_buffer, TEST_BUFFER_SIZE * sizeof(uint32_t));
}

#define BAL_TEST_FUNCTION(test_function_name)                               \
    do                                                                      \
    {                                                                       \
        fprintf(stderr, "\n-------------------------------------------\n"); \
        fprintf(stderr, "Starting %s()...\n", #test_function_name);         \
        test_setup(&context);                                               \
        return_value = (test_function_name(&context));                      \
        test_teardown(&context);                                            \
        context.code_buffer = NULL;                                         \
                                                                            \
        if (return_value != EXIT_SUCCESS)                                   \
        {                                                                   \
            return return_value;                                            \
        }                                                                   \
                                                                            \
    } while (0)

#endif // TEST_SETUP_H
