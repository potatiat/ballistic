local ffi = require("ffi")
local log = require("log")

local M = {}

function is_array(t)
    if type(t) ~= "table" then
        return false
    end
    return #t > 0 and next(t, #t) == nil
end

function M.parse_header(C, header_path, clang_args)
    log.info("Parsing header %s.", header_path)
    local file = io.open(header_path, "r")

    if not file then
        log.error("Aborting function: Failed to open header file %s.", header_path)
        return
    end

    if not C then
        log.error("Aborting function: libclang not initialized.")
        return
    end

    local args = clang_args or {}
    local argc = #args
    local argv = nil

    if argc > 0 then
        argv = ffi.new("const char*[?]", argc)

        for i = 1, argc do
            argv[i - 1] = args[i]
        end
    end

    local index = C.clang_createIndex(0, 1)
    local unsaved_files = nil
    local num_unsaved_files = 0
    local options = 0
    local translation_unit = C.clang_parseTranslationUnit(index, header_path, argv, argc, unsaved_files, num_unsaved_files, options)

    if translation_unit == nil then
        C.clang_disposeIndex(index)
        log.error("Aborting function: failed to create parse translation unit %s.", header_path)
        return
    end

    log.debug("Translation unit created successfully.")
end

return M