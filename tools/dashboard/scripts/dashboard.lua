local script_path = debug.getinfo(1, "S").source:sub(2)
script_dir = script_path:match("(.*[/\\])") or "./"

-- Append the script's directory to package.path
package.path = package.path .. ";" .. script_dir .. "?.lua"

local ffi = require("ffi")
local imgui = require("imgui.glfw")

ffi.cdef [[
typedef struct bal_file_dialog_t bal_file_dialog_t;
void dashboard_file_dialog_open(bal_file_dialog_t* dialog);
bool dashboard_file_dialog_draw(bal_file_dialog_t* dialog);
const char *dashboard_file_dialog_get_current_path(bal_file_dialog_t *dialog);
]]

local C = ffi.C

function dashboard_render(host_context, p_file_dialog)
    imgui.SetCurrentContext(host_context)
    local viewport = imgui.GetMainViewport()
    imgui.SetNextWindowPos(viewport.Pos)
    local size = imgui.ImVec2(viewport.WorkSize.x, viewport.WorkSize.y)
    imgui.SetNextWindowSize(size)

    local window_flags = bit.bor(
            imgui.lib.ImGuiWindowFlags_NoTitleBar,
            imgui.lib.ImGuiWindowFlags_NoCollapse,
            imgui.lib.ImGuiWindowFlags_NoResize,
            imgui.lib.ImGuiWindowFlags_NoMove,
            imgui.lib.ImGuiWindowFlags_NoBringToFrontOnFocus
    )
    imgui.PushStyleColor(imgui.lib.ImGuiCol_WindowBg, imgui.ImVec4(0.06, 0.08, 0.10, 1.0))

    imgui.Begin("Dashboard", nil, window_flags)
    local button_width = 400
    local button_height = 80
    local center_x = (size.x - button_width) * 0.5
    local center_y = (size.y - button_height) * 0.5
    imgui.SetCursorPos(imgui.ImVec2(center_x, center_y))
    imgui.PushStyleColor(imgui.lib.ImGuiCol_Button, imgui.ImVec4(0.22, 0.68, 0.84, 1.0))
    imgui.PushStyleColor(imgui.lib.ImGuiCol_ButtonHovered, imgui.ImVec4(0.28, 0.78, 0.94, 1.0))
    imgui.PushStyleColor(imgui.lib.ImGuiCol_ButtonActive, imgui.ImVec4(0.15, 0.50, 0.65, 1.0))
    imgui.PushStyleVar(imgui.lib.ImGuiStyleVar_FrameRounding, 8.0)

    if imgui.Button("Generate Minimal Working Example", imgui.ImVec2(button_width, button_height)) then
        C.dashboard_file_dialog_open(p_file_dialog)
    end

    imgui.PopStyleColor(3)
    imgui.PopStyleVar(1)

    if C.dashboard_file_dialog_draw(p_file_dialog) then
        local selected_path = ffi.string(C.dashboard_file_dialog_get_current_path(p_file_dialog))
        print("Directory chosen: " .. selected_path)
    end

    imgui.End()
    imgui.PopStyleColor()
end