local log = require("log")
local ffi = require("ffi")

ffi.cdef[[
typedef void* CXIndex;
typedef void* CXTranslationUnit;
typedef void* CXClientData;
typedef void* CXFile;

typedef struct { const void *ptr_data[2]; unsigned int_data; } CXSourceLocation;
typedef struct { const void *ptr_data[2]; unsigned begin_int_data; unsigned end_int_data; } CXSourceRange;
typedef struct { int kind; int xdata; void *data[3]; } CXCursor;
typedef struct { int kind; void *data[2]; } CXType;
typedef struct { const void *data; unsigned private_flags; } CXString;
typedef struct { unsigned int_data[4]; void *ptr_data; } CXToken;

typedef enum { CXChildVisit_Break = 0, CXChildVisit_Continue = 1, CXChildVisit_Recurse = 2 } CXChildVisitResult;

CXIndex clang_createIndex(int excludeDeclarationsFromPCH, int displayDiagnostics);
void clang_disposeIndex(CXIndex index);
CXTranslationUnit clang_parseTranslationUnit(CXIndex CIdx, const char *source_filename, const char *const *command_line_args, int num_command_line_args, void *unsaved_files, unsigned num_unsaved_files, unsigned options);
void clang_disposeTranslationUnit(CXTranslationUnit);
CXCursor clang_getTranslationUnitCursor(CXTranslationUnit);

int clang_getCursorKind(CXCursor);
CXString clang_getCursorSpelling(CXCursor);
CXType clang_getCursorType(CXCursor);
CXType clang_getCursorResultType(CXCursor);
CXString clang_Cursor_getRawCommentText(CXCursor);
int clang_isCursorDefinition(CXCursor);
int clang_Cursor_isAnonymous(CXCursor);
int clang_Cursor_getNumArguments(CXCursor);
CXCursor clang_Cursor_getArgument(CXCursor, unsigned i);
CXSourceLocation clang_getCursorLocation(CXCursor);
CXSourceRange clang_getCursorExtent(CXCursor);
int clang_Location_isFromMainFile(CXSourceLocation);
void clang_getExpansionLocation(CXSourceLocation location, CXFile *file, unsigned *line, unsigned *column, unsigned *offset);
long long clang_getEnumConstantDeclValue(CXCursor);
CXType clang_getTypedefDeclUnderlyingType(CXCursor);
CXCursor clang_getTypeDeclaration(CXType);

CXString clang_getTypeSpelling(CXType);
CXType clang_getCanonicalType(CXType);
CXType clang_getPointeeType(CXType);
CXType clang_getResultType(CXType);
int clang_getNumArgTypes(CXType);

CXFile clang_getFile(CXTranslationUnit tu, const char *file_name);
const char *clang_getFileContents(CXTranslationUnit tu, CXFile file, size_t *size);
CXSourceLocation clang_getLocationForOffset(CXTranslationUnit tu, CXFile file, unsigned offset);
CXSourceRange clang_getRange(CXSourceLocation begin, CXSourceLocation end);
void clang_tokenize(CXTranslationUnit TU, CXSourceRange Range, CXToken **Tokens, unsigned *NumTokens);
void clang_annotateTokens(CXTranslationUnit TU, CXToken *Tokens, unsigned NumTokens, CXCursor *Cursors);
void clang_disposeTokens(CXTranslationUnit TU, CXToken *Tokens, unsigned NumTokens);

const char *clang_getCString(CXString string);
void clang_disposeString(CXString string);

typedef struct DIR DIR;
struct dirent {
    unsigned long  d_ino;
    unsigned long  d_off;
    unsigned short d_reclen;
    unsigned char  d_type;
    char           d_name[256];
};
DIR *opendir(const char *name);
struct dirent *readdir(DIR *dirp);
int closedir(DIR *dirp);
]]

local M = {}

M.ERROR = {
    SUCCESS = 0,
    INVALID_ARGUMENT = -1,
    STRUCT_CORRUPTED = -2,
    LIBRARY_NOT_FOUND = -50,
    LIBRARY_NOT_LOADED = -52,
}

M.MAGIC_UNINITIALIZED = 0x00000000
M.MAGIC_ALIVE = 0xC1A2C3A4
M.MAGIC_DEAD = 0xDEADC1A2

M.KIND = {
    StructDecl = 2,
    UnionDecl = 3,
    EnumDecl = 5,
    FieldDecl = 6,
    EnumConstantDecl = 7,
    FunctionDecl = 8,
    ParmDecl = 10,
    TypedefDecl = 20,
    MacroDefinition = 501,
}

M.TYPE = {
    Pointer = 101,
    Record = 105,
    Enum = 106,
    FunctionNoProto = 110,
    FunctionProto = 111,
}

