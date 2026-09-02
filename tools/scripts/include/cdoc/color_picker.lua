local M = {}

-- Dark token colors follow the old C generator; light is a named palette.
local THEMES = {
    dark = {
        bg = "#0f1419",
        sidebar_bg = "#0a0e13",
        text = "#c5c5c5",
        link = "#39afd7",
        code_bg = "#191f26",
        border = "#252c37",
        header_text = "#fff",
        kw = "#ab8ac1",
        type = "#769acb",
        fn = "#d7a3ea",
        lit = "#83a300",
        string = "#83a300",
        comment = "#8d8d8b",
        navbar_bg = "#0f1419",
    },
    light = {
        bg = "#ffffff",
        sidebar_bg = "#ececec",
        text = "#333333",
        link = "#0066cc",
        code_bg = "#f0f0f0",
        border = "#dddddd",
        header_text = "#111111",
        kw = "#8959a8",
        type = "#4271ae",
        fn = "#795da3",
        lit = "#718c00",
        string = "#718c00",
        comment = "#8e908c",
        navbar_bg = "#ffffff",
    },
}

function M.named(name)
    return THEMES[name] or THEMES.dark
end

function M.has(name)
    return THEMES[name] ~= nil
end

function M.css(theme)
    theme = theme or THEMES.dark
    return string.format([[
:root {
  --bg: %s;
  --sidebar-bg: %s;
  --text: %s;
  --link: %s;
  --code-bg: %s;
  --border: %s;
  --header-text: %s;
  --kw: %s;
  --type: %s;
  --fn: %s;
  --lit: %s;
  --string: %s;
  --comment: %s;
  --navbar-bg: %s;
}
]], theme.bg, theme.sidebar_bg, theme.text, theme.link, theme.code_bg, theme.border,
        theme.header_text, theme.kw, theme.type, theme.fn, theme.lit, theme.string, theme.comment, theme.navbar_bg)
end

return M
