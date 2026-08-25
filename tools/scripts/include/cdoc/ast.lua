local log = require("log")

local M = {}

M.KIND = {
    MODULE = 1,
    STRUCT = 2,
    UNION = 3,
    FIELD = 4,
    ENUM = 5,
    VARIANT = 6,
    FUNCTION = 7,
    PARAMETER = 8,
    TYPEDEF = 9,
    CONSTANT = 10,
    STATIC_ASSERT = 11,
}

function M.create_location_table(filepath, line_number, column_number)
    return {
        filepath = filepath,
        line_number = line_number or 1,
        column_number = column_number or 1,
    }
end

function M.create_module(name, filepath, documentation)
    log.trace("Creating module node '%s' from %s.", name, filepath)
    return {
        kind = M.KIND.MODULE,
        name = name,
        filepath = filepath,
        documentation = documentation,
        items = {},
        location = M.create_location_table(filepath, 1, 1),
    }
end

function M.create_field(name, type_name, documentation, location)
    return {
        kind = M.KIND.FIELD,
        name = name,
        type = type_name,
        documentation = documentation,
        location = location,
    }
end

function M.create_variant(name, value, documentation, location)
    return {
        kind = M.KIND.VARIANT,
        name = name,
        value = value,
        documentation = documentation,
        location = location,
    }
end

function M.create_parameter(name, type_name)
    return {
        kind = M.KIND.PARAMETER,
        name = name,
        type = type_name,
    }
end

function M.create_struct(name, fields, documentation, location, union)
    return {
        kind = union and M.KIND.UNION or M.KIND.STRUCT,
        name = name,
        fields = fields or {},
        documentation = documentation,
        location = location,
        anchor = "struct." .. name,
    }
end

function M.create_enum(name, variants, documentation, location)
    return {
        kind = M.KIND.ENUM,
        name = name,
        variants = variants or {},
        documentation = documentation,
        location = location,
        anchor = "enum." .. name,
    }
end

function M.create_function(name, return_type, parameters, documentation, location)
    return {
        kind = M.KIND.FUNCTION,
        name = name,
        return_type = return_type,
        parameters = parameters or {},
        documentation = documentation,
        location = location,
        anchor = "fn." .. name,
    }
end

function M.create_typedef(name, underlying_type, return_type, parameters, documentation, location)
    return {
        kind = M.KIND.TYPEDEF,
        name = name,
        underlying_type = underlying_type,
        return_type = return_type,
        parameters = parameters or {},
        documentation = documentation,
        location = location,
        anchor = "type." .. name,
    }
end

function M.create_constant(name, value, documentation, location)
    return {
        kind = M.KIND.CONSTANT,
        name = name,
        value = value,
        documentation = documentation,
        location = location,
        anchor = "constant." .. name,
    }
end

return M
