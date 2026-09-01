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

local SEARCH_KIND = {
    [ast.KIND.STRUCT] = "struct",
    [ast.KIND.UNION] = "union",
    [ast.KIND.ENUM] = "enum",
    [ast.KIND.FUNCTION] = "function",
    [ast.KIND.TYPEDEF] = "typedef",
    [ast.KIND.CONSTANT] = "constant",
}

local SIDEBAR_SECTIONS = {
    { kind = ast.KIND.STRUCT, title = "Structs" },
    { kind = ast.KIND.UNION, title = "Unions" },
    { kind = ast.KIND.ENUM, title = "Enums" },
    { kind = ast.KIND.FUNCTION, title = "Functions" },
    { kind = ast.KIND.TYPEDEF, title = "Type Aliases" },
    { kind = ast.KIND.CONSTANT, title = "Constants" },
}

local CHROME_HELPERS = { "page", "module_sidebar", "index_sidebar", "global_symbols", "breadcrumbs" }

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

local function json_string(value)
    return '"' .. value
        :gsub("\\", "\\\\")
        :gsub('"', '\\"')
        :gsub("[%z\1-\31]", function(c)
            return string.format("\\u%04x", string.byte(c))
        end)
        :gsub("</", "<\\/")
        .. '"'
end

local function safe_index_href(href)
    return type(href) == "string"
        and (href:match("^[%w._-]+%.html$") or href:match("^[%w._-]+%.html#[%w._-]+$"))
end

