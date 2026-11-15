--[[
	DataService - salva e carrega o progresso dos jogadores.
	- Tentativas com backoff em caso de falha
	- Se o carregamento falhar, o perfil fica marcado como "não salvável" para
	  nunca sobrescrever dados bons com dados vazios
	- Autosave periódico e salvamento em BindToClose
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local Config = require(game.ReplicatedStorage.Shared.Config)

local DataService = {}
DataService.Profiles = {} -- [player] = { Data = {...}, CanSave = bool }

local store
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore unavailable:", result)
	end
end

local function defaultData()
	return {
		Cash = Config.StartingCash,
		Bank = 0,
		Rebirths = 0,
		Owned = {},
		TotalEarned = 0,
		LastOnline = 0,
		Settings = { Music = true, Guide = true },
		Weapons = {},          -- [id] = true (permanente)
		Skins = {},            -- [id] = true (permanente)
		EquippedSkin = "",
		Premium = {},          -- itens VIP comprados com Robux (permanente)
		TestPasses = {},       -- passes liberados no modo teste do Studio
		Levels = {},           -- nível de cada dropper (zera no rebirth)
		PlayTime = 0,          -- segundos jogados (leaderboard)
		RobuxSpent = 0,        -- Robux gastos no jogo (leaderboard)
		CountedPasses = {},    -- passes já somados em RobuxSpent
		Receipts = {},         -- últimos PurchaseIds processados
		Version = 2,
	}
end

-- Garante que dados antigos ganhem campos novos
local function reconcile(data)
	local template = defaultData()
	for k, v in pairs(template) do
		if data[k] == nil then
			data[k] = v
		elseif type(v) == "table" and type(data[k]) == "table" and k == "Settings" then
			for sk, sv in pairs(v) do
				if data[k][sk] == nil then data[k][sk] = sv end
			end
		end
	end
	data.Rebirths = math.clamp(data.Rebirths or 0, 0, Config.MaxRebirths or 10)
	-- remove itens que não existem mais na Config
	for id in pairs(data.Owned) do
		if not Config.ItemsById[id] then data.Owned[id] = nil end
	end
	return data
end

local function keyFor(player)
	return "Player_" .. player.UserId
end

local function withRetries(fn, attempts)
	attempts = attempts or 4
	local lastErr
	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then return true, result end
		lastErr = result
		task.wait(math.min(2 ^ i, 8))
	end
	return false, lastErr
end

function DataService.Load(player)
	if not store then
		local profile = { Data = defaultData(), CanSave = false, Reason = "DataStore unavailable" }
		DataService.Profiles[player] = profile
		return profile
	end
	local ok, result = withRetries(function()
		return store:GetAsync(keyFor(player))
	end, RunService:IsStudio() and 1 or 4)
	local profile
	if ok then
		profile = { Data = reconcile(type(result) == "table" and result or defaultData()), CanSave = true }
	else
		warn("[DataService] Failed to load", player.Name, result)
		profile = { Data = defaultData(), CanSave = false, Reason = tostring(result) }
	end
	if player.Parent == nil then return nil end
	DataService.Profiles[player] = profile
	return profile
end

function DataService.Get(player)
	return DataService.Profiles[player]
end

function DataService.Save(player)
	local profile = DataService.Profiles[player]
	if not profile or not profile.CanSave or not store then return false end
	profile.Data.LastOnline = os.time()
	-- cópia rasa para não sofrer alterações durante o yield
	local snapshot = table.clone(profile.Data)
	snapshot.Owned = table.clone(profile.Data.Owned)
	snapshot.Settings = table.clone(profile.Data.Settings)
	snapshot.Weapons = table.clone(profile.Data.Weapons)
	snapshot.Skins = table.clone(profile.Data.Skins)
	snapshot.Premium = table.clone(profile.Data.Premium)
	snapshot.TestPasses = table.clone(profile.Data.TestPasses)
	snapshot.Levels = table.clone(profile.Data.Levels)
	snapshot.CountedPasses = table.clone(profile.Data.CountedPasses)
	snapshot.Receipts = table.clone(profile.Data.Receipts)
	local ok, err = withRetries(function()
		store:UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end, 3)
	if not ok then
		warn("[DataService] Failed to save", player.Name, err)
	end
	return ok
end

function DataService.Release(player)
	DataService.Save(player)
	DataService.Profiles[player] = nil
end

function DataService.StartAutosave()
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in pairs(DataService.Profiles) do
				task.spawn(DataService.Save, player)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in pairs(DataService.Profiles) do
			pending += 1
			task.spawn(function()
				DataService.Save(player)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
