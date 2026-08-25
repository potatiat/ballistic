local markdown = require("cdoc.markdown")
local syntax = require("cdoc.syntax_picker")
local colors = require("cdoc.color_picker")
local page = require("cdoc.page_structure")
local ast = require("cdoc.ast")
local ffi = require("ffi")

local M = {}

if jit.os == "Windows" then
    ffi.cdef[[ int _mkdir(const char *pathname); ]]
else
    ffi.cdef[[ int mkdir(const char *pathname, int mode); ]]
end

local KIND_LABEL = {
    [ast.KIND.STRUCT] = "Struct",
    [ast.KIND.UNION] = "Union",
    [ast.KIND.ENUM] = "Enum",
    [ast.KIND.FUNCTION] = "Function",
    [ast.KIND.TYPEDEF] = "Type Alias",
    [ast.KIND.CONSTANT] = "Constant",
}

local SIDEBAR_KIND = {
    [ast.KIND.STRUCT] = "struct",
    [ast.KIND.UNION] = "struct",
    [ast.KIND.ENUM] = "enum",
    [ast.KIND.FUNCTION] = "fn",
    [ast.KIND.TYPEDEF] = "type",
    [ast.KIND.CONSTANT] = "const",
}

local function href(target, current_file)
    if not target then
        return nil
    end
    if target.kind == ast.KIND.MODULE then
        return target.source_file .. ".html"
    end
    local page_name = target.source_file .. ".html"
    if target.anchor and target.anchor ~= "" then
        if current_file and target.source_file == current_file then
            return "#" .. target.anchor
        end
        return page_name .. "#" .. target.anchor
    end
    return page_name
end

local function resolve_markdown(registry, text, current_file)
    if not text then
        return ""
    end
    return text:gsub("%[`([^`]+)`%]", function(name)
        local target = registry[name]
        if not target then
            return "[`" .. name .. "`]"
        end
        return string.format("[`%s`](%s)", name, href(target, current_file))
    end)
end

