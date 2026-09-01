local function escape_html(text)
    text = text or ""
    return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

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
  width: 300px;
  background: var(--sidebar-bg);
  border-right: 1px solid var(--border);
  overflow-y: auto;
  padding: 16px 20px 24px;
  flex-shrink: 0;
}
.main {
  flex: 1;
  padding: 32px 40px 48px;
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
  margin: 4px 0;
  padding: 2px 6px;
  border-radius: 3px;
}
.sidebar a:hover { color: var(--link); background: var(--code-bg); }
.sidebar h3 {
  font-family: "Fira Sans", sans-serif;
  font-size: 12px;
  color: var(--header-text);
  margin: 18px 0 8px;
  text-transform: uppercase;
  letter-spacing: 0.04em;
  font-weight: 500;
}
.sidebar-crate {
  font-size: 18px;
  font-weight: 600;
  margin: 0 0 12px;
  color: var(--header-text);
}
.sidebar a.sidebar-crate { color: var(--header-text); padding: 0; }
.sidebar a.sidebar-crate:hover { color: var(--link); background: transparent; }
.sidebar-module {
  font-family: "Fira Sans", sans-serif;
  font-weight: 600;
  color: var(--header-text);
  margin: 12px 0 8px;
  font-size: 14px;
}
.breadcrumbs {
  font-family: "Fira Sans", sans-serif;
  font-size: 14px;
  margin: 0 0 1em;
  color: var(--text);
}
.breadcrumbs .sep {
  margin: 0 0.4em;
  opacity: 0.55;
}
h1, h2, h3 {
  font-family: "Fira Sans", sans-serif;
}
h1 {
  font-size: 28px;
  color: var(--header-text);
  margin: 0 0 16px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 10px;
  font-weight: 500;
}
h2 {
  font-size: 22px;
  color: var(--header-text);
  margin-top: 40px;
  border-bottom: 1px solid var(--border);
  padding-bottom: 4px;
  font-weight: 500;
}
h2 a {
  font-family: "Source Code Pro", monospace;
  font-weight: 600;
}
h2 a.fn, h2 a.macro { color: var(--fn); }
h2 a.type, h2 a.constant { color: var(--type); }
.item-kind {
  font-weight: 400;
  color: var(--header-text);
}
h3 {
  font-size: 18px;
  color: var(--header-text);
  margin-top: 28px;
  margin-bottom: 12px;
  font-weight: 500;
}
a { color: var(--link); text-decoration: none; }
a:hover { text-decoration: underline; }
pre {
  width: 100%;
  box-sizing: border-box;
  background: var(--code-bg);
  padding: 14px 16px;
  border-radius: 4px;
  overflow-x: auto;
  font-size: 14px;
  line-height: 1.45;
  border: 1px solid var(--border);
  tab-size: 4;
}
code {
  font-family: "Source Code Pro", monospace;
  background: var(--code-bg);
  padding: 0.1em 0.3em;
  border-radius: 4px;
  font-size: 0.875em;
}
pre code {
  background: transparent;
  padding: 0;
  border-radius: 0;
  font-size: 14px;
}
.item-decl {
  width: 100%;
  box-sizing: border-box;
  background: var(--code-bg);
  padding: 14px 16px;
  font-family: "Source Code Pro", monospace;
  margin: 0 0 1em;
  border-radius: 4px;
  white-space: pre-wrap;
  overflow-x: auto;
  font-size: 14px;
  line-height: 1.45;
  color: var(--text);
  border: 1px solid var(--border);
  tab-size: 4;
}
.item-decl a, pre a {
  color: var(--type);
  text-decoration: none;
  border-bottom: 1px dotted var(--border);
}
.item-decl a:hover, pre a:hover {
  text-decoration: none;
  border-bottom: 1px solid var(--type);
}
.item-decl a.fn, pre a.fn, .item-decl a.macro, pre a.macro { color: var(--fn); }
.kw { color: var(--kw); font-weight: 600; }
.type { color: var(--type); }
.fn { color: var(--fn); font-weight: 600; }
.macro { color: var(--fn); font-weight: 600; }
.constant { color: var(--type); }
.lit { color: var(--lit); }
.string { color: var(--string); }
.comment { color: var(--comment); }
.field-item { margin-bottom: 15px; }
.field-name {
  font-family: "Source Code Pro", monospace;
  font-size: 16px;
  font-weight: 600;
  color: var(--header-text);
  background: var(--code-bg);
  padding: 2px 6px;
  border-radius: 4px;
  display: inline-block;
}
.field-doc * { margin-top: 6px; margin-left: 10px; color: var(--text); font-size: 16px; line-height: 1.5; }
.field-doc { margin: 0; }
.field-doc .docblock { margin: 0; }
.docblock { margin-top: 10px; margin-bottom: 30px; font-size: 16px; }
.docblock h1 { font-size: 18px; font-weight: 600; margin-top: 25px; margin-bottom: 10px; border-bottom: none; color: var(--header-text); }
.docblock h2 { font-size: 17px; font-weight: 600; margin-top: 25px; margin-bottom: 10px; border-bottom: none; color: var(--header-text); }
.docblock h3 { font-size: 16px; font-weight: 600; margin-top: 20px; margin-bottom: 10px; }
#search { width: 100%; padding: 6px 8px; background: var(--code-bg); color: var(--text); border: 1px solid var(--border); }
.docblock p { margin-bottom: 1em; }
.docblock ul { padding-left: 20px; margin-bottom: 1em; }
.docblock ol { padding-left: 20px; }
.module-card { margin-bottom: 24px; }
#search-results {
  display: none;
  margin: 6px 0 10px;
  max-height: 220px;
  overflow-y: auto;
  border: 1px solid var(--border);
  background: var(--code-bg);
  border-radius: 3px;
}
#search-results a {
  padding: 4px 8px;
  margin: 0;
  font-size: 13px;
}
#search-results a.search-selected {
  background: var(--border);
  color: var(--link);
}
.symbol-chips {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  margin-top: 12px;
}
.symbol-chips a {
  display: inline-block;
  padding: 4px 10px;
  background: var(--code-bg);
  border: 1px solid var(--border);
  border-radius: 4px;
  font-family: "Source Code Pro", monospace;
  font-size: 13px;
}
]]
end

