#include "bal_memory.h"
#include <assert.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

static void                   *default_allocate(bal_allocator_handle_t, size_t, size_t);
static void                    default_free(bal_allocator_handle_t, void *, size_t);
static bal_executable_buffer_t default_allocate_executable(bal_allocator_handle_t handle,
                                                           size_t                 alignment,
                                                           size_t                 size);
static bal_error_t             default_reprotect_executable(bal_allocator_handle_t  handle,
                                                            bal_executable_buffer_t buffer,
                                                            size_t                  size);
static void                    default_free_executable(bal_allocator_handle_t  handle,
                                                       bal_executable_buffer_t buffer,
                                                       size_t                  size);
BAL_HOT static const uint8_t  *bal_flat_translation_interface_translate(void *,
                                                                        bal_guest_address_t,
                                                                        size_t *);

typedef struct
{
    uint8_t     *host;
    size_t       size;
    bal_logger_t logger;
    char         _pad[8];
} flat_translation_interface_t;

static_assert(0 == sizeof(flat_translation_interface_t) % 16, "Struct must be aligned to 16 bytes");

void
bal_allocator_default_init(bal_allocator_t *out_allocator)
{
    out_allocator->handle               = NULL;
    out_allocator->allocate             = default_allocate;
    out_allocator->free                 = default_free;
    out_allocator->allocate_executable  = default_allocate_executable;
    out_allocator->reprotect_executable = default_reprotect_executable;
    out_allocator->free_executable      = default_free_executable;
}

BAL_COLD bal_error_t
bal_flat_translation_interface_init(bal_allocator_t *BAL_RESTRICT        allocator,
                                    bal_memory_interface_t *BAL_RESTRICT interface,
                                    void *BAL_RESTRICT                   buffer,
                                    const size_t                         size,
                                    const bal_logger_t                   logger)

{
    if (NULL == allocator || NULL == interface || NULL == buffer || 0 == size)
    {
        BAL_LOG_ERROR(&logger,
                      "Memory init failed. Invalid arguments (Allocator: %p, Interface: %p, "
                      "Buffer: %p, Size: %zu).",
                      allocator,
                      interface,
                      buffer,
                      size);

        return BAL_ERROR_INVALID_ARGUMENT;
    }

    BAL_LOG_INFO(
        &logger, "Initializing Flat Memory Model. Base: %p, Size: %zu bytes.", buffer, size);

    // ABI compliant 16-byte memory alignment.
    const size_t memory_alignment = 15U;

    if (((uintptr_t)buffer & memory_alignment) != 0)
    {
        BAL_LOG_ERROR(&logger, "Buffer %p is not 16-byte aligned.", buffer);
        return BAL_ERROR_MEMORY_ALIGNMENT;
    }

    const size_t                  memory_alignment_bytes = 16U;
    flat_translation_interface_t *flat_interface         = allocator->allocate(
        allocator->handle, memory_alignment_bytes, sizeof(flat_translation_interface_t));

    if (NULL == flat_interface)
    {
        BAL_LOG_ERROR(&logger,
                      "Failed to allocate interface context (%zu bytes).",
                      sizeof(flat_translation_interface_t));
        return BAL_ERROR_ALLOCATION_FAILED;
    }

    flat_interface->host   = (uint8_t *)buffer;
    flat_interface->size   = size;
    flat_interface->logger = logger;
    interface->context     = flat_interface;
    interface->translate   = bal_flat_translation_interface_translate;

    BAL_LOG_INFO(&logger, "Flat interface created successfully at %p.", (void *)flat_interface);

    return BAL_SUCCESS;
}

bal_error_t
bal_flat_translation_interface_destroy(bal_allocator_t        *allocator,
                                       bal_memory_interface_t *interface)
{
    if (NULL == allocator || NULL == interface)
    {
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    if (NULL == interface->context)
    {
        *interface = (bal_memory_interface_t) {};
        return BAL_SUCCESS;
    }

    allocator->free(allocator->handle, interface->context, sizeof(flat_translation_interface_t));
    *interface = (bal_memory_interface_t) {};
    return BAL_SUCCESS;
}

#if BAL_PLATFORM_POSIX
#include <sys/mman.h>

static void *
default_allocate(bal_allocator_handle_t handle, size_t alignment, size_t size)
{
    (void)handle;

    if (0 == size)
    {
        return NULL;
    }

    void *memory = aligned_alloc(alignment, size);
    return memory;
}

static void
default_free(bal_allocator_handle_t handle, void *pointer, size_t size)
{
    (void)handle;
    (void)size;

    if (NULL == pointer)
    {
        return;
    }

    free(pointer);
}

bal_executable_buffer_t
default_allocate_executable(bal_allocator_handle_t handle, size_t alignment, size_t size)
{
    (void)handle;
    (void)alignment;

    if (0 == size)
    {
        return (bal_executable_buffer_t) { NULL, NULL };
    }

    void *memory = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);

    if (memory == MAP_FAILED)
    {
        return (bal_executable_buffer_t) { NULL, NULL };
    }

    return (bal_executable_buffer_t) { memory, memory };
}

