local ffi = require("ffi")
local log = require("log")
local ast = require("cdoc.ast")
local documentation = require("cdoc.documentation")
local clang = require("cdoc.clang")

local M = {}

function is_array(t)
    if type(t) ~= "table" then
        return false
    end
    return #t > 0 and next(t, #t) == nil
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

            table.insert(lines, content)
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

local function fill_module(context, tu, module, header_path)
    local seen = {}
    local library = context.library

    for _, cursor in ipairs(clang.declarations(context, tu, header_path)) do
        if clang.from_main_file(context, cursor) then
            local kind = tonumber(library.clang_getCursorKind(cursor))
            local name = clang.spelling(context, cursor)
            local location = item_location(context, cursor, header_path)

            if kind == clang.CURSOR.FunctionDecl then
                add_item(module, seen, ast.create_function(
                    name,
                    clang.type_spelling(context, library.clang_getCursorResultType(cursor)),
                    parse_parameters(context, tu, cursor),
                    documentation.parse(clang.comment(context, cursor)),
                    location
                ))
            elseif kind == clang.CURSOR.StructDecl then
                if not skippable(context, cursor) and library.clang_isCursorDefinition(cursor) ~= 0 then
                    add_item(module, seen, ast.create_struct(
                        name,
                        parse_fields(context, tu, cursor, header_path),
                        {},
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.UnionDecl then
                if not skippable(context, cursor) and library.clang_isCursorDefinition(cursor) ~= 0 then
                    add_item(module, seen, ast.create_union(
                        name,
                        parse_fields(context, tu, cursor, header_path),
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.EnumDecl then
                if not skippable(context, cursor) and library.clang_isCursorDefinition(cursor) ~= 0 then
                    add_item(module, seen, ast.create_enum(
                        name,
                        parse_variants(context, tu, cursor, header_path),
                        documentation.parse(clang.comment(context, cursor)),
                        location
                    ))
                end
            elseif kind == clang.CURSOR.TypedefDecl then
                local underlying = library.clang_getTypedefDeclUnderlyingType(cursor)
                local canonical = library.clang_getCanonicalType(underlying)
                local type_kind = tonumber(canonical.kind)
                local declared = library.clang_getTypeDeclaration(canonical)

                if type_kind == clang.TYPE.Record then
                    local union = tonumber(library.clang_getCursorKind(declared)) == clang.CURSOR.UnionDecl
                    if union then
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
                    if tonumber(underlying.kind) == clang.TYPE.Pointer then
                        local pointee = library.clang_getPointeeType(underlying)
                        if tonumber(pointee.kind) == clang.TYPE.FunctionProto then
                            return_type = clang.type_spelling(context, library.clang_getResultType(pointee))
                            parameters = parse_parameters(context, tu, cursor)
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
                if not is_include_guard(name) then
                    add_item(module, seen, ast.create_constant(
                        name,
                        nil,
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
        elseif item.kind == KIND.STRUCT or item.kind == KIND.UNION then
            return "struct." .. item.name
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
        project.symbols[item.name] = item
        if item.kind == KIND.ENUM then
            for _, variant in ipairs(item.variants or {}) do
                variant.source_file = module.name
                variant.anchor = item.anchor
                project.symbols[variant.name] = variant
            end
        elseif item.kind == KIND.STRUCT or item.kind == KIND.UNION then
            for _, field in ipairs(item.fields or {}) do
                field.source_file = module.name
                field.anchor = item.anchor
                project.symbols[item.name .. "." .. field.name] = field
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

    local args = clang_args or {}
    local argc = #args
    local argv = nil

    if argc > 0 then
        argv = ffi.new("const char*[?]", argc)

        for i = 1, argc do
            argv[i - 1] = args[i]
        end
    end

    local clang_library = clang_context.library
    local index = clang_library.clang_createIndex(0, 1)
    local unsaved_files = nil
    local num_unsaved_files = 0
    -- DetailedPreprocessingRecord (0x01): MacroDefinition cursors for KIND.CONSTANT.
    -- SkipFunctionBodies (0x40): signatures only.
    local options = 0x01 + 0x40
    local ok, translation_unit = pcall(clang_library.clang_parseTranslationUnit, index, header_path, argv, argc, unsaved_files, num_unsaved_files, options)

    if not ok then
        clang_library.clang_disposeIndex(index)
        log.error("Aborting function: failed to parse translation unit because %s.", tostring(translation_unit))
        return nil
    end

    if translation_unit == nil then
        clang_library.clang_disposeIndex(index)
        log.error("Aborting function: failed to create parse translation unit %s.", header_path)
        return
    end

    log.debug("Translation unit created successfully.")
    local file_level_documentation = parse_file_level_docs(header_path)
    local module_name = header_path:match("([^/\\]+)$") or header_path
    local module_node = ast.create_module(module_name, header_path, file_level_documentation)
    fill_module(clang_context, translation_unit, module_node, header_path)
    clang_library.clang_disposeTranslationUnit(translation_unit)
    clang_library.clang_disposeIndex(index)
    return module_node
end

function M.parse_headers(clang_context, headers, clang_args)
    local project = {
        modules = {},
        symbols = {},
    }
    for _, header_path in ipairs(headers) do
        local module = M.parse_header(clang_context, header_path, clang_args)
        if module then
            project.modules[#project.modules + 1] = module
            register_symbols(project, module)
        end
    end
    return project
end

return M