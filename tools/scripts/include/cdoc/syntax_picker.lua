local function escape_html(text)
    text = text or ""
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local M = {}

function M.keyword(text)
    return "<span class=\"kw\">" .. escape_html(text) .. "</span>"
end

function M.type_name(text)
    return "<span class=\"type\">" .. escape_html(text) .. "</span>"
end

function M.function_name(text)
    return "<span class=\"fn\">" .. escape_html(text) .. "</span>"
end

function M.literal(text)
    return "<span class=\"lit\">" .. escape_html(text) .. "</span>"
end

function M.new(overrides, md)
    local escape = escape_html
    if md then
        escape = md.escape
    end
    local picker = {
        keyword = function(text)
            return "<span class=\"kw\">" .. escape(text) .. "</span>"
        end,
        type_name = function(text)
            return "<span class=\"type\">" .. escape(text) .. "</span>"
        end,
        function_name = function(text)
            return "<span class=\"fn\">" .. escape(text) .. "</span>"
        end,
        literal = function(text)
            return "<span class=\"lit\">" .. escape(text) .. "</span>"
        end,
    }
    for key, value in pairs(overrides or {}) do
        picker[key] = value
    end
    return picker
end

return M
