local M = {}

local function escape(text)
    text = text or ""
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

function M.inline(text)
    local parts = {}
    local rest = text or ""

    while rest ~= "" do
        local code_at = rest:find("`", 1, true)
        local link_at = rest:find("[", 1, true)
        local bold_at = rest:find("**", 1, true)
        local em_at = rest:find("*", 1, true)

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
        if em_at and (not bold_at or em_at ~= bold_at) then
            consider(em_at, "em")
        end

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
                local scheme = href:match("^(%a[%w+.-]*):")
                if scheme then
                    scheme = scheme:lower()
                    if scheme ~= "http" and scheme ~= "https" then
                        parts[#parts + 1] = "[" .. M.inline(label) .. "](" .. escape(href) .. ")"
                        rest = after
                    else
                        parts[#parts + 1] = string.format("<a href=\"%s\">%s</a>", escape(href), M.inline(label))
                        rest = after
                    end
                else
                    parts[#parts + 1] = string.format("<a href=\"%s\">%s</a>", escape(href), M.inline(label))
                    rest = after
                end
            end
        elseif kind == "bold" then
            local close = rest:find("**", 3, true)
            if not close then
                parts[#parts + 1] = escape(rest)
                break
            end
            parts[#parts + 1] = "<strong>" .. M.inline(rest:sub(3, close - 1)) .. "</strong>"
            rest = rest:sub(close + 2)
        else
            local close = rest:find("*", 2, true)
            if not close or close == 2 then
                parts[#parts + 1] = "*"
                rest = rest:sub(2)
            else
                parts[#parts + 1] = "<em>" .. M.inline(rest:sub(2, close - 1)) .. "</em>"
                rest = rest:sub(close + 1)
            end
        end
    end

    return table.concat(parts)
end

function M.render(markdown)
    if not markdown or markdown == "" then
        return ""
    end

    local lines = {}
    for line in (markdown .. "\n"):gmatch("(.-)\n") do
        lines[#lines + 1] = line
    end

    local html = {}
    local i = 1
    local in_list = false
    local paragraph = nil

    local function close_list()
        if in_list then
            html[#html + 1] = "</ul>"
            in_list = false
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
            html[#html + 1] = string.format(
                "<pre><code class=\"language-%s\">%s</code></pre>",
                escape(lang == "" and "text" or lang),
                escape(table.concat(code, "\n"))
            )
        elseif line:match("^#%s+") then
            close_list()
            end_paragraph()
            local hashes, title = line:match("^(#+)%s+(.*)$")
            local level = math.min(#hashes, 3)
            html[#html + 1] = string.format("<h%d>%s</h%d>", level, M.inline(title), level)
        elseif line:match("^%s*[-*]%s+") then
            end_paragraph()
            if not in_list then
                html[#html + 1] = "<ul>"
                in_list = true
            end
            html[#html + 1] = "<li>" .. M.inline(line:match("^%s*[-*]%s+(.*)$")) .. "</li>"
        elseif line:match("^%s*$") then
            close_list()
            end_paragraph()
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
