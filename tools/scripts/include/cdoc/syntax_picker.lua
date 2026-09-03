local function escape_html(text)
    text = text or ""
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local KEYWORDS = {}
do
    local list = table.concat({
        "auto break case char const continue default do double else enum extern",
        "float for goto if inline int long register restrict return short signed",
        "sizeof static struct switch typedef union unsigned void volatile while",
        "_Alignas _Alignof _Atomic _Bool _Complex _Generic _Imaginary _Noreturn",
        "_Static_assert _Thread_local bool true false alignas alignof",
        "static_assert thread_local",
    }, " ")
    for word in list:gmatch("%S+") do
        KEYWORDS[word] = true
    end
end

local STD_TYPES = {}
do
    local list = table.concat({
        "uint8_t uint16_t uint32_t uint64_t int8_t int16_t int32_t int64_t",
        "int_fast8_t int_fast16_t int_fast32_t int_fast64_t",
        "uint_fast8_t uint_fast16_t uint_fast32_t uint_fast64_t",
        "int_least8_t int_least16_t int_least32_t int_least64_t",
        "uint_least8_t uint_least16_t uint_least32_t uint_least64_t",
        "size_t ssize_t uintptr_t intptr_t ptrdiff_t wchar_t char16_t char32_t",
        "intmax_t uintmax_t max_align_t",
    }, " ")
    for word in list:gmatch("%S+") do
        STD_TYPES[word] = true
    end
end

local LINK_CLASSES = { type = true, fn = true, kw = true, macro = true }

local function is_safe_href(href)
    return type(href) == "string" and (
        href:match("^#[%w._-]+$")
        or href:match("^[%w._-]+%.html$")
        or href:match("^[%w._-]+%.html#[%w._-]+$")
    )
end

