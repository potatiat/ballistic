#ifndef BALLISTIC_DASHBOARD_H
#define BALLISTIC_DASHBOARD_H

#include "GLFW/glfw3.h"
#include "bal_attributes.h"
#include "lua.h"
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif // __cplusplus

    BAL_ALIGNED(64) typedef struct
    {
        lua_State  *lua;
        GLFWwindow *window;
        uint64_t    last_script_mtime;
        uint32_t    window_width;
        uint32_t    window_height;
        bool        is_running;
        uint8_t     pad[31];
    } bal_dashboard_context_t;

    static_assert(64 == sizeof(bal_dashboard_context_t), "Struct size mismatch: Must be 64 bytes");

#ifdef __cplusplus
}
#endif // __cplusplus

#endif // BALLISTIC_DASHBOARD_H