local function encode_search_index(entries)
    local parts = { "[" }
    local first = true
    for _, entry in ipairs(entries) do
        if type(entry.name) == "string" and type(entry.kind) == "string" and safe_index_href(entry.href) then
            if not first then
                parts[#parts + 1] = ","
            end
            first = false
            parts[#parts + 1] = "{\"name\":" .. json_string(entry.name)
                .. ",\"kind\":" .. json_string(entry.kind)
                .. ",\"href\":" .. json_string(entry.href)
                .. "}"
        end
    end
    parts[#parts + 1] = "]"
    return table.concat(parts)
end

local function require_chrome(chrome)
    for _, name in ipairs(CHROME_HELPERS) do
        if type(chrome[name]) ~= "function" then
            log.error("Page chrome is missing %s().", name)
            return false
        end
    end
    return true
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

local function is_function_like_macro(item)
    return item.kind == ast.KIND.CONSTANT and item.function_like == true
end

local function item_heading_class(item)
    if is_function_like_macro(item) then
        return "macro"
    elseif item.kind == ast.KIND.FUNCTION then
        return "fn"
    elseif item.kind == ast.KIND.CONSTANT then
        return "constant"
    end
    return "type"
end

local function item_kind_label(item)
    if is_function_like_macro(item) then
        return "Macro"
    end
    return KIND_LABEL[item.kind] or "Item"
end

local function item_search_kind(item)
    if is_function_like_macro(item) then
        return "macro"
    end
    return SEARCH_KIND[item.kind]
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

local function type_span(html)
    return "<span class=\"type\">" .. html .. "</span>"
end

local function doc_to_markdown(doc, heading)
    if not doc then
        return ""
    end
    heading = heading or "## "
    local parts = {}
    if doc.summary and doc.summary ~= "" then
        parts[#parts + 1] = doc.summary
    end
    for _, section in ipairs(doc.sections or {}) do
        parts[#parts + 1] = heading .. section.name
        parts[#parts + 1] = section.content or ""
    end
    return table.concat(parts, "\n\n")
end

local function render_doc(registry, doc, current_file, heading)
    local md = doc_to_markdown(doc, heading)
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
        parts[#parts + 1] = type_span(linkify_type(registry, item.return_type, current_file))
        parts[#parts + 1] = " "
        parts[#parts + 1] = paint.function_name(item.name)
        parts[#parts + 1] = "("
        for i, param in ipairs(item.parameters or {}) do
            parts[#parts + 1] = "\n    "
            parts[#parts + 1] = type_span(linkify_type(registry, param.type, current_file))
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
            parts[#parts + 1] = type_span(linkify_type(registry, field.type, current_file))
            parts[#parts + 1] = " "
            parts[#parts + 1] = markdown.escape(field.name)
            if type(field.bit_width) == "number" then
                parts[#parts + 1] = " : " .. tostring(field.bit_width)
            end
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
            parts[#parts + 1] = type_span(linkify_type(registry, item.return_type, current_file))
            parts[#parts + 1] = " (*"
            parts[#parts + 1] = paint.type_name(item.name)
            parts[#parts + 1] = ")("
            for i, param in ipairs(item.parameters or {}) do
                if i > 1 then
                    parts[#parts + 1] = ", "
                end
                parts[#parts + 1] = type_span(linkify_type(registry, param.type, current_file))
                if param.name and param.name ~= "" then
                    parts[#parts + 1] = " "
                    parts[#parts + 1] = markdown.escape(param.name)
                end
            end
            parts[#parts + 1] = ")"
        else
            parts[#parts + 1] = type_span(linkify_type(registry, item.underlying_type, current_file))
            parts[#parts + 1] = " "
            parts[#parts + 1] = paint.type_name(item.name)
        end
    elseif item.kind == ast.KIND.CONSTANT then
        parts[#parts + 1] = paint.keyword("#define")
        parts[#parts + 1] = " "
        parts[#parts + 1] = paint.function_name(item.name)
        if item.value and item.value ~= "" then
            if not is_function_like_macro(item) then
                parts[#parts + 1] = " "
            end
            parts[#parts + 1] = markdown.escape(item.value)
        end
    end
    return "<div class=\"item-decl\">" .. table.concat(parts) .. "</div>"
end

local function sidebar_entries(matched)
    local entries = {}
    for _, item in ipairs(matched) do
        local anchor = item.anchor
        if type(anchor) == "string" and anchor:match("^[%w._-]+$") then
            entries[#entries + 1] = { href = "#" .. anchor, name = item.name }
        end
    end
    return entries
end

local function add_sidebar_section(sections, title, matched)
    if #matched == 0 then
        return
    end
    table.sort(matched, function(a, b)
        return a.name < b.name
    end)
    local entries = sidebar_entries(matched)
    if #entries > 0 then
        sections[#sections + 1] = { title = title, items = entries }
    end
end

local function module_sidebar_sections(items)
    local sections = {}
    for _, spec in ipairs(SIDEBAR_SECTIONS) do
        if spec.kind == ast.KIND.CONSTANT then
            local macros = {}
            local constants = {}
            for _, item in ipairs(items) do
                if item.kind == ast.KIND.CONSTANT then
                    if is_function_like_macro(item) then
                        macros[#macros + 1] = item
                    else
                        constants[#constants + 1] = item
                    end
                end
            end
            if #macros > 0 and #constants > 0 then
                add_sidebar_section(sections, "Macros", macros)
                add_sidebar_section(sections, "Constants", constants)
            elseif #macros > 0 then
                add_sidebar_section(sections, "Macros", macros)
            else
                add_sidebar_section(sections, "Constants", constants)
            end
        else
            add_sidebar_section(sections, spec.title, sorted_items(items, spec.kind))
        end
    end
    return sections
end

local function write_file(path, contents)
    local file, err = io.open(path, "w")
    if not file then
        log.error("Cannot write '%s': %s", path, tostring(err))
        return false
    end
    local written, write_err = file:write(contents)
    local closed, close_err = file:close()
    if not written then
        log.error("Cannot write '%s': %s", path, tostring(write_err))
        return false
    end
    if not closed then
        log.error("Cannot close '%s': %s", path, tostring(close_err))
        return false
    end
    return true
end

local function render_module(project, module, theme_css, paint, crate_name, chrome, search_index_json)
    local body = {
        chrome.breadcrumbs({
            { href = "index.html", name = crate_name },
            { name = module.name },
        }, markdown.escape),
        "<h1>Header <span class=\"fn\">" .. markdown.escape(module.name) .. "</span></h1>",
        render_doc(project.symbols, module.documentation, module.name),
    }

    for _, item in ipairs(module.items) do
        local label = item_kind_label(item)
        local anchor = markdown.escape(item.anchor or item.name)
        body[#body + 1] = string.format(
            "<h2 id=\"%s\"><span class=\"item-kind\">%s</span> <a class=\"%s\" href=\"#%s\">%s</a></h2>",
            anchor,
            markdown.escape(label),
            item_heading_class(item),
            anchor,
            markdown.escape(item.name)
        )
        body[#body + 1] = render_decl(item, project.symbols, module.name, paint)
        body[#body + 1] = render_doc(project.symbols, item.documentation, module.name, "### ")
        if item.fields and #item.fields > 0 then
            body[#body + 1] = "<h3>Fields</h3>"
            for _, field in ipairs(item.fields) do
                body[#body + 1] = "<div class=\"field-item\" id=\"" .. markdown.escape(field.anchor or (item.anchor .. "." .. field.name)) .. "\">"
                body[#body + 1] = "<code class=\"field-name\">" .. markdown.escape(field.name) .. "</code>"
                body[#body + 1] = "<div class=\"field-doc\">"
                    .. render_doc(project.symbols, field.documentation, module.name, "### ")
                    .. "</div></div>"
            end
        end
        if item.variants and #item.variants > 0 then
            body[#body + 1] = "<h3>Variants</h3>"
            for _, variant in ipairs(item.variants) do
                body[#body + 1] = "<div class=\"field-item\" id=\"" .. markdown.escape(variant.anchor or (item.anchor .. "." .. variant.name)) .. "\">"
                body[#body + 1] = "<code class=\"field-name\">" .. markdown.escape(variant.name) .. "</code>"
                body[#body + 1] = "<div class=\"field-doc\">"
                    .. render_doc(project.symbols, variant.documentation, module.name, "### ")
                    .. "</div></div>"
            end
        end
    end

    return chrome.page(
        module.name,
        theme_css,
        chrome.module_sidebar(module.name, module_sidebar_sections(module.items), markdown.escape, crate_name),
        table.concat(body),
        crate_name,
        markdown.escape,
        search_index_json
    )
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

    if not require_chrome(chrome) then
        markdown = saved_markdown
        return false
    end

    local ok = true
    local seen = {}
    local accepted = {}
    local index_modules = {}
    local global_chips = {}
    local search_index = {}
    local index_body = {
        chrome.breadcrumbs({ { name = crate_name } }, markdown.escape),
        "<h1>" .. markdown.escape(crate_name) .. "</h1>",
    }

    table.sort(project.modules, function(a, b)
        return a.name < b.name
    end)

    for _, module in ipairs(project.modules) do
        local dest = page_href(module.name)
        if not dest then
            log.error("Skipping module '%s': name is not a safe header basename.", tostring(module.name))
            ok = false
        elseif seen[dest] then
            log.error("Duplicate module name '%s'.", module.name)
            ok = false
        else
            seen[dest] = true
            accepted[#accepted + 1] = { module = module, dest = dest }
            index_modules[#index_modules + 1] = { href = dest, name = module.name }
            search_index[#search_index + 1] = { name = module.name, kind = "module", href = dest }
            index_body[#index_body + 1] = "<div class=\"module-card\">"
            index_body[#index_body + 1] = string.format(
                "<a href=\"%s\"><strong>%s</strong></a>",
                markdown.escape(dest),
                markdown.escape(module.name)
            )
            index_body[#index_body + 1] = render_doc(project.symbols, module.documentation, nil)
            index_body[#index_body + 1] = "</div>"

            for _, item in ipairs(module.items) do
                local kind_label = KIND_LABEL[item.kind]
                if kind_label then
                    local source = item.source_file or module.name
                    local item_href = page_href(source, item.anchor)
                    if item_href then
                        search_index[#search_index + 1] = {
                            name = item.name,
                            kind = item_search_kind(item) or kind_label:lower(),
                            href = item_href,
                        }
                        global_chips[#global_chips + 1] = {
                            href = item_href,
                            name = item.name,
                        }
                    end
                    if item.kind == ast.KIND.ENUM then
                        for _, variant in ipairs(item.variants or {}) do
                            if type(variant.name) == "string" and variant.name ~= "" then
                                item_href = page_href(source, variant.anchor)
                                if item_href then
                                    search_index[#search_index + 1] = {
                                        name = variant.name,
                                        kind = "variant",
                                        href = item_href,
                                    }
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    if not ok then
        markdown = saved_markdown
        return false
    end

    if not ensure_directory(out_directory) then
        markdown = saved_markdown
        return false
    end

    table.sort(global_chips, function(a, b)
        return a.name < b.name
    end)
    index_body[#index_body + 1] = chrome.global_symbols(global_chips, markdown.escape)

    local search_index_json = encode_search_index(search_index)
    local pending = {}
    for _, entry in ipairs(accepted) do
        pending[#pending + 1] = {
            path = out_directory .. "/" .. entry.dest,
            contents = render_module(project, entry.module, theme_css, paint, crate_name, chrome, search_index_json),
        }
    end
    pending[#pending + 1] = {
        path = out_directory .. "/index.html",
        contents = chrome.page(
            crate_name,
            theme_css,
            chrome.index_sidebar(index_modules, markdown.escape, crate_name),
            table.concat(index_body),
            crate_name,
            markdown.escape,
            search_index_json
        ),
    }

    for _, item in ipairs(pending) do
        if not write_file(item.path, item.contents) then
            ok = false
            break
        end
    end

    markdown = saved_markdown
    return ok
end

return M
