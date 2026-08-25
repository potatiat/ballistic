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

return M
