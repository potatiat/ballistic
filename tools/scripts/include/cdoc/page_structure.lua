local markdown = require("cdoc.markdown")

local M = {}

function M.stylesheet(theme_css)
    return theme_css .. [[
* { box-sizing: border-box; }
html, body { margin: 0; padding: 0; height: 100%; }
body {
    font-family: "Source Serif 4", serif;
    font-size: 16px;
    background: var(--bg);
    color: var(--text);
    margin: 0;
    display: flex;
    flex-direction: column;
    height: 100vh;
    overflow: hidden;
    line-height: 1.6;
}
.navbar {
    display: flex;
    align-items: center;
    height: 40px;
    padding: 0 20px;
    background: var(--navbar-bg);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    font-family: "Fira Sans", sans-serif;
}
.navbar a {
    color: var(--header-text);
    font-weight: 600;
    text-decoration: none;
}
.workspace {
    display: flex;
    flex: 1;
    min-height: 0;
}
.sidebar {
  width: 250px;
  background: var(--sidebar-bg);
  border-right: 1px solid var(--border);
  overflow-y: auto;
  padding: 20px;
  flex-shrink: 0;
}
.main {
  flex: 1;
  padding: 40px;
  overflow-y: auto;
  max-width: 960px;
  margin: 0 auto;
}
.sidebar a {
  display: block;
  color: var(--text);
  text-decoration: none;
  font-family: "Fira Sans", sans-serif;
  font-size: 14px;
  margin: 6px 0;
}
.sidebar a:hover { color: var(--link); background: var(--code-bg); border-radius: 3px; }
.sidebar h3 {
  font-family: "Fira Sans", sans-serif;
  font-size: 14px;
  color: var(--header-text);
  margin-top: 20px;
  text-transform: uppercase;
  font-weight: 500;
}
h1 {
  font-size: 28px;
  color: var(--header-text);
  margin-bottom: 20px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 10px;
}
h2 {
  font-size: 24px;
  color: var(--header-text);
  margin-top: 50px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 5px;
  font-weight: 600;
}
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
pre {
  width: 100%;
  box-sizing: border-box;
  background: var(--code-bg);
  padding: 15px;
  border-radius: 6px;
  overflow-x: auto;
  font-size: 14px;
  line-height: 1.5;
  border: 1px solid var(--border);
}
code {
  font-family: "Source Code Pro", monospace;
  background: var(--code-bg);
  padding: 0.1em 0.3em;
  border-radius: 4px;
  font-size: 0.875em;
}
.item-decl {
  width: 100%;
  box-sizing: border-box;
  background: var(--code-bg);
  padding: 15px;
  font-family: "Source Code Pro", monospace;
  margin-bottom: 20px;
  border-radius: 6px;
  white-space: pre-wrap;
  overflow-x: auto;
  font-size: 14px;
  line-height: 1.5;
  color: var(--text);
  border: 1px solid var(--border);
}
.item-decl a.type { color: var(--type); text-decoration: none; border-bottom: 1px dotted var(--border); }
.kw { color: var(--kw); font-weight: bold; }
.type { color: var(--type); }
.fn { color: var(--fn); font-weight: bold; }
.lit { color: var(--lit); }
.docblock { margin-top: 10px; margin-bottom: 30px; font-size: 16px; }
.docblock h1, .docblock h2, .docblock h3 {
  border-bottom: none;
  color: var(--header-text);
}
.module-card { margin-bottom: 24px; }
]]
end

function M.search_script()
    return [[
<script>
(function () {
  var input = document.getElementById("search");
  if (!input) return;
  input.addEventListener("input", function () {
    var q = input.value.toLowerCase();
    var links = document.querySelectorAll(".sidebar a[data-name]");
    for (var i = 0; i < links.length; i++) {
      var name = links[i].getAttribute("data-name") || "";
      links[i].style.display = name.toLowerCase().indexOf(q) === -1 ? "none" : "";
    }
  });
})();
</script>
]]
end

function M.page(title, theme_css, sidebar, body, crate_name, escape)
    crate_name = crate_name or "ballistic"
    escape = escape or markdown.escape
    return table.concat({
        "<!DOCTYPE html><html lang=\"en\"><head><meta charset=\"utf-8\">",
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">",
        "<title>" .. escape(title) .. "</title>",
        "<link rel=\"stylesheet\" href=\"https://fonts.googleapis.com/css2?family=Fira+Sans:wght@400;500&family=Source+Code+Pro:wght@400;600&family=Source+Serif+4:wght@400;600;700&display=swap\">",
        "<style>",
        M.stylesheet(theme_css),
        "</style></head><body>",
        "<div class=\"navbar\"><a href=\"index.html\">" .. escape(crate_name) .. "</a></div>",
        "<div class=\"workspace\">",
        sidebar,
        "<main class=\"main\">",
        body,
        "</main></div>",
        M.search_script(),
        "</body></html>\n",
    })
end

return M
