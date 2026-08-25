local markdown = require("cdoc.markdown")

local M = {}

function M.keyword(text)
    return "<span class=\"kw\">" .. markdown.escape(text) .. "</span>"
end

function M.type_name(text)
    return "<span class=\"type\">" .. markdown.escape(text) .. "</span>"
end

function M.function_name(text)
    return "<span class=\"fn\">" .. markdown.escape(text) .. "</span>"
end

function M.literal(text)
    return "<span class=\"lit\">" .. markdown.escape(text) .. "</span>"
end

function M.new(overrides, md)
    md = md or markdown
    local picker = {
        keyword = function(text)
            return "<span class=\"kw\">" .. md.escape(text) .. "</span>"
        end,
        type_name = function(text)
            return "<span class=\"type\">" .. md.escape(text) .. "</span>"
        end,
        function_name = function(text)
            return "<span class=\"fn\">" .. md.escape(text) .. "</span>"
        end,
        literal = function(text)
            return "<span class=\"lit\">" .. md.escape(text) .. "</span>"
        end,
    }
    for key, value in pairs(overrides or {}) do
        picker[key] = value
    end
    return picker
end

return M
