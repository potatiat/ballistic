local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*[/\\])") or "./"
package.path = package.path .. ";" .. script_dir .. "/?.lua"

local clang_api = require("cdoc.clang")
local parser = require("cdoc.parser")
local html_generator = require("cdoc.html_generator")
local color_picker = require("cdoc.color_picker")
local syntax_picker = require("cdoc.syntax_picker")
local page_structure = require("cdoc.page_structure")
local markdown = require("cdoc.markdown")
local documentation = require("cdoc.documentation")
local ast = require("cdoc.ast")

local function main(...)
    local args = { ... }
    local out_directory = "docs/cdoc"
    local clang_library_path = nil
    local headers = {}
    local user_clang_arguments = {}

    local i = 1
    while i <= #args do
        if args[i] == "--out-directory" and args[i+1] then
            out_directory = args[i+1];
            i = i + 2
        elseif args[i] == "--clang-library" and args[i+1] then
            clang_library_path = args[i+1]
            i = i + 2
        elseif args[i] == "--clang-arguments" and args[i+1] then
            table.insert(user_clang_arguments, args[i+1])
            i = i + 2
        else
            headers[#headers + 1] = args[i]
            i = i + 1
        end
    end

    if #headers == 0 then
        print("Usage: luajit cdoc.lua --out-directory <dir> [--clang-library <path>] [--clang-arg <arg>] <header1.h> ...")
        return 1
    end

    local clang_context = clang_api.create_context()
    clang_api.init(clang_context, clang_library_path)
    local clang_resource_directory = clang_api.resource_directory(clang_context)
    local clang_arguments = {"-xc"}

    if clang_resource_directory then
        table.insert(clang_arguments, "-I" .. clang_resource_directory)
    end

    for _, user_clang_argument in ipairs(user_clang_arguments) do
        table.insert(clang_arguments, user_clang_argument)
    end

    local project = parser.parse_headers(clang_context, headers, clang_arguments, {
        clang = clang_api, documentation = documentation, ast = ast,
    })
    clang_api.destroy(clang_context)
    if not project or #project.modules ~= #headers then
        return 1
    end
    local ok = html_generator.generate(project, out_directory, {
        crate_name = "ballistic", theme = color_picker.named("dark"),
        syntax = syntax_picker.new(nil, markdown), colors = color_picker,
        page = page_structure, markdown = markdown,
    })
    if not ok then
        return 1
    end
    return 0
end

os.exit(main(...))