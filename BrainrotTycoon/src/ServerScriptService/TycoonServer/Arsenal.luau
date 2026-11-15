--[[
	Arsenal - armas e skins brainrot (compras permanentes, exigem rebirth mínimo).
	- Loja: RemoteFunction ShopAction (State / Buy / Equip / Unequip)
	- Armas: Tools em ServerStorage.WeaponTools, combate validado no servidor
	- Skins: peças em ServerStorage.SkinModels soldadas no personagem
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = ReplicatedStorage.Remotes

local Arsenal = {}
local DataService, Services

local weaponTools = ServerStorage:WaitForChild("WeaponTools")
local skinModels = ServerStorage:WaitForChild("SkinModels")

------------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------------
local function keys(t)
	local list = {}
	for k, v in pairs(t) do if v then table.insert(list, k) end end
	table.sort(list)
	return list
end

local function syncAttributes(player)
	local profile = DataService.Get(player)
	if not profile then return end
	local d = profile.Data
	player:SetAttribute("OwnedWeapons", table.concat(keys(d.Weapons), ","))
	player:SetAttribute("OwnedSkins", table.concat(keys(d.Skins), ","))
	player:SetAttribute("EquippedSkin", d.EquippedSkin or "")
end

local function toolFor(id)
	for _, t in ipairs(weaponTools:GetChildren()) do
		if t:GetAttribute("WeaponId") == id then return t end
	end
	return nil
end

local function inSafeZone(position)
	return Vector3.new(position.X, 0, position.Z).Magnitude < Config.SafeZoneRadius
end

------------------------------------------------------------------------------
-- Armas no inventário
------------------------------------------------------------------------------
function Arsenal.GiveWeapons(player)
	local profile = DataService.Get(player)
	if not profile then return end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	for _, w in ipairs(Config.Weapons) do
		if profile.Data.Weapons[w.Id] then
			local has = false
			for _, container in ipairs({ backpack, player.Character }) do
				if container then
					for _, t in ipairs(container:GetChildren()) do
						if t:IsA("Tool") and t:GetAttribute("WeaponId") == w.Id then has = true end
					end
				end
			end
			local template = toolFor(w.Id)
			if not has and template then
				template:Clone().Parent = backpack
			end
		end
	end
end

------------------------------------------------------------------------------
-- Skins
------------------------------------------------------------------------------
local BODY = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand", "Torso", "Left Arm", "Right Arm" }
local LEGS = { "LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot", "Left Leg", "Right Leg" }

local function restore(character)
	local old = character:FindFirstChild("BrainrotSkin")
	if old then old:Destroy() end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			local t = d:GetAttribute("OrigTransparency")
			if t ~= nil then d.Transparency = t; d:SetAttribute("OrigTransparency", nil) end
		end
		if d:IsA("BasePart") then
			local c = d:GetAttribute("OrigColor")
			if c ~= nil then d.Color = c; d:SetAttribute("OrigColor", nil) end
		end
	end
end

local function hide(obj)
	if obj:GetAttribute("OrigTransparency") == nil then obj:SetAttribute("OrigTransparency", obj.Transparency) end
	obj.Transparency = 1
end

local function recolor(part, color)
	if not part or not part:IsA("BasePart") then return end
	if part:GetAttribute("OrigColor") == nil then part:SetAttribute("OrigColor", part.Color) end
	part.Color = color
end

function Arsenal.ApplySkin(player)
	local character = player.Character
	local profile = DataService.Get(player)
	if not character or not profile then return end
	restore(character)
	local id = profile.Data.EquippedSkin
	local model = id and id ~= "" and skinModels:FindFirstChild(id)
	if not model then return end

	if model:GetAttribute("HideHead") then
		local head = character:FindFirstChild("Head")
		if head then
			hide(head)
			for _, d in ipairs(head:GetChildren()) do if d:IsA("Decal") then hide(d) end end
		end
		for _, acc in ipairs(character:GetChildren()) do
			if acc:IsA("Accessory") then
				local handle = acc:FindFirstChild("Handle")
				local attachment = handle and handle:FindFirstChildWhichIsA("Attachment")
				if handle and attachment and (attachment.Name:find("Hat") or attachment.Name:find("Hair") or attachment.Name:find("Face")) then
					hide(handle)
				end
			end
		end
	end
	local bodyColor, legColor, headColor = model:GetAttribute("BodyColor"), model:GetAttribute("LegColor"), model:GetAttribute("HeadColor")
	if bodyColor then for _, n in ipairs(BODY) do recolor(character:FindFirstChild(n), bodyColor) end end
	if legColor or bodyColor then for _, n in ipairs(LEGS) do recolor(character:FindFirstChild(n), legColor or bodyColor) end end
	if headColor then recolor(character:FindFirstChild("Head"), headColor) end

	local folder = Instance.new("Folder")
	folder.Name = "BrainrotSkin"
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local target = character:FindFirstChild(p:GetAttribute("AttachTo") or "Head")
				or character:FindFirstChild("Head")
			if target then
				local c = p:Clone()
				c.CFrame = target.CFrame * p.CFrame
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = target
				weld.Part1 = c
				weld.Parent = c
				c.Parent = folder
			end
		end
	end
	folder.Parent = character
end

------------------------------------------------------------------------------
-- Loja
------------------------------------------------------------------------------
local function shopState(player)
	local profile = DataService.Get(player)
	if not profile then return nil end
	return { Weapons = keys(profile.Data.Weapons), Skins = keys(profile.Data.Skins), Equipped = profile.Data.EquippedSkin }
end

local function shopAction(player, kind, action, id)
	local profile = DataService.Get(player)
	if not profile then return { ok = false, msg = "Data still loading" } end
	local data = profile.Data
	if action == "State" then
		return { ok = true, state = shopState(player) }
	end
	if kind == "Pass" then
		if action ~= "Buy" or typeof(id) ~= "string" then return { ok = false, msg = "Invalid action" } end
		return Services.Monetization.PromptPass(player, id)
	end
	if kind == "Cash" then
		if action ~= "Buy" or typeof(id) ~= "string" then return { ok = false, msg = "Invalid action" } end
		return Services.Monetization.PromptCash(player, id)
	end
	local cfg = (kind == "Weapon" and Config.WeaponsById[id]) or (kind == "Skin" and Config.SkinsById[id])
	if not cfg then return { ok = false, msg = "Invalid item" } end
	local ownedTable = (kind == "Weapon") and data.Weapons or data.Skins

	if action == "Buy" then
		if ownedTable[id] then return { ok = false, msg = "You already own this" } end
		if data.Rebirths < cfg.Rebirth then
			return { ok = false, msg = "🔒 Requires " .. cfg.Rebirth .. " rebirth" .. (cfg.Rebirth > 1 and "s" or "") }
		end
		if data.Cash < cfg.Price then
			return { ok = false, msg = "💸 Need " .. Format.Cash(cfg.Price - data.Cash) }
		end
		Services.AddCash(player, -cfg.Price)
		ownedTable[id] = true
		if kind == "Weapon" then
			Arsenal.GiveWeapons(player)
		else
			data.EquippedSkin = id
			Arsenal.ApplySkin(player)
		end
		syncAttributes(player)
		task.spawn(DataService.Save, player)
		return { ok = true, msg = cfg.Icon .. " " .. cfg.Name .. " purchased!", state = shopState(player) }
	elseif action == "Equip" and kind == "Skin" then
		if not ownedTable[id] then return { ok = false, msg = "You don't own this skin" } end
		data.EquippedSkin = id
		Arsenal.ApplySkin(player)
		syncAttributes(player)
		return { ok = true, msg = cfg.Icon .. " Wearing " .. cfg.Name, state = shopState(player) }
	elseif action == "Unequip" and kind == "Skin" then
		data.EquippedSkin = ""
		Arsenal.ApplySkin(player)
		syncAttributes(player)
		return { ok = true, msg = "Skin removed", state = shopState(player) }
	end
	return { ok = false, msg = "Invalid action" }
end

------------------------------------------------------------------------------
-- Combate
------------------------------------------------------------------------------
local cooldowns = {}
local safeWarn = {}

local function characterOfPart(part)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then return p, model end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function damage(attacker, victim, amount, fromPos, knockback)
	if victim == attacker then return end
	local character = victim.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return end
	if inSafeZone(hrp.Position) then return end
	local before = hum.Health
	hum:TakeDamage(amount)
	local dir = (hrp.Position - fromPos)
	dir = Vector3.new(dir.X, 0, dir.Z)
	dir = dir.Magnitude > 0.01 and dir.Unit or Vector3.new(0, 0, 1)
	Remotes.Knockback:FireClient(victim, dir * knockback + Vector3.new(0, knockback * 0.45, 0))
	if before > 0 and hum.Health <= 0 then
		Remotes.Notify:FireClient(attacker, "💥 You knocked out " .. victim.DisplayName .. "!", "success")
		Remotes.Notify:FireClient(victim, "😵 " .. attacker.DisplayName .. " knocked you out!", "error")
	end
end

local function splash(attacker, center, radius, amount, knockback)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= attacker and other.Character then
			local hrp = other.Character:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - center).Magnitude <= radius then
				damage(attacker, other, amount, center, knockback)
			end
		end
	end
end

local function fireProjectile(attacker, cfg, origin, direction)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = { attacker.Character }
	local tycoons = workspace:FindFirstChild("Tycoons")
	if tycoons then
		for _, plot in ipairs(tycoons:GetChildren()) do
			local ores = plot:FindFirstChild("Ores")
			if ores then table.insert(ignore, ores) end
		end
	end
	params.FilterDescendantsInstances = ignore
	Remotes.WeaponFx:FireAllClients("Projectile", cfg.Id, origin, direction, cfg.Speed, cfg.Range, cfg.Color)
	local travelled = 0
	local pos = origin
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		local step = math.min(cfg.Speed * dt, cfg.Range - travelled)
		local result = workspace:Raycast(pos, direction * step, params)
		if result then
			conn:Disconnect()
			local victim = characterOfPart(result.Instance)
			if victim then damage(attacker, victim, cfg.Damage, pos, cfg.Knockback) end
			if cfg.Splash then splash(attacker, result.Position, cfg.Splash, cfg.Damage * 0.6, cfg.Knockback * 0.7) end
			Remotes.WeaponFx:FireAllClients("Impact", cfg.Id, result.Position, cfg.Color, cfg.Splash or 3)
			return
		end
		pos += direction * step
		travelled += step
		if travelled >= cfg.Range then
			conn:Disconnect()
		end
	end)