-- Detailed preprocessing (macros) + incomplete + skip function bodies.
-- Single-file parse is not used: it dropped every declaration.
local PARSE_OPTIONS = 0x01 + 0x02 + 0x40

local function magic_to_string(magic)
    if magic == M.MAGIC_UNINITIALIZED then
        return "CLANG_UNINITIALIZED"
    end
    if magic == M.MAGIC_ALIVE then
        return "CLANG_ALIVE"
    end
    if magic == M.MAGIC_DEAD then
        return "CLANG_DEAD"
    end
    return string.format("Unknown (0x%08X)", magic)
end

local function check_magic(context)
    if context == nil then
        log.error("Aborting function: context is NULL.")
        return false
    end

    if context.magic == M.MAGIC_ALIVE then
        return true
    end

    local reason = "memory corruption or wrong context passed"
    if context.magic == M.MAGIC_UNINITIALIZED then
        reason = "context was never initialized"
    elseif context.magic == M.MAGIC_DEAD then
        reason = "context was explicitly destroyed"
    end

    log.error("Clang context integrity check failed (expected 0x%08X %s, got 0x%08X %s) because %s",
        M.MAGIC_ALIVE, magic_to_string(M.MAGIC_ALIVE), context.magic, magic_to_string(context.magic), reason)
    context.status = M.ERROR.STRUCT_CORRUPTED
    return false
end

local function library_of(context)
    if not check_magic(context) then
        return nil
    end
    if context.library == nil then
        log.error("Aborting function: libclang not loaded; call init() first.")
        context.status = M.ERROR.LIBRARY_NOT_LOADED
        return nil
    end
    return context.library
end

local function copy_cursor(src)
    local dst = ffi.new("CXCursor")
    ffi.copy(dst, src, ffi.sizeof("CXCursor"))
    return dst
end

local function cstring(library, cxstring)
    local pointer = library.clang_getCString(cxstring)
    local text = pointer ~= nil and ffi.string(pointer) or ""
    library.clang_disposeString(cxstring)
    return text
end

function M.spelling(context, cursor)
    local library = library_of(context)
    if not library then
        return ""
    end
    return cstring(library, library.clang_getCursorSpelling(cursor))
end

function M.type_spelling(context, cx_type)
    local library = library_of(context)
    if not library then
        return ""
    end
    return cstring(library, library.clang_getTypeSpelling(cx_type))
end

function M.comment(context, cursor)
    local library = library_of(context)
    if not library then
        return nil
    end
    local text = cstring(library, library.clang_Cursor_getRawCommentText(cursor))
    if text == "" then
        return nil
    end
    return text
end

function M.location(context, cursor)
    local library = library_of(context)
    if not library then
        return { line = 1, column = 1, offset = 0 }
    end
    local file = ffi.new("CXFile[1]")
    local line = ffi.new("unsigned[1]")
    local column = ffi.new("unsigned[1]")
    local offset = ffi.new("unsigned[1]")
    library.clang_getExpansionLocation(library.clang_getCursorLocation(cursor), file, line, column, offset)
    return {
        line = tonumber(line[0]),
        column = tonumber(column[0]),
        offset = tonumber(offset[0]),
    }
end

