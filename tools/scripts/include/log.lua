-- Usage:
--   package.path = package.path .. ";path-to-this-file/?.lua"
--   local log = require("log")
--   log.info("Engine initialized.")
--   log.error("Failed: %s (%d)", reason, code)

local M = {}

M.levels = {
	NONE  = -1,
	ERROR = 0,
	WARN  = 1,
	INFO  = 2,
	DEBUG = 3,
	TRACE = 4,
}

local level_names = {
	[-1] = "NONE",
	[0]  = "ERROR",
	[1]  = "WARN",
	[2]  = "INFO",
	[3]  = "DEBUG",
	[4]  = "TRACE",
}

M.min_level = M.levels.TRACE

local function normalize_level(level)
	if type(level) == "string" then
		local n = M.levels[level:upper()]

		if n == nil then
			error("invalid log level: " .. level, 3)
		end

		return n
	end

	if type(level) ~= "number" or level ~= math.floor(level) then
		error("log level must be integer or level name", 3)
	end

	if level < M.levels.NONE or level > M.levels.TRACE then
		error("invalid log level: " .. tostring(level), 3)
	end

	return level
end

local function clean_source(source)
	if type(source) ~= "string" then
		return "=[?]"
	end

	if source:sub(1, 1) == "@" then
		source = source:sub(2)
	end

	local base = source:match(".*[/\\](.*)$")
	return base or source
end

local function caller_name(info)
	if info.name and info.name ~= "" then
		return info.name
	end

	if info.what == "main" then
		return "main"
	end

	if info.what == "C" then
		return "C"
	end

	return "anonymous"
end

local function format_message(message, ...)
	if select("#", ...) == 0 then
		return tostring(message)
	end

	local ok, formatted = pcall(string.format, tostring(message), ...)

	if ok then
		return formatted
	end

	return tostring(message)
end

local function emit(level, message, ...)
	if level == M.levels.NONE or level > M.min_level then
		return
	end

	local info = debug.getinfo(3, "Snl") or {}
	local level_str = level_names[level] or "MISSING"
	local func = caller_name(info)
	local filename = clean_source(info.source)
	local line = info.currentline or -1
	local text = format_message(message, ...)
	io.stderr:write(string.format("[%s] [%s] [%s:%d] %s\n",
		level_str, func, filename, line, text))
end

function M.log(level, message, ...)
	emit(normalize_level(level), message, ...)
end

function M.error(message, ...) emit(M.levels.ERROR, message, ...) end
function M.warn(message, ...)  emit(M.levels.WARN, message, ...)  end
function M.info(message, ...)  emit(M.levels.INFO, message, ...)  end
function M.debug(message, ...) emit(M.levels.DEBUG, message, ...) end
function M.trace(message, ...) emit(M.levels.TRACE, message, ...) end

function M.set_level(level)
	M.min_level = normalize_level(level)
end

M.ERROR = M.error
M.WARN  = M.warn
M.INFO  = M.info
M.DEBUG = M.debug
M.TRACE = M.trace

return M