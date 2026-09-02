#include "bal_fuzzer_protocol.h"

#include <string.h>
#include <unistd.h>

static int read_exact(int fd, void *data, size_t size);
static int write_exact(int fd, const void *data, size_t size);

int
main(void)
{
    bal_fuzzer_input_t    input    = {};
    bal_fuzzer_response_t response = {};

    for (;;)
    {
        if (read_exact(STDIN_FILENO, &input, sizeof(input)) != 0)
        {
            return 0;
        }

        response.message_id = input.message_id;
        response.status     = BAL_FUZZER_WORKER_OK;
        (void)memset(&response.final_state, 0, sizeof(response.final_state));

        response.final_state.x[0] = 42U;
        response.final_state.pc   = 8U;

        if (write_exact(STDOUT_FILENO, &response, sizeof(response)) != 0)
        {
            return 0;
        }
    }
}

int
read_exact(const int fd, void *BAL_RESTRICT data, const size_t size)
{
    uint8_t *BAL_RESTRICT cursor    = (uint8_t *)data;
    size_t                remaining = size;

    while (remaining > 0U)
    {
        const ssize_t bytes_read = read(fd, cursor, remaining);

        if (bytes_read <= 0)
        {
            return -1;
        }

        cursor += (size_t)bytes_read;
        remaining -= (size_t)bytes_read;
    }

    return 0;
}

int
write_exact(const int fd, const void *data, const size_t size)
{
    const uint8_t *cursor    = (const uint8_t *)data;
    size_t         remaining = size;

    while (remaining > 0U)
    {
        const ssize_t bytes_read = write(fd, cursor, remaining);

        if (bytes_read <= 0)
        {
            return -1;
        }

        cursor += (size_t)bytes_read;
        remaining -= (size_t)bytes_read;
    }

    return 0;
}

/*** end of file ***/