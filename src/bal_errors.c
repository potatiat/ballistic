#include "bal_errors.h"

const char *
bal_error_to_string(const bal_error_t error)
{
    const char *string = "";
    switch (error)
    {
        case BAL_ERROR_INVALID_ARGUMENT:
            string = "function argument is NULL or invalid";
            break;
        case BAL_ERROR_ALLOCATION_FAILED:
            string = "failed to allocate memory";
            break;
        case BAL_ERROR_PC_ALIGNMENT:
            string = "guest code tried to execute an unaligned instruction";
            break;
        case BAL_ERROR_MEMORY_ALIGNMENT:
            string = "buffer is not aligned to the required memory alignment";
            break;
        case BAL_ERROR_MEMORY_FAULT:
            string = "accessed invalid memory";
            break;
        case BAL_ERROR_UNKNOWN_INSTRUCTION:
            string = "failed to decode arm instruction";
            break;
        case BAL_ERROR_INSTRUCTION_OVERFLOW:
            string = "instructions array overflowed";
            break;
        case BAL_ERROR_INCORRECT_REGISTER_TYPE:
            string = "incorrect register type";
            break;
        case BAL_SUCCESS:
            string = "there is no error";
            break;
    }

    return string;
}

/*** end of file ***/
