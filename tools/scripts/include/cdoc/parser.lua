local log = require("log")
local ast = require("cdoc.ast")
local documentation = require("cdoc.documentation")
local clang = require("cdoc.clang")

local M = {}

local function parse_file_level_docs(header_path)
    local file = io.open(header_path, "r")

    if not file then
        log.error("parser: cannot open '%s' for file-level docs", header_path)
        return nil
    end

    local lines = {}
    local started = false

    for line in file:lines() do
        local stripped = line:match("^%s*(.-)%s*$")

        if stripped and stripped:sub(1, 3) == "//!" then
            started = true
            local content = stripped:sub(4)

            if content:sub(1, 1) == " " then
                content = content:sub(2)
            end

            table.insert(lines, content)
        elseif started then
            break
        elseif stripped and stripped ~= "" then
            break
        end
    end

    file:close()

    if #lines == 0 then
        return nil
    end

    local raw = table.concat(lines, "\n")
    local documentation_table = documentation.parse(raw)
    return documentation_table
end

local function skippable(context, cursor)
    if clang.is_anonymous(context, cursor) then
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
                clang.type_spelling(context, clang.cursor_type(context, field_cursor)),
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
                clang.enum_value(context, constant),
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
        log.debug("parser: dropping item with empty name in '%s'.", module.name or "?")
        return
    end
    if seen[item.name] then
        log.debug("parser: dropping duplicate '%s' in '%s'.", item.name, module.name or "?")
        return
    end
    seen[item.name] = true
    module.items[#module.items + 1] = item
end

local function is_include_guard(name, module_name)
    if type(name) ~= "string" or not name:match("^[%u%d_]+_H_?$") then
        return false
    end
    local stem = (module_name or ""):match("([^/\\]+)%.h$") or ""
    stem = stem:gsub("[^%w]", "_"):upper()
    if stem ~= "" and name:find(stem, 1, true) then
        return true
    end
    return name:match("^BALLISTIC_") ~= nil
end

local function fill_module(context, tu, module, header_path)
    local seen = {}
    local decls = clang.declarations(context, tu, header_path)
    if not decls then
        error("clang produced no file range for '" .. header_path .. "'", 0)
    end

    for _, cursor in ipairs(decls) do
        if clang.from_main_file(context, cursor) then
            local kind = clang.kind(context, cursor)
            local name = clang.spelling(context, cursor)
            local location = item_location(context, cursor, header_path)

            if kind == clang.CURSOR.FunctionDecl then
                add_item(module, seen, ast.create_function(
                    name,
                    clang.type_spelling(context, clang.result_type(context, cursor)),
                    parse_parameters(context, tu, cursor),
                    documentation.parse(clang.comment(context, cursor)),
                    location
                ))
            elseif kind == clang.CURSOR.StructDecl then
                if not skippable(context, cursor) and clang.is_definition(context, cursor) then
                    add_item(module, seen, ast.create_struct(
                        name,
                        parse_fields(context, tu, cursor, header_path),
                        {},
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.UnionDecl then
                if not skippable(context, cursor) and clang.is_definition(context, cursor) then
                    add_item(module, seen, ast.create_union(
                        name,
                        parse_fields(context, tu, cursor, header_path),
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.EnumDecl then
                if not skippable(context, cursor) and clang.is_definition(context, cursor) then
                    add_item(module, seen, ast.create_enum(
                        name,
                        parse_variants(context, tu, cursor, header_path),
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.TypedefDecl then
                local underlying = clang.typedef_underlying(context, cursor)
                local canonical = clang.canonical_type(context, underlying)
                local type_kind = clang.type_kind(canonical)
                local declared = clang.type_declaration(context, canonical)

                if type_kind == clang.TYPE.Record then
                    if clang.kind(context, declared) == clang.CURSOR.UnionDecl then
                        add_item(module, seen, ast.create_union(
                            name,
                            parse_fields(context, tu, declared, header_path),
                            comment_or_underlying(context, cursor, declared),
                            location
                        ))
                    else
                        add_item(module, seen, ast.create_struct(
                            name,
                            parse_fields(context, tu, declared, header_path),
                            {},
                            comment_or_underlying(context, cursor, declared),
                            location
                        ))
                    end
                elseif type_kind == clang.TYPE.Enum then
                    add_item(module, seen, ast.create_enum(
                        name,
                        parse_variants(context, tu, declared, header_path),
                        comment_or_underlying(context, cursor, declared),
                        location
                    ))
                else
                    local return_type = nil
                    local parameters = {}
                    if clang.type_kind(underlying) == clang.TYPE.Pointer then
                        local pointee = clang.pointee_type(context, underlying)
                        if clang.type_kind(pointee) == clang.TYPE.FunctionProto then
                            return_type = clang.type_spelling(context, clang.result_type_of(context, pointee))
                            for _, arg in ipairs(clang.prototype_parameters(context, pointee)) do
                                parameters[#parameters + 1] = ast.create_parameter(arg.name, arg.type)
                            end
                        end
                    end
                    add_item(module, seen, ast.create_typedef(
                        name,
                        clang.type_spelling(context, underlying),
                        return_type,
                        parameters,
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.MacroDefinition then
                if not is_include_guard(name, module.name) then
                    add_item(module, seen, ast.create_constant(
                        name,
                        clang.macro_replacement(context, tu, cursor),
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            end
        end
    end
end

local function register_symbols(project, module)
    local KIND = ast.KIND
    local function anchor_for(item)
        if item.kind == KIND.FUNCTION then
            return "fn." .. item.name
        elseif item.kind == KIND.STRUCT then
            return "struct." .. item.name
        elseif item.kind == KIND.UNION then
            return "union." .. item.name
        elseif item.kind == KIND.ENUM then
            return "enum." .. item.name
        elseif item.kind == KIND.TYPEDEF then
            return "type." .. item.name
        elseif item.kind == KIND.CONSTANT then
            return "constant." .. item.name
        end
        return item.name
    end

    project.symbols[module.name] = module
    module.source_file = module.name
    module.kind = module.kind or ast.KIND.MODULE
    for _, item in ipairs(module.items) do
        item.source_file = module.name
        item.anchor = anchor_for(item)
        if not project.symbols[item.name] then
            project.symbols[item.name] = item
        end
        if item.kind == KIND.ENUM then
            for _, variant in ipairs(item.variants or {}) do
                variant.source_file = module.name
                variant.anchor = item.anchor .. "." .. variant.name
                if not project.symbols[variant.name] then
                    project.symbols[variant.name] = variant
                end
            end
        elseif item.kind == KIND.STRUCT or item.kind == KIND.UNION then
            for _, field in ipairs(item.fields or {}) do
                field.source_file = module.name
                field.anchor = item.anchor .. "." .. field.name
                local field_key = item.name .. "." .. field.name
                if not project.symbols[field_key] then
                    project.symbols[field_key] = field
                end
            end
        end
    end
end

function M.parse_header(clang_context, header_path, clang_args)
    log.info("Parsing header %s.", header_path)
    local file = io.open(header_path, "r")

    if not file then
        log.error("Aborting function: Failed to open header file %s.", header_path)
        return
    end
    file:close()

    if not clang_context then
        log.error("Aborting function: libclang not initialized.")
        return
    end

    local translation_unit, index, parse_error = clang.parse(clang_context, header_path, clang_args)
    if not translation_unit then
        log.error("Aborting function: failed to parse translation unit because %s.", tostring(parse_error))
        return nil
    end

    log.debug("Translation unit created successfully.")
    local file_level_documentation = parse_file_level_docs(header_path)
    local module_name = header_path:match("([^/\\]+)$") or header_path
    if not module_name:match("^[%w._-]+%.h$") then
        log.error("Aborting function: header basename '%s' is not a safe module name.", module_name)
        clang.dispose_parse(clang_context, translation_unit, index)
        return nil
    end
    local module_node = ast.create_module(module_name, header_path, file_level_documentation)
    local filled, fill_error = pcall(fill_module, clang_context, translation_unit, module_node, header_path)
    clang.dispose_parse(clang_context, translation_unit, index)
    if not filled then
        log.error("Aborting function: failed to walk '%s' because %s.", header_path, tostring(fill_error))
        return nil
    end
    return module_node
end

function M.parse_headers(clang_context, headers, clang_args, apis)
    local saved_clang, saved_docs, saved_ast = clang, documentation, ast
    if apis then
        clang = apis.clang or clang
        documentation = apis.documentation or documentation
        ast = apis.ast or ast
    end

    local ok, project = pcall(function()
        local parsed = {
            modules = {},
            symbols = {},
        }
        for _, header_path in ipairs(headers) do
            local module = M.parse_header(clang_context, header_path, clang_args)
            if module then
                parsed.modules[#parsed.modules + 1] = module
                register_symbols(parsed, module)
            end
        end
        return parsed
    end)

    clang, documentation, ast = saved_clang, saved_docs, saved_ast
    if not ok then
        error(project)
    end
    return project
end

return M