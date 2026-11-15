--[[
	Leaderboards - 3 placares globais na praça central (OrderedDataStore):
	tempo jogado, dinheiro gerado no total e Robux gastos.
	Placas em workspace.Map.Leaderboards (TimePlayed / MoneyEarned / RobuxSpent).
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Format)

local Leaderboards = {}
local UPDATE_INTERVAL = 60
local SCALE = 1e15

local function commas(n)
	local s = tostring(math.floor(n))
	local r = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (r:gsub("^,", ""))
end

local function duration(sec)
	sec = math.floor(sec)
	local d = math.floor(sec / 86400)
	local h = math.floor(sec % 86400 / 3600)
	local m = math.floor(sec % 3600 / 60)
	if d > 0 then return string.format("%dd %dh", d, h) end
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm", m)
end

local BOARDS = {
	{ Key = "PlayTime", Store = "LB_PlayTime_v1", Board = "TimePlayed",
		Encode = function(v) return math.floor(v) end, Decode = function(s) return s end,
		Show = duration },
	{ Key = "TotalEarned", Store = "LB_TotalEarned_v1", Board = "MoneyEarned",
		-- valores passam de 2^63: guardamos log10 escalado (mantém a ordem)
		Encode = function(v) if v < 1 then return 0 end return math.floor(math.log10(v) * SCALE) end,
		Decode = function(s) if s <= 0 then return 0 end return 10 ^ (s / SCALE) end,
		Show = function(v) return "$" .. Format.Abbreviate(v) end },
	{ Key = "RobuxSpent", Store = "LB_RobuxSpent_v1", Board = "RobuxSpent",
		Encode = function(v) return math.floor(v) end, Decode = function(s) return s end,
		Show = function(v) return "R$ " .. commas(v) end },
}

local names = {}
local function nameOf(userId)
	if names[userId] then return names[userId] end
	local p = Players:GetPlayerByUserId(userId)
	if p then names[userId] = p.DisplayName return names[userId] end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = ok and n or ("Player " .. userId)
	return names[userId]
end

local function render(def, entries)
	local folder = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Leaderboards")
	local model = folder and folder:FindFirstChild(def.Board)
	local list = model and model:FindFirstChild("Board") and model.Board.Gui:FindFirstChild("List", true)
	if not list then return end
	for i = 1, 10 do
		local row = list:FindFirstChild("Row" .. i)
		if row then
			local e = entries[i]
			row.PlayerName.Text = e and e.name or "—"
			row.Value.Text = e and def.Show(e.value) or ""
		end
	end
end

local function localEntries(def, DataService)
	local entries = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(p)
		if profile then table.insert(entries, { name = p.DisplayName, value = profile.Data[def.Key] or 0 }) end
	end
	table.sort(entries, function(a, b) return a.value > b.value end)
	return entries
end

local function update(DataService)
	for _, def in ipairs(BOARDS) do
		local okStore, store = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, def.Store)
		if okStore then
			for _, p in ipairs(Players:GetPlayers()) do
				local profile = DataService.Get(p)
				if profile and profile.CanSave then
					local value = def.Encode(profile.Data[def.Key] or 0)
					if value > 0 then
						pcall(store.SetAsync, store, tostring(p.UserId), value)
					end
				end
			end
		end
		local entries
		if okStore then
			local ok, pages = pcall(store.GetSortedAsync, store, false, 10)
			if ok then
				entries = {}
				for _, item in ipairs(pages:GetCurrentPage()) do
					local uid = tonumber(item.key)
					if uid then table.insert(entries, { name = nameOf(uid), value = def.Decode(item.value) }) end
				end
			end
		end
		render(def, entries or localEntries(def, DataService))
	end
end

function Leaderboards.Init(DataService)
	task.spawn(function()
		task.wait(8)
		while true do
			local ok, err = pcall(update, DataService)
			if not ok then warn("[Leaderboards]", err) end
			task.wait(UPDATE_INTERVAL)
		end
	end)
end

return Leaderboards
