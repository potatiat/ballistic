/** @file bal_errors.h
 *
 * @brief Defines Ballistic error types.
 */

#ifndef BAL_ERRORS_H
#define BAL_ERRORS_H

#include "bal_attributes.h"

#ifdef __cplusplus
extern "C"
{
#endif /* __cplusplus */

    typedef enum
    {
        // General Errors.
        //
        BAL_SUCCESS                 = 0,
        BAL_ERROR_INVALID_ARGUMENT  = -1,
        BAL_ERROR_ALLOCATION_FAILED = -2,

        /// Guest code tried to execute an unaligned instruction.
        BAL_ERROR_PC_ALIGNMENT     = -3,
        BAL_ERROR_MEMORY_ALIGNMENT = -4,

        /// Ballistic tried to access memory it was not allowed to access.
        BAL_ERROR_MEMORY_FAULT        = -5,
        BAL_ERROR_UNKNOWN_INSTRUCTION = -6,

        /// Error when creating a thread.
        BAL_ERROR_THREAD_CREATION = -7,

        // IR Errors.
        //
        BAL_ERROR_INSTRUCTION_OVERFLOW = -100,

        /// The decoded register type does not match the expected type.
        BAL_ERROR_INCORRECT_REGISTER_TYPE = -101,
    } bal_error_t;

    /// Converts the enum into a readable string for error handling.
    BAL_COLD const char *bal_error_to_string(bal_error_t error);

#ifdef __cplusplus
}
#endif /* __cplusplus */

#endif /* BAL_ERRORS_H */

/*** end of file ***/
