local markdown = require("cdoc.markdown")

local M = {}

function M.stylesheet(theme_css)
    return theme_css .. [[

* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; height: 100%; }
body {
  font-family: "Source Serif 4", "Iowan Old Style", Palatino, Georgia, serif;
  font-size: 16px;
  background: var(--bg);
  color: var(--text);
  display: flex;
  flex-direction: column;
  line-height: 1.6;
}
.navbar {
  background: var(--navbar-bg);
  border-bottom: 1px solid var(--border);
  padding: 10px 20px;
  display: flex;
  align-items: center;
  gap: 16px;
  flex-shrink: 0;
}
.navbar .crate {
  font-family: "Fira Sans", "Helvetica Neue", Arial, sans-serif;
  font-weight: 500;
  color: var(--header-text);
  text-decoration: none;
  font-size: 18px;
}
.navbar input {
  background: var(--code-bg);
  border: 1px solid var(--border);
  color: var(--text);
  padding: 6px 10px;
  border-radius: 4px;
  font-family: "Source Code Pro", "SFMono-Regular", Consolas, monospace;
  font-size: 13px;
  min-width: 220px;
}
.layout { display: flex; flex: 1; min-height: 0; }
.sidebar {
  width: 260px;
  background: var(--sidebar-bg);
  border-right: 1px solid var(--border);
  overflow-y: auto;
  padding: 16px 18px 32px;
  flex-shrink: 0;
}
.sidebar a {
  display: block;
  color: var(--text);
  text-decoration: none;
  font-family: "Fira Sans", "Helvetica Neue", Arial, sans-serif;
  font-size: 14px;
  margin: 4px 0;
  padding: 2px 4px;
  border-radius: 3px;
}
.sidebar a:hover { color: var(--link); background: var(--code-bg); }
.sidebar h3 {
  font-family: "Fira Sans", "Helvetica Neue", Arial, sans-serif;
  font-size: 12px;
  color: var(--header-text);
  margin: 18px 0 8px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  font-weight: 500;
}
.sidebar .kind {
  font-family: "Source Code Pro", monospace;
  font-size: 12px;
  margin-right: 6px;
  color: var(--kw);
}
.sidebar .kind.fn { color: var(--fn); }
.sidebar .kind.struct, .sidebar .kind.union, .sidebar .kind.enum { color: var(--type); }
.main {
  flex: 1;
  padding: 32px 40px 64px;
  overflow-y: auto;
  max-width: 960px;
}
h1, h2, h3 { color: var(--header-text); font-weight: 600; }
h1 { font-size: 28px; border-bottom: 1px solid var(--border); padding-bottom: 10px; }
h2 { font-size: 22px; margin-top: 48px; border-bottom: 1px solid var(--border); padding-bottom: 6px; }
h3 { font-size: 18px; margin-top: 28px; }
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
pre, .item-decl {
  width: 100%;
  background: var(--code-bg);
  padding: 14px 16px;
  border-radius: 6px;
  overflow-x: auto;
  font-size: 14px;
  line-height: 1.5;
  border: 1px solid var(--border);
  font-family: "Source Code Pro", "SFMono-Regular", Consolas, monospace;
}
code {
  font-family: "Source Code Pro", "SFMono-Regular", Consolas, monospace;
  background: var(--code-bg);
  padding: 0.1em 0.3em;
  border-radius: 4px;
  font-size: 0.875em;
}
.item-decl { white-space: pre-wrap; color: #e6e6e6; margin-bottom: 16px; }
.item-decl a.type { color: var(--type); border-bottom: 1px dotted #555; text-decoration: none; }
.item-decl a.type:hover { border-bottom: 1px solid var(--type); }
.kw { color: var(--kw); font-weight: bold; }
.type { color: var(--type); }
.fn { color: var(--fn); font-weight: bold; }
.lit { color: var(--lit); }
.field-item { margin-bottom: 14px; }
.field-name {
  font-family: "Source Code Pro", monospace;
  font-weight: 600;
  color: var(--header-text);
  background: var(--code-bg);
  padding: 2px 6px;
  border-radius: 4px;
}
.docblock { margin-top: 8px; margin-bottom: 28px; }
.docblock h1, .docblock h2, .docblock h3 { border-bottom: none; margin-top: 20px; }
.item-kind {
  font-family: "Fira Sans", sans-serif;
  font-size: 14px;
  color: var(--kw);
  font-weight: 500;
  margin-right: 8px;
}
.module-card {
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 12px 16px;
  margin: 10px 0;
  background: var(--sidebar-bg);
}
.symbol-index { display: flex; flex-wrap: wrap; gap: 8px; }
.symbol-index a {
  background: var(--code-bg);
  padding: 4px 10px;
  border-radius: 4px;
  font-family: "Source Code Pro", monospace;
  font-size: 13px;
}
]]
end

function M.document(title, theme_css, navbar, sidebar, main)
    return table.concat({
        "<!DOCTYPE html>",
        "<html lang=\"en\">",
        "<head>",
        "<meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
        "<title>" .. markdown.escape(title) .. "</title>",
        "<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Fira+Sans:wght@400;500&family=Source+Code+Pro:wght@400;600&family=Source+Serif+4:wght@400;600;700&display=swap\">",
        "<style>",
        M.stylesheet(theme_css),
        "</style>",
        "</head>",
        "<body>",
        navbar,
        "<div class=\"layout\">",
        sidebar,
        "<main class=\"main\">",
        main,
        "</main>",
        "</div>",
        [[<script>
(function () {
  var input = document.getElementById("search");
  if (!input) return;
  input.addEventListener("input", function () {
    var q = input.value.toLowerCase();
    document.querySelectorAll(".sidebar a.item").forEach(function (a) {
      a.style.display = a.textContent.toLowerCase().indexOf(q) !== -1 ? "" : "none";
    });
  });
})();
</script>]],
        "</body></html>",
    }, "\n")
end

function M.navbar(crate_name)
    return string.format(
        "<nav class=\"navbar\"><a class=\"crate\" href=\"index.html\">%s</a>"
            .. "<input id=\"search\" type=\"search\" placeholder=\"Search symbols\"></nav>",
        markdown.escape(crate_name)
    )
end

function M.sidebar(groups)
    local parts = { "<nav class=\"sidebar\">" }
    for _, group in ipairs(groups) do
        if #group.links > 0 then
            parts[#parts + 1] = "<h3>" .. markdown.escape(group.title) .. "</h3>"
            for _, link in ipairs(group.links) do
                local kind_class = link.kind and link.kind:match("^[%w]+$") or nil
                local kind = kind_class and string.format("<span class=\"kind %s\">%s</span>", kind_class, markdown.escape(link.kind)) or ""
                parts[#parts + 1] = string.format(
                    "<a class=\"item\" href=\"%s\">%s%s</a>",
                    markdown.escape(link.href),
                    kind,
                    kind ~= "" and (" " .. markdown.escape(link.label)) or markdown.escape(link.label)
                )
            end
        end
    end
    parts[#parts + 1] = "</nav>"
    return table.concat(parts, "\n")
end

return M