end

local function onWeaponAction(player, weaponId, aimPos)
	if typeof(weaponId) ~= "string" or typeof(aimPos) ~= "Vector3" then return end
	local cfg = Config.WeaponsById[weaponId]
	local profile = DataService.Get(player)
	if not cfg or not profile or not profile.Data.Weapons[weaponId] then return end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hum or not hrp or hum.Health <= 0 then return end
	local tool = character:FindFirstChildOfClass("Tool")
	if not tool or tool:GetAttribute("WeaponId") ~= weaponId then return end

	local now = os.clock()
	cooldowns[player] = cooldowns[player] or {}
	if (cooldowns[player][weaponId] or 0) > now then return end
	cooldowns[player][weaponId] = now + cfg.Cooldown * 0.85

	if inSafeZone(hrp.Position) then
		if (safeWarn[player] or 0) < now then
			safeWarn[player] = now + 4
			Remotes.Notify:FireClient(player, "🕊️ The central plaza is a safe zone — no attacks here", "info")
		end
		return
	end

	if cfg.Kind == "Melee" then
		local look = hrp.CFrame.LookVector
		local center = hrp.Position + look * (cfg.Range * 0.5)
		local radius = cfg.Splash or (cfg.Range * 0.6)
		Remotes.WeaponFx:FireAllClients("Melee", cfg.Id, center, cfg.Color, radius)
		for _, other in ipairs(Players:GetPlayers()) do
			if other ~= player and other.Character then
				local ohrp = other.Character:FindFirstChild("HumanoidRootPart")
				if ohrp then
					local offset = ohrp.Position - hrp.Position
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local inFront = flat.Magnitude < 2 or flat.Unit:Dot(Vector3.new(look.X, 0, look.Z).Unit) > 0.2
					if (ohrp.Position - center).Magnitude <= radius and inFront and math.abs(offset.Y) < 8 then
						damage(player, other, cfg.Damage, hrp.Position, cfg.Knockback)
					end
				end
			end
		end
	else
		local handle = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle")
		local origin = handle and handle.Position or (hrp.Position + Vector3.new(0, 1.5, 0))
		if (origin - hrp.Position).Magnitude > 10 then origin = hrp.Position + Vector3.new(0, 1.5, 0) end
		local dir = aimPos - origin
		if dir.Magnitude < 0.5 then dir = hrp.CFrame.LookVector end
		fireProjectile(player, cfg, origin, dir.Unit)
	end
end

------------------------------------------------------------------------------
function Arsenal.Init(dataService, services)
	DataService = dataService
	Services = services
	Remotes.ShopAction.OnServerInvoke = function(player, kind, action, id)
		local ok, result = pcall(shopAction, player, kind, action, id)
		if ok then return result end
		warn("[Arsenal] shop error:", result)
		return { ok = false, msg = "Shop error" }
	end
	Remotes.WeaponAction.OnServerEvent:Connect(onWeaponAction)
	Players.PlayerRemoving:Connect(function(p) cooldowns[p] = nil; safeWarn[p] = nil end)
end

-- Chamado quando o perfil carrega e a cada personagem novo
function Arsenal.OnCharacter(player, character)
	syncAttributes(player)
	local t0 = os.clock()
	while not player:HasAppearanceLoaded() and os.clock() - t0 < 6 do task.wait(0.1) end
	task.wait(0.2)
	if player.Character ~= character then return end
	Arsenal.ApplySkin(player)
	Arsenal.GiveWeapons(player)
end

Arsenal.SyncAttributes = syncAttributes
return Arsenal
