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

local function ensure_directory(path)
    if jit.os == "Windows" then
        ffi.C._mkdir(path)
    else
        ffi.C.mkdir(path, tonumber("755", 8))
    end
end

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

local function doc_to_markdown(doc)
    if not doc then
        return ""
    end
    local parts = {}
    if doc.summary and doc.summary ~= "" then
        parts[#parts + 1] = doc.summary
    end
    for _, section in ipairs(doc.sections or {}) do
        parts[#parts + 1] = "# " .. section.name
        parts[#parts + 1] = section.content or ""
    end
    return table.concat(parts, "\n\n")
end

local function render_doc(registry, doc, current_file)
    local md = doc_to_markdown(doc)
    if md == "" then
        return ""
    end
    return "<div class=\"docblock\">"
        .. markdown.render(resolve_markdown(registry, md, current_file))
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

local function render_decl(item, registry, current_file)
    local parts = {}
    if item.kind == ast.KIND.FUNCTION then
        parts[#parts + 1] = linkify_type(registry, item.return_type, current_file)
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax.function_name(item.name)
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
        parts[#parts + 1] = syntax.keyword(item.kind == ast.KIND.UNION and "union" or "struct")
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax.type_name(item.name)
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
        parts[#parts + 1] = syntax.keyword("enum")
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax.type_name(item.name)
        parts[#parts + 1] = " {"
        for _, variant in ipairs(item.variants or {}) do
            parts[#parts + 1] = "\n    "
            parts[#parts + 1] = markdown.escape(variant.name)
            if variant.value then
                parts[#parts + 1] = " = "
                parts[#parts + 1] = syntax.literal(tostring(variant.value))
            end
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = "\n}"
    elseif item.kind == ast.KIND.TYPEDEF then
        parts[#parts + 1] = syntax.keyword("typedef")
        parts[#parts + 1] = " "
        if item.return_type then
            parts[#parts + 1] = linkify_type(registry, item.return_type, current_file)
            parts[#parts + 1] = " (*"
            parts[#parts + 1] = syntax.type_name(item.name)
            parts[#parts + 1] = ")("
            for i, param in ipairs(item.parameters or {}) do
                if i > 1 then
                    parts[#parts + 1] = ", "
                end
                parts[#parts + 1] = linkify_type(registry, param.type, current_file)
            end
            parts[#parts + 1] = ")"
        else
            parts[#parts + 1] = linkify_type(registry, item.underlying_type, current_file)
            parts[#parts + 1] = " "
            parts[#parts + 1] = syntax.type_name(item.name)
        end
    elseif item.kind == ast.KIND.CONSTANT then
        parts[#parts + 1] = syntax.keyword("#define")
        parts[#parts + 1] = " "
        parts[#parts + 1] = syntax.function_name(item.name)
    end
    return "<div class=\"item-decl\">" .. table.concat(parts) .. "</div>"
end

local function sidebar(module, items)
    local html = { "<nav class=\"sidebar\">" }
    html[#html + 1] = "<a href=\"index.html\" style=\"font-size: 18px; font-weight: bold; margin-bottom: 20px;\">Back to Index</a>"
    html[#html + 1] = "<input id=\"search\" placeholder=\"Search\" aria-label=\"Search\">"
    html[#html + 1] = "<div style=\"font-weight: bold; color: var(--header-text); margin-bottom: 10px;\">"
        .. markdown.escape(module.name) .. "</div>"

    local function section(kind, title)
        local matched = sorted_items(items, kind)
        if #matched == 0 then
            return
        end
        html[#html + 1] = "<h3>" .. title .. "</h3>"
        for _, item in ipairs(matched) do
            html[#html + 1] = string.format(
                "<a href=\"#%s\" data-name=\"%s\">%s</a>",
                markdown.escape(item.anchor or item.name),
                markdown.escape(item.name),
                markdown.escape(item.name)
            )
        end
    end

    section(ast.KIND.STRUCT, "Structs")
    section(ast.KIND.UNION, "Unions")
    section(ast.KIND.ENUM, "Enums")
    section(ast.KIND.FUNCTION, "Functions")
    section(ast.KIND.TYPEDEF, "Type Aliases")
    section(ast.KIND.CONSTANT, "Constants")
    html[#html + 1] = "</nav>"
    return table.concat(html)
end

local function write_file(path, contents)
    local file = assert(io.open(path, "w"))
    file:write(contents)
    file:close()
end

local function render_module(project, module, theme_css)
    local body = {
        "<h1>Header <span class=\"fn\">" .. markdown.escape(module.name) .. "</span></h1>",
        render_doc(project.symbols, module.documentation, module.name),
    }

    for _, item in ipairs(module.items) do
        local label = KIND_LABEL[item.kind] or "Item"
        body[#body + 1] = string.format(
            "<h2 id=\"%s\">%s <a href=\"#%s\">%s</a></h2>",
            markdown.escape(item.anchor or item.name),
            markdown.escape(label),
            markdown.escape(item.anchor or item.name),
            markdown.escape(item.name)
        )
        body[#body + 1] = render_decl(item, project.symbols, module.name)
        body[#body + 1] = render_doc(project.symbols, item.documentation, module.name)
        if item.fields then
            for _, field in ipairs(item.fields) do
                body[#body + 1] = "<div class=\"field-item\" id=\"" .. markdown.escape(item.anchor) .. "." .. markdown.escape(field.name) .. "\">"
                body[#body + 1] = "<span class=\"field-name\">" .. markdown.escape(field.name) .. "</span>"
                body[#body + 1] = render_doc(project.symbols, field.documentation, module.name)
                body[#body + 1] = "</div>"
            end
        end
        if item.variants then
            for _, variant in ipairs(item.variants) do
                body[#body + 1] = "<div class=\"field-item\" id=\"" .. markdown.escape(variant.name) .. "\">"
                body[#body + 1] = "<span class=\"field-name\">" .. markdown.escape(variant.name) .. "</span>"
                body[#body + 1] = render_doc(project.symbols, variant.documentation, module.name)
                body[#body + 1] = "</div>"
            end
        end
    end

    return page.page(module.name, theme_css, sidebar(module, module.items), table.concat(body))
end

function M.generate(project, out_directory, options)
    options = options or {}
    local theme = options.theme or colors.named("dark")
    local theme_css = colors.css(theme)
    ensure_directory(out_directory)

    local index_body = { "<h1>" .. markdown.escape(options.crate_name or "ballistic") .. "</h1>" }
    local index_sidebar = { "<nav class=\"sidebar\"><h3>Modules</h3>" }

    table.sort(project.modules, function(a, b)
        return a.name < b.name
    end)

    for _, module in ipairs(project.modules) do
        index_sidebar[#index_sidebar + 1] = string.format(
            "<a href=\"%s\" data-name=\"%s\">%s</a>",
            markdown.escape(module.name .. ".html"),
            markdown.escape(module.name),
            markdown.escape(module.name)
        )
        index_body[#index_body + 1] = "<div class=\"module-card\">"
        index_body[#index_body + 1] = string.format(
            "<a href=\"%s\"><strong>%s</strong></a>",
            markdown.escape(module.name .. ".html"),
            markdown.escape(module.name)
        )
        index_body[#index_body + 1] = render_doc(project.symbols, module.documentation, nil)
        index_body[#index_body + 1] = "</div>"
        write_file(out_directory .. "/" .. module.name .. ".html", render_module(project, module, theme_css))
    end

    index_sidebar[#index_sidebar + 1] = "<input id=\"search\" placeholder=\"Search\" aria-label=\"Search\"></nav>"
    write_file(
        out_directory .. "/index.html",
        page.page(options.crate_name or "ballistic", theme_css, table.concat(index_sidebar), table.concat(index_body))
    )
end

return M