local function scan_directory_for_libraries(directory, prefix, suffix)
    local results = {}
    local d = ffi.C.opendir(directory)
    if d == nil then
        log.trace("Skipping directory '%s' as it does not exist or is not accessible.", directory)
        return results
    end

    local scanned = 0
    while true do
        local ent = ffi.C.readdir(d)
        if ent == nil then
            break
        end
        scanned = scanned + 1
        local name = ffi.string(ent.d_name)
        local matches = name:sub(1, #prefix) == prefix
        if #suffix > 0 then
            matches = matches and name:sub(-#suffix) == suffix
        end
        if matches then
            results[#results + 1] = directory .. "/" .. name
        end
    end
    ffi.C.closedir(d)
    log.debug("Scanned %d entries in '%s', found %d matching candidates.", scanned, directory, #results)
    return results
end

local function get_common_paths()
    local os_name = jit and jit.os or "Unknown"
    log.info("Detecting libclang paths for %s.", os_name)

    local paths = {
        "clang", "libclang", "libclang.so", "libclang.dylib", "libclang.dll",
        "libclang-20", "libclang-19", "libclang-18", "libclang-17", "libclang-16",
        "libclang-15", "libclang-14", "libclang-13",
    }

    if os_name == "Linux" then
        local directories = {
            "/usr/lib", "/usr/lib64", "/usr/local/lib",
            "/usr/lib/x86_64-linux-gnu", "/usr/lib/aarch64-linux-gnu",
        }
        for i = 10, 22 do
            table.insert(directories, string.format("/usr/lib/llvm-%d/lib", i))
            table.insert(directories, string.format("/usr/lib/llvm-%d/lib64", i))
        end
        for _, directory in ipairs(directories) do
            for _, path in ipairs(scan_directory_for_libraries(directory, "libclang.so", "")) do
                table.insert(paths, path)
            end
        end
    elseif os_name == "Windows" then
        table.insert(paths, "C:\\Program Files\\LLVM\\bin\\libclang.dll")
        table.insert(paths, "C:\\Program Files (x86)\\LLVM\\bin\\libclang.dll")
        local years = { "2022", "2019", "2017" }
        local editions = { "Community", "Professional", "Enterprise", "BuildTools" }
        local roots = {
            "C:\\Program Files\\Microsoft Visual Studio",
            "C:\\Program Files (x86)\\Microsoft Visual Studio",
        }
        for _, root in ipairs(roots) do
            for _, year in ipairs(years) do
                for _, edition in ipairs(editions) do
                    local base = root .. "\\" .. year .. "\\" .. edition .. "\\VC\\Tools\\Llvm"
                    table.insert(paths, base .. "\\bin\\libclang.dll")
                    table.insert(paths, base .. "\\x64\\bin\\libclang.dll")
                end
            end
        end
    else
        log.warn("Unrecognized OS '%s', using base library names only.", os_name)
    end

    return paths
end

function M.create_context()
    return {
        library = nil,
        status = M.ERROR.INVALID_ARGUMENT,
        magic = M.MAGIC_UNINITIALIZED,
    }
end

function M.init(context, custom_path)
    if context == nil then
        log.error("Aborting function: context is NULL")
        return false
    end

    if custom_path then
        log.info("Initializing libclang with custom path %s.", custom_path)
    else
        log.info("Initializing libclang with automatic discovery.")
    end

    local paths = custom_path and { custom_path } or get_common_paths()
    local errors = {}

    for attempt, path in ipairs(paths) do
        log.trace("Attempt %d/%d: ffi.load('%s')", attempt, #paths, path)
        local ok, library = pcall(ffi.load, path)
        if ok then
            log.info("Successfully loaded libclang from %s (attempt %d/%d).", path, attempt, #paths)
            context.library = library
            context.status = M.ERROR.SUCCESS
            context.magic = M.MAGIC_ALIVE
            return true
        end
        table.insert(errors, tostring(library))
    end

    log.error("Failed to load libclang after %d attempts.", #paths)
    log.warn("Pass --clang-library <path> to specify your libclang location manually.")
    context.status = M.ERROR.LIBRARY_NOT_FOUND
    return false
end

function M.destroy(context)
    if context == nil then
        return
    end
    if check_magic(context) then
        log.info("Destroying clang context.")
        context.library = nil
        context.status = M.ERROR.SUCCESS
        context.magic = M.MAGIC_DEAD
    end
end

function M.create_index(context)
    local library = library_of(context)
    if not library then
        return nil
    end
    return library.clang_createIndex(1, 0)
end

function M.dispose_index(context, index)
    local library = library_of(context)
    if library and index ~= nil then
        library.clang_disposeIndex(index)
    end
end

function M.parse_translation_unit(context, index, header_path, clang_args)
    local library = library_of(context)
    if not library then
        return nil
    end

    local argc = clang_args and #clang_args or 0
    local argv = nil
    if argc > 0 then
        argv = ffi.new("const char*[?]", argc)
        for i = 1, argc do
            argv[i - 1] = clang_args[i]
        end
    end

    local tu = library.clang_parseTranslationUnit(index, header_path, argv, argc, nil, 0, PARSE_OPTIONS)
    if tu == nil then
        log.error("Aborting function: failed to create parse translation unit %s.", header_path)
    end
    return tu
end

function M.dispose_translation_unit(context, tu)
    local library = library_of(context)
    if library and tu ~= nil then
        library.clang_disposeTranslationUnit(tu)
    end
end

local function file_range(library, tu, header_path)
    local file = library.clang_getFile(tu, header_path)
    if file == nil then
        log.error("Aborting function: clang_getFile failed for %s.", header_path)
        return nil
    end
    local size = ffi.new("size_t[1]")
    if library.clang_getFileContents(tu, file, size) == nil then
        log.error("Aborting function: clang_getFileContents failed for %s.", header_path)
        return nil
    end
    return library.clang_getRange(
        library.clang_getLocationForOffset(tu, file, 0),
        library.clang_getLocationForOffset(tu, file, size[0])
    )
end

-- LuaJIT FFI callbacks cannot take structs by value, so the WIP clang_visitChildren
-- cdef cannot be invoked from Lua. Tokenize + annotate is the same libclang walk
-- without a C callback.
local function cursors_in_range(context, tu, range, kind_set)
    local found = {}
    local library = library_of(context)
    if not library or range == nil then
        return found
    end

    local tokens_ptr = ffi.new("CXToken*[1]")
    local count = ffi.new("unsigned[1]")
    library.clang_tokenize(tu, range, tokens_ptr, count)
    local n = tonumber(count[0])
    if n == 0 or tokens_ptr[0] == nil then
        return found
    end

    local tokens = tokens_ptr[0]
    local walk = n
    if walk > 100000 then
        log.warn("Truncating token walk from %d to 100000.", walk)
        walk = 100000
    end
    local annotated = ffi.new("CXCursor[?]", walk)
    library.clang_annotateTokens(tu, tokens, walk, annotated)

    local seen = {}
    for i = 0, walk - 1 do
        local kind = annotated[i].kind
        if not kind_set or kind_set[kind] then
            local name = M.spelling(context, annotated[i])
            local where = M.location(context, annotated[i])
            local key = kind .. "\0" .. name .. "\0" .. tostring(where.line)
            if not seen[key] then
                seen[key] = true
                found[#found + 1] = copy_cursor(annotated[i])
            end
        end
    end

    library.clang_disposeTokens(tu, tokens, n)
    return found
end

local TOP_LEVEL_KINDS = {
    [M.KIND.StructDecl] = true,
    [M.KIND.UnionDecl] = true,
    [M.KIND.EnumDecl] = true,
    [M.KIND.FunctionDecl] = true,
    [M.KIND.TypedefDecl] = true,
    [M.KIND.MacroDefinition] = true,
}

function M.declarations(context, tu, header_path)
    local library = library_of(context)
    if not library then
        return {}
    end
    return cursors_in_range(context, tu, file_range(library, tu, header_path), TOP_LEVEL_KINDS)
end

function M.fields(context, tu, cursor)
    local library = library_of(context)
    if not library then
        return {}
    end
    return cursors_in_range(context, tu, library.clang_getCursorExtent(cursor), {
        [M.KIND.FieldDecl] = true,
    })
end

function M.enum_constants(context, tu, cursor)
    local library = library_of(context)
    if not library then
        return {}
    end
    return cursors_in_range(context, tu, library.clang_getCursorExtent(cursor), {
        [M.KIND.EnumConstantDecl] = true,
    })
end

function M.parameters(context, tu, cursor)
    local library = library_of(context)
    if not library then
        return {}
    end

    local n = library.clang_Cursor_getNumArguments(cursor)
    if n > 0 then
        local args = {}
        for i = 0, n - 1 do
            local arg = library.clang_Cursor_getArgument(cursor, i)
            args[#args + 1] = {
                name = M.spelling(context, arg),
                type = M.type_spelling(context, library.clang_getCursorType(arg)),
            }
        end
        return args
    end

    local found = cursors_in_range(context, tu, library.clang_getCursorExtent(cursor), {
        [M.KIND.ParmDecl] = true,
    })
    local args = {}
    for _, arg in ipairs(found) do
        args[#args + 1] = {
            name = M.spelling(context, arg),
            type = M.type_spelling(context, library.clang_getCursorType(arg)),
        }
    end
    return args
end

local function directory_has_stdarg(path)
    local file = io.open(path .. "/stdarg.h", "r") or io.open(path .. "\\stdarg.h", "r")
    if file then
        file:close()
        return true
    end
    return false
end

function M.resource_directory(context)
    if context == nil then
        log.error("Aborting function: context is NULL.")
        return nil
    end

    local command = (jit and jit.os == "Windows") and "clang -print-resource-dir 2>nul" or "clang -print-resource-dir 2>/dev/null"
    local pipe = io.popen(command)
    if pipe then
        local line = pipe:read("*l")
        pipe:close()
        if line then
            line = line:gsub("%s+$", "")
            local include_path = line .. "/include"
            if directory_has_stdarg(include_path) then
                log.info("Found clang resource dir: %s", include_path)
                return include_path
            end
        end
    end

    local os_name = jit and jit.os or "Unknown"
    local candidates = {}
    if os_name == "Linux" then
        for ver = 22, 10, -1 do
            candidates[#candidates + 1] = string.format("/usr/lib/clang/%d/include", ver)
            candidates[#candidates + 1] = string.format("/usr/lib/llvm-%d/lib/clang/%d/include", ver, ver)
        end
    elseif os_name == "Windows" then
        candidates[#candidates + 1] = "C:\\Program Files\\LLVM\\lib\\clang"
    end

    for _, path in ipairs(candidates) do
        if directory_has_stdarg(path) then
            log.info("Found clang resource dir: %s", path)
            return path
        end
    end

    log.warn("Could not locate clang resource directory.")
    return nil
end

return M
