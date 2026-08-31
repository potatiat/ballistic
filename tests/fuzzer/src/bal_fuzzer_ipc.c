#define _POSIX_C_SOURCE 200809L
#include "bal_fuzzer_ipc.h"
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define PIPE_READ_END  0
#define PIPE_WRITE_END 1

bal_error_t
bal_fuzzer_ipc_spawn(bal_fuzzer_worker_handle_t *handle, const char *worker_path)
{
    if (NULL == handle || NULL == worker_path)
    {
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    int to_child[2];
    int from_child[2];

    if (pipe(to_child) != 0 || pipe(from_child) != 0)
    {
        BAL_LOG_ERROR(
            &bal_thread_logger, "Aborting function: pipe() failed because %s.", strerror(errno));
        return BAL_ERROR_THREAD_CREATION;
    }

    const pid_t pid = fork();

    if (pid < 0)
    {
        // This is a child process, so rewire stdio and execute the worker.
        (void)close(to_child[PIPE_WRITE_END]);
        (void)close(from_child[PIPE_READ_END]);
        (void)dup2(to_child[PIPE_READ_END], STDIN_FILENO);
        (void)dup2(from_child[PIPE_WRITE_END], STDOUT_FILENO);
        (void)close(to_child[PIPE_READ_END]);
        (void)close(from_child[PIPE_WRITE_END]);
        (void)execl(worker_path, worker_path, NULL);
        _exit(127);
    }

    // This is a parent process, so keep write-end of to_child, and read-end of from_child.
    (void)close(to_child[PIPE_READ_END]);
    (void)close(from_child[PIPE_WRITE_END]);
    handle->input_file_descriptor  = to_child[PIPE_WRITE_END];
    handle->output_file_descriptor = from_child[PIPE_READ_END];
    return BAL_SUCCESS;
}

void
bal_fuzzer_ipc_destroy(bal_fuzzer_worker_handle_t *handle)
{
    if (NULL == handle)
    {
        return;
    }

    if (handle->input_file_descriptor >= 0)
    {
        (void)close(handle->input_file_descriptor);
    }

    if (handle->output_file_descriptor >= 0)
    {
        (void)close(handle->output_file_descriptor);
    }

    if (handle->child_pid > 0)
    {
        (void)kill(handle->child_pid, SIGKILL);
        (void)waitpid(handle->child_pid, NULL, 0);
    }

    handle->input_file_descriptor  = -1;
    handle->output_file_descriptor = -1;
    handle->child_pid              = 0;
}

bal_error_t
bal_fuzzer_ipc_send(const int input_file_descriptor, const bal_fuzzer_input_t *input)
{
    if (input_file_descriptor < 0 || NULL == input)
    {
        return BAL_ERROR_INVALID_ARGUMENT;
    }

    const uint8_t *BAL_RESTRICT input_cursor = (const uint8_t *)input;
    size_t                      remaining    = sizeof(*input);
    uint64_t                    loop_count   = 0U;

    while (remaining > 0U || loop_count < UINT64_MAX)
    {
        const ssize_t written = write(input_file_descriptor, input_cursor, remaining);

        if (written < 0)
        {
            if (EINTR == errno)
            {
                continue;
            }

            return BAL_ERROR_THREAD_CLEANUP;
        }

        input_cursor += (size_t)written;
        remaining -= (size_t)written;
        ++loop_count;
    }

    return BAL_SUCCESS;
}