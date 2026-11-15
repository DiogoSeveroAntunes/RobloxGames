--[[
	BRAINROT TYCOON - servidor principal
	Liga jogadores ↔ terrenos, dinheiro, leaderstats, rebirth e ganhos offline.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local PhysicsService = game:GetService("PhysicsService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local DataService = require(script.Parent.DataService)
local Tycoon = require(script.Parent.Tycoon)
local Arsenal = require(script.Parent.Arsenal)
local Monetization = require(script.Parent.Monetization)
local Leaderboards = require(script.Parent.Leaderboards)
local Remotes = ReplicatedStorage.Remotes

-- Grupos de colisão: minérios não colidem com jogadores --------------------
pcall(function() PhysicsService:RegisterCollisionGroup("Ores") end)
pcall(function() PhysicsService:RegisterCollisionGroup("Characters") end)
PhysicsService:CollisionGroupSetCollidable("Ores", "Characters", false)

-- Cria os terrenos -----------------------------------------------------------
local template = ServerStorage:WaitForChild("TycoonTemplate")
local tycoons = {}
local playerTycoon = {}

local Services = {}

local function updateStats(player: Player)
	local profile = DataService.Get(player)
	if not profile then return end
	local data = profile.Data
	player:SetAttribute("Cash", data.Cash)
	player:SetAttribute("Rebirths", data.Rebirths)
	player:SetAttribute("Multiplier", Config.GetMultiplier(data.Rebirths))
	local maxed = data.Rebirths >= Config.MaxRebirths
	player:SetAttribute("RebirthMaxed", maxed)
	player:SetAttribute("RebirthCost", maxed and 0 or Config.GetRebirthCost(data.Rebirths))
	player:SetAttribute("MaxLevel", Config.GetMaxLevel(data.Rebirths))
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		ls.Cash.Value = Format.Cash(data.Cash)
		ls.Rebirths.Value = data.Rebirths
	end
end

function Services.AddCash(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then return end
	profile.Data.Cash = math.max(0, profile.Data.Cash + amount)
	updateStats(player)
end

local plotsFolder = workspace:WaitForChild("Plots")
local markers = plotsFolder:GetChildren()
table.sort(markers, function(a, b) return (a:GetAttribute("PlotIndex") or 0) < (b:GetAttribute("PlotIndex") or 0) end)
for _, marker in ipairs(markers) do
	local index = marker:GetAttribute("PlotIndex")
	tycoons[index] = Tycoon.new(index, marker, template, Services)
end

local function findFreeTycoon()
	for _, t in ipairs(tycoons) do
		if not t.Owner then return t end
	end
	return nil
end

-- Personagem -----------------------------------------------------------------
local function setCharacterGroup(character: Model)
	local function apply(part)
		if part:IsA("BasePart") then part.CollisionGroup = "Characters" end
	end
	for _, d in ipairs(character:GetDescendants()) do apply(d) end
	character.DescendantAdded:Connect(apply)
end

local function onCharacterAdded(player: Player, character: Model)
	setCharacterGroup(character)
	if DataService.Get(player) then
		task.spawn(Arsenal.OnCharacter, player, character)
	end
	local hrp = character:WaitForChild("HumanoidRootPart", 10)
	if not hrp then return end
	task.wait(0.1)
	local tycoon = playerTycoon[player]
	if tycoon and tycoon.Owner == player then
		tycoon:TeleportOwner()
	end
	Monetization.ApplyPasses(player)
end

-- Entrada / saída ------------------------------------------------------------
local function makeLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local cash = Instance.new("StringValue"); cash.Name = "Cash"; cash.Value = "$0"; cash.Parent = ls
	local reb = Instance.new("IntValue"); reb.Name = "Rebirths"; reb.Parent = ls
	ls.Parent = player
end

local function onPlayerAdded(player: Player)
	makeLeaderstats(player)
	player.CharacterAdded:Connect(function(character) onCharacterAdded(player, character) end)

	local profile = DataService.Load(player)
	if not profile or not player.Parent then return end
	updateStats(player)

	local tycoon = findFreeTycoon()
	if not tycoon then
		Remotes.Notify:FireClient(player, "All plots are taken 😭", "error")
		return
	end
	playerTycoon[player] = tycoon
	player:SetAttribute("PlotIndex", tycoon.Index)
	tycoon:Claim(player, profile)
	updateStats(player)
	Monetization.LoadPasses(player)

	-- Ganhos offline (parte da renda estimada dos droppers, já com buffs)
	local off = Config.OfflineEarnings
	if off.Enabled and profile.Data.LastOnline > 0 then
		local vip = Monetization.HasPass(player, "OfflineVIP")
		local seconds = math.clamp(os.time() - profile.Data.LastOnline, 0, vip and off.VipMaxSeconds or off.MaxSeconds)
		local rate = (tycoon.EstimatedIncome or 0) * (vip and off.VipRate or off.Rate)
		if seconds >= off.MinSeconds and rate > 0 then
			local amount = math.floor(rate * seconds)
			tycoon:AddBank(amount)
			task.delay(2, function()
				if player.Parent then Remotes.WelcomeBack:FireClient(player, amount, seconds) end
			end)
		end
	end

	Remotes.PlotAssigned:FireClient(player, tycoon.Index)
	if not profile.CanSave then
		task.delay(3, function()
			if player.Parent then
				Remotes.Notify:FireClient(player, "⚠️ Couldn't load your data — progress in this session won't be saved.", "error")
			end
		end)
	end

	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	local tycoon = playerTycoon[player]
	DataService.Release(player)
	if tycoon then
		tycoon:Release()
		playerTycoon[player] = nil
	end
end

Services.Monetization = Monetization
Services.PromptRobux = Monetization.PromptItem
Monetization.Init(DataService, function(p) return playerTycoon[p] end)
Arsenal.Init(DataService, Services)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
DataService.StartAutosave()
Leaderboards.Init(DataService)

-- Tempo jogado (leaderboard)
task.spawn(function()
	while true do
		task.wait(10)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataService.Get(player)
			if profile then profile.Data.PlayTime += 10 end
		end
	end
end)

-- Remotes --------------------------------------------------------------------
local rebirthLock = {}
Remotes.RequestRebirth.OnServerEvent:Connect(function(player)
	if rebirthLock[player] then return end
	local profile = DataService.Get(player)
	local tycoon = playerTycoon[player]
	if not profile or not tycoon then return end
	local data = profile.Data
	if data.Rebirths >= Config.MaxRebirths then
		Remotes.Notify:FireClient(player, "🏆 You're already at max rebirth (" .. Config.MaxRebirths .. ")!", "info")
		return
	end
	local cost = Config.GetRebirthCost(data.Rebirths)
	if data.Cash < cost then
		Remotes.Notify:FireClient(player, "Need " .. Format.Cash(cost - data.Cash) .. " more to rebirth", "error")
		return
	end
	rebirthLock[player] = true
	data.Rebirths += 1
	data.Cash = 0
	data.Bank = 0
	data.Owned = {}
	data.Levels = {}
	tycoon:Reset()
	updateStats(player)
	tycoon:TeleportOwner()
	Remotes.RebirthDone:FireClient(player, data.Rebirths, Config.GetMultiplier(data.Rebirths))
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			Remotes.Notify:FireClient(other, "⭐ " .. player.DisplayName .. " reached rebirth #" .. data.Rebirths .. "!", "rebirth")
		end
	end
	task.spawn(DataService.Save, player)
	task.delay(1, function() rebirthLock[player] = nil end)
end)

local teleportCooldown = {}
Remotes.TeleportHome.OnServerEvent:Connect(function(player)
	local now = os.clock()
	if (teleportCooldown[player] or 0) > now then return end
	teleportCooldown[player] = now + 1
	local tycoon = playerTycoon[player]
	if tycoon then tycoon:TeleportOwner() end
end)

local ALLOWED_SETTINGS = { Music = "boolean", Guide = "boolean" }
Remotes.GetState.OnServerInvoke = function(player, action, key, value)
	local profile = DataService.Get(player)
	if not profile then return nil end
	if action == "SetSetting" then
		if ALLOWED_SETTINGS[key] and typeof(value) == ALLOWED_SETTINGS[key] then
			profile.Data.Settings[key] = value
		end
		return true
	end
	return {
		Settings = profile.Data.Settings,
		PlotIndex = playerTycoon[player] and playerTycoon[player].Index,
		TotalEarned = profile.Data.TotalEarned,
	}
end

Players.PlayerRemoving:Connect(function(player)
	rebirthLock[player] = nil
	teleportCooldown[player] = nil
end)

-- Ferramenta de teste (só existe no Studio): ServerStorage.DebugTycoon:Invoke("cash", 1e6)
if game:GetService("RunService"):IsStudio() then
	local debugFn = Instance.new("BindableFunction")
	debugFn.Name = "DebugTycoon"
	debugFn.OnInvoke = function(action, value)
		local player = Players:GetPlayers()[1]
		if not player then return "no player" end
		if action == "cash" then
			Services.AddCash(player, value or 1e6)
		elseif action == "bank" then
			local t = playerTycoon[player]
			if t then t:AddBank(value or 1000) end
		elseif action == "rebirths" then
			local profile = DataService.Get(player)
			profile.Data.Rebirths = math.clamp(value or 1, 0, Config.MaxRebirths)
			updateStats(player)
			local t = playerTycoon[player]
			if t then t:RefreshButtons(); t:RecalculateIncome(); t:_updateSign() end
		end
		local profile = DataService.Get(player)
		return profile and profile.Data.Cash
	end
	debugFn.Parent = ServerStorage
end
