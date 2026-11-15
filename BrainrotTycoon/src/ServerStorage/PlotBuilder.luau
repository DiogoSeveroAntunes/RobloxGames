--[[
	PlotBuilder - gera as peças do terreno a partir da Config (só usado no Studio).
	Coordenadas locais: o centro do chão do térreo é (0,0,0), a entrada fica em +Z.
	Terreno de 140x140, andares em Y = 0, 20, 40, 60 e 80.
]]

local B = require(script.Parent.BuildTools)
-- (no Studio o require fica em cache; um clone temporário "ConfigOverride" garante a versão atual)
local Config = require(script.Parent:FindFirstChild("ConfigOverride") or game.ReplicatedStorage.Shared.Config)
local Format = require(game.ReplicatedStorage.Shared.Format)

local PB = {}
PB.HALF = 70
PB.FloorY = { 0, 20, 40, 60, 80, 100, 120, 140, 160, 180 }
PB.CeilingH = 19
PB.BeltFrom, PB.BeltTo = 56, -50
-- 6 vagas de brainrot por andar: 1-3 na fileira da frente, 4-6 na de trás
PB.PedestalX = { 22, 36, 50, 22, 36, 50 }
PB.PedestalZ = { 14, 14, 14, 28, 28, 28 }

local P, E, Ball, Cyl = B.P, B.E, B.Ball, B.Cyl
local rad = math.rad

local function model(name, parent)
	local m = Instance.new("Model")
	m.Name = name
	if parent then m.Parent = parent end
	return m
end
PB.Model = model

