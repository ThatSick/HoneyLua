--[[
HoneyLua - Universal Dump

What this does:
- Scans the entire DataModel (game:GetDescendants())
- Collects:
  • RemoteEvent / RemoteFunction
  • BindableEvent / BindableFunction
  • ModuleScript + LocalScript (with source when possible)
  • A flat list of ALL instances with class & path
- Optionally (if available):
  • Uses getgc() to dump *sanitized* runtime Lua tables (primitive key/value samples)

Output:
- Writes a JSON file named:
    HoneyLua_UniversalDump_<placeId>.json
  to your executor's workspace.

Requirements:
- Executor with:
  • writefile
  • HttpService:JSONEncode (built-in)
  • (optional) getgc for memory table dump

Notes:
- This still can't see server-only stuff (server scripts/modules, hidden values).
- GC table dump is size-limited to avoid 100MB JSON files.
]]

local HttpService = game:GetService("HttpService")

if type(writefile) ~= "function" then
    warn("[HoneyLua/Universal Dump] writefile is not available in this environment.")
    return
end

local function safeType(v: any): string
    local ok, t = pcall(function()
        return typeof(v)
    end)
    if ok and t then
        return t
    end
    return type(v)
end

local function getPath(inst: Instance): string
    -- Instance:GetFullName() returns e.g. "ReplicatedStorage.Remotes.BuyItem"
    -- Prefix with "game." to match the style.
    return "game." .. inst:GetFullName()
end

local data = {
    meta = {
        gameId = game.GameId,
        placeId = game.PlaceId,
        jobId = game.JobId,
        timestampUnix = os.time(),
    },

    -- high-level buckets
    remotes = {
        RemoteEvent = {},
        RemoteFunction = {},
    },
    bindables = {
        BindableEvent = {},
        BindableFunction = {},
    },

    scripts = {
        ModuleScript = {},
        LocalScript = {},
    },

    -- plain list of EVERY instance
    instances = {},

    -- optional memory dump (GC tables)
    memory = {
        tables = {}, -- filled only if getgc exists
    },
}

local function push(list: {any}, inst: Instance, extra: table?)
    local entry = {
        name = inst.Name,
        class = inst.ClassName,
        path = getPath(inst),
    }

    if extra then
        for k, v in pairs(extra) do
            entry[k] = v
        end
    end

    list[#list + 1] = entry
end

---------------------------------------------------------------------
-- Pass 1: walk all instances and bucket them
---------------------------------------------------------------------
for _, inst in ipairs(game:GetDescendants()) do
    -- Global instance list
    push(data.instances, inst)

    -- Remotes
    if inst:IsA("RemoteEvent") then
        push(data.remotes.RemoteEvent, inst)

    elseif inst:IsA("RemoteFunction") then
        push(data.remotes.RemoteFunction, inst)

    -- Bindables
    elseif inst:IsA("BindableEvent") then
        push(data.bindables.BindableEvent, inst)

    elseif inst:IsA("BindableFunction") then
        push(data.bindables.BindableFunction, inst)

    -- Scripts with source
    elseif inst:IsA("ModuleScript") then
        local extra = {}

        pcall(function()
            extra.source = inst.Source
        end)

        push(data.scripts.ModuleScript, inst, extra)

    elseif inst:IsA("LocalScript") then
        local extra = {}

        pcall(function()
            extra.source = inst.Source
        end)

        push(data.scripts.LocalScript, inst, extra)
    end
end

---------------------------------------------------------------------
-- Optional: GC-based table dump (runtime Lua tables)
---------------------------------------------------------------------

-- Shallow-sanitized clone: only primitive key/value pairs,
-- converts keys to strings (JSON requirement), limits entries per table.
local function cloneTableShallow(src: table, maxEntries: number): table
    local out = {}
    local count = 0

    for k, v in pairs(src) do
        if count >= maxEntries then
            break
        end

        local tk = safeType(k)
        local tv = safeType(v)

        local keyIsPrimitive = (tk == "string" or tk == "number" or tk == "boolean")
        local valIsPrimitive = (tv == "string" or tv == "number" or tv == "boolean")

        if keyIsPrimitive and valIsPrimitive then
            local keyStr = tostring(k)
            out[keyStr] = v
            count += 1
        end
    end

    return out
end

local okGetgc = (type(getgc) == "function")

if okGetgc then
    local maxTables = 300             -- how many tables to sample
    local maxEntriesPerTable = 64     -- key/value pairs per table
    local tCount = 0

    for _, obj in ipairs(getgc(true)) do
        if type(obj) == "table" then
            tCount += 1
            if tCount > maxTables then
                break
            end

            local entry = {
                id = tostring(obj),
            }

            -- try to safely clone a slice
            local ok, sample = pcall(function()
                return cloneTableShallow(obj, maxEntriesPerTable)
            end)

            if ok and sample then
                entry.sample = sample
            end

            table.insert(data.memory.tables, entry)
        end
    end
else
    data.memory.info = "getgc not available in this environment."
end

---------------------------------------------------------------------
-- Sorting helpers (by path)
---------------------------------------------------------------------
local function sortByPath(a, b)
    return (a.path or "") < (b.path or "")
end

table.sort(data.instances, sortByPath)
table.sort(data.remotes.RemoteEvent, sortByPath)
table.sort(data.remotes.RemoteFunction, sortByPath)
table.sort(data.bindables.BindableEvent, sortByPath)
table.sort(data.bindables.BindableFunction, sortByPath)
table.sort(data.scripts.ModuleScript, sortByPath)
table.sort(data.scripts.LocalScript, sortByPath)

---------------------------------------------------------------------
-- Write JSON
---------------------------------------------------------------------
local fileName = string.format("HoneyLua_UniversalDump_%d.json", game.PlaceId)

local success, jsonOrErr = pcall(function()
    return HttpService:JSONEncode(data)
end)

if not success then
    warn("[HoneyLua/Universal Dump] JSONEncode failed:", jsonOrErr)
    return
end

writefile(fileName, jsonOrErr)

print(string.format(
    "[HoneyLua/Universal Dump] Wrote %s | Instances=%d | RemoteEvents=%d | RemoteFunctions=%d | BindableEvents=%d | BindableFunctions=%d | ModuleScripts=%d | LocalScripts=%d | GCTables=%d",
    fileName,
    #data.instances,
    #data.remotes.RemoteEvent,
    #data.remotes.RemoteFunction,
    #data.bindables.BindableEvent,
    #data.bindables.BindableFunction,
    #data.scripts.ModuleScript,
    #data.scripts.LocalScript,
    #(data.memory.tables or {})
))
