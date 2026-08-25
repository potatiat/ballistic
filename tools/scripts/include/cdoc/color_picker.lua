local M = {}

-- Closest match to the original cdoc.c :root block.
function M.classic()
    return {
        name = "classic",
        vars = {
            ["bg"] = "#0f1419",
            ["sidebar-bg"] = "#14191f",
            ["text"] = "#c5c5c5",
            ["link"] = "#39afd7",
            ["code-bg"] = "#191f26",
            ["border"] = "#252c37",
            ["header-text"] = "#fff",
            ["kw"] = "#ff7b72",
            ["type"] = "#79c0ff",
            ["fn"] = "#d2a8ff",
            ["lit"] = "#a5d6ff",
            ["navbar-bg"] = "#14191f",
        },
    }
end

-- rustdoc ayu-dark-ish tokens used by docs.rs.
function M.dark()
    return {
        name = "dark",
        vars = {
            ["bg"] = "#0c1018",
            ["sidebar-bg"] = "#161b22",
            ["text"] = "#c5c5c5",
            ["link"] = "#39afd7",
            ["code-bg"] = "#14191f",
            ["border"] = "#2a313c",
            ["header-text"] = "#ddd",
            ["kw"] = "#ff7733",
            ["type"] = "#39bae6",
            ["fn"] = "#ffb454",
            ["lit"] = "#95e6cb",
            ["navbar-bg"] = "#0a0e14",
        },
    }
end

function M.light()
    return {
        name = "light",
        vars = {
            ["bg"] = "#fff",
            ["sidebar-bg"] = "#f5f5f5",
            ["text"] = "#000",
            ["link"] = "#3873ad",
            ["code-bg"] = "#f5f5f5",
            ["border"] = "#ddd",
            ["header-text"] = "#111",
            ["kw"] = "#a71d5d",
            ["type"] = "#0086b3",
            ["fn"] = "#795da3",
            ["lit"] = "#183691",
            ["navbar-bg"] = "#f5f5f5",
        },
    }
end

function M.named(name)
    if name == "classic" then
        return M.classic()
    elseif name == "light" then
        return M.light()
    end
    return M.dark()
end

function M.to_css(theme)
    local lines = { ":root {" }
    for key, value in pairs(theme.vars) do
        lines[#lines + 1] = string.format("  --%s: %s;", key, value)
    end
    lines[#lines + 1] = "}"
    return table.concat(lines, "\n")
end

return M