local function is_alpha_(b)
    return (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b == 95
end

local function is_alnum_(b)
    return is_alpha_(b) or (b >= 48 and b <= 57)
end

local function is_digit_b(b)
    return b >= 48 and b <= 57
end

local function is_hex_b(b)
    return is_digit_b(b) or (b >= 65 and b <= 70) or (b >= 97 and b <= 102)
end

local function is_space_no_nl(b)
    return b == 32 or b == 9 or b == 13 or b == 11 or b == 12
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

function M.highlight_c(source, opts)
    source = source or ""
    opts = opts or {}
    local escape = opts.escape or escape_html
    local link = opts.link
    local kind_of = opts.kind
    local n = #source
    if n == 0 then
        return ""
    end

    local byte = string.byte
    local sub = string.sub
    local i = 1
    local line_start = true
    local after_include = false
    local out = {}

    local function span(class, text)
        return "<span class=\"" .. class .. "\">" .. escape(text) .. "</span>"
    end

    local function note_range(from, to)
        for k = from, to do
            local b = byte(source, k)
            if b == 10 then
                line_start = true
            elseif not is_space_no_nl(b) then
                line_start = false
            end
        end
    end

    local function slice_to(stop)
        local text = sub(source, i, stop)
        note_range(i, stop)
        i = stop + 1
        return text
    end

    local function emit_ident(word)
        if KEYWORDS[word] then
            out[#out + 1] = span("kw", word)
            return
        end
        local dest = link and link(word)
        if dest and is_safe_href(dest) then
            local class = "type"
            if kind_of then
                local k = kind_of(word)
                if type(k) == "string" and LINK_CLASSES[k] then
                    class = k
                end
            end
            out[#out + 1] = string.format(
                "<a class=\"%s\" href=\"%s\">%s</a>",
                class,
                escape(dest),
                escape(word)
            )
            return
        end
        if STD_TYPES[word] then
            out[#out + 1] = span("type", word)
            return
        end
        out[#out + 1] = escape(word)
    end

    local function take_quoted(quote)
        local start = i
        i = i + 1
        while i <= n do
            local b = byte(source, i)
            if b == 92 then
                i = i + 2
                if i > n + 1 then
                    i = n + 1
                end
            elseif b == quote then
                i = i + 1
                break
            else
                i = i + 1
            end
        end
        if i - 1 > n then
            i = n + 1
        end
        local stop = i - 1
        i = start
        return slice_to(stop)
    end

    local function take_number()
        local start = i
        local b0 = byte(source, i)
        if b0 == 48 and i < n then
            local b1 = byte(source, i + 1)
            if b1 == 120 or b1 == 88 then
                i = i + 2
                while i <= n and is_hex_b(byte(source, i)) do
                    i = i + 1
                end
                if i <= n and byte(source, i) == 46 then
                    local nxt = i + 1 <= n and byte(source, i + 1)
                    if nxt and is_hex_b(nxt) then
                        i = i + 1
                        while i <= n and is_hex_b(byte(source, i)) do
                            i = i + 1
                        end
                    end
                end
                if i <= n then
                    local exp = byte(source, i)
                    if exp == 112 or exp == 80 then
                        local j = i + 1
                        if j <= n then
                            local sign = byte(source, j)
                            if sign == 43 or sign == 45 then
                                j = j + 1
                            end
                        end
                        if j <= n and is_digit_b(byte(source, j)) then
                            i = j
                            while i <= n and is_digit_b(byte(source, i)) do
                                i = i + 1
                            end
                        end
                    end
                end
            else
                i = i + 1
                while i <= n and is_digit_b(byte(source, i)) do
                    i = i + 1
                end
            end
        elseif b0 == 46 then
            i = i + 1
            while i <= n and is_digit_b(byte(source, i)) do
                i = i + 1
            end
        else
            while i <= n and is_digit_b(byte(source, i)) do
                i = i + 1
            end
            if i <= n and byte(source, i) == 46 then
                local nxt = i + 1 <= n and byte(source, i + 1)
                if nxt and is_digit_b(nxt) then
                    i = i + 1
                    while i <= n and is_digit_b(byte(source, i)) do
                        i = i + 1
                    end
                end
            end
        end
        if i <= n then
            local exp = byte(source, i)
            if exp == 101 or exp == 69 then
                local j = i + 1
                if j <= n then
                    local sign = byte(source, j)
                    if sign == 43 or sign == 45 then
                        j = j + 1
                    end
                end
                if j <= n and is_digit_b(byte(source, j)) then
                    i = j
                    while i <= n and is_digit_b(byte(source, i)) do
                        i = i + 1
                    end
                end
            end
        end
        while i <= n do
            local s = byte(source, i)
            if s == 117 or s == 85 or s == 108 or s == 76 or s == 102 or s == 70 then
                i = i + 1
            else
                break
            end
        end
        local stop = i - 1
        i = start
        return slice_to(stop)
    end

    while i <= n do
        local b = byte(source, i)
        local nxt = i < n and byte(source, i + 1)

        if b == 47 and nxt == 47 then
            local start = i
            i = i + 2
            while i <= n and byte(source, i) ~= 10 do
                i = i + 1
            end
            local stop = i - 1
            i = start
            out[#out + 1] = span("comment", slice_to(stop))
            after_include = false
        elseif b == 47 and nxt == 42 then
            local start = i
            i = i + 2
            while i < n and not (byte(source, i) == 42 and byte(source, i + 1) == 47) do
                i = i + 1
            end
            if i < n then
                i = i + 2
            else
                i = n + 1
            end
            local stop = i - 1
            i = start
            out[#out + 1] = span("comment", slice_to(stop))
            after_include = false
        elseif b == 34 then
            out[#out + 1] = span("string", take_quoted(34))
            after_include = false
        elseif b == 39 then
            out[#out + 1] = span("string", take_quoted(39))
            after_include = false
        elseif after_include and b == 60 then
            local start = i
            i = i + 1
            while i <= n do
                local hb = byte(source, i)
                if hb == 62 or hb == 10 then
                    if hb == 62 then
                        i = i + 1
                    end
                    break
                end
                i = i + 1
            end
            local stop = i - 1
            i = start
            out[#out + 1] = span("string", slice_to(stop))
            after_include = false
        elseif line_start and b == 35 then
            local hash_at = i
            i = i + 1
            while i <= n and is_space_no_nl(byte(source, i)) do
                i = i + 1
            end
            if i <= n and is_alpha_(byte(source, i)) then
                local dir_start = i
                while i <= n and is_alnum_(byte(source, i)) do
                    i = i + 1
                end
                local directive = sub(source, dir_start, i - 1)
                local stop = i - 1
                i = hash_at
                out[#out + 1] = span("kw", slice_to(stop))
                after_include = directive == "include"
            else
                i = hash_at
                out[#out + 1] = escape(slice_to(hash_at))
                after_include = false
            end
        elseif is_alpha_(b) then
            local start = i
            i = i + 1
            while i <= n and is_alnum_(byte(source, i)) do
                i = i + 1
            end
            local stop = i - 1
            i = start
            local word = slice_to(stop)
            emit_ident(word)
            after_include = false
        elseif is_digit_b(b) or (b == 46 and nxt and is_digit_b(nxt)) then
            out[#out + 1] = span("lit", take_number())
            after_include = false
        else
            out[#out + 1] = escape(slice_to(i))
            if not is_space_no_nl(b) and b ~= 10 then
                after_include = false
            end
        end
    end

    return table.concat(out)
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
        highlight_c = function(source, opts)
            opts = opts or {}
            if not opts.escape then
                opts = {
                    escape = escape,
                    link = opts.link,
                    kind = opts.kind,
                }
            end
            return M.highlight_c(source, opts)
        end,
    }
    for key, value in pairs(overrides or {}) do
        picker[key] = value
    end
    return picker
end

return M
