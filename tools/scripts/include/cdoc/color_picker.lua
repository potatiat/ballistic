local M = {}

-- Dark values copy the in-tree C generator (tools/cdoc.c write_common_head).
local THEMES = {
    dark = {
        bg = "#0f1419",
        sidebar_bg = "#14191f",
        text = "#c5c5c5",
        link = "#39afd7",
        code_bg = "#191f26",
        border = "#252c37",
        header_text = "#fff",
        kw = "#ff7b72",
        type = "#79c0ff",
        fn = "#d2a8ff",
        lit = "#a5d6ff",
        navbar_bg = "#0f1419",
    },
    light = {
        bg = "#ffffff",
        sidebar_bg = "#f5f5f5",
        text = "#333333",
        link = "#0066cc",
        code_bg = "#f0f0f0",
        border = "#dddddd",
        header_text = "#111111",
        kw = "#a71d5d",
        type = "#0086b3",
        fn = "#795da3",
        lit = "#0086b3",
        navbar_bg = "#ffffff",
    },
}

function M.named(name)
    return THEMES[name] or THEMES.dark
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
  --navbar-bg: %s;
}
]], theme.bg, theme.sidebar_bg, theme.text, theme.link, theme.code_bg, theme.border,
        theme.header_text, theme.kw, theme.type, theme.fn, theme.lit, theme.navbar_bg)
end

return M
