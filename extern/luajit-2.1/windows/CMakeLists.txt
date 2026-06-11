cmake_minimum_required(VERSION 3.25)
message(STATUS "[LuaJIT-Windows] Locating pre-compiled Windows binaries...")
file(GLOB LUAJIT_PACKAGE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/mingw-w64-x86_64-luajit-2.1.*.pkg")
list(LENGTH LUAJIT_PACKAGE_DIRECTORIES PACKAGE_COUNT)

if (PACKAGE_COUNT EQUAL 0)
    message(FATAL_ERROR "[LuaJIT-Windows] Could not find the extracted LuaJIT package directory.\n "
            "Expected a directory matching 'mingw-w64-x86_64-luajit-2.1.*.pkg' in ${CMAKE_CURRENT_SOURCE_DIR}.")
elseif (PACKAGE_COUNT GREATER 1)
    message(FATAL_ERROR "[LuaJIT-Windows] Multiple LuaJIT package directories found!\n"
            "Delete older package directories in ${CMAKE_CURRENT_SOURCE_DIR}.")
endif ()

list(GET LUAJIT_PACKAGE_DIRECTORIES 0 LUAJIT_PACKAGE_DIRECTORY)
set(LUAJIT_EXECUTABLE "${LUAJIT_PACKAGE_DIRECTORY}/mingw64/bin/luajit.exe")

if (NOT EXISTS "${LUAJIT_EXECUTABLE}")
    message(FATAL_ERROR "[LuaJIT-Windows] Executable not found at expected path: ${LUAJIT_EXECUTABLE}.\n"
            "Verify the contents of the extracted package.")
endif ()

message(STATUS "[LuaJIT-Windows] Found LuaJIT executable: ${LUAJIT_EXECUTABLE}.")
file(GLOB LUAJIT_DLL_FILES "${LUAJIT_PACKAGE_DIRECTORY}/mingw64/bin/lua51.dll")
file(GLOB LUAJIT_LIB_FILES "${LUAJIT_PACKAGE_DIRECTORY}/mingw64/lib/libluajit-*.dll.a"
        "${LUAJIT_PACKAGE_DIRECTORY}/mingw64/lib/libluajit-*.a")
file(GLOB LUAJIT_HEADERS_DIRECTORY "${LUAJIT_PACKAGE_DIRECTORY}/mingw64/include/luajit-2.1")
file(COPY "${LUAJIT_EXECUTABLE}" DESTINATION "${BALLISTIC_BINARIES_DIRECTORY}")

if (LUAJIT_DLL_FILES)
    file(COPY ${LUAJIT_DLL_FILES} DESTINATION "${BALLISTIC_LIBRARIES_DIRECTORY}")
    list(GET LUAJIT_DLL_FILES 0 LUAJIT_DLL)
endif ()

if (LUAJIT_LIB_FILES)
    file(COPY ${LUAJIT_LIB_FILES} DESTINATION "${BALLISTIC_LIBRARIES_DIRECTORY}")
    list(GET LUAJIT_LIB_FILES 0 LUAJIT_IMPLIB)
endif ()

if (LUAJIT_DLL)
    add_library(luajit_lib SHARED IMPORTED GLOBAL)
    set_target_properties(luajit_lib PROPERTIES
            IMPORTED_LOCATION "${LUAJIT_DLL}"
            IMPORTED_IMPLIB "${LUAJIT_IMPLIB}"
            INTERFACE_INCLUDE_DIRECTORIES "${LUAJIT_HEADERS_DIRECTORY}")
    message(STATUS "[LuaJIT-Windows] Exported library target 'luajit_lib' linked to ${LUAJIT_DLL}.")
endif ()

add_executable(luajit IMPORTED GLOBAL)
set_target_properties(luajit PROPERTIES IMPORTED_LOCATION "${LUAJIT_EXECUTABLE}")
target_link_libraries(luajit INTERFACE luajit_lib)

message(STATUS "==================================================================")
message(STATUS "[LuaJIT-Windows] Pre-compiled targets successfully configured.")
message(STATUS "==================================================================")
