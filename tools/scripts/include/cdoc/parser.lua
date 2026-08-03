local log = require("log")
local M = {}

function is_array(t)
    if type(t) ~= "table" then
        return false
    end
    return #t > 0 and next(t, #t) == nil
end

function M.parse_header(clang, header_path, clang_args)
    log.info("Parsing header %s.", header_path)
    local file = io.open(header_path, "r")

    if not file then
        log.error("Aborting function: Failed to open header file %s.", header_path)
        error("failed to parse header file.")
    end

    if not clang then
        log.error("Aborting function: libclang not initialized.")
        error("libclang not initialized.")
    end
end

return M