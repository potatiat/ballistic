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
    context->logger.min_level = BAL_LOG_LEVEL_ERROR;
}

static void
test_teardown(test_context_t *context)
{
    bal_memory_destroy_flat(&context->allocator, &context->interface);
    context->allocator.free(
        context->allocator.handle, context->code_buffer, TEST_BUFFER_SIZE * sizeof(uint32_t));
}

#define BAL_TEST_FUNCTION(test_function_name)          \
    do                                                 \
    {                                                  \
        return_value = (test_function_name(&context)); \
        if (return_value != EXIT_SUCCESS)              \
        {                                              \
            return return_value;                       \
        }                                              \
    } while (0)

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

static int
test_memory__default_flat_translation_init__success(test_context_t *context)
{
    const size_t code_buffer_size_bytes = TEST_BUFFER_SIZE * sizeof(uint32_t);
    const size_t memory_alignment       = 16U;
    context->code_buffer                = context->allocator.allocate(
        context->allocator.handle, memory_alignment, code_buffer_size_bytes);

    if (context->code_buffer == NULL)
    {
        BAL_LOG_ERROR(&context->logger, "Expected code buffer != NULL");
        return EXIT_FAILURE;
    }

    const bal_error_t error = bal_memory_init_flat(&context->allocator,
                                                   &context->interface,
                                                   context->code_buffer,
                                                   code_buffer_size_bytes,
                                                   context->logger);

    if (error != BAL_SUCCESS)
    {
        BAL_LOG_ERROR(&context->logger, "Expected BAL_SUCCESS");
        return EXIT_FAILURE;
    }

    return EXIT_SUCCESS;
}

static int
test_memory__default_flat_translation_init__invalid_arguments_returns_error(test_context_t *context)
{
    int return_code = EXIT_SUCCESS;
    for (int i = 0; i < 1; ++i)
    {
        bal_logger_t logger = { 0 };
        bal_logger_init_default(&logger);

        // Disable logging because Ballistic will output error logs (which is a good thing since
        // we're testing errors).
        //
        logger.min_level = BAL_LOG_LEVEL_NONE;

        bal_allocator_t       *valid_allocator   = &context->allocator;
        bal_memory_interface_t valid_interface   = { 0 };
        uint32_t              *valid_code_buffer = context->code_buffer;
        const uint32_t         valid_buffer_size = TEST_BUFFER_SIZE;

        bal_allocator_t        *invalid_allocator   = NULL;
        bal_memory_interface_t *invalid_interface   = NULL;
        uint32_t               *invalid_code_buffer = NULL;
        const uint32_t          invalid_buffer_size = 0;

        bal_error_t error = bal_memory_init_flat(
            invalid_allocator, &valid_interface, valid_code_buffer, valid_buffer_size, logger);

        if (error != BAL_ERROR_INVALID_ARGUMENT)
        {
            logger.min_level = BAL_LOG_LEVEL_ERROR;
            BAL_LOG_ERROR(&logger, "Expected BAL_ERROR_INVALID_ARGUMENT");
            return_code = EXIT_FAILURE;
            break;
        }

        error = bal_memory_init_flat(
            valid_allocator, invalid_interface, valid_code_buffer, valid_buffer_size, logger);

        if (error != BAL_ERROR_INVALID_ARGUMENT)
        {
            logger.min_level = BAL_LOG_LEVEL_ERROR;
            BAL_LOG_ERROR(&logger, "Expected BAL_ERROR_INVALID_ARGUMENT");
            return_code = EXIT_FAILURE;
            break;
        }

        error = bal_memory_init_flat(
            valid_allocator, &valid_interface, invalid_code_buffer, valid_buffer_size, logger);

        if (error != BAL_ERROR_INVALID_ARGUMENT)
        {
            logger.min_level = BAL_LOG_LEVEL_ERROR;
            BAL_LOG_ERROR(&logger, "Expected BAL_ERROR_INVALID_ARGUMENT");
            return_code = EXIT_FAILURE;
            break;
        }
        error = bal_memory_init_flat(
            valid_allocator, &valid_interface, valid_code_buffer, invalid_buffer_size, logger);

        if (error != BAL_ERROR_INVALID_ARGUMENT)
        {
            logger.min_level = BAL_LOG_LEVEL_ERROR;
            BAL_LOG_ERROR(&logger, "Expected BAL_ERROR_INVALID_ARGUMENT");
            return_code = EXIT_FAILURE;
            break;
        }
    }

    return return_code;
}

int
main(void)
{
    test_context_t context;
    test_setup(&context);
    int return_value = EXIT_SUCCESS;
    BAL_TEST_FUNCTION(test_memory__default_allocate__invalid_size_returns_nullptr);
    BAL_TEST_FUNCTION(test_memory__default_flat_translation_init__success);
    BAL_TEST_FUNCTION(test_memory__default_flat_translation_init__invalid_arguments_returns_error);
    test_teardown(&context);
    return return_value;
}
