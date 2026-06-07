cmake_minimum_required(VERSION 3.25)

if (APPLE)
    # Only the Linux and Windows binaries have been added, so if LuaJIT is already installed on the system that would be
    # ideal.
    message(STATUS "[LuaJIT-macOS] macOS detected, searching for Homebrew or system LuaJIT...")
    find_program(LUAJIT_EXECUTABLE luajit PATHS "/opt/homebrew/bin" "/usr/local/bin")

    if (NOT LUAJIT_EXECUTABLE)
        message(FATAL_ERROR "[LuaJIT-macOS] 'luajit' executable not found on macOS.\n"
                "Please install LuaJIT via Homebrew: brew install luajit")
    endif ()

    find_path(LUAJIT_HEADERS_DIRECTORY NAMES lua.h PATH_SUFFIXES "luajit-2.1" PATHS "/opt/homebrew/include" "/usr/local/include")
    find_library(LUAJIT_SO_FILES NAMES luajit-5.1 luajit PATHS "/opt/homebrew/lib" "usr/local/lib")
    message(STATUS "[LuaJIT-macOS] Found LuaJIT executable: ${LUAJIT_EXECUTABLE}")

    if (LUAJIT_HEADERS_DIRECTORY)
        message(STATUS "[LuaJIT-macOS] Found LuaJIT headers: ${LUAJIT_HEADERS_DIRECTORY}")
        file(COPY "${LUAJIT_HEADERS_DIRECTORY}" DESTINATION "${BALLISTIC_LIBRARIES_DIRECTORY}")
    endif ()

    if (LUAJIT_SO_FILES)
        message(STATUS "[LuaJIT-macOS] Found LuaJIT library: ${LUAJIT_SO_FILES}")
        file(COPY "${LUAJIT_SO_FILES}" DESTINATION "${BALLISTIC_LIBRARIES_DIRECTORY}")
        get_filename_component(SO_NAME "${LUAJIT_SO}" NAME)
        set(LUAJIT_SO "${BALLISTIC_LIBRARIES_DIRECTORY}/${SO_NAME}")
    endif ()
else ()
    message(STATUS "[LuaJIT-Linux] Linux detected, locating precompiled binaries...")
    file(GLOB LUAJIT_PACKAGE_DIRECTORIES "${CMAKE_CURRENT_SOURCE_DIR}/luajit-2.1.*.pkg")
    list(LENGTH LUAJIT_PACKAGE_DIRECTORIES PACKAGE_COUNT)

    if (PACKAGE_COUNT EQUAL 0)
        message(FATAL_ERROR "[LuaJIT-Linux] Could not find the extracted LuaJIT package directory.\n "
                "Expected a directory matching 'luajit-2.1.*.pkg' in ${CMAKE_CURRENT_SOURCE_DIR}.")
    elseif (PACKAGE_COUNT GREATER 1)
        message(FATAL_ERROR "[LuaJIT-Linux] Multiple LuaJIT package directories found!\n"
                "Delete older package directories in ${CMAKE_CURRENT_SOURCE_DIR}.")
    endif ()

    list(GET LUAJIT_PACKAGE_DIRECTORIES 0 LUAJIT_PACKAGE_DIRECTORY)
    set(LUAJIT_EXECUTABLE "${LUAJIT_PACKAGE_DIRECTORY}/usr/bin/luajit")

    if (NOT EXISTS "${LUAJIT_EXECUTABLE}")
        message(FATAL_ERROR "[LuaJIT-Linux] Executable not found at expected path: ${LUAJIT_EXECUTABLE}.\n"
                "Verify the contents of the extracted package.")
    endif ()

    message(STATUS "[LuaJIT-Linux] Found LuaJIT executable: ${LUAJIT_EXECUTABLE}.")
    file(GLOB LUAJIT_SO_FILES "${LUAJIT_PACKAGE_DIRECTORY}/usr/lib/libluajit-*.so*")
    file(GLOB LUAJIT_A_FILES "${LUAJIT_PACKAGE_DIRECTORY}/usr/lib/libluajit-*.a")
    file(GLOB LUAJIT_HEADERS_DIRECTORY "${LUAJIT_PACKAGE_DIRECTORY}/usr/include/luajit-2.1")
    file(COPY "${LUAJIT_EXECUTABLE}" DESTINATION "${BALLISTIC_BINARIES_DIRECTORY}")

    if (LUAJIT_SO_FILES)
        file(COPY ${LUAJIT_SO_FILES} DESTINATION "${BALLISTIC_LIBRARIES_DIRECTORY}")
        list(GET LUAJIT_SO_FILES 0 LUAJIT_SO)
    endif ()

    if (LUAJIT_A_FILES)
        file(COPY ${LUAJIT_A_FILES} DESTINATION "${BALLISTIC_LIBRARIES_DIRECTORY}")
    endif ()
endif ()

if (LUAJIT_SO)
    add_library(luajit_lib SHARED IMPORTED GLOBAL)
    set_target_properties(luajit_lib PROPERTIES
            IMPORTED_LOCATION "${LUAJIT_SO}"
            INTERFACE_INCLUDE_DIRECTORIES "${LUAJIT_HEADERS_DIRECTORY}")
    message(STATUS "[LuaJIT-Linux] Exported library target 'luajit_lib' linked to ${LUAJIT_SO}.")
endif ()

add_executable(luajit IMPORTED GLOBAL)
set_target_properties(luajit PROPERTIES IMPORTED_LOCATION "${LUAJIT_EXECUTABLE}")
target_link_libraries(luajit INTERFACE luajit_lib)

message(STATUS "==================================================================")
message(STATUS "[LuaJIT-Linux] Pre-compiled targets successfully configured.")
message(STATUS "==================================================================")