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
local log = require("log")

local function main(...)
    local args = { ... }
    local out_directory = "docs/cdoc"
    local clang_library_path = nil
    local headers = {}
    local user_clang_arguments = {}
    local theme_name = "dark"
    local crate_name = "ballistic"
    local crate_intro = "A rewrite of the dynarmic ARM recompiler with an extremely low cache footprint."
    local usage = "Usage: luajit cdoc.lua --out-directory <dir> [--theme dark|light] [--crate-intro <text>] [--clang-library <path>] [--clang-arguments <arg>] [--clang-arg <arg>] <header1.h> ..."

    local i = 1
    while i <= #args do
        local flag = args[i]
        if flag == "--out-directory" or flag == "--clang-library"
            or flag == "--clang-arguments" or flag == "--clang-arg"
            or flag == "--theme" or flag == "--crate-intro" then
            if not args[i + 1] or args[i + 1]:sub(1, 2) == "--" then
                print(usage)
                return 1
            end
            if flag == "--out-directory" then
                out_directory = args[i + 1]
            elseif flag == "--clang-library" then
                clang_library_path = args[i + 1]
            elseif flag == "--clang-arguments" or flag == "--clang-arg" then
                table.insert(user_clang_arguments, args[i + 1])
            elseif flag == "--crate-intro" then
                crate_intro = args[i + 1]
            else
                theme_name = args[i + 1]
            end
            i = i + 2
        elseif flag:sub(1, 1) == "-" then
            -- Single-dash leftovers such as -I. are clang argv, not headers.
            -- Treating them as paths made parse_headers fail and skipped HTML.
            print(usage)
            return 1
        else
            headers[#headers + 1] = args[i]
            i = i + 1
        end
    end

    if #headers == 0 or not color_picker.has(theme_name) then
        print(usage)
        return 1
    end

    log.set_level("INFO")
    local started = os.clock()

    local clang_context = clang_api.create_context()
    if not clang_api.init(clang_context, clang_library_path) then
        return 1
    end
    local clang_resource_directory = clang_api.resource_directory(clang_context)
    if not clang_resource_directory then
        log.error("Could not locate clang builtin headers (stdarg.h) for the loaded libclang.")
        clang_api.destroy(clang_context)
        return 1
    end

    local clang_arguments = {"-xc", "-I.", "-Iinclude", "-I" .. clang_resource_directory}
    for _, user_clang_argument in ipairs(user_clang_arguments) do
        table.insert(clang_arguments, user_clang_argument)
    end

    local project = parser.parse_headers(clang_context, headers, clang_arguments, {
        clang = clang_api,
        documentation = documentation,
        ast = ast,
    })
    if #project.modules ~= #headers then
        log.error("Parsed %d of %d headers; not writing HTML.", #project.modules, #headers)
        clang_api.destroy(clang_context)
        return 1
    end
    clang_api.destroy(clang_context)

    local generated = html_generator.generate(project, out_directory, {
        crate_name = crate_name,
        crate_intro = crate_intro,
        theme = color_picker.named(theme_name),
        syntax = syntax_picker.new(nil, markdown),
        colors = color_picker,
        page = page_structure,
        markdown = markdown,
    })

    if not generated then
        log.error("Failed to write HTML under '%s'.", out_directory)
        return 1
    end

    local elapsed_ms = math.floor((os.clock() - started) * 1000 + 0.5)
    log.info("Generated %d modules in %d ms.", #project.modules, elapsed_ms)
    return 0
end

os.exit(main(...))
