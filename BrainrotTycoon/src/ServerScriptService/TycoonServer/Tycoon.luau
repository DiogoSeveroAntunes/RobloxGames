--[[
	Tycoon - uma instância por terreno.
	Cuida de: botões, construção de itens, minérios, upgraders, cofre,
	buff dos brainrots, auto-coletor, porta laser e placa do dono.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = ReplicatedStorage.Remotes

local Tycoon = {}
Tycoon.__index = Tycoon


local function getPlayerFromHit(hit)
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				return player, model
			end
			return nil
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

function Tycoon.new(index: number, marker: BasePart, template: Model, services)
	local self = setmetatable({}, Tycoon)
	self.Index = index
	self.Services = services
	self.Owner = nil
	self.Profile = nil
	self.Bank = 0
	self.Owned = {}
	self.Droppers = {}
	self.Connections = {}
	self.AutoCollect = false
	self.Locked = false
	self._denyThrottle = {}
	self._laserThrottle = {}
	self._collectDebounce = false
	self._bankDirty = false

	local model = template:Clone()
	model.Name = "Plot" .. index
	model:PivotTo(marker.CFrame)
	model:SetAttribute("PlotIndex", index)
	model:SetAttribute("OwnerId", 0)
	self.Model = model
	self.Pivot = marker.CFrame

	self.Storage = Instance.new("Folder")
	self.Storage.Name = "PlotStorage" .. index
	self.Storage.Parent = ServerStorage
	self.ItemStore = Instance.new("Folder"); self.ItemStore.Name = "Items"; self.ItemStore.Parent = self.Storage
	self.ButtonStore = Instance.new("Folder"); self.ButtonStore.Name = "Buttons"; self.ButtonStore.Parent = self.Storage
	self.LiveItems = model.Items
	self.LiveButtons = model.Buttons

	for _, item in ipairs(self.LiveItems:GetChildren()) do item.Parent = self.ItemStore end
	for _, button in ipairs(self.LiveButtons:GetChildren()) do
		button.Parent = self.ButtonStore
		local pad = button:FindFirstChild("Pad")
		if pad then
			pad.Touched:Connect(function(hit)
				self:_onButtonTouched(button.Name, hit)
			end)
		end
	end

	self.Ores = Instance.new("Folder")
	self.Ores.Name = "Ores"
	self.Ores.Parent = model

	local folder = workspace:FindFirstChild("Tycoons") or Instance.new("Folder")
	folder.Name = "Tycoons"
	folder.Parent = workspace
	model.Parent = folder

	self:_setupBase()
	return self
end

------------------------------------------------------------------------------
-- Base fixa
------------------------------------------------------------------------------
function Tycoon:_setupConveyors(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Conveyor") then
			local flow = d:GetAttribute("Flow") or Vector3.new(-1, 0, 0)
			d.AssemblyLinearVelocity = d.CFrame:VectorToWorldSpace(flow) * Config.ConveyorSpeed
			d.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1.2, 0, 50, 1)
		end
	end
end

function Tycoon:_setupBase()
	local base = self.Model.Base
	self:_setupConveyors(base)

	for _, d in ipairs(base:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Intake") then
			d.Touched:Connect(function(hit) self:_processOre(hit) end)
		end
	end

	-- plataformas de coleta do térreo (as dos outros andares são ligadas no _build)
	for _, d in ipairs(base:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("CollectPad") then
			d.Touched:Connect(function(hit) self:_tryCollect(hit) end)
		end
	end
	self:_refreshBankLabels()

	local gate = base.Gate
	self.Laser = gate.Laser
	self.DoorLight = gate:FindFirstChild("DoorLight")
	self.DoorPrompt = gate:FindFirstChild("DoorPanel") and gate.DoorPanel:FindFirstChild("DoorPrompt")
	self.Laser.Touched:Connect(function(hit) self:_onLaserTouched(hit) end)
	if self.DoorPrompt then
		local lastToggle = 0
		self.DoorPrompt.Triggered:Connect(function(player)
			if player ~= self.Owner or os.clock() - lastToggle < 0.8 then return end
			lastToggle = os.clock()
			self:SetLocked(not self.Locked)
		end)
	end

	self.SpawnPoint = base.SpawnPoint
	self:_updateSign()
	self:_renderBank(true)
end

------------------------------------------------------------------------------
-- Dono
------------------------------------------------------------------------------
function Tycoon:Claim(player: Player, profile)
	self.Owner = player
	self.Profile = profile
	self.Model:SetAttribute("OwnerId", player.UserId)
	self.Bank = profile.Data.Bank or 0
	self.Owned = {}

	for _, item in ipairs(Config.Items) do
		if profile.Data.Owned[item.Id] then
			self:_build(item.Id, false)
		end
	end
	self:BuildPremium(false)
	self:RefreshButtons()
	self:RecalculateIncome()
	self:SetLocked(false, true)
	self:_updateSign()
	self:_renderBank(true)

	self.Running = true
	local runId = {}
	self._runId = runId
	task.spawn(function() self:_loop(runId) end)
end

function Tycoon:_clearItems()
	for _, conn in ipairs(self.Connections) do conn:Disconnect() end
	table.clear(self.Connections)
	for _, item in ipairs(self.LiveItems:GetChildren()) do
		item.Parent = self.ItemStore
	end
	for _, button in ipairs(self.LiveButtons:GetChildren()) do
		button.Parent = self.ButtonStore
	end
	for _, root in ipairs({ self.Model, self.ItemStore }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d.Name == "Empty" and d:IsA("BillboardGui") then d.Enabled = true end
		end
	end
	self.Ores:ClearAllChildren()
	table.clear(self.Droppers)
	self.Owned = {}
	self.AutoCollect = false
	self:_refreshBankLabels()
end

-- Telas do cofre (uma por andar liberado)
function Tycoon:_refreshBankLabels()
	local labels = {}
	for _, d in ipairs(self.Model:GetDescendants()) do
		if d:IsA("TextLabel") and d:GetAttribute("BankLabel") then table.insert(labels, d) end
	end
	self.BankLabels = labels
	self._bankDirty = true
end

-- Liga entradas de minério e plataformas de coleta de um item recém-construído
function Tycoon:_wireItem(item: Instance)
	local hasBank = false
	for _, d in ipairs(item:GetDescendants()) do
		if d:IsA("BasePart") then
			if d:GetAttribute("Intake") then
				table.insert(self.Connections, d.Touched:Connect(function(hit) self:_processOre(hit) end))
			elseif d:GetAttribute("CollectPad") then
				table.insert(self.Connections, d.Touched:Connect(function(hit) self:_tryCollect(hit) end))
			end
		elseif d:IsA("TextLabel") and d:GetAttribute("BankLabel") then
			hasBank = true
		end
	end
	if hasBank then self:_refreshBankLabels() end
end

function Tycoon:Release()
	self.Running = false
	self._runId = nil
	self:_clearItems()
	self.Owner = nil
	self.Profile = nil
	self.Bank = 0
	self.Model:SetAttribute("OwnerId", 0)
	self:SetLocked(false, true)
	self:_updateSign()
	self:_renderBank(true)
end

-- Usado no rebirth: limpa tudo mas mantém o dono
function Tycoon:Reset()
	self:_clearItems()
	self.Bank = 0
	if self.Profile then self.Profile.Data.Bank = 0 end
	self:RefreshButtons()
	self:RecalculateIncome()
	self:_updateSign()
	self:_renderBank(true)
end

function Tycoon:_updateSign()
	local sign = self.Model.Base.Gate.OwnerSign
	local owner = self.Owner
	local image = ""
	if owner then
		local ok, url = pcall(function()
			return Players:GetUserThumbnailAsync(owner.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
		end)
		if ok then image = url end
	end
	for _, gui in ipairs(sign:GetChildren()) do
		if gui:IsA("SurfaceGui") then
			if owner then
				gui.Owner.Text = owner.DisplayName .. "'s Base"
				local rebirths = self.Profile and self.Profile.Data.Rebirths or 0
				gui.Status.Text = rebirths > 0 and ("⭐ " .. rebirths .. " rebirth" .. (rebirths > 1 and "s" or "") .. "  •  x" .. Config.GetMultiplier(rebirths) .. " income") or "brainrot under construction..."
				gui.Avatar.Image = image
			else
				gui.Owner.Text = "Free Base"
				gui.Status.Text = "waiting for an owner"
				gui.Avatar.Image = ""
			end
		end
	end
end

------------------------------------------------------------------------------
-- Botões e construção
------------------------------------------------------------------------------
function Tycoon:_requirementsMet(cfg)
	for _, req in ipairs(cfg.Requires) do
		if not self.Owned[req] then return false end
	end
	return true
end

function Tycoon:RefreshButtons()
	for _, cfg in ipairs(Config.Items) do
		local button = self.LiveButtons:FindFirstChild(cfg.Id) or self.ButtonStore:FindFirstChild(cfg.Id)
		if button then
			local premiumOwned = cfg.Premium and self.Profile and self.Profile.Data.Premium[cfg.Id]
			local visible = self.Owner ~= nil and not self.Owned[cfg.Id] and not premiumOwned and self:_requirementsMet(cfg)
			local target = visible and self.LiveButtons or self.ButtonStore
			if button.Parent ~= target then button.Parent = target end
		end
	end
end

function Tycoon:_build(id: string, animate: boolean)
	local cfg = Config.ItemsById[id]
	local item = self.ItemStore:FindFirstChild(id) or self.LiveItems:FindFirstChild(id)
	if not cfg or not item then
		warn("[Tycoon] Item not found:", id)
		return
	end
	self.Owned[id] = true
	item:SetAttribute("Animate", animate)
	item.Parent = self.LiveItems
	self:_wireItem(item)

	if cfg.Type == "Dropper" then
		local spout
		for _, d in ipairs(item:GetDescendants()) do
			if d:GetAttribute("Spout") then spout = d break end
		end
		self.Droppers[id] = { Spout = spout, Cfg = cfg, Next = os.clock() + (animate and 1.2 or math.random() * cfg.Interval) }
		if not cfg.Premium then self:_setupLevelPrompt(item, cfg) end
	elseif cfg.Type == "Upgrader" then
		for _, d in ipairs(item:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("UpgradeSensor") then
				table.insert(self.Connections, d.Touched:Connect(function(hit)
					self:_upgradeOre(hit, id, cfg.Multiplier)
				end))
			end
		end
	elseif cfg.Type == "Conveyor" then
		self:_setupConveyors(item)
	elseif cfg.Type == "Brainrot" then
		-- o pedestal pode estar no térreo (Base) ou dentro de uma escada/andar
		local ped = self.Model:FindFirstChild("Pedestal_" .. id, true) or self.ItemStore:FindFirstChild("Pedestal_" .. id, true)
		if ped then ped.Anchor.Empty.Enabled = false end
	elseif cfg.Type == "AutoCollector" then
		self.AutoCollect = true
	end

	if animate then
		Remotes.Purchased:FireAllClients(self.Index, id)
	end
end

function Tycoon:_onButtonTouched(id: string, hit: BasePart)
	if not self.Owner or not self.Profile then return end
	local button = self.LiveButtons:FindFirstChild(id)
	if not button then return end
	local player = getPlayerFromHit(hit)
	if player ~= self.Owner then return end
	if self.Owned[id] then return end

	local cfg = Config.ItemsById[id]
	if not self:_requirementsMet(cfg) then return end
	local data = self.Profile.Data
	if (cfg.Rebirth or 0) > (data.Rebirths or 0) then
		local now = os.clock()
		if (self._denyThrottle[id] or 0) < now then
			self._denyThrottle[id] = now + 2
			Remotes.Notify:FireClient(player, "🔒 " .. cfg.Name .. " requires " .. cfg.Rebirth .. " rebirth" .. (cfg.Rebirth > 1 and "s" or "") .. " — rebirth ⭐", "error")
		end
		return
	end
	if cfg.Robux then
		if self.Services.PromptRobux then self.Services.PromptRobux(player, cfg) end
		return
	end
	if data.Cash < cfg.Price then
		local now = os.clock()
		if (self._denyThrottle[id] or 0) < now then
			self._denyThrottle[id] = now + 2
			Remotes.ButtonDenied:FireClient(player, id, cfg.Price - data.Cash)
		end
		return
	end

	-- Compra confirmada
	self.Services.AddCash(player, -cfg.Price)
	data.Owned[id] = true
	button.Parent = self.ButtonStore
	self:_build(id, true)
	self:RefreshButtons()
	self:BuildPremium(true)
	self:RecalculateIncome()

	if cfg.Type == "Brainrot" then
		local rarity = Config.Rarities[cfg.Rarity]
		if rarity.Order >= Config.Rarities["Legendary"].Order then
			Remotes.Announce:FireAllClients(player.DisplayName, id)
		end
	end
end

------------------------------------------------------------------------------
-- Minérios
------------------------------------------------------------------------------
function Tycoon:_spawnOre(dropper)
	if #self.Ores:GetChildren() >= Config.MaxOresPerPlot then return end
	local spout = dropper.Spout
	if not spout or not spout.Parent then return end
	local oreCfg = dropper.Cfg.Ore
	local part = Instance.new("Part")
	part.Name = "Ore"
	-- Sempre bloco na física (não rola, desliza na velocidade da esteira);
	-- bolas ganham uma malha esférica só no visual
	part.Shape = Enum.PartType.Block
	part.Size = Vector3.one * oreCfg.Size
	if oreCfg.Shape == "Ball" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Color = oreCfg.Color
	part.Material = Enum.Material[oreCfg.Material] or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CollisionGroup = "Ores"
	part.CastShadow = false
	part.CustomPhysicalProperties = PhysicalProperties.new(0.6, 1, 0, 50, 1)
	local jitter = Vector3.new((math.random() - 0.5) * 0.6, 0, (math.random() - 0.5) * 0.8)
	part.CFrame = CFrame.new(spout.Position + jitter) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
	part:SetAttribute("OreValue", dropper.Cfg.Value * Config.GetLevelMultiplier(self:GetLevel(dropper.Cfg.Id)))
	part:SetAttribute("Plot", self.Index)
	part:SetAttribute("Upgrades", 0)

	if oreCfg.Trail then
		local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, oreCfg.Size * 0.3, 0); a0.Parent = part
		local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -oreCfg.Size * 0.3, 0); a1.Parent = part
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0; trail.Attachment1 = a1
		trail.Lifetime = 0.25
		trail.LightEmission = 1
		trail.Color = ColorSequence.new(oreCfg.Color)
		trail.Transparency = NumberSequence.new(0.3, 1)
		trail.FaceCamera = true
		trail.Parent = part
	end

	part.Parent = self.Ores
	pcall(function() part:SetNetworkOwner(nil) end)
	Debris:AddItem(part, Config.OreLifetime)
end

function Tycoon:_upgradeOre(hit: BasePart, upgraderId: string, multiplier: number)
	if hit.Parent ~= self.Ores then return end
	local flag = "Up_" .. upgraderId
	if hit:GetAttribute(flag) then return end
	hit:SetAttribute(flag, true)
	hit:SetAttribute("OreValue", (hit:GetAttribute("OreValue") or 0) * multiplier)
	hit:SetAttribute("Upgrades", (hit:GetAttribute("Upgrades") or 0) + 1)
	local cfg = Config.ItemsById[upgraderId]
	local tint = (cfg and cfg.Tint) or Color3.new(1, 1, 1)
	hit:SetAttribute("LastMult", multiplier)
	hit.Color = hit.Color:Lerp(tint, 0.55)
	hit.Material = Enum.Material.Neon
	hit.Size = hit.Size * 1.06
end

function Tycoon:_processOre(hit: BasePart)
	if hit.Parent ~= self.Ores then return end
	if hit:GetAttribute("Processed") then return end
	hit:SetAttribute("Processed", true)
	local value = (hit:GetAttribute("OreValue") or 0) * self:GetMultiplier() * self:GetDropperBuff()
	local pos, color = hit.Position, hit.Color
	hit:Destroy()
	if not self.Owner then return end
	self:AddBank(value)
	Remotes.OreProcessed:FireClient(self.Owner, pos, value, color)
end

------------------------------------------------------------------------------
-- Cofre
------------------------------------------------------------------------------
function Tycoon:GetMultiplier(): number
	local rebirths = self.Profile and self.Profile.Data.Rebirths or 0
	local double = self.Owner and self.Owner:GetAttribute("Pass_DoubleCash") and 2 or 1
	return Config.GetMultiplier(rebirths) * double
end

------------------------------------------------------------------------------
-- Itens VIP (Robux) e níveis dos droppers
------------------------------------------------------------------------------
function Tycoon:BuildPremium(animate: boolean)
	if not self.Profile then return end
	local premium = self.Profile.Data.Premium
	local rebirths = self.Profile.Data.Rebirths or 0
	local changed = false
	for _, cfg in ipairs(Config.Items) do
		if cfg.Premium and premium[cfg.Id] and not self.Owned[cfg.Id] and (cfg.Rebirth or 0) <= rebirths and self:_requirementsMet(cfg) then
			local button = self.LiveButtons:FindFirstChild(cfg.Id)
			if button then button.Parent = self.ButtonStore end
			self:_build(cfg.Id, animate)
			changed = true
		end
	end
	self:RefreshButtons()
	if changed then self:RecalculateIncome() end
end

function Tycoon:GetLevel(id: string): number
	return (self.Profile and self.Profile.Data.Levels[id]) or 1
end

function Tycoon:_updateLevelPrompt(id: string)
	local item = self.LiveItems:FindFirstChild(id)
	local cfg = Config.ItemsById[id]
	if not item or not cfg or not item.PrimaryPart then return end
	local prompt = item.PrimaryPart:FindFirstChild("LevelPrompt")
	local level = self:GetLevel(id)
	local maxLevel = Config.GetMaxLevel(self.Profile and self.Profile.Data.Rebirths or 0)
	if prompt then
		prompt.ObjectText = cfg.Name .. " · Lv." .. level
		if level >= maxLevel then
			prompt.ActionText = "Max level"
		else
			prompt.ActionText = "Upgrade to Lv." .. (level + 1) .. " · " .. Format.Cash(Config.GetLevelCost(cfg, level))
		end
	end
	local panel = item:FindFirstChild("Panel")
	local label = panel and panel:FindFirstChild("PanelGui") and panel.PanelGui:FindFirstChild("Value")
	if label then
		label.Text = Format.Cash(cfg.Value * Config.GetLevelMultiplier(level)) .. " · Lv." .. level
	end
end

function Tycoon:_setupLevelPrompt(item: Model, cfg)
	local body = item.PrimaryPart
	if not body then return end
	if not body:FindFirstChild("LevelPrompt") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "LevelPrompt"
		prompt:SetAttribute("LevelPrompt", true)
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0.2
		prompt.MaxActivationDistance = 18
		prompt.RequiresLineOfSight = false
		prompt.UIOffset = Vector2.new(0, 40)
		prompt.Parent = body
		prompt.Triggered:Connect(function(player) self:UpgradeLevel(player, cfg.Id) end)
	end
	self:_updateLevelPrompt(cfg.Id)
end

function Tycoon:UpgradeLevel(player: Player, id: string)
	if player ~= self.Owner or not self.Profile or not self.Owned[id] then return end
	local cfg = Config.ItemsById[id]
	local data = self.Profile.Data
	local level = self:GetLevel(id)
	local maxLevel = Config.GetMaxLevel(data.Rebirths or 0)
	if level >= maxLevel then
		Remotes.Notify:FireClient(player, "⭐ Max level! Rebirths raise the cap (now: Lv." .. maxLevel .. ")", "info")
		return
	end
	local cost = Config.GetLevelCost(cfg, level)
	if data.Cash < cost then
		Remotes.ButtonDenied:FireClient(player, id, cost - data.Cash)
		return
	end
	self.Services.AddCash(player, -cost)
	data.Levels[id] = level + 1
	self:_updateLevelPrompt(id)
	self:RecalculateIncome()
	local item = self.LiveItems:FindFirstChild(id)
	Remotes.LevelUp:FireClient(player, id, level + 1, item and item:GetPivot().Position)
end

-- 1 + soma dos buffs (%) dos brainrots comprados
function Tycoon:GetDropperBuff(): number
	return 1 + (self.BuffPercent or 0) / 100
end

function Tycoon:AddBank(amount: number)
	self.Bank += amount
	if self.Profile then
		self.Profile.Data.Bank = self.Bank
		self.Profile.Data.TotalEarned += amount
	end
	self._bankDirty = true
end

function Tycoon:_renderBank(force)
	if not force and not self._bankDirty then return end
	self._bankDirty = false
	local text = Format.Cash(math.floor(self.Bank))
	for _, label in ipairs(self.BankLabels or {}) do
		if label.Parent then label.Text = text end
	end
	self.Model:SetAttribute("Bank", math.floor(self.Bank))
end

function Tycoon:Collect(auto: boolean)
	if not self.Owner or not self.Profile then return end
	local amount = math.floor(self.Bank)
	if amount < 1 then return end
	self.Bank -= amount
	self.Profile.Data.Bank = self.Bank
	self.Services.AddCash(self.Owner, amount)
	self:_renderBank(true)
	Remotes.Collected:FireClient(self.Owner, amount, auto == true)
end

function Tycoon:_tryCollect(hit: BasePart)
	if self._collectDebounce then return end
	local player = getPlayerFromHit(hit)
	if not player or player ~= self.Owner then return end
	self._collectDebounce = true
	self:Collect(false)
	task.delay(0.35, function() self._collectDebounce = false end)
end

------------------------------------------------------------------------------
-- Renda
------------------------------------------------------------------------------
function Tycoon:RecalculateIncome()
	local buff, ores = 0, 0
	for id in pairs(self.Owned) do
		local cfg = Config.ItemsById[id]
		if cfg.Type == "Brainrot" then
			buff += cfg.Buff or 0
		elseif cfg.Type == "Dropper" then
			local mult = 1
			for upId in pairs(self.Owned) do
				local up = Config.ItemsById[upId]
				if up.Type == "Upgrader" and up.Belt == cfg.Belt then mult *= up.Multiplier end
			end
			ores += cfg.Value * Config.GetLevelMultiplier(self:GetLevel(id)) / cfg.Interval * mult
		end
	end
	self.BuffPercent = math.min(buff, Config.MaxBrainrotBuff or math.huge)
	buff = self.BuffPercent
	self.EstimatedIncome = ores * self:GetMultiplier() * self:GetDropperBuff()
	if self.Owner then
		self.Owner:SetAttribute("DropperBuff", buff)
		self.Owner:SetAttribute("IncomePerSecond", self.EstimatedIncome)
	end
end

function Tycoon:_loop(runId)
	local lastAuto = os.clock()
	local lastRender = 0
	while self.Running and self._runId == runId do
		local now = os.clock()
		for _, dropper in pairs(self.Droppers) do
			if now >= dropper.Next then
				dropper.Next = now + dropper.Cfg.Interval
				self:_spawnOre(dropper)
			end
		end
		local auto = self.AutoCollect or (self.Owner and self.Owner:GetAttribute("Pass_AutoCollect"))
		if auto and now - lastAuto >= Config.AutoCollectInterval then
			lastAuto = now
			self:Collect(true)
		end
		if now - lastRender >= 0.2 then
			lastRender = now
			self:_renderBank(false)
		end
		task.wait(0.05)
	end
end

------------------------------------------------------------------------------
-- Porta laser
------------------------------------------------------------------------------
function Tycoon:_outward(): Vector3
	return self.Pivot:VectorToWorldSpace(Vector3.new(0, 0, 1))
end

function Tycoon:_isInside(position: Vector3): boolean
	local localPos = self.Pivot:PointToObjectSpace(position)
	return math.abs(localPos.X) < 70 and math.abs(localPos.Z) < 70 and localPos.Y < 110
end

function Tycoon:_eject(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local target = self.Laser.Position + self:_outward() * 7
	character:PivotTo(CFrame.new(Vector3.new(target.X, self.Pivot.Position.Y + 3, target.Z)) * (hrp.CFrame - hrp.Position))
	hrp.AssemblyLinearVelocity = self:_outward() * 30 + Vector3.new(0, 25, 0)
end

function Tycoon:SetLocked(locked: boolean, silent: boolean?)
	self.Locked = locked
	self.Laser:SetAttribute("Locked", locked)
	self.Laser.Transparency = locked and 0.6 or 1
	if self.DoorLight then
		self.DoorLight.Color = locked and Color3.fromRGB(255, 60, 80) or Color3.fromRGB(80, 255, 140)
	end
	if self.DoorPrompt then
		self.DoorPrompt.ActionText = locked and "Unlock base" or "Lock base"
	end
	if locked then
		for _, player in ipairs(Players:GetPlayers()) do
			if player ~= self.Owner and player.Character then
				local hrp = player.Character:FindFirstChild("HumanoidRootPart")
				if hrp and self:_isInside(hrp.Position) then
					self:_eject(player.Character)
					Remotes.Notify:FireClient(player, "🚫 " .. self.Owner.DisplayName .. " locked their base!", "error")
				end
			end
		end
	end
	if not silent and self.Owner then
		Remotes.Notify:FireClient(self.Owner, locked and "🔒 Base locked — only you can enter" or "🔓 Base open to visitors", "info")
	end
end

function Tycoon:_onLaserTouched(hit: BasePart)
	if not self.Locked then return end
	local player, character = getPlayerFromHit(hit)
	if not player or player == self.Owner then return end
	self:_eject(character)
	local now = os.clock()
	if (self._laserThrottle[player] or 0) < now then
		self._laserThrottle[player] = now + 3
		Remotes.Notify:FireClient(player, "🚫 " .. self.Owner.DisplayName .. "'s base is locked!", "error")
	end
end

------------------------------------------------------------------------------
function Tycoon:TeleportOwner()
	local player = self.Owner
	local character = player and player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	character:PivotTo(self.SpawnPoint.CFrame + Vector3.new(0, 2, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
end

return Tycoon
