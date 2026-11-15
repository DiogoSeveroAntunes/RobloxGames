--[[
	Combat - lado do cliente das armas brainrot: clique -> pede ataque ao servidor,
	animação do golpe, desenha projéteis e impactos, aplica empurrão recebido.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local Combat = {}
local Hud, WorldFx
local hooked = {}
local cooldownUntil = {}
local projectiles = {}

local PROJECTILE_LOOK = {
	Bazuca = { Size = 1.3, Color = Color3.fromRGB(130, 70, 40), Material = Enum.Material.SmoothPlastic },
	Varinha = { Size = 0.8, Color = Color3.fromRGB(255, 240, 150), Material = Enum.Material.Neon },
	Cetro = { Size = 1.3, Color = Color3.fromRGB(235, 45, 40), Material = Enum.Material.SmoothPlastic },
	Pimenta = { Size = 0.7, Color = Color3.fromRGB(255, 50, 30), Material = Enum.Material.Neon },
	Arco = { Size = 0.9, Color = Color3.fromRGB(255, 225, 60), Material = Enum.Material.SmoothPlastic },
}

local function swing(tool, cfg)
	local base = tool:GetAttribute("BaseGrip")
	if not base then
		base = tool.Grip
		tool:SetAttribute("BaseGrip", base)
	end
	if cfg.Kind == "Melee" then
		tool.Grip = base * CFrame.Angles(math.rad(-80), 0, 0)
		task.delay(0.12, function() tool.Grip = base * CFrame.Angles(math.rad(40), 0, 0) end)
		task.delay(0.25, function() tool.Grip = base end)
	else
		tool.Grip = base * CFrame.new(0, 0, 0.5)
		task.delay(0.12, function() tool.Grip = base end)
	end
end

local function hookTool(tool)
	if not tool:IsA("Tool") or hooked[tool] then return end
	local id = tool:GetAttribute("WeaponId")
	local cfg = id and Config.WeaponsById[id]
	if not cfg then return end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local now = os.clock()
		if (cooldownUntil[id] or 0) > now then return end
		cooldownUntil[id] = now + cfg.Cooldown
		Remotes.WeaponAction:FireServer(id, mouse.Hit.Position)
		swing(tool, cfg)
		Hud.Play("Click", 0.25)
	end)
	tool.AncestryChanged:Connect(function()
		if not tool.Parent then hooked[tool] = nil end
	end)
end

local function watch(container)
	for _, c in ipairs(container:GetChildren()) do hookTool(c) end
	container.ChildAdded:Connect(hookTool)
end

local function newPart(look)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	p.Size = Vector3.one * look.Size
	p.Color = look.Color
	p.Material = look.Material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, look.Size * 0.3, 0); a0.Parent = p
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, -look.Size * 0.3, 0); a1.Parent = p
	local trail = Instance.new("Trail"); trail.Attachment0 = a0; trail.Attachment1 = a1; trail.Lifetime = 0.25
	trail.Color = ColorSequence.new(look.Color); trail.LightEmission = 1; trail.Transparency = NumberSequence.new(0.2, 1); trail.FaceCamera = true; trail.Parent = p
	p.Parent = workspace:FindFirstChild("ClientFx") or workspace
	return p
end

function Combat.Init(hud, worldFx)
	Hud, WorldFx = hud, worldFx

	local function onCharacter(character)
		watch(character)
	end
	if player.Character then onCharacter(player.Character) end
	player.CharacterAdded:Connect(onCharacter)
	local backpack = player:WaitForChild("Backpack")
	watch(backpack)
	player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then watch(c) end end)

	Remotes.WeaponFx.OnClientEvent:Connect(function(kind, weaponId, a, b, c, d, e)
		if kind == "Melee" then
			local center, color, radius = a, b, c
			WorldFx.Shockwave(center - Vector3.new(0, 2.5, 0), color, radius * 2)
			WorldFx.Burst(center, color, 18, 14)
		elseif kind == "Projectile" then
			local origin, dir, speed, range = a, b, c, d
			local look = PROJECTILE_LOOK[weaponId] or { Size = 1, Color = e, Material = Enum.Material.Neon }
			local p = newPart(look)
			local entry = { Part = p, Weapon = weaponId, Pos = origin, Dir = dir, Speed = speed, Left = range }
			p.Position = origin
			table.insert(projectiles, entry)
		elseif kind == "Impact" then
			local pos, color, radius = a, b, c
			-- remove o projétil mais próximo desta arma
			local best, bestD
			for i, pr in ipairs(projectiles) do
				if pr.Weapon == weaponId then
					local dd = (pr.Pos - pos).Magnitude
					if not bestD or dd < bestD then best, bestD = i, dd end
				end
			end
			if best then projectiles[best].Part:Destroy(); table.remove(projectiles, best) end
			WorldFx.Burst(pos, color, 30, 16)
			WorldFx.Shockwave(pos, color, (radius or 3) * 2)
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and (hrp.Position - pos).Magnitude < 80 then Hud.Play("Pop", 0.2) end
		end
	end)

	Remotes.Knockback.OnClientEvent:Connect(function(velocity)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		hum:ChangeState(Enum.HumanoidStateType.FallingDown)
		hrp.AssemblyLinearVelocity = velocity
		task.delay(0.6, function()
			if hum.Parent and hum.Health > 0 then hum:ChangeState(Enum.HumanoidStateType.GettingUp) end
		end)
		Hud.Play("Error", 0.3)
	end)

	RunService.RenderStepped:Connect(function(dt)
		for i = #projectiles, 1, -1 do
			local pr = projectiles[i]
			local step = pr.Speed * dt
			pr.Pos += pr.Dir * step
			pr.Left -= step
			if pr.Left <= 0 or not pr.Part.Parent then
				pr.Part:Destroy()
				table.remove(projectiles, i)
			else
				pr.Part.CFrame = CFrame.new(pr.Pos) * CFrame.Angles(os.clock() * 8, os.clock() * 5, 0)
			end
		end
	end)
end

return Combat
