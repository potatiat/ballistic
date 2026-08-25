local log = require("log")
local clang = require("cdoc.clang")
local ast = require("cdoc.ast")
local documentation = require("cdoc.documentation")

local M = {}

local function basename(path)
    return path:match("([^/\\]+)$") or path
end

local function parse_file_level_docs(header_path)
    local file = io.open(header_path, "r")
    if not file then
        log.error("parser: cannot open '%s' for file-level docs", header_path)
        return nil
    end

    local lines = {}
    for line in file:lines() do
        local stripped = line:match("^%s*(.-)%s*$")
        if stripped and stripped:sub(1, 3) == "//!" then
            local content = stripped:sub(4)
            if content:sub(1, 1) == " " then
                content = content:sub(2)
            end
            if content:sub(1, 6) ~= "// ---" then
                lines[#lines + 1] = content
            end
        end
    end
    file:close()

    if #lines == 0 then
        return nil
    end
    return documentation.parse(table.concat(lines, "\n"))
end

local function skippable(context, cursor)
    if context.library.clang_Cursor_isAnonymous(cursor) ~= 0 then
        return true
    end
    local name = clang.spelling(context, cursor)
    return name == "" or name:find("%(unnamed", 1, true) ~= nil
end

local function item_location(context, cursor, header_path)
    local where = clang.location(context, cursor)
    return ast.create_location_table(header_path, where.line, where.column)
end

local function parse_fields(context, tu, record_cursor, header_path)
    local fields = {}
    for _, field_cursor in ipairs(clang.fields(context, tu, record_cursor)) do
        local name = clang.spelling(context, field_cursor)
        if name ~= "" then
            fields[#fields + 1] = ast.create_field(
                name,
                clang.type_spelling(context, context.library.clang_getCursorType(field_cursor)),
                documentation.parse(clang.comment(context, field_cursor)),
                item_location(context, field_cursor, header_path)
            )
        end
    end
    return fields
end

local function parse_variants(context, tu, enum_cursor, header_path)
    local variants = {}
    for _, constant in ipairs(clang.enum_constants(context, tu, enum_cursor)) do
        local name = clang.spelling(context, constant)
        if name ~= "" then
            variants[#variants + 1] = ast.create_variant(
                name,
                tostring(tonumber(context.library.clang_getEnumConstantDeclValue(constant))),
                documentation.parse(clang.comment(context, constant)),
                item_location(context, constant, header_path)
            )
        end
    end
    return variants
end

local function parse_parameters(context, tu, cursor)
    local parameters = {}
    for _, arg in ipairs(clang.parameters(context, tu, cursor)) do
        parameters[#parameters + 1] = ast.create_parameter(arg.name, arg.type)
    end
    return parameters
end

local function comment_or_underlying(context, cursor, underlying_cursor)
    local doc = documentation.parse(clang.comment(context, cursor))
    if doc then
        return doc
    end
    if underlying_cursor then
        return documentation.parse(clang.comment(context, underlying_cursor))
    end
    return nil
end

local function add_item(module, seen, item)
    if not item or not item.name or item.name == "" then
        return
    end
    if seen[item.name] then
        return
    end
    seen[item.name] = true
    module.items[#module.items + 1] = item
end

local function is_include_guard(name)
    return name:match("_H$") ~= nil or name:match("_H_$") ~= nil
end

function M.parse_header(clang_context, header_path, clang_args, index)
    log.info("Parsing header %s.", header_path)

    local owns_index = index == nil
    if owns_index then
        index = clang.create_index(clang_context)
    end
    if not index then
        return nil
    end

    local tu = clang.parse_translation_unit(clang_context, index, header_path, clang_args)
    if tu == nil then
        if owns_index then
            clang.dispose_index(clang_context, index)
        end
        return nil
    end

    local library = clang_context.library
    local module = ast.create_module(basename(header_path), header_path, parse_file_level_docs(header_path))
    local seen = {}

    for _, cursor in ipairs(clang.declarations(clang_context, tu, header_path)) do
        local kind = cursor.kind
        local name = clang.spelling(clang_context, cursor)
        local location = item_location(clang_context, cursor, header_path)

        if kind == clang.KIND.FunctionDecl then
            add_item(module, seen, ast.create_function(
                name,
                clang.type_spelling(clang_context, library.clang_getCursorResultType(cursor)),
                parse_parameters(clang_context, tu, cursor),
                documentation.parse(clang.comment(clang_context, cursor)),
                location
            ))
        elseif kind == clang.KIND.StructDecl or kind == clang.KIND.UnionDecl then
            if not skippable(clang_context, cursor) and library.clang_isCursorDefinition(cursor) ~= 0 then
                add_item(module, seen, ast.create_struct(
                    name,
                    parse_fields(clang_context, tu, cursor, header_path),
                    documentation.parse(clang.comment(clang_context, cursor)),
                    location,
                    kind == clang.KIND.UnionDecl
                ))
            end
        elseif kind == clang.KIND.EnumDecl then
            if not skippable(clang_context, cursor) and library.clang_isCursorDefinition(cursor) ~= 0 then
                add_item(module, seen, ast.create_enum(
                    name,
                    parse_variants(clang_context, tu, cursor, header_path),
                    documentation.parse(clang.comment(clang_context, cursor)),
                    location
                ))
            end
        elseif kind == clang.KIND.TypedefDecl then
            local underlying = library.clang_getTypedefDeclUnderlyingType(cursor)
            local canonical = library.clang_getCanonicalType(underlying)
            local declared = library.clang_getTypeDeclaration(canonical)

            if canonical.kind == clang.TYPE.Record then
                add_item(module, seen, ast.create_struct(
                    name,
                    parse_fields(clang_context, tu, declared, header_path),
                    comment_or_underlying(clang_context, cursor, declared),
                    location,
                    false
                ))
            elseif canonical.kind == clang.TYPE.Enum then
                add_item(module, seen, ast.create_enum(
                    name,
                    parse_variants(clang_context, tu, declared, header_path),
                    comment_or_underlying(clang_context, cursor, declared),
                    location
                ))
            else
                local return_type = nil
                local parameters = {}
                if underlying.kind == clang.TYPE.Pointer then
                    local pointee = library.clang_getPointeeType(underlying)
                    if pointee.kind == clang.TYPE.FunctionProto or pointee.kind == clang.TYPE.FunctionNoProto then
                        return_type = clang.type_spelling(clang_context, library.clang_getResultType(pointee))
                        parameters = parse_parameters(clang_context, tu, cursor)
                    end
                end
                add_item(module, seen, ast.create_typedef(
                    name,
                    clang.type_spelling(clang_context, underlying),
                    return_type,
                    parameters,
                    documentation.parse(clang.comment(clang_context, cursor)),
                    location
                ))
            end
        elseif kind == clang.KIND.MacroDefinition then
            if not is_include_guard(name) then
                add_item(module, seen, ast.create_constant(
                    name,
                    nil,
                    documentation.parse(clang.comment(clang_context, cursor)),
                    location
                ))
            end
        end
    end

    clang.dispose_translation_unit(clang_context, tu)
    if owns_index then
        clang.dispose_index(clang_context, index)
    end
    log.debug("Parsed %d items from %s.", #module.items, header_path)
    return module
end

local function register_item(registry, item, source_file)
    if not item.name then
        return
    end

    registry[item.name] = {
        name = item.name,
        kind = item.kind,
        source_file = source_file,
        anchor = item.anchor,
    }

    if item.kind == ast.KIND.ENUM then
        for _, variant in ipairs(item.variants or {}) do
            registry[variant.name] = {
                name = variant.name,
                kind = ast.KIND.VARIANT,
                source_file = source_file,
                anchor = variant.name,
            }
        end
    elseif item.kind == ast.KIND.STRUCT or item.kind == ast.KIND.UNION then
        for _, field in ipairs(item.fields or {}) do
            registry[item.name .. "." .. field.name] = {
                name = field.name,
                kind = ast.KIND.FIELD,
                source_file = source_file,
                anchor = field.name,
            }
        end
    end
end

function M.parse_headers(clang_context, headers, clang_args)
    local index = clang.create_index(clang_context)
    local modules = {}
    local registry = {}

    for _, header_path in ipairs(headers) do
        local module = M.parse_header(clang_context, header_path, clang_args, index)
        if module then
            modules[#modules + 1] = module
            registry[module.name] = {
                name = module.name,
                kind = ast.KIND.MODULE,
                source_file = module.name,
                anchor = "",
            }
            for _, item in ipairs(module.items) do
                register_item(registry, item, module.name)
            end
        end
    end

    clang.dispose_index(clang_context, index)
    return { modules = modules, registry = registry }
end

return M
