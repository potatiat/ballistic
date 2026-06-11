cmake_minimum_required(VERSION 3.25)
project(BallisticDashboard LANGUAGES C CXX VERSION 0.1.0)
set(CMAKE_C_STANDARD 17)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_C_EXTENSIONS OFF) # Strict ISO C
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

add_executable(${PROJECT_NAME}
        main.c
        dashboard_backend.cpp
        dashboard_file_dialog.cpp
        ${cimgui_SOURCE_DIR}/cimgui/cimgui.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/imgui.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/imgui_draw.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/imgui_demo.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/imgui_tables.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/imgui_widgets.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/backends/imgui_impl_glfw.cpp
        ${cimgui_SOURCE_DIR}/cimgui/imgui/backends/imgui_impl_opengl3.cpp
)

target_compile_definitions(${PROJECT_NAME} PRIVATE
        -DDASHBOARD_DIRECTORY="${CMAKE_CURRENT_SOURCE_DIR}"
        -DBALLISTIC_DIRECTORY="${CMAKE_SOURCE_DIR}"
        -DCIMGUI_USE_OPENGL3
        -DCIMGUI_USE_GLFW)
target_include_directories(${PROJECT_NAME} PRIVATE
        ${cimgui_SOURCE_DIR}/cimgui
        ${cimgui_SOURCE_DIR}/cimgui/imgui
        ${glfw_SOURCE_DIR}/include
)

# TODO: find_package(OpenGL) for macOS.
target_link_libraries(${PROJECT_NAME} PRIVATE Ballistic glfw cimgui_glfw luajit_lib)

set_target_properties(${PROJECT_NAME} PROPERTIES ENABLE_EXPORTS TRUE)

if (CMAKE_SYSTEM_NAME STREQUAL "Windows")
    target_link_libraries(${PROJECT_NAME} PRIVATE kernel32)
    target_compile_options(${PROJECT_NAME} PRIVATE -DNOMINMAX -DWIN32_LEAN_AND_MEAN)
else ()
    target_link_libraries(${PROJECT_NAME} PRIVATE m dl)
endif ()