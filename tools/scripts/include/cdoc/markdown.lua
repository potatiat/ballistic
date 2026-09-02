local M = {}

local function escape(text)
    text = text or ""
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function decode_entities(text)
    local named = {
        amp = "&",
        lt = "<",
        gt = ">",
        quot = '"',
        apos = "'",
        colon = ":",
        sol = "/",
        bsol = "\\",
    }

    local function from_code(n)
        n = tonumber(n)
        if not n or n < 32 or n > 126 then
            return ""
        end
        return string.char(n)
    end

    for _ = 1, 4 do
        local next_text = text
            :gsub("&(%a+);", function(name)
                return named[name:lower()] or ("&" .. name .. ";")
            end)
            :gsub("&#[xX](%x+);", function(hex)
                return from_code(tonumber(hex, 16))
            end)
            :gsub("&#(%d+);", function(dec)
                return from_code(tonumber(dec, 10))
            end)
        if next_text == text then
            break
        end
        text = next_text
    end
    return text
end

local function percent_decode(text)
    for _ = 1, 4 do
        local next_text = text:gsub("%%(%x%x)", function(hex)
            return string.char(tonumber(hex, 16))
        end)
        if next_text == text then
            break
        end
        text = next_text
    end
    return text
end

local function safe_href(href)
    local decoded = percent_decode(decode_entities(href or ""))
        :gsub("[%z\1-\31]", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
    if decoded == "" or decoded:sub(1, 1) == "\\" or decoded:sub(1, 2) == "//" then
        return nil
    end
    local scheme = decoded:match("^(%a[%w+.-]*):")
    if scheme then
        scheme = scheme:lower()
        if scheme ~= "http" and scheme ~= "https" then
            return nil
        end
        return decoded
    end
    if decoded:find(":", 1, true) then
        return nil
    end
    -- Percent-wrap (%26colon%3B) and leftover named entities hide : / \.
    -- http(s) already returned; relative hrefs must not keep '&'.
    if decoded:find("&", 1, true) then
        return nil
    end
    return decoded
end

function M.inline(text)
    local parts = {}
    local rest = text or ""

    while rest ~= "" do
        local code_at = rest:find("`", 1, true)
        local link_at = rest:find("[", 1, true)
        local bold_at = rest:find("**", 1, true)

        local next_at, kind = nil, nil
        local function consider(pos, name)
            if pos and (not next_at or pos < next_at) then
                next_at = pos
                kind = name
            end
        end

        consider(code_at, "code")
        consider(link_at, "link")
        consider(bold_at, "bold")

        if not next_at then
            parts[#parts + 1] = escape(rest)
            break
        end

        if next_at > 1 then
            parts[#parts + 1] = escape(rest:sub(1, next_at - 1))
        end
        rest = rest:sub(next_at)

        if kind == "code" then
            local close = rest:find("`", 2, true)
            if not close then
                parts[#parts + 1] = escape(rest)
                break
            end
            parts[#parts + 1] = "<code>" .. escape(rest:sub(2, close - 1)) .. "</code>"
            rest = rest:sub(close + 1)
        elseif kind == "link" then
            local label, href, after = rest:match("^%[([^%]]+)%]%(([^%)]+)%)(.*)$")
            if not label then
                parts[#parts + 1] = "["
                rest = rest:sub(2)
            else
                local allowed = safe_href(href)
                if not allowed then
                    parts[#parts + 1] = "[" .. M.inline(label) .. "](" .. escape(href) .. ")"
                else
                    parts[#parts + 1] = string.format("<a href=\"%s\">%s</a>", escape(allowed), M.inline(label))
                end
                rest = after
            end
        elseif kind == "bold" then
            local close = rest:find("**", 3, true)
            if not close then
                parts[#parts + 1] = escape(rest)
                break
            end
            parts[#parts + 1] = "<strong>" .. M.inline(rest:sub(3, close - 1)) .. "</strong>"
            rest = rest:sub(close + 2)
        end
    end

    return table.concat(parts)
end

function M.render(markdown, highlight)
    if not markdown or markdown == "" then
        return ""
    end

    local lines = {}
    for line in (markdown .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local html = {}
    local i = 1
    local list_tag = nil
    local list_item = nil
    local paragraph = nil

    local function flush_item()
        if list_item then
            html[#html + 1] = "<li>" .. M.inline(list_item) .. "</li>"
            list_item = nil
        end
    end

    local function close_list()
        flush_item()
        if list_tag then
            html[#html + 1] = "</" .. list_tag .. ">"
            list_tag = nil
        end
    end

    local function open_list(tag)
        if list_tag ~= tag then
            close_list()
            html[#html + 1] = "<" .. tag .. ">"
            list_tag = tag
        else
            flush_item()
        end
    end

    local function end_paragraph()
        if paragraph then
            html[#html + 1] = "<p>" .. M.inline(paragraph) .. "</p>"
            paragraph = nil
        end
    end

    while i <= #lines do
        local line = lines[i]
        local fence = line:match("^```(.*)$")
        if fence then
            close_list()
            end_paragraph()
            local lang = fence:match("^%s*(%w*)") or ""
            local code = {}
            i = i + 1
            while i <= #lines and not lines[i]:match("^```%s*$") do
                code[#code + 1] = lines[i]
                i = i + 1
            end
            local lang_key = lang == "" and "text" or lang
            local body = table.concat(code, "\n")
            local rendered
            if lang_key:lower() == "c" and type(highlight) == "function" then
                rendered = highlight(body) or ""
            else
                rendered = escape(body)
            end
            html[#html + 1] = string.format(
                "<pre><code class=\"language-%s\">%s</code></pre>",
                escape(lang_key),
                rendered
            )
        elseif line:match("^%s?%s?%s?#+%s+") then
            close_list()
            end_paragraph()
            local hashes, title = line:match("^%s?%s?%s?(#+)%s+(.*)$")
            local level = math.min(#hashes, 3)
            html[#html + 1] = string.format("<h%d>%s</h%d>", level, M.inline(title), level)
        elseif line:match("^%s*[-*]%s+") then
            end_paragraph()
            open_list("ul")
            list_item = line:match("^%s*[-*]%s+(.*)$")
        elseif line:match("^%s*%d+%.%s+") then
            end_paragraph()
            open_list("ol")
            list_item = line:match("^%s*%d+%.%s+(.*)$")
        elseif line:match("^%s*$") then
            close_list()
            end_paragraph()
        elseif list_tag and line:match("^%s+") then
            local cont = line:match("^%s+(.*)$")
            if list_item then
                list_item = list_item .. " " .. cont
            else
                list_item = cont
            end
        else
            close_list()
            if paragraph then
                paragraph = paragraph .. " " .. line
            else
                paragraph = line
            end
        end
        i = i + 1
    end

    close_list()
    end_paragraph()
    return table.concat(html, "\n")
end

M.escape = escape

return M