local function linkify_type(registry, raw_type, current_file)
    if not raw_type then
        return ""
    end

    local out = {}
    local i = 1
    while i <= #raw_type do
        local first, last = raw_type:find("[%a_][%w_]*", i)
        if not first then
            out[#out + 1] = markdown.escape(raw_type:sub(i))
            break
        end
        if first > i then
            out[#out + 1] = markdown.escape(raw_type:sub(i, first - 1))
        end
        local word = raw_type:sub(first, last)
        local target = registry[word]
        if target and target.kind ~= ast.KIND.MODULE then
            out[#out + 1] = string.format(
                "<a class=\"type\" href=\"%s\">%s</a>",
                markdown.escape(href(target, current_file)),
                markdown.escape(word)
            )
        else
            out[#out + 1] = markdown.escape(word)
        end
        i = last + 1
    end
    return table.concat(out)
end

local function render_doc(registry, doc, current_file)
    if not doc or not doc.markdown then
        return ""
    end
    return "<div class=\"docblock\">"
        .. markdown.render(resolve_markdown(registry, doc.markdown, current_file))
        .. "</div>"
end

local function sorted_items(items, kind)
    local matched = {}
    for _, item in ipairs(items) do
        if item.kind == kind then
            matched[#matched + 1] = item
        end
    end
    table.sort(matched, function(a, b)
        return a.name < b.name
    end)
    return matched
end

local function render_decl(item, registry, current_file, syntax_picker)
    local parts = {}
    if item.kind == ast.KIND.FUNCTION then
        parts[#parts + 1] = linkify_type(registry, item.return_type, current_file)
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax_picker.function_name(item.name)
        parts[#parts + 1] = "("
        for i, param in ipairs(item.parameters or {}) do
            parts[#parts + 1] = "\n    "
            parts[#parts + 1] = linkify_type(registry, param.type, current_file)
            parts[#parts + 1] = " "
            parts[#parts + 1] = markdown.escape(param.name)
            if i < #item.parameters then
                parts[#parts + 1] = ","
            end
        end
        if #(item.parameters or {}) > 0 then
            parts[#parts + 1] = "\n"
        end
        parts[#parts + 1] = ")"
    elseif item.kind == ast.KIND.STRUCT or item.kind == ast.KIND.UNION then
        parts[#parts + 1] = syntax_picker.keyword(item.kind == ast.KIND.UNION and "union" or "struct")
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax_picker.type_name(item.name)
        parts[#parts + 1] = " {"
        for _, field in ipairs(item.fields or {}) do
            parts[#parts + 1] = "\n    "
            parts[#parts + 1] = linkify_type(registry, field.type, current_file)
            parts[#parts + 1] = " "
            parts[#parts + 1] = markdown.escape(field.name)
            parts[#parts + 1] = ";"
        end
        parts[#parts + 1] = "\n}"
    elseif item.kind == ast.KIND.ENUM then
        parts[#parts + 1] = syntax_picker.keyword("enum")
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax_picker.type_name(item.name)
        parts[#parts + 1] = " {"
        for _, variant in ipairs(item.variants or {}) do
            parts[#parts + 1] = "\n    "
            parts[#parts + 1] = markdown.escape(variant.name)
            parts[#parts + 1] = " = "
            parts[#parts + 1] = syntax_picker.literal(variant.value)
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = "\n}"
    elseif item.kind == ast.KIND.CONSTANT then
        parts[#parts + 1] = syntax_picker.keyword("#define")
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax_picker.function_name(item.name)
        if item.value then
            parts[#parts + 1] = " "
            parts[#parts + 1] = syntax_picker.literal(item.value)
        end
    elseif item.return_type and #(item.parameters or {}) > 0 then
        parts[#parts + 1] = syntax_picker.keyword("typedef")
        parts[#parts + 1] = " "
        parts[#parts + 1] = markdown.escape(item.name)
        parts[#parts + 1] = " = "
        parts[#parts + 1] = linkify_type(registry, item.return_type, current_file)
        parts[#parts + 1] = " (*)("
        for i, param in ipairs(item.parameters) do
            parts[#parts + 1] = linkify_type(registry, param.type, current_file)
            parts[#parts + 1] = " "
            parts[#parts + 1] = markdown.escape(param.name)
            if i < #item.parameters then
                parts[#parts + 1] = ", "
            end
        end
        parts[#parts + 1] = ");"
    else
        parts[#parts + 1] = syntax_picker.keyword("typedef")
        parts[#parts + 1] = " "
        parts[#parts + 1] = markdown.escape(item.name)
        parts[#parts + 1] = " = "
        parts[#parts + 1] = linkify_type(registry, item.underlying_type, current_file)
        parts[#parts + 1] = ";"
    end
    return "<div class=\"item-decl\">" .. table.concat(parts) .. "</div>"
end

local function render_members(item, registry, current_file)
    local members = item.fields or item.variants
    if not members or #members == 0 then
        return ""
    end

    local parts = { "<h3>" .. (item.kind == ast.KIND.ENUM and "Variants" or "Fields") .. "</h3>" }
    for _, member in ipairs(members) do
        parts[#parts + 1] = string.format("<div id=\"%s\" class=\"field-item\">", markdown.escape(member.name))
        parts[#parts + 1] = "<code class=\"field-name\">" .. markdown.escape(member.name) .. "</code>"
        if member.type then
            parts[#parts + 1] = " " .. linkify_type(registry, member.type, current_file)
        elseif member.value then
            parts[#parts + 1] = " = " .. syntax.literal(member.value)
        end
        if member.documentation then
            parts[#parts + 1] = render_doc(registry, member.documentation, current_file)
        end
        parts[#parts + 1] = "</div>"
    end
    return table.concat(parts, "\n")
end

local function module_sidebar(project, module)
    local groups = {
        { title = "Modules", links = {} },
        { title = "Structs", links = {} },
        { title = "Enums", links = {} },
        { title = "Functions", links = {} },
        { title = "Type Aliases", links = {} },
        { title = "Constants", links = {} },
    }

    groups[1].links[#groups[1].links + 1] = { href = "index.html", label = "crate root" }
    for _, other in ipairs(project.modules) do
        groups[1].links[#groups[1].links + 1] = {
            href = other.name .. ".html",
            label = other.name,
            kind = "mod",
        }
    end

    local function add_kind(index, kind)
        for _, item in ipairs(sorted_items(module.items, kind)) do
            groups[index].links[#groups[index].links + 1] = {
                href = "#" .. item.anchor,
                label = item.name,
                kind = SIDEBAR_KIND[kind],
            }
        end
    end

    add_kind(2, ast.KIND.STRUCT)
    add_kind(2, ast.KIND.UNION)
    add_kind(3, ast.KIND.ENUM)
    add_kind(4, ast.KIND.FUNCTION)
    add_kind(5, ast.KIND.TYPEDEF)
    add_kind(6, ast.KIND.CONSTANT)
    return groups
end

local function write_file(path, contents)
    local file, err = io.open(path, "w")
    if not file then
        error("cannot write " .. path .. ": " .. tostring(err))
    end
    file:write(contents)
    file:close()
end

local function mkdir(path)
    local normalized = path:gsub("\\", "/")
    local acc = ""
    for part in normalized:gmatch("[^/]+") do
        if acc == "" then
            if normalized:sub(1, 1) == "/" then
                acc = "/" .. part
            else
                acc = part
            end
        else
            acc = acc .. "/" .. part
        end
        if not acc:match("^%a:$") then
            if jit.os == "Windows" then
                ffi.C._mkdir(acc)
            else
                ffi.C.mkdir(acc, tonumber("755", 8))
            end
        end
    end
end

local function join_path(directory, name)
    if directory:sub(-1) == "/" or directory:sub(-1) == "\\" then
        return directory .. name
    end
    return directory .. "/" .. name
end

function M.generate(project, out_directory, opts)
    opts = opts or {}
    local crate_name = opts.crate_name or "ballistic"
    local theme = opts.theme or colors.dark()
    local syntax_picker = opts.syntax or syntax
    local structure = opts.page or page
    local theme_css = colors.to_css(theme)
    local navbar = structure.navbar(crate_name)

    mkdir(out_directory)

    for _, module in ipairs(project.modules) do
        local main = {}
        main[#main + 1] = "<h1>Header <span class=\"fn\">" .. markdown.escape(module.name) .. "</span></h1>"
        main[#main + 1] = render_doc(project.registry, module.documentation, module.name)

        for _, item in ipairs(module.items) do
            local label = KIND_LABEL[item.kind] or tostring(item.kind)
            main[#main + 1] = string.format(
                "<h2 id=\"%s\"><span class=\"item-kind\">%s</span> <a href=\"#%s\">%s</a></h2>",
                markdown.escape(item.anchor),
                markdown.escape(label),
                markdown.escape(item.anchor),
                markdown.escape(item.name)
            )
            main[#main + 1] = render_decl(item, project.registry, module.name, syntax_picker)
            main[#main + 1] = render_doc(project.registry, item.documentation, module.name)
            main[#main + 1] = render_members(item, project.registry, module.name)
        end

        write_file(
            join_path(out_directory, module.name .. ".html"),
            structure.document(
                module.name,
                theme_css,
                navbar,
                structure.sidebar(module_sidebar(project, module)),
                table.concat(main, "\n")
            )
        )
    end

    local index_groups = { { title = "Modules", links = {} } }
    local index_main = {
        "<h1>" .. markdown.escape(crate_name) .. "</h1>",
        "<p>C API documentation generated from public headers.</p>",
        "<h2>Modules</h2>",
    }
    for _, module in ipairs(project.modules) do
        index_groups[1].links[#index_groups[1].links + 1] = {
            href = module.name .. ".html",
            label = module.name,
            kind = "mod",
        }
        local summary = module.documentation and module.documentation.summary or ""
        index_main[#index_main + 1] = "<div class=\"module-card\">"
        index_main[#index_main + 1] = "<a href=\"" .. markdown.escape(module.name) .. ".html\"><strong>"
            .. markdown.escape(module.name) .. "</strong></a>"
        if summary ~= "" then
            index_main[#index_main + 1] = "<div class=\"docblock\"><p>" .. markdown.inline(
                resolve_markdown(project.registry, summary, module.name)
            ) .. "</p></div>"
        end
        index_main[#index_main + 1] = "</div>"
    end

    index_main[#index_main + 1] = "<h2>Symbols</h2><div class=\"symbol-index\">"
    local names = {}
    for name, entry in pairs(project.registry) do
        if entry.kind ~= ast.KIND.MODULE and entry.kind ~= ast.KIND.FIELD and entry.kind ~= ast.KIND.VARIANT then
            names[#names + 1] = name
        end
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local entry = project.registry[name]
        index_main[#index_main + 1] = string.format(
            "<a href=\"%s\">%s</a>",
            markdown.escape(href(entry, nil)),
            markdown.escape(name)
        )
    end
    index_main[#index_main + 1] = "</div>"

    write_file(
        join_path(out_directory, "index.html"),
        structure.document(
            crate_name,
            theme_css,
            navbar,
            structure.sidebar(index_groups),
            table.concat(index_main, "\n")
        )
    )
end

return M
