local log = require("log")

local M = {}

M.KIND = {
    -- Root node holding file-level documentation and all items.
    MODULE = 1,

    --- Struct declaration with fields and static asserts.
    STRUCT = 2,

    --- Union declaration with fields.
    UNION = 3,

    --- Single member of a struct or union.
    FIELD = 4,

    --- Enum declaration with variants.
    ENUM = 5,

    --- Single named constant inside an enum.
    VARIANT = 6,

    --- Function declaration with parameters and return type.
    FUNCTION = 7,

    --- Single parameter of a function.
    PARAMETER = 8,

    --- Typedef alias, optionally a function pointer.
    TYPEDEF = 9,

    --- #define numeric constant.
    CONSTANT = 10,

    --- static_assert verifying struct size of invariants.
    STATIC_ASSERT = 11,
}

--- Creates a source location table that records where a declaration appears in the original header file. `filepath`
--- is the absolute or relative path to the header. `line_number` and `column_number` tracks where the declaration
--- starts in `filepath`.
---
--- Returns { filepath = filepath, line_number = line_number, column_number = column_number }
function M.create_location_table(filepath, line_number, column_number)
    return {filepath = filepath, line_number = line_number, column_number = column_number}
end

--- Create a module node. This mirrors rustdoc's crate root.
--- Returns:
--- {
---     kind = ast.Kind.MODULE,                 -- integer enum discriminator
---     name = string,                          -- header filename (e.g. "bal_assembler.h")
---     filepath = string,                      -- absolute path to the parsed .h file
---     documentation = table|nil,              -- parsed //! file-level doc (from doc.lua)
---     items = {                               -- ordered list of top-level AST nodes
---         { kind = ast.Kind.STRUCT, ... },
---         { kind = ast.Kind.UNION, ... },
---         { kind = ast.Kind.ENUM, ... },
---         { kind = ast.Kind.FUNCTION, ... },
---         { kind = ast.Kind.TYPEDEF, ... },
---         { kind = ast.Kind.CONSTANT, ... },
---         { kind = ast.Kind.STATIC_ASSERT, ... },
---     },
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_module(name, filepath, documentation)
    log.trace("Creating module node '%s' from %s.", name, filepath)
    local line_number = 1
    local column_number = 1
    return
        {
            kind = "module",
            name = name,
            filepath = filepath,
            documentation = documentation,
            items = {},
            location = M.create_location_table(filepath, line_number, column_number)
        }
end

return M