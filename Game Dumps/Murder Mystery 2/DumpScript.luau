--[[
HoneyLua - Murder Mystery 2 Dump Script

What this does:
- Scans the entire DataModel (game:GetDescendants())
- Collects:
  • RemoteEvent / RemoteFunction
  • BindableEvent / BindableFunction
  • ModuleScript
- Writes a JSON file named "HoneyLua_MM2_Dump.json" to your executor's workspace

How to use:
1) Join Murder Mystery 2 in Roblox.
2) Execute this script with an executor that supports:
   - writefile
   - HttpService:JSONEncode (HttpService is available client-side; JSONEncode does not require HTTP enabled)
3) After it runs, open the generated file "HoneyLua_MM2_Dump.json" in your executor's workspace folder.

Notes:
- Paths are stored like: "game.ReplicatedStorage.Remotes.BuyItem"
- Some instances may be created later at runtime; re-run after loading in if you need a fresh dump.
]]

local HttpService = game:GetService("HttpService")

-- Basic environment checks (won't hard-crash if missing, but will warn and stop writing).
if type(writefile) ~= "function" then
	warn("[HoneyLua/MM2 Dump] writefile is not available in this environment.")
	return
end

local function getPath(inst: Instance): string
	-- Instance:GetFullName() returns e.g. "ReplicatedStorage.Remotes.BuyItem"
	-- Prefix with "game." to match the requested style.
	return "game." .. inst:GetFullName()
end

local data = {
	meta = {
		gameId = game.GameId,
		placeId = game.PlaceId,
		jobId = game.JobId,
		timestampUnix = os.time(),
	},
	remotes = {
		RemoteEvent = {},
		RemoteFunction = {},
	},
	bindables = {
		BindableEvent = {},
		BindableFunction = {},
	},
	modules = {},
}

local function push(list: {any}, inst: Instance)
	list[#list + 1] = {
		name = inst.Name,
		class = inst.ClassName,
		path = getPath(inst),
	}
end

for _, inst in ipairs(game:GetDescendants()) do
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

	-- Modules
	elseif inst:IsA("ModuleScript") then
		push(data.modules, inst)
	end
end

-- Optional: sort results by path for stable diffs.
local function sortByPath(a, b)
	return a.path < b.path
end

table.sort(data.remotes.RemoteEvent, sortByPath)
table.sort(data.remotes.RemoteFunction, sortByPath)
table.sort(data.bindables.BindableEvent, sortByPath)
table.sort(data.bindables.BindableFunction, sortByPath)
table.sort(data.modules, sortByPath)

local json = HttpService:JSONEncode(data)
writefile("HoneyLua_MM2_Dump.json", json)

print(string.format(
	"[HoneyLua/MM2 Dump] Wrote HoneyLua_MM2_Dump.json | RemoteEvents=%d RemoteFunctions=%d BindableEvents=%d BindableFunctions=%d Modules=%d",
	#data.remotes.RemoteEvent,
	#data.remotes.RemoteFunction,
	#data.bindables.BindableEvent,
	#data.bindables.BindableFunction,
	#data.modules
))
