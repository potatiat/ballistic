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
    height: 100vh;
    overflow: hidden;
    line-height: 1.6;
}
.workspace {
    display: flex;
    height: 100%;
    min-width: 0;
    min-height: 0;
}
.sidebar {
  flex: 0 0 300px;
  width: 300px;
  height: 100%;
  background: var(--sidebar-bg);
  border-right: 1px solid var(--border);
  overflow-x: hidden;
  overflow-y: auto;
  padding: 16px 20px 24px;
}
.main {
  position: relative;
  flex: 1 1 0%;
  min-width: 0;
  min-height: 0;
  height: 100%;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
.navbar {
    display: flex;
    align-items: center;
    justify-content: flex-end;
    gap: 8px;
    height: 44px;
    padding: 0 16px;
    background: var(--navbar-bg);
    border-bottom: 1px solid var(--border);
    flex-shrink: 0;
    font-family: "Fira Sans", sans-serif;
}
.search-form {
  flex: 1 1 auto;
  width: auto;
  max-width: 100%;
}
.content-scroll {
  flex: 1 1 auto;
  min-width: 0;
  min-height: 0;
  width: 100%;
  overflow: auto;
}
.content {
  width: 100%;
  max-width: 960px;
  margin: 0 auto;
  padding: 32px 40px 48px;
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
  max-width: 100%;
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
  display: block;
  position: relative;
  z-index: 1;
  width: 100%;
  max-width: 100%;
  min-width: 0;
  box-sizing: border-box;
  background: var(--code-bg);
  padding: 14px 16px;
  font-family: "Source Code Pro", monospace;
  margin: 0 0 1em;
  border-radius: 4px;
  white-space: pre;
  overflow-x: auto;
  overflow-wrap: normal;
  word-break: normal;
  font-size: 14px;
  line-height: 1.45;
  color: var(--text);
  border: 1px solid var(--border);
  tab-size: 4;
}
.item-decl a, pre a {
  position: relative;
  z-index: 2;
  pointer-events: auto;
  text-decoration: none;
  border-bottom: 1px dotted;
}
.item-decl a:hover, pre a:hover {
  text-decoration: none;
  border-bottom-style: solid;
}
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
#search {
  width: 100%;
  padding: 6px 8px;
  background: var(--code-bg);
  color: var(--text);
  border: 1px solid var(--border);
  border-radius: 3px;
  font-family: "Fira Sans", sans-serif;
  font-size: 14px;
}
#search:focus {
  outline: 1px solid var(--link);
  border-color: var(--link);
}
.docblock p { margin-bottom: 1em; }
.docblock ul { padding-left: 20px; margin-bottom: 1em; }
.docblock ol { padding-left: 20px; }
.crate-intro { margin: 0 0 8px; }
.module-card {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 8px 16px;
  margin-bottom: 8px;
  padding: 10px 12px;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--code-bg);
}
.module-card-desc { margin: 0; flex: 1 1 12em; font-size: 15px; }
.module-card-desc.empty { color: var(--comment); font-style: italic; }
#search-results {
  display: none;
  position: absolute;
  top: 44px;
  left: 0;
  right: 0;
  bottom: 0;
  z-index: 20;
  margin: 0;
  padding: 12px 24px 32px;
  overflow-y: auto;
  border: none;
  border-top: 1px solid var(--border);
  background: var(--bg);
  border-radius: 0;
}
#search-results a {
  display: block;
  padding: 8px 12px;
  margin: 0;
  font-size: 15px;
  font-family: "Fira Sans", sans-serif;
  border-bottom: 1px solid var(--border);
}
#search-results a.search-selected {
  background: var(--border);
  color: var(--link);
}
.help-button {
  flex-shrink: 0;
  width: 28px;
  height: 28px;
  padding: 0;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--code-bg);
  color: var(--header-text);
  font-family: "Fira Sans", sans-serif;
  font-size: 16px;
  cursor: pointer;
}
.help-button:hover {
  border-color: var(--link);
  color: var(--link);
}
.help-overlay {
  position: fixed;
  inset: 0;
  z-index: 40;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.55);
}
.help-overlay[hidden] { display: none !important; }
.help-panel {
  background: var(--sidebar-bg);
  color: var(--text);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 20px 24px;
  min-width: 280px;
  max-width: 90vw;
  font-family: "Fira Sans", sans-serif;
}
.help-panel h2 {
  margin: 0 0 12px;
  font-size: 18px;
  border-bottom: none;
}
.help-panel dl { margin: 0 0 16px; }
.help-panel dt { font-weight: 600; margin-top: 10px; }
.help-panel dd { margin: 4px 0 0; }
.help-panel kbd {
  font-family: "Source Code Pro", monospace;
  padding: 1px 6px;
  border: 1px solid var(--border);
  border-radius: 3px;
  background: var(--code-bg);
}
.help-close {
  font-family: "Fira Sans", sans-serif;
  padding: 4px 10px;
  border: 1px solid var(--border);
  border-radius: 4px;
  background: var(--code-bg);
  color: var(--header-text);
  cursor: pointer;
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

local function search_results_slot()
    return "<div id=\"search-results\"></div>"
end

function M.search_box()
    return table.concat({
        "<form class=\"search-form\" role=\"search\" action=\"#\" method=\"get\">",
        "<input id=\"search\" type=\"search\" placeholder=\"Search\" aria-label=\"Search\" autocomplete=\"off\" spellcheck=\"false\">",
        "</form>",
    })
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

  var overlay = document.getElementById("help-overlay");
  var selected = -1;

  function closeSearch() {
    results.style.display = "none";
    selected = -1;
  }

  function isSafeHref(href) {
    if (typeof href !== "string") return false;
    return /^#[\w.-]+$/.test(href)
      || /^[\w.-]+\.html$/.test(href)
      || /^[\w.-]+\.html#[\w.-]+$/.test(href);
  }

  function isTypingTarget(el) {
    if (!el) return false;
    var tag = (el.tagName || "").toLowerCase();
    if (tag === "input" || tag === "textarea" || tag === "select") return true;
    return !!el.isContentEditable;
  }

  function helpOpen() {
    return !!(overlay && !overlay.hasAttribute("hidden"));
  }

  function setHelp(open) {
    if (!overlay) return;
    if (open) overlay.removeAttribute("hidden");
    else overlay.setAttribute("hidden", "");
  }

  function focusSearch() {
    setHelp(false);
    input.focus();
    if (typeof input.select === "function") input.select();
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
    closeSearch();
    input.blur();
    if (typeof target.click === "function") target.click();
    else location.assign(href);
  }

  results.addEventListener("click", function (e) {
    var el = e.target;
    while (el && el !== results && (el.tagName || "").toLowerCase() !== "a") {
      el = el.parentNode;
    }
    if (el && el !== results) closeSearch();
  });

  if (input.form) {
    input.form.addEventListener("submit", function (e) {
      e.preventDefault();
      navigateSelected();
    });
  }

  var helpToggle = document.getElementById("help-toggle");
  if (helpToggle) {
    helpToggle.addEventListener("click", function () {
      setHelp(!helpOpen());
    });
  }
  var helpClose = document.getElementById("help-close");
  if (helpClose) {
    helpClose.addEventListener("click", function () {
      setHelp(false);
    });
  }
  if (overlay) {
    overlay.addEventListener("click", function (e) {
      if (e.target === overlay) setHelp(false);
    });
  }

  document.addEventListener("keydown", function (e) {
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    if (e.key === "Escape") {
      if (helpOpen()) {
        e.preventDefault();
        setHelp(false);
        return;
      }
      if (document.activeElement === input || results.style.display === "block") {
        e.preventDefault();
        closeSearch();
        input.blur();
      }
      return;
    }
    if (isTypingTarget(e.target)) return;
    if (e.key === "?") {
      e.preventDefault();
      setHelp(!helpOpen());
      return;
    }
    if (e.key === "/" || e.key === "s" || e.key === "S") {
      e.preventDefault();
      focusSearch();
    }
  });

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
      closeSearch();
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
    if (!shown) {
      var empty = document.createElement("div");
      empty.textContent = "No results found.";
      results.appendChild(empty);
    }
    results.style.display = "block";
  });

  input.addEventListener("keydown", function (e) {
    var list = hits();
    if (e.key === "Enter") {
      e.preventDefault();
      if (list.length) navigateSelected();
      else closeSearch();
      return;
    }
    if (!list.length) return;
    if (e.key === "ArrowDown") {
      e.preventDefault();
      setSelected(selected < 0 ? 0 : selected + 1);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSelected(selected < 0 ? list.length - 1 : selected - 1);
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
        "<div class=\"workspace\">",
        sidebar,
        "<main class=\"main\">",
        "<nav class=\"navbar\" aria-label=\"" .. escape(crate_name) .. " documentation toolbar\">",
        M.search_box(),
        "<button type=\"button\" class=\"help-button\" id=\"help-toggle\" title=\"Keyboard shortcuts\" aria-label=\"Keyboard shortcuts\">?</button>",
        "</nav>",
        search_results_slot(),
        "<div class=\"content-scroll\">",
        "<div class=\"content\">",
        body,
        "</div></div></main></div>",
        "<div id=\"help-overlay\" class=\"help-overlay\" hidden>",
        "<div class=\"help-panel\" role=\"dialog\" aria-modal=\"true\" aria-labelledby=\"help-title\">",
        "<h2 id=\"help-title\">Keyboard shortcuts</h2>",
        "<dl>",
        "<dt><kbd>/</kbd> or <kbd>s</kbd></dt><dd>Focus search</dd>",
        "<dt><kbd>?</kbd></dt><dd>Open this help</dd>",
        "<dt><kbd>Esc</kbd></dt><dd>Close help or search</dd>",
        "</dl>",
        "<button type=\"button\" class=\"help-close\" id=\"help-close\">Close</button>",
        "</div></div>",
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
