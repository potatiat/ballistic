local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("(.*[/\\])") or "./"
package.path = package.path .. ";" .. script_dir .. "/?.lua"

local clang = require("cdoc.clang")

local function main(...)
    local args = { ... }
    local out_directory = "docs/"
    local clang_library_path = nil
    local headers = {}
    local clang_arguments = {}

    local i = 1
    while i <= #args do
        if args[i] == "--out-directory" and args[i+1] then
            out_directory = args[i+1];
            i = i + 2
        elseif args[i] == "--clang-library" and args[i+1] then
            clang_library_path = args[i+1]
            i = i + 2
        elseif args[i] == "--clang-arguments" and args[i+1] then
            clang_arguments[#clang_arguments + 1] = args[i+1]
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

    clang.init(clang_library_path)

    return 0
end

main(...)