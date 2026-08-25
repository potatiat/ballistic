local log = require("log")

local M = {}

--- Strip comment prefixes (///, //!, /**, *, */) from raw comment text.
--- Returns clean lines as a table.
local function strip_comment_markers(raw)
    if not raw or raw == "" then
        return {}
    end

    local lines = {}
    raw = raw:gsub("\r\n", "\n"):gsub("\r", "\n")

    -- Keep empty lines. gmatch("[^\r\n]+") would drop them, so "# Examples"
    -- never sees the blank line that ends a summary.
    for line in (raw .. "\n"):gmatch("(.-)\n") do
        local cleaned = line

        -- Strip leading whitespace
        cleaned = cleaned:match("^%s*(.*)$") or ""

        -- Strip /// or //!
        if cleaned:sub(1, 3) == "///" or cleaned:sub(1, 3) == "//!" then
            cleaned = cleaned:sub(4)

        -- Strip /** or /*!
        elseif cleaned:sub(1, 3) == "/**" or cleaned:sub(1, 3) == "/*!" then
            cleaned = cleaned:sub(4)

        -- Strip */
        elseif cleaned:sub(1, 2) == "*/" then
            goto continue

        -- Strip leading *
        elseif cleaned:sub(1, 1) == "*" then
            cleaned = cleaned:sub(2)
        end

        -- Strip one leading space after marker
        if cleaned:sub(1, 1) == " " then
            cleaned = cleaned:sub(2)
        end

        lines[#lines + 1] = cleaned

        ::continue::
    end

    return lines
end

--- Extract [`SYMBOL`] links from text. Returns list of symbol names.
local function extract_links(text)
    local links = {}

    for symbol in text:gmatch("%[`([^`]+)`%]") do
        table.insert(links, symbol)
    end

    return links
end

--- Parse a raw doc comment string into a structured doc table.
--- Returns:
--- {
---     summary = string,        -- text before first # Section
---     sections = {             -- ordered list of { name, content }
---         { name = "Safety", content = "..." },
---     },
---     links = { "SYM1", ... }, -- all [`SYM`] references found
---     raw = string,            -- original text
--- }
function M.parse(raw)
    if not raw or raw == "" then
        return nil
    end

    log.trace("parsing comment (%d chars)", #raw)

    local lines = strip_comment_markers(raw)

    if #lines == 0 then
        return nil
    end

    local doc = {
        summary = "",
        sections = {},
        links = {},
        raw = raw,
    }

    local current_section = nil
    local summary_lines = {}
    local section_lines = {}

    local function flush_section()
        if current_section then
            local content = table.concat(section_lines, "\n")
            doc.sections[#doc.sections + 1] = {
                name = current_section,
                content = content,
            }
            log.debug("doc: parsed section '# %s' (%d chars)", current_section, #content)
            section_lines = {}
        end
    end

    for _, line in ipairs(lines) do
        -- "# Safety" or "  # Platform Support" (extra space after ///).
        local header = line:match("^%s*#+%s+(.-)%s*$")

        if header and header ~= "" then
            flush_section()
            current_section = header
        elseif current_section then
            section_lines[#section_lines + 1] = line
        else
            summary_lines[#summary_lines + 1] = line
        end

        -- Extract links from every line
        local line_links = extract_links(line)

        for _, sym in ipairs(line_links) do
            doc.links[#doc.links + 1] = sym
        end
    end

    flush_section()
    doc.summary = table.concat(summary_lines, "\n"):match("^%s*(.-)%s*$") or ""
    log.debug("doc: summary=%d chars, sections=%d, links=%d", #doc.summary, #doc.sections, #doc.links)
    return doc
end

return M