bal_error_t
default_reprotect_executable(bal_allocator_handle_t  handle,
                             bal_executable_buffer_t buffer,
                             size_t                  size)
{
    (void)handle;

    if (NULL == buffer.rx_pointer)
    {
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    if (mprotect(buffer.rx_pointer, size, PROT_READ | PROT_EXEC) != 0)
    {
        return BAL_ERROR_MEMORY_FAULT;
    }

    return BAL_SUCCESS;
}
void
default_free_executable(bal_allocator_handle_t handle, bal_executable_buffer_t buffer, size_t size)
{
    (void)handle;

    if (NULL == buffer.rx_pointer)
    {
        return;
    }

    munmap(buffer.rx_pointer, size);
}

#endif /* BAL_PLATFORM_POSIX */

#if BAL_PLATFORM_WINDOWS

#include <malloc.h>
#include <windows.h>

static void *
default_allocate(bal_allocator_handle_t handle, size_t alignment, size_t size)
{
    (void)handle;

    if (0 == size)
    {
        return NULL;
    }

    void *memory = _aligned_malloc(size, alignment);
    return memory;
}

static void
default_free(bal_allocator_handle_t handle, void *pointer, size_t size)
{
    (void)handle;
    (void)size;
    _aligned_free(pointer);
}

bal_executable_buffer_t
default_allocate_executable(bal_allocator_handle_t handle, size_t alignment, size_t size)
{
    (void)handle;
    (void)alignment;

    if (0 == size)
    {
        return (bal_executable_buffer_t) { NULL, NULL };
    }

    void *memory = VirtualAlloc(NULL, size, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
    return (bal_executable_buffer_t) { memory, memory };
}

bal_error_t
default_reprotect_executable(bal_allocator_handle_t  handle,
                             bal_executable_buffer_t buffer,
                             size_t                  size)
{
    (void)handle;

    if (NULL == buffer.rx_pointer)
    {
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    DWORD old_protect;

    if (!VirtualProtect(buffer.rx_pointer, size, PAGE_EXECUTE_READ, &old_protect))
    {
        return BAL_ERROR_MEMORY_FAULT;
    }

    return BAL_SUCCESS;
}
void
default_free_executable(bal_allocator_handle_t handle, bal_executable_buffer_t buffer, size_t size)
{
    (void)handle;

    if (NULL == buffer.rx_pointer)
    {
        return;
    }

    VirtualFree(buffer.rx_pointer, 0, MEM_RELEASE);
}

#endif /* BAL_PLATFORM_WINDOWS */

static const uint8_t *
bal_flat_translation_interface_translate(void *BAL_RESTRICT   interface,
                                         bal_guest_address_t  guest_address,
                                         size_t *BAL_RESTRICT max_readable_size)
{
    if (BAL_UNLIKELY(NULL == interface || NULL == max_readable_size))
    {
        return NULL;
    }

    const flat_translation_interface_t *BAL_RESTRICT context
        = ((bal_memory_interface_t *)interface)->context;

    if (NULL == context)
    {
        fprintf(stderr, "Casting memory interface returned NULL\n");
        return NULL;
    }

    // Is address out of bounds.
    //
    if (guest_address >= context->size)
    {
        BAL_LOG_ERROR(&context->logger,
                      "GVA 0x%llX Out of bounds (Limit: 0x%llX)",
                      (unsigned long long)guest_address,
                      (unsigned long long)context->size);
        return NULL;
    }

    *max_readable_size          = context->size - guest_address;
    const uint8_t *host_address = context->host + guest_address;

    BAL_LOG_TRACE(&context->logger,
                  "Translate 0x%llx -> Host %p",
                  (unsigned long long)guest_address,
                  (void *)host_address);
    return host_address;
}

/*** end of file ***/
