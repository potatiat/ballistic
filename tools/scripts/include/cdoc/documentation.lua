local log = require("log")

local M = {}

local function strip_comment_markers(raw)
    if not raw or raw == "" then
        return {}
    end

    local lines = {}
    for line in raw:gmatch("[^\r\n]+") do
        local cleaned = line:match("^%s*(.*)$") or ""

        if cleaned:sub(1, 3) == "///" or cleaned:sub(1, 3) == "//!" then
            cleaned = cleaned:sub(4)
        elseif cleaned:sub(1, 3) == "/**" or cleaned:sub(1, 3) == "/*!" then
            cleaned = cleaned:sub(4)
        elseif cleaned:sub(1, 2) == "*/" then
            goto continue
        elseif cleaned:sub(1, 1) == "*" then
            cleaned = cleaned:sub(2)
        end

        if cleaned:sub(1, 1) == " " then
            cleaned = cleaned:sub(2)
        end

        if cleaned:sub(1, 6) ~= "// ---" then
            lines[#lines + 1] = cleaned
        end

        ::continue::
    end

    return lines
end

local function extract_links(text)
    local links = {}
    for symbol in text:gmatch("%[`([^`]+)`%]") do
        links[#links + 1] = symbol
    end
    return links
end

function M.parse(raw)
    if not raw or raw == "" then
        return nil
    end

    local lines = strip_comment_markers(raw)
    if #lines == 0 then
        return nil
    end

    local markdown = table.concat(lines, "\n")
    markdown = markdown:match("^%s*(.-)%s*$") or ""
    if markdown == "" then
        return nil
    end

    local first_blank = markdown:find("\n%s*\n")
    local summary = first_blank and markdown:sub(1, first_blank - 1) or markdown
    summary = summary:gsub("^#%s+[^\n]+\n*", "")
    summary = summary:match("^%s*(.-)%s*$") or ""

    log.trace("Parsed comment (%d chars).", #markdown)
    return {
        markdown = markdown,
        summary = summary,
        links = extract_links(markdown),
        raw = raw,
    }
end

return M
