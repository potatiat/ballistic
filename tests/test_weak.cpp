#include "bal_assert.h"
#include "bal_log.h"
#include "bal_memory.h"
#include <cstdarg>
#include <cstdio>
#include <cstring>
#include <gtest/gtest.h>

static bool g_assert_override_called                = false;
static bool g_logger_init_override_called           = false;
static bool g_default_logger_override_called        = false;
static bool g_allocator_init_override_called        = false;
static bool g_default_allocate_override_called      = false;
static bool g_default_free_override_called          = false;
static bool g_default_allocate_exec_override_called = false;
static bool g_default_free_exec_override_called     = false;
static bool g_default_protect_rw_override_called    = false;
static bool g_default_protect_rx_override_called    = false;

extern "C"
{
    void bal_internal_assert_fail(const char *file,
                                  int         line,
                                  const char *func,
                                  const char *expr_str,
                                  const char *user_msg,
                                  ...)
    {
        g_assert_override_called = true;
    }

    void bal_logger_init_default(void)
    {
        g_logger_init_override_called = true;
        bal_thread_logger.log         = nullptr;
        bal_thread_logger.min_level   = BAL_LOG_LEVEL_NONE;
        bal_thread_logger.user_data   = nullptr;
    }

    void bal_default_logger(void           *user_data,
                            bal_log_data_t *bal_data,
                            const char     *format,
                            va_list         args)
    {
        g_default_logger_override_called = true;
    }

    void bal_allocator_default_init(bal_allocator_t *out_allocator)
    {
        g_allocator_init_override_called = true;
        memset(out_allocator, 0, sizeof(bal_allocator_t));
    }

    // Forward declare the internal memory functions so we can override them
    void                   *bal_default_allocate(bal_allocator_handle_t, size_t, size_t);
    void                    bal_default_free(bal_allocator_handle_t, void *, size_t);
    bal_executable_buffer_t bal_default_allocate_executable(bal_allocator_handle_t, size_t, size_t);
    void bal_default_free_executable(bal_allocator_handle_t, bal_executable_buffer_t, size_t);
    void bal_default_protect_rw(bal_allocator_handle_t, bal_executable_buffer_t, size_t);
    void bal_default_protect_rx(bal_allocator_handle_t, bal_executable_buffer_t, size_t);

    void *bal_default_allocate(bal_allocator_handle_t handle, size_t alignment, size_t size)
    {
        g_default_allocate_override_called = true;
        return nullptr;
    }

    void bal_default_free(bal_allocator_handle_t handle, void *pointer, size_t size)
    {
        g_default_free_override_called = true;
    }

    bal_executable_buffer_t bal_default_allocate_executable(bal_allocator_handle_t handle,
                                                            size_t                 alignment,
                                                            size_t                 size)
    {
        g_default_allocate_exec_override_called = true;
        const bal_executable_buffer_t buf       = { nullptr, nullptr };
        return buf;
    }

    // 8. Override bal_default_free_executable
    void bal_default_free_executable(bal_allocator_handle_t  handle,
                                     bal_executable_buffer_t buffer,
                                     size_t                  size)
    {
        g_default_free_exec_override_called = true;
    }

    // 9. Override bal_default_protect_rw
    void bal_default_protect_rw(bal_allocator_handle_t  handle,
                                bal_executable_buffer_t buffer,
                                size_t                  size)
    {
        g_default_protect_rw_override_called = true;
    }

    // 10. Override bal_default_protect_rx
    void bal_default_protect_rx(bal_allocator_handle_t  handle,
                                bal_executable_buffer_t buffer,
                                size_t                  size)
    {
        g_default_protect_rx_override_called = true;
    }
}

TEST(WeakSymbolsTest, AssertOverride)
{
    g_assert_override_called = false;
    // This would normally abort the program.
    // Since we override it, it should just set the flag and return.
    BAL_ASSERT(1 == 0);
    EXPECT_TRUE(g_assert_override_called);
}

TEST(WeakSymbolsTest, LoggerInitOverride)
{
    g_logger_init_override_called = false;
    bal_logger_init_default();
    EXPECT_TRUE(g_logger_init_override_called);
    EXPECT_EQ(bal_thread_logger.min_level, BAL_LOG_LEVEL_NONE);
}

TEST(WeakSymbolsTest, DefaultLoggerOverride)
{
    g_default_logger_override_called = false;
    bal_logger_t logger              = {};

    logger.log       = bal_default_logger;
    logger.min_level = BAL_LOG_LEVEL_TRACE;

    BAL_LOG_INFO(&logger, "Testing weak logger override");
    EXPECT_TRUE(g_default_logger_override_called);
}

TEST(WeakSymbolsTest, AllocatorInitOverride)
{
    g_allocator_init_override_called = false;
    bal_allocator_t allocator        = {};
    bal_allocator_default_init(&allocator);
    EXPECT_TRUE(g_allocator_init_override_called);
    EXPECT_EQ(allocator.allocate, nullptr);
}

TEST(WeakSymbolsTest, InternalMemoryOverrides)
{
    g_default_allocate_override_called      = false;
    g_default_free_override_called          = false;
    g_default_allocate_exec_override_called = false;
    g_default_free_exec_override_called     = false;
    g_default_protect_rw_override_called    = false;
    g_default_protect_rx_override_called    = false;

    bal_allocator_t allocator     = {};
    allocator.allocate            = bal_default_allocate;
    allocator.free                = bal_default_free;
    allocator.allocate_executable = bal_default_allocate_executable;
    allocator.free_executable     = bal_default_free_executable;
    allocator.protect_rw          = bal_default_protect_rw;
    allocator.protect_rx          = bal_default_protect_rx;

    void *ptr = allocator.allocate(nullptr, 16, 1024);
    EXPECT_TRUE(g_default_allocate_override_called);

    allocator.free(nullptr, ptr, 1024);
    EXPECT_TRUE(g_default_free_override_called);

    const bal_executable_buffer_t exec_buf = allocator.allocate_executable(nullptr, 4096, 1024);
    EXPECT_TRUE(g_default_allocate_exec_override_called);

    allocator.protect_rw(nullptr, exec_buf, 1024);
    EXPECT_TRUE(g_default_protect_rw_override_called);

    allocator.protect_rx(nullptr, exec_buf, 1024);
    EXPECT_TRUE(g_default_protect_rx_override_called);

    allocator.free_executable(nullptr, exec_buf, 1024);
    EXPECT_TRUE(g_default_free_exec_override_called);
}