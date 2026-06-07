cmake_minimum_required(VERSION 3.25)
project(LuaJIT_Precompiled)

message(STATUS "==================================================================")
message(STATUS "[LuaJIT] Configuring pre-compiled LuaJIT dependency...")
message(STATUS "==================================================================")

if (WIN32)
    message(STATUS "[LuaJIT] Windows platform detected. Routing to windows/...")
    add_subdirectory(windows)
else ()
    message(STATUS "[LuaJIT] Unix Platform detected. Routing to unix/...")
    add_subdirectory(unix)
endif ()