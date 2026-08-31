#include "bal_fuzzer_ipc.h"
#include <errno.h>
#include <fcntl.h>
#include <string.h>
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