------------------------------------------------------------------------------
-- Esteira + triturador compacto na ponta
------------------------------------------------------------------------------
function PB.Belt(name, Y, z, accent, parent)
	local m = model(name)
	local xFrom, xTo = PB.BeltFrom, PB.BeltTo
	local len = xFrom - xTo
	local cx = (xFrom + xTo) / 2
	local belt = P({Name="Belt", Size=Vector3.new(len, 1, 6), CFrame=CFrame.new(cx, Y + 2.5, z), Color=Color3.fromRGB(45, 40, 60)}, m)
	belt:SetAttribute("Conveyor", true)
	belt:SetAttribute("Flow", Vector3.new(-1, 0, 0))
	local sg = Instance.new("SurfaceGui"); sg.Name = "Stripes"; sg.Face = Enum.NormalId.Top; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 10; sg.LightInfluence = 0.6; sg.Parent = belt
	local fr = Instance.new("Frame"); fr.Name = "Pattern"; fr.BorderSizePixel = 0; fr.BackgroundColor3 = Color3.new(1,1,1); fr.Size = UDim2.fromScale(1.5, 1); fr.Parent = sg
	local kps = {}
	for i = 0, 19 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 19, (i % 2 == 0) and Color3.fromRGB(50, 45, 70) or Color3.fromRGB(95, 85, 125)))
	end
	local grad = Instance.new("UIGradient"); grad.Name = "Flow"; grad.Color = ColorSequence.new(kps); grad.Parent = fr
	for _, s in ipairs({-1, 1}) do
		P({Name="Rail", Size=Vector3.new(len, 1.4, 0.6), CFrame=CFrame.new(cx, Y + 3.6, z + s * 3.3), Color=Color3.fromRGB(235, 235, 245), Material=Enum.Material.Metal}, m)
		P({Name="RailNeon", Size=Vector3.new(len, 0.25, 0.65), CFrame=CFrame.new(cx, Y + 4.2, z + s * 3.3), Color=accent, Material=Enum.Material.Neon, CastShadow=false}, m)
	end
	for x = xTo + 3, xFrom - 1, 10 do
		for _, s in ipairs({-1, 1}) do
			P({Name="Leg", Size=Vector3.new(1, 2, 1), CFrame=CFrame.new(x, Y + 1, z + s * 2.4), Color=Color3.fromRGB(120, 110, 140), Material=Enum.Material.Metal}, m)
		end
	end
	P({Name="EndCap", Size=Vector3.new(0.8, 2.2, 7.2), CFrame=CFrame.new(xFrom + 0.4, Y + 3.6, z), Color=Color3.fromRGB(235, 235, 245), Material=Enum.Material.Metal}, m)

	-- Triturador (recebe os minérios)
	local body = P({Name="Shredder", Size=Vector3.new(9, 9, 10), CFrame=CFrame.new(-55, Y + 4.5, z), Color=Color3.fromRGB(150, 90, 230)}, m)
	P({Name="ShredderTop", Size=Vector3.new(9.6, 0.8, 10.6), CFrame=CFrame.new(-55, Y + 9.2, z), Color=Color3.fromRGB(255, 255, 255)}, m)
	P({Name="ShredderBase", Size=Vector3.new(9.8, 1, 10.8), CFrame=CFrame.new(-55, Y + 0.5, z), Color=Color3.fromRGB(90, 50, 160)}, m)
	P({Name="Mouth", Size=Vector3.new(0.3, 4.6, 7), CFrame=CFrame.new(-50.4, Y + 4.4, z), Color=Color3.fromRGB(15, 10, 25)}, m)
	P({Name="MouthGlow", Size=Vector3.new(0.35, 0.5, 7.6), CFrame=CFrame.new(-50.35, Y + 7, z), Color=accent, Material=Enum.Material.Neon, CastShadow=false}, m)
	for i = 0, 2 do
		P({Name="Stripe", Size=Vector3.new(9.1, 0.35, 0.3), CFrame=CFrame.new(-55, Y + 2 + i * 1.6, z + 5.05), Color=accent, Material=Enum.Material.Neon, CastShadow=false}, m)
		P({Name="Stripe", Size=Vector3.new(9.1, 0.35, 0.3), CFrame=CFrame.new(-55, Y + 2 + i * 1.6, z - 5.05), Color=accent, Material=Enum.Material.Neon, CastShadow=false}, m)
	end
	for _, s in ipairs({-1, 1}) do
		local gear = Cyl("Gear", 0.6, 3, CFrame.new(-55, Y + 9.9, z + s * 2.4) * CFrame.Angles(0, 0, rad(90)), accent, m)
		gear:SetAttribute("Spin", true)
	end
	local sensor = P({Name="Intake", Size=Vector3.new(3, 5, 6), CFrame=CFrame.new(-51.6, Y + 4.5, z), Transparency=1, CanCollide=false}, m)
	sensor:SetAttribute("Intake", true)
	-- cano que leva o dinheiro para o cofre (visual)
	local top = (Y == PB.FloorY[#PB.FloorY]) and (Y + 14) or (Y + PB.CeilingH)
	local ph = top - (Y + 9.6)
	Cyl("Pipe", ph, 2, CFrame.new(-58, Y + 9.6 + ph / 2, z), Color3.fromRGB(235, 235, 245), m, Enum.Material.Metal)
	Cyl("PipeNeon", ph, 2.1, CFrame.new(-58, Y + 9.6 + ph / 2, z), accent, m, Enum.Material.Neon).Transparency = 0.7
	m.PrimaryPart = belt
	m.Parent = parent
	return m
end

------------------------------------------------------------------------------
-- Dropper
------------------------------------------------------------------------------
function PB.Dropper(cfg, parent)
	local beltCfg = Config.Belts[cfg.Belt]
	local Y = PB.FloorY[beltCfg.Floor]
	local x = (cfg.Slot == "VIP") and Config.VipSlotX.Dropper or Config.DropperSlotsX[cfg.Slot]
	local bz = beltCfg.Z
	local col = cfg.Ore.Color
	local m = model(cfg.Id)
	local dz = bz - 7
	local body = P({Name="Body", Size=Vector3.new(5, 8, 5), CFrame=CFrame.new(x, Y + 4, dz), Color=Color3.fromRGB(245, 240, 255)}, m)
	P({Name="Band", Size=Vector3.new(5.2, 1.2, 5.2), CFrame=CFrame.new(x, Y + 6.5, dz), Color=col}, m)
	P({Name="BandNeon", Size=Vector3.new(5.3, 0.3, 5.3), CFrame=CFrame.new(x, Y + 1.2, dz), Color=col, Material=Enum.Material.Neon, CastShadow=false}, m)
	P({Name="Arm", Size=Vector3.new(3, 2, 8), CFrame=CFrame.new(x, Y + 9, bz - 3.5), Color=Color3.fromRGB(245, 240, 255)}, m)
	P({Name="ArmStripe", Size=Vector3.new(3.1, 0.4, 8.1), CFrame=CFrame.new(x, Y + 9.4, bz - 3.5), Color=col}, m)
	Cyl("Nozzle", 1.6, 2.6, CFrame.new(x, Y + 7.6, bz), Color3.fromRGB(70, 60, 90), m, Enum.Material.Metal)
	local ng = Cyl("NozzleGlow", 0.3, 2.7, CFrame.new(x, Y + 6.85, bz), col, m, Enum.Material.Neon); ng.CastShadow = false
	local spout = P({Name="Spout", Size=Vector3.new(1, 1, 1), CFrame=CFrame.new(x, Y + 5.8, bz), Transparency=1, CanCollide=false, CanQuery=false, CanTouch=false}, m)
	spout:SetAttribute("Spout", true)
	local hop = Cyl("Hopper", 3.4, 4.4, CFrame.new(x, Y + 9.7, dz), Color3.fromRGB(200, 240, 255), m, Enum.Material.Glass)
	hop.Transparency = 0.5; hop.CastShadow = false
	Cyl("HopperLid", 0.6, 4.8, CFrame.new(x, Y + 11.7, dz), col, m)
	local rng = Random.new(#cfg.Id + x)
	for i = 1, 6 do
		local s = cfg.Ore.Size * 0.75
		P({Name="Stock", Shape=(cfg.Ore.Shape == "Ball") and Enum.PartType.Ball or Enum.PartType.Block, Size=Vector3.new(s, s, s), CFrame=CFrame.new(x + rng:NextNumber(-1, 1), Y + 8.6 + rng:NextNumber(0, 1.6), dz + rng:NextNumber(-1, 1)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Color=col, Material=Enum.Material[cfg.Ore.Material], CanCollide=false, CastShadow=false}, m)
	end
	local panel = P({Name="Panel", Size=Vector3.new(4, 3, 0.2), CFrame=CFrame.new(x, Y + 4, dz + 2.6), Color=Color3.fromRGB(30, 20, 45)}, m)
	local sg = Instance.new("SurfaceGui"); sg.Name = "PanelGui"; sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.LightInfluence = 0; sg.Parent = panel
	local ic = Instance.new("TextLabel"); ic.BackgroundTransparency = 1; ic.Size = UDim2.fromScale(1, 0.62); ic.Text = cfg.Icon; ic.TextScaled = true; ic.Font = Enum.Font.FredokaOne; ic.Parent = sg
	local vl = Instance.new("TextLabel"); vl.Name = "Value"; vl.BackgroundTransparency = 1; vl.Position = UDim2.fromScale(0, 0.6); vl.Size = UDim2.fromScale(1, 0.36); vl.Text = "$" .. Format.Abbreviate(cfg.Value) .. "/un"; vl.TextScaled = true; vl.Font = Enum.Font.FredokaOne; vl.TextColor3 = Color3.fromRGB(120, 255, 140); vl.Parent = sg
	local gear = Cyl("Gear", 3, 3, CFrame.new(x - 2.7, Y + 5, dz) * CFrame.Angles(0, 0, rad(-90)), col, m)
	gear.Size = Vector3.new(0.6, 3, 3); gear.CFrame = CFrame.new(x - 2.7, Y + 5, dz)
	gear:SetAttribute("Spin", true)
	m.PrimaryPart = body
	m.Parent = parent
	return m
end

------------------------------------------------------------------------------
-- Multiplicador (upgrader)
------------------------------------------------------------------------------
function PB.Upgrader(cfg, parent)
	local beltCfg = Config.Belts[cfg.Belt]
	local Y = PB.FloorY[beltCfg.Floor]
	local x = (cfg.Slot == "VIP") and Config.VipSlotX.Upgrader or Config.UpgraderSlotsX[cfg.Slot]
	local bz = beltCfg.Z
	local c1 = cfg.Tint or Color3.fromRGB(255, 225, 60)
	local c2 = c1:Lerp(Color3.new(1, 1, 1), 0.45)
	local m = model(cfg.Id)
	local frame = Color3.fromRGB(40, 30, 60)
	for _, s in ipairs({-1, 1}) do
		P({Name="Pillar", Size=Vector3.new(3, 11, 2), CFrame=CFrame.new(x, Y + 5.5, bz + s * 4.6), Color=frame, Material=Enum.Material.Metal}, m)
		for _, d in ipairs({-1.4, 1.4}) do
			P({Name="PillarNeon", Size=Vector3.new(0.4, 9, 2.1), CFrame=CFrame.new(x + d, Y + 5.5, bz + s * 4.6), Color=c1, Material=Enum.Material.Neon, CastShadow=false}, m)
		end
	end
	local top = P({Name="Top", Size=Vector3.new(4, 2.4, 11.2), CFrame=CFrame.new(x, Y + 12, bz), Color=frame, Material=Enum.Material.Metal}, m)
	P({Name="TopStripe", Size=Vector3.new(4.1, 0.5, 11.3), CFrame=CFrame.new(x, Y + 12.5, bz), Color=c2, Material=Enum.Material.Neon, CastShadow=false}, m)
	local laser = P({Name="Laser", Size=Vector3.new(0.3, 6, 6.4), CFrame=CFrame.new(x, Y + 6, bz), Color=c1, Material=Enum.Material.Neon, Transparency=0.55, CanCollide=false, CastShadow=false}, m)
	laser:SetAttribute("Upgrader", true)
	local sensor = P({Name="UpgradeSensor", Size=Vector3.new(4, 6, 6.4), CFrame=laser.CFrame, Transparency=1, CanCollide=false, CanQuery=false, CastShadow=false}, m)
	sensor:SetAttribute("UpgradeSensor", true)
	for i = 0, 2 do
		local line = P({Name="ScanLine", Size=Vector3.new(0.35, 0.2, 6.4), CFrame=CFrame.new(x, Y + 4 + i * 2, bz), Color=c2, Material=Enum.Material.Neon, CanCollide=false, CastShadow=false}, m)
		line:SetAttribute("Scan", i)
	end
	local sign = P({Name="Sign", Size=Vector3.new(4.2, 2.4, 0.2), CFrame=CFrame.new(x, Y + 12, bz + 5.7), Color=frame}, m)
	local sg = Instance.new("SurfaceGui"); sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.LightInfluence = 0; sg.Brightness = 1.5; sg.Parent = sign
	local t = Instance.new("TextLabel"); t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.Text = "x" .. cfg.Multiplier; t.TextScaled = true; t.Font = Enum.Font.FredokaOne; t.TextColor3 = c2; t.Parent = sg
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.new(0, 0, 0); st.Parent = t
	local light = Instance.new("PointLight"); light.Color = c1; light.Range = 12; light.Brightness = 1.5; light.Parent = laser
	if cfg.Slot == 2 or cfg.Slot == "VIP" then
		for i, r in ipairs({9, 11}) do
			local ring = Cyl("Ring", 0.25, r, CFrame.new(x, Y + 6, bz) * CFrame.Angles(0, 0, rad(90)), (i == 1) and c1 or c2, m, Enum.Material.Neon)
			ring.Transparency = 0.8; ring.CanCollide = false; ring.CastShadow = false
		end
	end
	local sparks = Instance.new("ParticleEmitter"); sparks.Name = "Zap"; sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sparks.Rate = 6
	sparks.Lifetime = NumberRange.new(0.4, 0.8); sparks.Speed = NumberRange.new(2, 5); sparks.SpreadAngle = Vector2.new(180, 180); sparks.LightEmission = 1
	sparks.Color = ColorSequence.new(c1, c2); sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0)}); sparks.Parent = laser
	m.PrimaryPart = top
	m.Parent = parent
	return m
end

------------------------------------------------------------------------------
-- Pedestal de brainrot
------------------------------------------------------------------------------
function PB.Pedestal(id, parent)
	local cfg = Config.ItemsById[id]
	local rar = Config.Rarities[cfg.Rarity]
	local Y = PB.FloorY[cfg.Floor]
	local x, z = PB.PedestalX[cfg.Slot], PB.PedestalZ[cfg.Slot]
	local m = model("Pedestal_" .. id)
	m:SetAttribute("ItemId", id)
	local stand = Cyl("Stand", 2, 9, CFrame.new(x, Y + 1, z), Color3.fromRGB(250, 248, 255), m)
	Cyl("StandBase", 0.6, 10, CFrame.new(x, Y + 0.3, z), Color3.fromRGB(70, 50, 110), m)
	local ring = Cyl("Ring", 0.3, 9.4, CFrame.new(x, Y + 1.75, z), rar.Color, m, Enum.Material.Neon); ring.Transparency = 0.6; ring.CastShadow = false
	local anchor = P({Name="Anchor", Size=Vector3.new(1, 1, 1), CFrame=CFrame.new(x, Y + 2, z), Transparency=1, CanCollide=false, CanQuery=false, CanTouch=false}, m)
	local holo = Instance.new("BillboardGui"); holo.Name = "Empty"; holo.Size = UDim2.fromScale(5, 5); holo.StudsOffset = Vector3.new(0, 3, 0); holo.MaxDistance = 80; holo.LightInfluence = 0; holo.Parent = anchor
	local q = Instance.new("TextLabel"); q.BackgroundTransparency = 1; q.Size = UDim2.fromScale(1, 1); q.Text = "?"; q.TextScaled = true; q.Font = Enum.Font.FredokaOne; q.TextColor3 = rar.Color; q.TextTransparency = 0.35; q.Parent = holo
	local qs = Instance.new("UIStroke"); qs.Thickness = 3; qs.Transparency = 0.4; qs.Color = Color3.fromRGB(40, 20, 60); qs.Parent = q
	m.PrimaryPart = stand
	m.Parent = parent
	return m, anchor
end

------------------------------------------------------------------------------
-- Botão de compra
------------------------------------------------------------------------------
function PB.Button(cfg, x, y, z, parent)
	local m = model(cfg.Id)
	m:SetAttribute("ItemId", cfg.Id)
	Cyl("Base", 0.4, 6, CFrame.new(x, y + 0.2, z), Color3.fromRGB(40, 30, 60), m).CanTouch = false
	local pad = Cyl("Pad", 0.6, 5, CFrame.new(x, y + 0.4, z), Color3.fromRGB(255, 80, 90), m, Enum.Material.Neon)
	pad:SetAttribute("Button", true)
	local anchor = P({Name="LabelAnchor", Size=Vector3.new(1, 1, 1), CFrame=CFrame.new(x, y + 4.2, z), Transparency=1, CanCollide=false, CanQuery=false, CanTouch=false}, m)
	local bb = Instance.new("BillboardGui"); bb.Name = "Label"; bb.Size = UDim2.fromScale(7.5, 3.6); bb.MaxDistance = 60; bb.LightInfluence = 0; bb.Parent = anchor
	local card = Instance.new("Frame"); card.Name = "Card"; card.Size = UDim2.fromScale(1, 1); card.BackgroundColor3 = Color3.fromRGB(35, 22, 55); card.BackgroundTransparency = 0.15; card.Parent = bb
	Instance.new("UICorner", card).CornerRadius = UDim.new(0.2, 0)
	local stroke = Instance.new("UIStroke"); stroke.Name = "Stroke"; stroke.Thickness = 3; stroke.Color = Color3.fromRGB(255, 80, 90); stroke.Parent = card
	local icon = Instance.new("TextLabel"); icon.Name = "Icon"; icon.BackgroundTransparency = 1; icon.Size = UDim2.fromScale(0.3, 0.9); icon.Position = UDim2.fromScale(0.02, 0.05); icon.Text = cfg.Icon; icon.TextScaled = true; icon.Font = Enum.Font.FredokaOne; icon.Parent = card
	local name = Instance.new("TextLabel"); name.Name = "ItemName"; name.BackgroundTransparency = 1; name.Size = UDim2.fromScale(0.64, 0.46); name.Position = UDim2.fromScale(0.33, 0.08); name.Text = cfg.Name; name.TextScaled = true; name.Font = Enum.Font.FredokaOne; name.TextColor3 = Color3.new(1, 1, 1); name.TextXAlignment = Enum.TextXAlignment.Left; name.Parent = card
	local price = Instance.new("TextLabel"); price.Name = "Price"; price.BackgroundTransparency = 1; price.Size = UDim2.fromScale(0.64, 0.4); price.Position = UDim2.fromScale(0.33, 0.52); price.TextScaled = true; price.Font = Enum.Font.FredokaOne; price.TextXAlignment = Enum.TextXAlignment.Left; price.Parent = card
	if cfg.Robux then
		price.Text = "R$ " .. cfg.Robux
	else
		price.Text = (cfg.Price == 0) and "FREE" or ("$" .. Format.Abbreviate(cfg.Price))
	end
	price.TextColor3 = Color3.fromRGB(255, 80, 90)
	local ps = Instance.new("UIStroke"); ps.Thickness = 2; ps.Color = Color3.fromRGB(20, 10, 30); ps.Parent = price
	local tail = Instance.new("TextLabel"); tail.Name = "Tail"; tail.BackgroundTransparency = 1; tail.Size = UDim2.fromScale(0.2, 0.3); tail.Position = UDim2.fromScale(0.4, 0.97); tail.Text = "▼"; tail.TextScaled = true; tail.Font = Enum.Font.FredokaOne; tail.TextColor3 = Color3.fromRGB(35, 22, 55); tail.TextTransparency = 0.15; tail.Parent = card
	local tagText, tagColor
	if cfg.Robux then
		tagText, tagColor = "💎 ROBUX · PERMANENT", Color3.fromRGB(255, 215, 60)
	elseif cfg.Type == "Brainrot" then
		tagText, tagColor = cfg.Rarity .. " · +" .. cfg.Buff .. "%", Config.Rarities[cfg.Rarity].Color
	elseif cfg.Type == "Floor" then
		tagText, tagColor = "NEW FLOOR", Color3.fromRGB(110, 220, 255)
	elseif cfg.Type == "Upgrader" then
		tagText, tagColor = "x" .. cfg.Multiplier .. " on belt", cfg.Tint
	elseif cfg.Type == "Dropper" then
		tagText, tagColor = "$" .. Format.Abbreviate(cfg.Value) .. " per ore", Color3.fromRGB(120, 255, 140)
	end
	if cfg.Rebirth and cfg.Rebirth > 0 then
		-- cadeado (o cliente mostra quando o jogador ainda não tem rebirths suficientes)
		local lock = Instance.new("TextLabel"); lock.Name = "Lock"; lock.Visible = false; lock.ZIndex = 5
		lock.BackgroundColor3 = Color3.fromRGB(25, 15, 35); lock.BackgroundTransparency = 0.1; lock.Size = UDim2.fromScale(1, 1)
		lock.Text = "🔒 Rebirth " .. cfg.Rebirth; lock.TextScaled = true; lock.Font = Enum.Font.FredokaOne; lock.TextColor3 = Color3.fromRGB(255, 220, 90); lock.Parent = card
		Instance.new("UICorner", lock).CornerRadius = UDim.new(0.2, 0)
		local lp = Instance.new("UIPadding"); lp.PaddingTop = UDim.new(0.18, 0); lp.PaddingBottom = UDim.new(0.18, 0); lp.PaddingLeft = UDim.new(0.06, 0); lp.PaddingRight = UDim.new(0.06, 0); lp.Parent = lock
	end
	if tagText then
		local rl = Instance.new("TextLabel"); rl.Name = "RarityTag"; rl.BackgroundColor3 = tagColor; rl.Size = UDim2.fromScale(0.62, 0.26); rl.Position = UDim2.fromScale(0.36, -0.16); rl.Text = tagText; rl.TextScaled = true; rl.Font = Enum.Font.FredokaOne; rl.TextColor3 = Color3.fromRGB(25, 15, 35); rl.Parent = card
		Instance.new("UICorner", rl).CornerRadius = UDim.new(0.4, 0)
	end
	m.PrimaryPart = pad
	m.Parent = parent
	return m
end

------------------------------------------------------------------------------
-- Parede com faixa de janelas
------------------------------------------------------------------------------
function PB.Wall(parent, x1, z1, x2, z2, y0, h, style)
	local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
	local len = alongX and math.abs(x2 - x1) or math.abs(z2 - z1)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local function seg(name, yA, yB, color, mat, transp, thick)
		local hh = yB - yA
		local size = alongX and Vector3.new(len, hh, thick or 1) or Vector3.new(thick or 1, hh, len)
		return P({Name=name, Size=size, CFrame=CFrame.new(cx, y0 + yA + hh / 2, cz), Color=color, Material=mat or Enum.Material.SmoothPlastic, Transparency=transp or 0, CastShadow=(transp or 0) < 0.3}, parent)
	end
	if style.Parapet then
		seg("Glass", 0, h, style.Glass, Enum.Material.Glass, 0.5, 0.4)
		seg("Cap", h, h + 0.4, style.Trim, nil, 0, 0.9)
		seg("CapNeon", h + 0.4, h + 0.6, style.Neon, Enum.Material.Neon, 0, 0.95)
	else
		seg("WallLow", 0, 4, style.Wall)
		seg("Window", 4, 13, style.Glass, Enum.Material.Glass, 0.55, 0.4)
		seg("WallHigh", 13, h, style.Wall)
		seg("Trim", 3.8, 4.2, style.Trim, nil, 0, 1.1)
		seg("Trim", 12.8, 13.2, style.Trim, nil, 0, 1.1)
		seg("TopNeon", h - 0.5, h - 0.2, style.Neon, Enum.Material.Neon, 0, 1.1)
	end
	local steps = math.max(1, math.floor(len / 14))
	for i = 0, steps do
		local f = i / steps
		P({Name="Pillar", Size=Vector3.new(1.4, h, 1.4), CFrame=CFrame.new(x1 + (x2 - x1) * f, y0 + h / 2, z1 + (z2 - z1) * f), Color=style.Trim}, parent)
	end
end

------------------------------------------------------------------------------
-- Escada (degraus de 1 stud) + corrimão
------------------------------------------------------------------------------
-- sobe a partir de zStart, andando dir (+1/-1) em Z, na coluna x ± 4
function PB.Stairs(parent, x, zStart, dir, y0, rise, colorA, colorB, neon)
	for k = 1, rise do
		local zc = zStart + dir * (2 * k - 1)
		P({Name="Step", Size=Vector3.new(8, k, 2), CFrame=CFrame.new(x, y0 + k / 2, zc), Color=(k % 2 == 0) and colorA or colorB}, parent)
		P({Name="StepNeon", Size=Vector3.new(8.05, 0.15, 0.3), CFrame=CFrame.new(x, y0 + k - 0.05, zc - dir * 0.9), Color=neon, Material=Enum.Material.Neon, CastShadow=false}, parent)
	end
end

function PB.Railing(parent, x1, z1, x2, z2, y, color)
	local alongX = math.abs(x2 - x1) > math.abs(z2 - z1)
	local len = alongX and math.abs(x2 - x1) or math.abs(z2 - z1)
	local cx, cz = (x1 + x2) / 2, (z1 + z2) / 2
	local function size(t, h) return alongX and Vector3.new(len, h, t) or Vector3.new(t, h, len) end
	P({Name="RailBar", Size=size(0.4, 0.4), CFrame=CFrame.new(cx, y + 3.2, cz), Color=color, Material=Enum.Material.Neon, CastShadow=false}, parent)
	P({Name="RailGlass", Size=size(0.2, 3), CFrame=CFrame.new(cx, y + 1.6, cz), Color=Color3.fromRGB(200, 240, 255), Material=Enum.Material.Glass, Transparency=0.6, CastShadow=false}, parent)
	local n = math.max(1, math.floor(len / 4))
	for i = 0, n do
		local f = i / n
		P({Name="RailPost", Size=Vector3.new(0.5, 3.4, 0.5), CFrame=CFrame.new(x1 + (x2 - x1) * f, y + 1.7, z1 + (z2 - z1) * f), Color=Color3.fromRGB(255, 255, 255)}, parent)
	end
end

-- Laje (lista de retângulos {x1, x2, z1, z2}) no topo y
function PB.Slab(parent, rects, y, color)
	local first
	for _, r in ipairs(rects) do
		local p = P({Name="Slab", Size=Vector3.new(r[2] - r[1], 1, r[4] - r[3]), CFrame=CFrame.new((r[1] + r[2]) / 2, y - 0.5, (r[3] + r[4]) / 2), Color=color}, parent)
		first = first or p
	end
	return first
end

function PB.CeilingLights(parent, y)
	for _, x in ipairs({-40, 0, 40}) do
		for _, z in ipairs({-35, 0, 35}) do
			local p = P({Name="CeilingLight", Size=Vector3.new(8, 0.3, 8), CFrame=CFrame.new(x, y - 0.15, z), Color=Color3.fromRGB(255, 245, 252)}, parent)
			local l = Instance.new("PointLight"); l.Range = 34; l.Brightness = 0.7; l.Color = Color3.fromRGB(255, 228, 245); l.Shadows = false; l.Parent = p
		end
	end
end

------------------------------------------------------------------------------
-- Quiosque do cofre (tela + plataforma de coleta) — um por andar
------------------------------------------------------------------------------
function PB.BankKiosk(parent, x, y, z)
	local m = model("BankKiosk")
	P({Name="KioskPost", Size=Vector3.new(2, 7, 2), CFrame=CFrame.new(x, y + 3.5, z - 0.5), Color=Color3.fromRGB(150, 90, 230)}, m)
	P({Name="ScreenFrame", Size=Vector3.new(13, 7.5, 0.6), CFrame=CFrame.new(x, y + 9, z - 0.2), Color=Color3.fromRGB(255, 255, 255)}, m)
	local screen = P({Name="BankScreen", Size=Vector3.new(12, 6.5, 0.4), CFrame=CFrame.new(x, y + 9, z + 0.05), Color=Color3.fromRGB(25, 15, 40)}, m)
	local sg = Instance.new("SurfaceGui"); sg.Name = "BankGui"; sg.Face = Enum.NormalId.Back; sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; sg.PixelsPerStud = 40; sg.LightInfluence = 0; sg.Brightness = 1.5; sg.Parent = screen
	local title = Instance.new("TextLabel"); title.Name = "Title"; title.BackgroundTransparency = 1; title.Size = UDim2.fromScale(1, 0.3); title.Position = UDim2.fromScale(0, 0.05); title.Font = Enum.Font.FredokaOne; title.TextScaled = true; title.Text = "💰 VAULT"; title.TextColor3 = Color3.fromRGB(255, 200, 240); title.Parent = sg
	local amt = Instance.new("TextLabel"); amt.Name = "Amount"; amt.BackgroundTransparency = 1; amt.Size = UDim2.fromScale(0.9, 0.5); amt.Position = UDim2.fromScale(0.05, 0.38); amt.Font = Enum.Font.FredokaOne; amt.TextScaled = true; amt.Text = "$0"; amt.TextColor3 = Color3.fromRGB(120, 255, 140); amt.Parent = sg
	amt:SetAttribute("BankLabel", true)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(10, 60, 20); st.Parent = amt
	local pad = Cyl("CollectPad", 0.6, 11, CFrame.new(x, y + 0.3, z + 9), Color3.fromRGB(80, 220, 120), m)
	pad:SetAttribute("CollectPad", true)
	local ring = Cyl("PadRing", 0.5, 12.4, CFrame.new(x, y + 0.25, z + 9), Color3.fromRGB(160, 255, 180), m, Enum.Material.Neon); ring.CastShadow = false
	local pg = Instance.new("SurfaceGui"); pg.Name = "PadGui"; pg.Face = Enum.NormalId.Right; pg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud; pg.PixelsPerStud = 30; pg.LightInfluence = 0; pg.Parent = pad
	local pl = Instance.new("TextLabel"); pl.Name = "Label"; pl.BackgroundTransparency = 1; pl.AnchorPoint = Vector2.new(0.5, 0.5); pl.Size = UDim2.fromScale(0.75, 0.42); pl.Position = UDim2.fromScale(0.5, 0.5); pl.Rotation = 90; pl.Font = Enum.Font.FredokaOne; pl.TextScaled = true; pl.Text = "COLLECT"; pl.TextColor3 = Color3.new(1, 1, 1); pl.Parent = pg
	local ps = Instance.new("UIStroke"); ps.Thickness = 3; ps.Color = Color3.fromRGB(20, 90, 40); ps.Parent = pl
	m.PrimaryPart = pad
	m.Parent = parent
	return m
end

return PB
