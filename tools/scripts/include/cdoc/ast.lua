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

    --- #define constant. Stays KIND.CONSTANT; function_like iff `(` immediately after the name.
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
            kind = M.KIND.MODULE,
            name = name,
            filepath = filepath,
            documentation = documentation,
            items = {},
            location = M.create_location_table(filepath, line_number, column_number)
        }
end

--- Single member of a struct or union.
--- Returns:
--- {
---     kind = ast.Kind.FIELD,
---     name = string,
---     type = string,                          -- clang type spelling
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
---     bit_width = number|nil,                 -- from clang_getFieldDeclBitWidth
--- }
function M.create_field(name, type_name, documentation, location, bit_width)
    log.trace("Creating field node '%s'.", name)
    return
        {
            kind = M.KIND.FIELD,
            name = name,
            type = type_name,
            documentation = documentation,
            location = location,
            bit_width = bit_width,
        }
end

--- Single named constant inside an enum.
--- Returns:
--- {
---     kind = ast.Kind.VARIANT,
---     name = string,
---     value = string,                         -- enumerator value as text
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_variant(name, value, documentation, location)
    log.trace("Creating variant node '%s'.", name)
    return
        {
            kind = M.KIND.VARIANT,
            name = name,
            value = value,
            documentation = documentation,
            location = location,
        }
end

--- Single parameter of a function.
--- Returns:
--- {
---     kind = ast.Kind.PARAMETER,
---     name = string,
---     type = string,
--- }
function M.create_parameter(name, type_name)
    log.trace("Creating parameter node '%s'.", name)
    return
        {
            kind = M.KIND.PARAMETER,
            name = name,
            type = type_name,
        }
end

--- Struct declaration with fields and static asserts.
--- Returns:
--- {
---     kind = ast.Kind.STRUCT,
---     name = string,
---     fields = { { kind = ast.Kind.FIELD, ... }, ... },
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_struct(name, fields, documentation, location)
    log.trace("Creating struct node '%s'.", name)
    return
        {
            kind = M.KIND.STRUCT,
            name = name,
            fields = fields or {},
            documentation = documentation,
            location = location,
        }
end

--- Union declaration with fields.
--- Returns:
--- {
---     kind = ast.Kind.UNION,
---     name = string,
---     fields = { { kind = ast.Kind.FIELD, ... }, ... },
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_union(name, fields, documentation, location)
    log.trace("Creating union node '%s'.", name)
    return
        {
            kind = M.KIND.UNION,
            name = name,
            fields = fields or {},
            documentation = documentation,
            location = location,
        }
end

--- Enum declaration with variants.
--- Returns:
--- {
---     kind = ast.Kind.ENUM,
---     name = string,
---     variants = { { kind = ast.Kind.VARIANT, ... }, ... },
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_enum(name, variants, documentation, location)
    log.trace("Creating enum node '%s'.", name)
    return
        {
            kind = M.KIND.ENUM,
            name = name,
            variants = variants or {},
            documentation = documentation,
            location = location,
        }
end

--- Function declaration with parameters and return type.
--- Returns:
--- {
---     kind = ast.Kind.FUNCTION,
---     name = string,
---     return_type = string,
---     parameters = { { kind = ast.Kind.PARAMETER, ... }, ... },
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_function(name, return_type, parameters, documentation, location)
    log.trace("Creating function node '%s'.", name)
    return
        {
            kind = M.KIND.FUNCTION,
            name = name,
            return_type = return_type,
            parameters = parameters or {},
            documentation = documentation,
            location = location,
        }
end

--- Typedef alias, optionally a function pointer.
--- Returns:
--- {
---     kind = ast.Kind.TYPEDEF,
---     name = string,
---     underlying_type = string,
---     return_type = string|nil,               -- set when the alias is a function pointer
---     parameters = { { kind = ast.Kind.PARAMETER, ... }, ... },
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_typedef(name, underlying_type, return_type, parameters, documentation, location)
    log.trace("Creating typedef node '%s'.", name)
    return
        {
            kind = M.KIND.TYPEDEF,
            name = name,
            underlying_type = underlying_type,
            return_type = return_type,
            parameters = parameters or {},
            documentation = documentation,
            location = location,
        }
end

--- #define constant. Stays KIND.CONSTANT; function_like iff `(` immediately after the name.
--- Returns:
--- {
---     kind = ast.Kind.CONSTANT,
---     name = string,
---     value = string,
---     function_like = boolean,                -- true iff `(` immediately after the name
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_constant(name, value, documentation, location, function_like)
    log.trace("Creating constant node '%s'.", name)
    return
        {
            kind = M.KIND.CONSTANT,
            name = name,
            value = value,
            function_like = function_like == true,
            documentation = documentation,
            location = location,
        }
end

--- static_assert verifying struct size of invariants.
--- Returns:
--- {
---     kind = ast.Kind.STATIC_ASSERT,
---     message = string,
---     documentation = table|nil,
---     location = { filepath = string, line_number = number, column_number = number },
--- }
function M.create_static_assert(message, documentation, location)
    log.trace("Creating static_assert node.")
    return
        {
            kind = M.KIND.STATIC_ASSERT,
            message = message,
            documentation = documentation,
            location = location,
        }
end

return M