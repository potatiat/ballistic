local markdown = require("cdoc.markdown")
local ast = require("cdoc.ast")
local log = require("log")
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

local EEXIST = 17

local function mkdir_one(path)
    local rc
    if jit.os == "Windows" then
        rc = ffi.C._mkdir(path)
    else
        rc = ffi.C.mkdir(path, tonumber("755", 8))
    end
    if rc == 0 then
        return true
    end
    local err = ffi.errno()
    -- POSIX EEXIST is 17; Windows _mkdir may also set ERROR_ALREADY_EXISTS (183).
    return err == EEXIST or err == 183
end

local function ensure_directory(path)
    path = (path or ""):gsub("\\", "/"):gsub("/+$", "")
    if path == "" or path == "." then
        return true
    end

    local prefix = ""
    local rest = path
    local drive = rest:match("^(%a:)(.*)$")
    if drive then
        prefix = rest:sub(1, 2)
        rest = rest:sub(3):gsub("^/+", "")
        if rest == "" then
            return true
        end
        prefix = prefix .. "/"
    elseif rest:sub(1, 1) == "/" then
        prefix = "/"
        rest = rest:sub(2)
    end

    local acc = prefix
    for part in rest:gmatch("[^/]+") do
        if acc == "" or acc == "/" then
            acc = acc .. part
        else
            acc = acc .. "/" .. part
        end
        if not mkdir_one(acc) then
            log.error("mkdir '%s' failed (errno %d).", acc, ffi.errno())
            return false
        end
    end
    return true
end

local function page_href(name, anchor)
    if type(name) ~= "string" or not name:match("^[%w._-]+%.h$") then
        return nil
    end
    if anchor and anchor ~= "" then
        if not anchor:match("^[%w._-]+$") then
            return nil
        end
        return name .. ".html#" .. anchor
    end
    return name .. ".html"
end

local function href(target, current_file)
    if not target then
        return nil
    end
    local source = target.source_file
    if target.kind == ast.KIND.MODULE then
        return page_href(source)
    end
    if target.anchor and target.anchor ~= "" then
        if current_file and source == current_file then
            if target.anchor:match("^[%w._-]+$") then
                return "#" .. target.anchor
            end
            return nil
        end
        return page_href(source, target.anchor)
    end
    return page_href(source)
end

