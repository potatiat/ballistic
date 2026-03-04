#include "bal_logging.h"
#include "bal_memory.h"
#include <stdlib.h>

// -----------------------------------------------------------------------------
// Setup
// -----------------------------------------------------------------------------

#define TEST_BUFFER_SIZE 4096

typedef struct
{
    bal_allocator_t        allocator;
    bal_memory_interface_t interface;
    bal_logger_t           logger;
    uint32_t              *code_buffer;
} test_context_t;

static void
test_setup(test_context_t *context)
{
    bal_get_default_allocator(&context->allocator);
    bal_logger_init_default(&context->logger);
    context->logger.min_level = BAL_LOG_LEVEL_WARN;
}

static void
test_teardown(test_context_t *context)
{
    bal_memory_destroy_flat(&context->allocator, &context->interface);
    context->allocator.free(
        context->allocator.handle, context->code_buffer, TEST_BUFFER_SIZE * sizeof(uint32_t));
}

#define BAL_TEST_MAIN(test_function_name)        \
    int main(void)                               \
    {                                            \
        test_context_t context;                  \
        test_setup(&context);                    \
        int code = test_function_name(&context); \
        test_teardown(&context);                 \
        return code;                             \
    }

// -----------------------------------------------------------------------------
// Tests
// -----------------------------------------------------------------------------

static int
test_memory__default_allocate__invalid_size_returns_nullptr(test_context_t *context)
{
    int          return_code      = EXIT_SUCCESS;
    const size_t size             = 0;
    const size_t memory_alignment = 8;
    context->code_buffer
        = context->allocator.allocate(context->allocator.handle, memory_alignment, size);

    if (context->code_buffer != NULL)
    {
        BAL_LOG_ERROR(&context->logger, "Expected buffer == NULL");
        return_code = EXIT_FAILURE;
    }

    return return_code;
}

BAL_TEST_MAIN(test_memory__default_allocate__invalid_size_returns_nullptr);