local function safe_crumb_href(href)
    return type(href) == "string" and (
        href:match("^[%w._-]+%.html$")
        or href:match("^[%w._-]+%.html#[%w._-]+$")
        or href:match("^#[%w._-]+$")
    )
end

function M.breadcrumbs(parts, escape)
    escape = escape or escape_html
    if not parts or #parts == 0 then
        return ""
    end
    local html = { "<nav class=\"breadcrumbs\" aria-label=\"breadcrumbs\">" }
    for i, part in ipairs(parts) do
        if i > 1 then
            html[#html + 1] = "<span class=\"sep\">»</span>"
        end
        local name = escape(part.name or "")
        if safe_crumb_href(part.href) then
            html[#html + 1] = string.format("<a href=\"%s\">%s</a>", escape(part.href), name)
        else
            html[#html + 1] = "<span>" .. name .. "</span>"
        end
    end
    html[#html + 1] = "</nav>"
    return table.concat(html)
end

function M.search_box()
    return "<input id=\"search\" placeholder=\"Search\" aria-label=\"Search\">"
end

local function search_results_slot()
    return "<div id=\"search-results\"></div>"
end

function M.search_script()
    return [[
<script>
(function () {
  var input = document.getElementById("search");
  if (!input) return;

  var crateIndex = [];
  var indexEl = document.getElementById("crate-search-index");
  if (indexEl) {
    try {
      crateIndex = JSON.parse(indexEl.textContent);
      if (!Array.isArray(crateIndex)) crateIndex = [];
    } catch (e) {
      crateIndex = [];
    }
  }

  var results = document.getElementById("search-results");
  if (!results) {
    results = document.createElement("div");
    results.id = "search-results";
    if (input.parentNode) {
      input.parentNode.insertBefore(results, input.nextSibling);
    }
  }

  var selected = -1;

  function isSafeHref(href) {
    if (typeof href !== "string") return false;
    return /^#[\w.-]+$/.test(href)
      || /^[\w.-]+\.html$/.test(href)
      || /^[\w.-]+\.html#[\w.-]+$/.test(href);
  }

  function hits() {
    return results.querySelectorAll("a");
  }

  function setSelected(index) {
    var list = hits();
    if (!list.length) {
      selected = -1;
      return;
    }
    if (index < 0) index = 0;
    if (index >= list.length) index = list.length - 1;
    for (var i = 0; i < list.length; i++) {
      if (i === index) list[i].classList.add("search-selected");
      else list[i].classList.remove("search-selected");
    }
    selected = index;
    if (list[index].scrollIntoView) {
      list[index].scrollIntoView({ block: "nearest" });
    }
  }

  function navigateSelected() {
    var list = hits();
    if (!list.length) return;
    var target = list[selected >= 0 ? selected : 0];
    var href = target.getAttribute("href");
    if (!isSafeHref(href)) return;
    if (typeof target.click === "function") target.click();
    else location.assign(href);
  }

  input.addEventListener("input", function () {
    var q = input.value.toLowerCase();
    var links = document.querySelectorAll(".sidebar a[data-name]");
    for (var i = 0; i < links.length; i++) {
      var name = links[i].getAttribute("data-name") || "";
      links[i].style.display = (!q || name.toLowerCase().indexOf(q) !== -1) ? "" : "none";
    }

    selected = -1;
    while (results.firstChild) {
      results.removeChild(results.firstChild);
    }
    if (!q) {
      results.style.display = "none";
      return;
    }

    var shown = 0;
    for (var j = 0; j < crateIndex.length && shown < 30; j++) {
      var entry = crateIndex[j];
      if (!entry || typeof entry.name !== "string") continue;
      if (entry.name.toLowerCase().indexOf(q) === -1) continue;
      var href = entry.href;
      if (!isSafeHref(href)) continue;

      var a = document.createElement("a");
      a.href = href;
      a.textContent = entry.name;
      if (typeof entry.kind === "string" && entry.kind) {
        var kind = document.createElement("span");
        kind.textContent = " " + entry.kind;
        a.appendChild(kind);
      }
      results.appendChild(a);
      shown++;
    }
    results.style.display = shown ? "block" : "none";
  });

  input.addEventListener("keydown", function (e) {
    var list = hits();
    if (!list.length) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelected(selected < 0 ? 0 : selected + 1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelected(selected < 0 ? list.length - 1 : selected - 1);
    } else if (e.key === "Enter") {
      e.preventDefault();
      navigateSelected();
    }
  });
})();
</script>
]]
end

function M.module_sidebar(module_name, sections, escape, crate_name)
    escape = escape or escape_html
    local html = { "<nav class=\"sidebar\">" }
    html[#html + 1] = string.format(
        "<a class=\"sidebar-crate\" href=\"index.html\">%s</a>",
        escape(crate_name or "ballistic")
    )
    html[#html + 1] = M.search_box()
    html[#html + 1] = search_results_slot()
    html[#html + 1] = "<div class=\"sidebar-module\">" .. escape(module_name) .. "</div>"
    for _, section in ipairs(sections or {}) do
        html[#html + 1] = "<h3>" .. escape(section.title) .. "</h3>"
        for _, item in ipairs(section.items or {}) do
            html[#html + 1] = string.format(
                "<a href=\"%s\" data-name=\"%s\">%s</a>",
                escape(item.href),
                escape(item.name),
                escape(item.name)
            )
        end
    end
    html[#html + 1] = "</nav>"
    return table.concat(html)
end

function M.index_sidebar(modules, escape, crate_name)
    escape = escape or escape_html
    local html = {
        "<nav class=\"sidebar\">",
        string.format(
            "<a class=\"sidebar-crate\" href=\"index.html\">%s</a>",
            escape(crate_name or "ballistic")
        ),
        M.search_box(),
        search_results_slot(),
        "<h3>Modules</h3>",
    }
    for _, module in ipairs(modules or {}) do
        html[#html + 1] = string.format(
            "<a href=\"%s\" data-name=\"%s\">%s</a>",
            escape(module.href),
            escape(module.name),
            escape(module.name)
        )
    end
    html[#html + 1] = "</nav>"
    return table.concat(html)
end

function M.global_symbols(symbols, escape)
    escape = escape or escape_html
    if not symbols or #symbols == 0 then
        return ""
    end
    local html = { "<h2>Global Symbols</h2><div class=\"symbol-chips\">" }
    for _, symbol in ipairs(symbols) do
        html[#html + 1] = string.format(
            "<a href=\"%s\">%s</a>",
            escape(symbol.href),
            escape(symbol.name)
        )
    end
    html[#html + 1] = "</div>"
    return table.concat(html)
end

function M.page(title, theme_css, sidebar, body, crate_name, escape, search_index_json)
    crate_name = crate_name or "ballistic"
    escape = escape or escape_html
    local html = {
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
    }
    if search_index_json and search_index_json ~= "" then
        html[#html + 1] = "<script type=\"application/json\" id=\"crate-search-index\">"
        html[#html + 1] = search_index_json
        html[#html + 1] = "</script>"
    end
    html[#html + 1] = M.search_script()
    html[#html + 1] = "</body></html>\n"
    return table.concat(html)
end

return M