local function resolve_markdown(registry, text, current_file)
    if not text then
        return ""
    end
    return text:gsub("%[`([^`]+)`%]", function(name)
        local target = registry[name]
        local dest = target and href(target, current_file)
        if not dest then
            return "[`" .. name .. "`]"
        end
        return string.format("[`%s`](%s)", name, dest)
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
        local dest = target and target.kind ~= ast.KIND.MODULE and href(target, current_file)
        if dest then
            out[#out + 1] = string.format(
                "<a class=\"type\" href=\"%s\">%s</a>",
                markdown.escape(dest),
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

local function render_decl(item, registry, current_file, paint)
    local parts = {}
    if item.kind == ast.KIND.FUNCTION then
        parts[#parts + 1] = linkify_type(registry, item.return_type, current_file)
        parts[#parts + 1] = " "
        parts[#parts + 1] = paint.function_name(item.name)
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
        parts[#parts + 1] = paint.keyword(item.kind == ast.KIND.UNION and "union" or "struct")
        parts[#parts + 1] = " "
        parts[#parts + 1] = paint.type_name(item.name)
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
        parts[#parts + 1] = paint.keyword("enum")
        parts[#parts + 1] = " "
        parts[#parts + 1] = paint.type_name(item.name)
        parts[#parts + 1] = " {"
        for _, variant in ipairs(item.variants or {}) do
            parts[#parts + 1] = "\n    "
            parts[#parts + 1] = markdown.escape(variant.name)
            if variant.value then
                parts[#parts + 1] = " = "
                parts[#parts + 1] = paint.literal(tostring(variant.value))
            end
            parts[#parts + 1] = ","
        end
        parts[#parts + 1] = "\n}"
    elseif item.kind == ast.KIND.TYPEDEF then
        parts[#parts + 1] = paint.keyword("typedef")
        parts[#parts + 1] = " "
        if item.return_type then
            parts[#parts + 1] = linkify_type(registry, item.return_type, current_file)
            parts[#parts + 1] = " (*"
            parts[#parts + 1] = paint.type_name(item.name)
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
            parts[#parts + 1] = paint.type_name(item.name)
        end
    elseif item.kind == ast.KIND.CONSTANT then
        parts[#parts + 1] = paint.keyword("#define")
        parts[#parts + 1] = " "
        parts[#parts + 1] = paint.function_name(item.name)
        if item.value and item.value ~= "" then
            if item.value:sub(1, 1) ~= "(" then
                parts[#parts + 1] = " "
            end
            parts[#parts + 1] = markdown.escape(item.value)
        end
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
    local file, err = io.open(path, "w")
    if not file then
        log.error("Cannot write '%s': %s", path, tostring(err))
        return false
    end
    file:write(contents)
    file:close()
    return true
end

local function render_module(project, module, theme_css, paint, crate_name, chrome)
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
        body[#body + 1] = render_decl(item, project.symbols, module.name, paint)
        body[#body + 1] = render_doc(project.symbols, item.documentation, module.name)
        if item.fields then
            for _, field in ipairs(item.fields) do
                body[#body + 1] = "<div class=\"field-item\" id=\"" .. markdown.escape(field.anchor or (item.anchor .. "." .. field.name)) .. "\">"
                body[#body + 1] = "<span class=\"field-name\">" .. markdown.escape(field.name) .. "</span>"
                body[#body + 1] = render_doc(project.symbols, field.documentation, module.name)
                body[#body + 1] = "</div>"
            end
        end
        if item.variants then
            for _, variant in ipairs(item.variants) do
                body[#body + 1] = "<div class=\"field-item\" id=\"" .. markdown.escape(variant.anchor or (item.anchor .. "." .. variant.name)) .. "\">"
                body[#body + 1] = "<span class=\"field-name\">" .. markdown.escape(variant.name) .. "</span>"
                body[#body + 1] = render_doc(project.symbols, variant.documentation, module.name)
                body[#body + 1] = "</div>"
            end
        end
    end

    return chrome.page(module.name, theme_css, sidebar(module, module.items), table.concat(body), crate_name, markdown.escape)
end

function M.generate(project, out_directory, options)
    options = options or {}
    local saved_markdown = markdown
    markdown = options.markdown or markdown
    local colors = options.colors or require("cdoc.color_picker")
    local chrome = options.page or require("cdoc.page_structure")
    local theme = options.theme or colors.named("dark")
    local paint = options.syntax or require("cdoc.syntax_picker").new(nil, markdown)
    local crate_name = options.crate_name or "ballistic"
    local theme_css = options.theme_css or colors.css(theme)

    local ok = true
    if not ensure_directory(out_directory) then
        markdown = saved_markdown
        return false
    end

    local index_body = { "<h1>" .. markdown.escape(crate_name) .. "</h1>" }
    local index_sidebar = {
        "<nav class=\"sidebar\">",
        "<input id=\"search\" placeholder=\"Search\" aria-label=\"Search\">",
        "<h3>Modules</h3>",
    }

    table.sort(project.modules, function(a, b)
        return a.name < b.name
    end)

    for _, module in ipairs(project.modules) do
        local dest = page_href(module.name)
        if not dest then
            log.error("Skipping module '%s': name is not a safe header basename.", tostring(module.name))
            ok = false
        else
            index_sidebar[#index_sidebar + 1] = string.format(
                "<a href=\"%s\" data-name=\"%s\">%s</a>",
                markdown.escape(dest),
                markdown.escape(module.name),
                markdown.escape(module.name)
            )
            index_body[#index_body + 1] = "<div class=\"module-card\">"
            index_body[#index_body + 1] = string.format(
                "<a href=\"%s\"><strong>%s</strong></a>",
                markdown.escape(dest),
                markdown.escape(module.name)
            )
            index_body[#index_body + 1] = render_doc(project.symbols, module.documentation, nil)
            index_body[#index_body + 1] = "</div>"
            if not write_file(out_directory .. "/" .. module.name .. ".html", render_module(project, module, theme_css, paint, crate_name, chrome)) then
                ok = false
            end
        end
    end

    index_sidebar[#index_sidebar + 1] = "</nav>"
    if not write_file(
        out_directory .. "/index.html",
        chrome.page(crate_name, theme_css, table.concat(index_sidebar), table.concat(index_body), crate_name, markdown.escape)
    ) then
        ok = false
    end

    markdown = saved_markdown
    return ok
end

return M
