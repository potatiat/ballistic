local markdown = require("cdoc.markdown")

local M = {}

function M.classes()
    return {
        keyword = "kw",
        type_name = "type",
        function_name = "fn",
        literal = "lit",
        ident = "ident",
    }
end

function M.span(class_name, text)
    return string.format("<span class=\"%s\">%s</span>", class_name, markdown.escape(text))
end

function M.keyword(text)
    return M.span(M.classes().keyword, text)
end

function M.type_name(text)
    return M.span(M.classes().type_name, text)
end

function M.function_name(text)
    return M.span(M.classes().function_name, text)
end

function M.literal(text)
    return M.span(M.classes().literal, text)
end

return M
