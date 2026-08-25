local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*[/\\])") or "./"
package.path = package.path .. ";" .. script_dir .. "/?.lua"

local log = require("log")
local clang_api = require("cdoc.clang")
local parser = require("cdoc.parser")
local html_generator = require("cdoc.html_generator")
local color_picker = require("cdoc.color_picker")

local function print_usage()
    io.stderr:write(
        "Usage: luajit cdoc.lua --out-directory <dir> [--clang-library <path>] "
            .. "[--clang-arg <arg>] [--theme dark|light|classic] <header1.h> ...\n"
    )
end

local function main(...)
    local args = { ... }
    local out_directory = "docs/cdoc"
    local clang_library_path = nil
    local theme_name = "dark"
    local headers = {}
    local user_clang_arguments = {}

    local i = 1
    while i <= #args do
        if (args[i] == "--out-directory" or args[i] == "--clang-library"
            or args[i] == "--clang-arg" or args[i] == "--clang-arguments"
            or args[i] == "--theme") and not args[i + 1] then
            print_usage()
            return 1
        elseif args[i] == "--out-directory" then
            out_directory = args[i + 1]
            i = i + 2
        elseif args[i] == "--clang-library" then
            clang_library_path = args[i + 1]
            i = i + 2
        elseif args[i] == "--clang-arg" or args[i] == "--clang-arguments" then
            user_clang_arguments[#user_clang_arguments + 1] = args[i + 1]
            i = i + 2
        elseif args[i] == "--theme" then
            theme_name = args[i + 1]
            i = i + 2
        elseif args[i] == "--help" or args[i] == "-h" then
            print_usage()
            return 0
        else
            headers[#headers + 1] = args[i]
            i = i + 1
        end
    end

    if #headers == 0 then
        print_usage()
        return 1
    end

    log.set_level("INFO")

    local clang_context = clang_api.create_context()
    if not clang_api.init(clang_context, clang_library_path) then
        return 1
    end

    local clang_arguments = { "-xc", "-I.", "-Iinclude" }
    local clang_resource_directory = clang_api.resource_directory(clang_context)
    if clang_resource_directory then
        clang_arguments[#clang_arguments + 1] = "-I" .. clang_resource_directory
    end
    for _, user_clang_argument in ipairs(user_clang_arguments) do
        clang_arguments[#clang_arguments + 1] = user_clang_argument
    end

    local started = os.clock()
    local project = parser.parse_headers(clang_context, headers, clang_arguments)
    html_generator.generate(project, out_directory, {
        crate_name = "ballistic",
        theme = color_picker.named(theme_name),
    })
    clang_api.destroy(clang_context)
    local elapsed = os.clock() - started
    log.info("Wrote docs for %d headers to %s in %.3fs.", #project.modules, out_directory, elapsed)
    return 0
end

os.exit(main(...) or 0)
