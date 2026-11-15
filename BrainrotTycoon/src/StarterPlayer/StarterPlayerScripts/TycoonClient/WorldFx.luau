--[[
	WorldFx - efeitos e animações no mundo 3D (só no cliente):
	- animação de construção dos itens comprados
	- botões coloridos por saldo, pulsando quando dá para comprar
	- brainrots balançando, girando e com efeitos
	- esteiras com faixas em movimento, lasers, lâmpadas, giratórios
	- popups "+$" no processador, explosão de moedas ao coletar
	- seta guia até o próximo objetivo
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local WorldFx = {}
local Hud

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local startedAt = os.clock()

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ClientFx"
fxFolder.Parent = workspace

local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function newFxPart(name)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Parent = fxFolder
	return p
end

local function isMine(plot)
	return plot and plot:GetAttribute("OwnerId") == player.UserId
end

------------------------------------------------------------------------------
-- Registro de coisas animadas
------------------------------------------------------------------------------
local rigs, spinners, patterns, scans, lasers, lamps, blinks, rainbows = {}, {}, {}, {}, {}, {}, {}, {}
local building = {}

local function registerRig(rig: Model)
	if rigs[rig] or not rig.PrimaryPart then return end
	local base = rig.PrimaryPart.CFrame
	local subs = {}
	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("Model") and child:GetAttribute("Spin") and child.PrimaryPart then
			table.insert(subs, { Model = child, Offset = base:ToObjectSpace(child:GetPivot()), Speed = child:GetAttribute("SpinSpeed") or 1.6 })
		end
	end
	rigs[rig] = { Base = base, Phase = math.random() * 10, Subs = subs }
end

local function register(root: Instance)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in ipairs(list) do
		if d:IsA("Model") and d.Name == "Rig" then
			registerRig(d)
		elseif d:GetAttribute("Spin") and not d:FindFirstAncestor("Rig") then
			if d:IsA("Model") and d.PrimaryPart then
				spinners[d] = { Base = d:GetPivot(), Speed = d:GetAttribute("SpinSpeed") or 0.6, Model = true, Phase = math.random() * 6 }
			elseif d:IsA("BasePart") then
				spinners[d] = { Base = d.CFrame, Speed = d:GetAttribute("SpinSpeed") or 3, Model = false, Phase = math.random() * 6 }
			end
		elseif d:IsA("Frame") and d.Name == "Pattern" then
			patterns[d] = true
		elseif d:IsA("BasePart") and d:GetAttribute("Scan") then
			local i = d:GetAttribute("Scan")
			scans[d] = { Center = d.CFrame * CFrame.new(0, (1 - i) * 2, 0), Index = i }
		elseif d:IsA("BasePart") and d:GetAttribute("Upgrader") then
			lasers[d] = true
		elseif d:IsA("BasePart") and d:GetAttribute("Lamp") then
			lamps[d] = { Phase = math.random(), Light = d:FindFirstChildOfClass("PointLight") }
		elseif d:IsA("BasePart") and d:GetAttribute("Blink") then
			blinks[d] = true
		elseif d:IsA("UIGradient") and d.Name == "Rainbow" then
			rainbows[d] = true
		end
	end
end

------------------------------------------------------------------------------
-- Efeitos pontuais
------------------------------------------------------------------------------
local burstPart = newFxPart("Burst")
local burst = Instance.new("ParticleEmitter")
burst.Texture = SPARKLE
burst.Rate = 0
burst.Lifetime = NumberRange.new(0.6, 1.1)
burst.Speed = NumberRange.new(8, 16)
burst.SpreadAngle = Vector2.new(180, 180)
burst.Drag = 4
burst.LightEmission = 1
burst.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 0) })
burst.Parent = burstPart

function WorldFx.Burst(position: Vector3, color: Color3, count: number?, speed: number?)
	burstPart.Position = position
	burst.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	burst.Speed = NumberRange.new((speed or 12) * 0.6, speed or 12)
	burst:Emit(count or 30)
end

function WorldFx.Shockwave(position: Vector3, color: Color3, size: number?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.CastShadow = false
	ring.Size = Vector3.new(0.2, 1, 1)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = fxFolder
	local s = size or 14
	tween(ring, 0.6, { Size = Vector3.new(0.2, s, s), Transparency = 1 })
	Debris:AddItem(ring, 0.7)
end

-- Popups "+$" pooled
local popupPool = {}
local function getPopup()
	local p = table.remove(popupPool)
	if p then return p end
	p = newFxPart("Popup")
	local bb = Instance.new("BillboardGui")
	bb.Name = "BB"
	bb.Size = UDim2.fromScale(5, 1.6)
	bb.LightInfluence = 0
	bb.MaxDistance = 120
	bb.Parent = p
	local l = Instance.new("TextLabel")
	l.Name = "L"
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = Color3.fromRGB(120, 255, 140)
	l.Parent = bb
	local st = Instance.new("UIStroke"); st.Name = "S"; st.Thickness = 2.5; st.Color = Color3.fromRGB(15, 50, 20); st.Parent = l
	return p
end

function WorldFx.Popup(position: Vector3, text: string, color: Color3?, scale: number?)
	local p = getPopup()
	p.Position = position
	local bb = p.BB
	local sc = scale or 1
	bb.Size = UDim2.fromScale(5 * sc, 1.6 * sc)
	bb.L.Text = text
	bb.L.TextColor3 = color or Color3.fromRGB(120, 255, 140)
	bb.L.TextTransparency = 0
	bb.L.S.Transparency = 0
	bb.Enabled = true
	p.Parent = fxFolder
	tween(p, 1, { Position = position + Vector3.new((math.random() - 0.5) * 1.5, 4, (math.random() - 0.5) * 1.5) }, Enum.EasingStyle.Quad)
	task.delay(0.55, function()
		tween(bb.L, 0.4, { TextTransparency = 1 })
		tween(bb.L.S, 0.4, { Transparency = 1 })
	end)
	task.delay(1, function()
		bb.Enabled = false
		if #popupPool < 40 then table.insert(popupPool, p) else p:Destroy() end
	end)
end

------------------------------------------------------------------------------
-- Animação de construção
------------------------------------------------------------------------------
local function animateBuild(model: Model, onDone)
	building[model] = true
	local parts, guis = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, { Part = d, CFrame = d.CFrame, Transparency = d.Transparency })
		elseif d:IsA("BillboardGui") or d:IsA("SurfaceGui") or d:IsA("ParticleEmitter") then
			if d.Enabled then
				table.insert(guis, d)
				d.Enabled = false
			end
		end
	end
	if #parts == 0 then
		building[model] = nil
		if onDone then onDone() end
		return
	end
	table.sort(parts, function(a, b) return a.CFrame.Position.Y < b.CFrame.Position.Y end)
	local far = (camera.CFrame.Position - parts[1].CFrame.Position).Magnitude > 300
	local total = far and 0 or 0.7
	local center = model:GetPivot().Position
	for i, info in ipairs(parts) do
		local p = info.Part
		if not far then
			local dir = (info.CFrame.Position - center)
			dir = Vector3.new(dir.X, 0, dir.Z) * 0.15
			p.CFrame = info.CFrame * CFrame.Angles(math.rad(math.random(-25, 25)), math.rad(math.random(-25, 25)), 0) + Vector3.new(0, 9, 0) + dir
			p.Transparency = 1
			local delay = (i - 1) / #parts * total
			task.delay(delay, function()
				if not p.Parent then return end
				tween(p, 0.45, { CFrame = info.CFrame }, Enum.EasingStyle.Back)
				tween(p, 0.25, { Transparency = info.Transparency })
			end)
		end
	end
	task.delay(total + 0.5, function()
		for _, info in ipairs(parts) do
			if info.Part.Parent then
				info.Part.CFrame = info.CFrame
				info.Part.Transparency = info.Transparency
			end
		end
		for _, g in ipairs(guis) do g.Enabled = true end
		building[model] = nil
		if model.Parent then
			local pos = model:GetPivot().Position
			local color = Color3.fromRGB(255, 120, 220)
			local cfg = Config.ItemsById[model.Name]
			if cfg and cfg.Type == "Brainrot" then
				color = Config.Rarities[cfg.Rarity].Color
			end
			local ground = Vector3.new(pos.X, (parts[1].CFrame.Position.Y), pos.Z)
			WorldFx.Shockwave(ground + Vector3.new(0, 0.3, 0), color, 16)
			WorldFx.Burst(pos + Vector3.new(0, 2, 0), color, 40, 16)
		end
		if onDone then onDone() end
	end)
end

local function onItemAdded(item: Instance, plot: Model)
	if not item:IsA("Model") then return end
	-- espera a subárvore inteira replicar antes de mexer
	local cfg = Config.ItemsById[item.Name]
	if cfg and cfg.Type == "Brainrot" then item:WaitForChild("Rig", 3) end
	task.wait(0.1)
	if not item.Parent then return end
	local shouldAnimate = item:GetAttribute("Animate") and os.clock() - startedAt > 3
	if shouldAnimate then
		animateBuild(item, function() register(item) end)
		if isMine(plot) then
			Hud.Play("Purchase", 0.05)
			task.delay(0.5, function() Hud.Play("Pop", 0.15) end)
		end
	else
		register(item)
	end
end

------------------------------------------------------------------------------
-- Botões
------------------------------------------------------------------------------
local buttons = {} -- [model] = data
local AFFORD = Color3.fromRGB(70, 230, 120)
local EXPENSIVE = Color3.fromRGB(255, 80, 90)
local FREE = Color3.fromRGB(110, 220, 255)

local function onButtonAdded(btn: Instance, plot: Model)
	if not btn:IsA("Model") then return end
	local cfg = Config.ItemsById[btn.Name]
	local pad = btn:WaitForChild("Pad", 3)
	local anchor = btn:WaitForChild("LabelAnchor", 3)
	if not cfg or not pad or not anchor then return end
	local bb = anchor:WaitForChild("Label", 3)
	local card = bb and bb:WaitForChild("Card", 3)
	if not card or not card:WaitForChild("Stroke", 3) or not card:WaitForChild("Price", 3) then return end
	if not btn.Parent then return end
	local data = {
		Model = btn, Plot = plot, Cfg = cfg, Pad = pad, Base = btn:FindFirstChild("Base"),
		BB = bb, Card = bb.Card, BaseSize = bb.Size, PadSize = pad.Size, State = nil, Phase = math.random() * 6,
	}
	buttons[btn] = data
	if isMine(plot) then
		-- aparece com um "boing"
		bb.Size = UDim2.fromScale(0, 0)
		tween(bb, 0.5, { Size = data.BaseSize }, Enum.EasingStyle.Back)
		pad.Size = Vector3.new(pad.Size.X, 0.5, 0.5)
		tween(pad, 0.45, { Size = data.PadSize }, Enum.EasingStyle.Back)
		if os.clock() - startedAt > 3 then
			WorldFx.Burst(pad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 255, 255), 14, 8)
		end
	end
end

local LOCKED = Color3.fromRGB(120, 110, 140)
local function updateButtons(t)
	local cash = player:GetAttribute("Cash") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	for btn, data in pairs(buttons) do
		if not btn.Parent or not btn:IsDescendantOf(workspace) then
			buttons[btn] = nil
		else
			local mine = isMine(data.Plot)
			local state
			if not mine then
				state = "hidden"
			elseif (data.Cfg.Rebirth or 0) > rebirths then
				state = "locked"
			elseif data.Cfg.Robux then
				state = "robux"
			elseif data.Cfg.Price == 0 then
				state = "free"
			elseif cash >= data.Cfg.Price then
				state = "afford"
			else
				state = "expensive"
			end
			if state ~= data.State then
				local old = data.State
				data.State = state
				local hidden = state == "hidden"
				data.BB.Enabled = not hidden
				data.Pad.LocalTransparencyModifier = hidden and 1 or 0
				if data.Base then data.Base.LocalTransparencyModifier = hidden and 1 or 0 end
				local lock = data.Card:FindFirstChild("Lock")
				if lock then lock.Visible = (state == "locked") end
				if not hidden then
					local c = (state == "locked") and LOCKED or (state == "robux") and Color3.fromRGB(255, 205, 50) or ((state == "free") and FREE or (state == "afford" and AFFORD or EXPENSIVE))
					tween(data.Pad, 0.3, { Color = c })
					data.Card.Stroke.Color = c
					data.Card.Price.TextColor3 = c
					if state == "afford" and old == "expensive" then
						local s = data.Card:FindFirstChildOfClass("UIScale") or Instance.new("UIScale", data.Card)
						s.Scale = 1.25
						tween(s, 0.4, { Scale = 1 }, Enum.EasingStyle.Back)
					end
				end
			end
			if state == "afford" or state == "free" or state == "robux" then
				data.BB.StudsOffset = Vector3.new(0, math.sin(t * 4 + data.Phase) * 0.25 + 0.25, 0)
			elseif state == "expensive" or state == "locked" then
				data.BB.StudsOffset = Vector3.zero
			end
		end
	end
end

local function shakeButton(id)
	local plot = Hud.GetMyPlot()
	local btn = plot and plot.Buttons:FindFirstChild(id)
	local data = btn and buttons[btn]
	if not data then return end
	local card = data.Card
	for i = 1, 6 do
		card.Rotation = (i % 2 == 0 and 1 or -1) * (8 - i)
		task.wait(0.04)
	end
	card.Rotation = 0
end

------------------------------------------------------------------------------
-- Seta guia
------------------------------------------------------------------------------
local guideEnabled = true
local guideTarget = newFxPart("GuideTarget")
local guideA1 = Instance.new("Attachment")
guideA1.Axis = Vector3.new(0, 1, 0)
guideA1.SecondaryAxis = Vector3.new(1, 0, 0)
guideA1.Parent = guideTarget
local guideA0 = Instance.new("Attachment")
guideA0.Name = "GuideAttachment"
guideA0.Axis = Vector3.new(0, 1, 0)
guideA0.SecondaryAxis = Vector3.new(1, 0, 0)
local beam = Instance.new("Beam")
beam.Attachment0 = guideA0
beam.Attachment1 = guideA1
beam.FaceCamera = true
beam.Segments = 24
beam.Width0 = 0.5
beam.Width1 = 0.35
beam.CurveSize0 = 5
beam.CurveSize1 = -3
beam.LightEmission = 1
beam.Color = ColorSequence.new(Color3.fromRGB(110, 220, 255), Color3.fromRGB(255, 90, 200))
beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(0.15, 0.3), NumberSequenceKeypoint.new(1, 0.15) })
beam.Enabled = false
beam.Parent = guideTarget
local marker = Instance.new("BillboardGui")
marker.Size = UDim2.fromScale(3, 3)
marker.AlwaysOnTop = true
marker.LightInfluence = 0
marker.Enabled = false
marker.Parent = guideTarget
local markerLabel = Instance.new("TextLabel")
markerLabel.BackgroundTransparency = 1
markerLabel.Size = UDim2.fromScale(1, 1)
markerLabel.Font = Enum.Font.FredokaOne
markerLabel.TextScaled = true
markerLabel.Text = "▼"
markerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
markerLabel.Parent = marker
local ms = Instance.new("UIStroke"); ms.Thickness = 3; ms.Color = Color3.fromRGB(255, 90, 200); ms.Parent = markerLabel

local function updateGuide(t)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local plot = Hud.GetMyPlot()
	if not guideEnabled or not hrp or not plot then
		beam.Enabled = false
		marker.Enabled = false
		return
	end
	if guideA0.Parent ~= hrp then guideA0.Parent = hrp end

	local cash = player:GetAttribute("Cash") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	local bestAfford, cheapest
	for _, b in ipairs(plot.Buttons:GetChildren()) do
		local cfg = Config.ItemsById[b.Name]
		if cfg and not cfg.Robux and b:FindFirstChild("Pad") and (cfg.Rebirth or 0) <= rebirths then
			if cash >= cfg.Price and (not bestAfford or cfg.Price > bestAfford.Price) then
				bestAfford = { Price = cfg.Price, Pos = b.Pad.Position }
			end
			if not cheapest or cfg.Price < cheapest.Price then
				cheapest = { Price = cfg.Price, Pos = b.Pad.Position }
			end
		end
	end
	local targetPos, color
	local bank = plot:GetAttribute("Bank") or 0
	if bestAfford then
		targetPos, color = bestAfford.Pos, Color3.fromRGB(90, 235, 130)
	elseif bank >= 1 and cheapest and (cash + bank) >= cheapest.Price then
		local pad = WorldFx.NearestPad(plot, hrp.Position)
		targetPos, color = pad and pad.Position or cheapest.Pos, Color3.fromRGB(255, 220, 80)
	elseif cheapest then
		targetPos, color = cheapest.Pos, Color3.fromRGB(255, 90, 200)
	end
	if not targetPos or (Vector3.new(targetPos.X, 0, targetPos.Z) - Vector3.new(hrp.Position.X, 0, hrp.Position.Z)).Magnitude < 4 then
		beam.Enabled = false
		marker.Enabled = targetPos ~= nil
		if targetPos then guideTarget.Position = targetPos + Vector3.new(0, 7 + math.sin(t * 5) * 0.6, 0) end
		return
	end
	guideTarget.Position = targetPos + Vector3.new(0, 7 + math.sin(t * 5) * 0.6, 0)
	guideA1.Position = Vector3.new(0, -6 - math.sin(t * 5) * 0.6, 0)
	beam.Enabled = true
	marker.Enabled = true
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), color)
	ms.Color = color
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.95),
		NumberSequenceKeypoint.new(0.2, 0.35 + math.sin(t * 6) * 0.15),
		NumberSequenceKeypoint.new(1, 0.15),
	})
end

function WorldFx.SetGuide(on: boolean)
	guideEnabled = on
end

------------------------------------------------------------------------------
-- Balões de fala dos brainrots
------------------------------------------------------------------------------
local function speak(item: Model, text: string)
	local rig = item:FindFirstChild("Rig")
	local info = item:FindFirstChild("InfoAnchor")
	if not rig or not rig.PrimaryPart or not info then return end
	local old = rig.PrimaryPart:FindFirstChild("Speech")
	if old then old:Destroy() end
	local bb = Instance.new("BillboardGui")
	bb.Name = "Speech"
	bb.Size = UDim2.fromScale(9, 2.6)
	bb.StudsOffsetWorldSpace = Vector3.new(0, (info.Position.Y - rig.PrimaryPart.Position.Y) + 4.6, 0)
	bb.LightInfluence = 0
	bb.MaxDistance = 70
	bb.Parent = rig.PrimaryPart
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.fromScale(0.5, 1)
	frame.Size = UDim2.fromScale(1, 0.8)
	frame.BackgroundColor3 = Color3.new(1, 1, 1)
	frame.Parent = bb
	Instance.new("UICorner", frame).CornerRadius = UDim.new(0.35, 0)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(255, 90, 200); st.Parent = frame
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, -16, 1, -8)
	l.Position = UDim2.fromOffset(8, 4)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = Color3.fromRGB(50, 25, 70)
	l.Parent = frame
	local tail = Instance.new("TextLabel")
	tail.BackgroundTransparency = 1
	tail.AnchorPoint = Vector2.new(0.5, 0)
	tail.Position = UDim2.fromScale(0.5, 0.97)
	tail.Size = UDim2.fromScale(0.15, 0.3)
	tail.Font = Enum.Font.FredokaOne
	tail.TextScaled = true
	tail.Text = "▼"
	tail.TextColor3 = Color3.new(1, 1, 1)
	tail.Parent = frame
	local s = Instance.new("UIScale"); s.Scale = 0; s.Parent = frame
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(3.6, function()
		if not bb.Parent then return end
		tween(s, 0.25, { Scale = 0 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.wait(0.3)
		bb:Destroy()
	end)
end

local function ownedBrainrots(plot)
	local list = {}
	if not plot then return list end
	for _, item in ipairs(plot.Items:GetChildren()) do
		local cfg = Config.ItemsById[item.Name]
		if cfg and cfg.Type == "Brainrot" and not building[item] then
			table.insert(list, { Item = item, Cfg = cfg })
		end
	end
	return list
end

------------------------------------------------------------------------------
-- Terrenos
------------------------------------------------------------------------------
-- Plataformas de coleta (uma por andar liberado), mantidas por terreno
local plotPads = {} -- [plot] = { [pad] = true }

function WorldFx.GetPads(plot)
	local list = {}
	for pad in pairs(plotPads[plot] or {}) do
		if pad.Parent and pad:IsDescendantOf(workspace) then table.insert(list, pad) end
	end
	return list
end

function WorldFx.NearestPad(plot, position)
	local best, bestDist
	for _, pad in ipairs(WorldFx.GetPads(plot)) do
		local d = (pad.Position - position).Magnitude
		if not bestDist or d < bestDist then best, bestDist = pad, d end
	end
	return best
end

local function myPosition()
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	return hrp and hrp.Position or camera.CFrame.Position
end

local upgradeThrottle = 0
local function hookOre(ore: Instance, plot: Model)
	if not ore:IsA("BasePart") then return end
	ore:GetAttributeChangedSignal("Upgrades"):Connect(function()
		if not isMine(plot) or not ore.Parent then return end
		local now = os.clock()
		WorldFx.Burst(ore.Position, ore.Color, 8, 7)
		if now > upgradeThrottle then
			upgradeThrottle = now + 0.25
			local mult = ore:GetAttribute("LastMult") or 2
			WorldFx.Popup(ore.Position + Vector3.new(0, 2, 0), "⚡x" .. mult, Color3.fromRGB(255, 225, 80), 0.6)
		end
	end)
end

local function hookPlot(plot: Model)
	register(plot.Base)
	for _, item in ipairs(plot.Items:GetChildren()) do task.spawn(onItemAdded, item, plot) end
	plot.Items.ChildAdded:Connect(function(item) task.spawn(onItemAdded, item, plot) end)
	for _, b in ipairs(plot.Buttons:GetChildren()) do task.spawn(onButtonAdded, b, plot) end
	plot.Buttons.ChildAdded:Connect(function(b) task.spawn(onButtonAdded, b, plot) end)

	-- Prompt da porta só para o dono
	local prompt = plot.Base.Gate:FindFirstChild("DoorPanel") and plot.Base.Gate.DoorPanel:FindFirstChild("DoorPrompt")
	-- Prompts de nível dos droppers: só o dono vê
	local function setLevelPrompt(d)
		if d:IsA("ProximityPrompt") and d:GetAttribute("LevelPrompt") then d.Enabled = isMine(plot) end
	end
	plot.DescendantAdded:Connect(setLevelPrompt)
	local function refreshOwner()
		if prompt then prompt.Enabled = isMine(plot) end
		for _, d in ipairs(plot:GetDescendants()) do setLevelPrompt(d) end
	end
	plot:GetAttributeChangedSignal("OwnerId"):Connect(refreshOwner)
	refreshOwner()

	-- Plataformas de coleta mostram o valor do cofre
	plotPads[plot] = {}
	local function refreshBank()
		local bank = plot:GetAttribute("Bank") or 0
		local text = bank >= 1 and ("COLETAR\n" .. Format.Cash(bank)) or "COLLECT"
		for _, pad in ipairs(WorldFx.GetPads(plot)) do
			local label = pad:FindFirstChild("PadGui") and pad.PadGui:FindFirstChild("Label")
			if label then label.Text = text end
		end
	end
	local function trackPad(d)
		if d:IsA("BasePart") and d:GetAttribute("CollectPad") then
			plotPads[plot][d] = true
			task.defer(refreshBank)
		end
	end
	for _, d in ipairs(plot:GetDescendants()) do trackPad(d) end
	plot.DescendantAdded:Connect(trackPad)
	plot:GetAttributeChangedSignal("Bank"):Connect(refreshBank)
	refreshBank()

	local ores = plot:WaitForChild("Ores", 5)
	if ores then
		ores.ChildAdded:Connect(function(ore) hookOre(ore, plot) end)
	end
end

------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------
function WorldFx.Init(hud)
	Hud = hud
	Hud.OnGuideChanged = WorldFx.SetGuide

	local tycoons = workspace:WaitForChild("Tycoons")
	for _, plot in ipairs(tycoons:GetChildren()) do hookPlot(plot) end
	tycoons.ChildAdded:Connect(function(plot)
		plot:WaitForChild("Base"); plot:WaitForChild("Items"); plot:WaitForChild("Buttons")
		hookPlot(plot)
	end)
	local map = workspace:FindFirstChild("Map")
	if map then register(map) end

	-- Minério processado
	Remotes.OreProcessed.OnClientEvent:Connect(function(position, value, color)
		WorldFx.Popup(position + Vector3.new(0, 3, 0), "+" .. Format.Cash(value), Color3.fromRGB(120, 255, 140), 0.8)
		burstPart.Position = position
		burst.Color = ColorSequence.new(color)
		burst.Speed = NumberRange.new(4, 8)
		burst:Emit(4)
	end)

	-- Coleta: chuva de moedas na plataforma
	Remotes.Collected.OnClientEvent:Connect(function(amount, auto)
		local plot = Hud.GetMyPlot()
		if not plot then return end
		local pad = WorldFx.NearestPad(plot, myPosition())
		if not pad then return end
		if auto then
			WorldFx.Burst(pad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 80), 6, 6)
		else
			WorldFx.Burst(pad.Position + Vector3.new(0, 1, 0), Color3.fromRGB(255, 220, 80), 45, 18)
			WorldFx.Shockwave(pad.Position + Vector3.new(0, 0.4, 0), Color3.fromRGB(120, 255, 140), 18)
			WorldFx.Popup(pad.Position + Vector3.new(0, 4, 0), "+" .. Format.Cash(amount), Color3.fromRGB(255, 230, 90), 1.6)
		end
	end)

	-- Compra confirmada (mensagens do dono)
	Remotes.Purchased.OnClientEvent:Connect(function(plotIndex, id)
		if plotIndex ~= player:GetAttribute("PlotIndex") then return end
		local cfg = Config.ItemsById[id]
		if not cfg then return end
		if cfg.Type == "Brainrot" then
			Hud.Toast("🎉 " .. cfg.Name .. " arrived! Droppers +" .. (cfg.Buff or 0) .. "% income", "success")
		elseif cfg.Type == "Floor" then
			Hud.Toast("🪜 New floor unlocked! Go up the stairs 👆", "rebirth")
			Hud.Confetti(40)
			Hud.Play("Legendary")
		elseif cfg.Type == "AutoCollector" then
			Hud.Toast("🤖 Auto-Collector on: your vault empties by itself!", "success")
		else
			Hud.Toast("✅ " .. cfg.Icon .. " " .. cfg.Name .. " built!", "success")
		end
	end)

	Remotes.ButtonDenied.OnClientEvent:Connect(function(id)
		task.spawn(shakeButton, id)
	end)

	-- Dropper melhorado
	Remotes.LevelUp.OnClientEvent:Connect(function(id, level, pos)
		if pos then
			WorldFx.Burst(pos + Vector3.new(0, 4, 0), Color3.fromRGB(255, 220, 80), 30, 14)
			WorldFx.Shockwave(pos - Vector3.new(0, 3.5, 0), Color3.fromRGB(255, 220, 80), 10)
			WorldFx.Popup(pos + Vector3.new(0, 8, 0), "▲ Lv." .. level, Color3.fromRGB(255, 225, 90), 1.3)
		end
		Hud.Play("Purchase", 0.1)
	end)

	-- Pulso de buff dos brainrots + balões de fala
	task.spawn(function()
		local nextSpeech = os.clock() + 6
		while true do
			task.wait(5)
			local plot = Hud.GetMyPlot()
			local list = ownedBrainrots(plot)
			local camPos = camera.CFrame.Position
			for i, entry in ipairs(list) do
				local rig = entry.Item:FindFirstChild("Rig")
				if rig and rig.PrimaryPart and (rig.PrimaryPart.Position - camPos).Magnitude < 90 then
					task.delay(i * 0.15, function()
						if rig.PrimaryPart then
							local color = Config.Rarities[entry.Cfg.Rarity].Color
							WorldFx.Popup(rig.PrimaryPart.Position + Vector3.new(0, 3, 0), "⚡+" .. (entry.Cfg.Buff or 0) .. "%", Color3.fromRGB(255, 225, 90), 0.7)
							WorldFx.Shockwave(rig.PrimaryPart.Position + Vector3.new(0, 0.2, 0), color, 10)
						end
					end)
				end
			end
			if #list > 0 and os.clock() >= nextSpeech then
				nextSpeech = os.clock() + math.random(8, 14)
				local entry = list[math.random(1, #list)]
				local lines = Config.Catchphrases and Config.Catchphrases[entry.Cfg.Id]
				if lines then speak(entry.Item, lines[math.random(1, #lines)]) end
			end
		end
	end)

	-- Loop de animação
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local camPos = camera.CFrame.Position

		for rig, data in pairs(rigs) do
			if not rig.Parent or not rig:IsDescendantOf(workspace) then
				rigs[rig] = nil
			elseif not building[rig.Parent] and (data.Base.Position - camPos).Magnitude < 160 then
				local ph = data.Phase
				local bob = (math.sin(t * 2.4 + ph) + 1) * 0.18
				local sway = math.sin(t * 1.5 + ph) * math.rad(9)
				local tilt = math.sin(t * 2.4 + ph + 1) * math.rad(3)
				local cf = data.Base * CFrame.new(0, bob, 0) * CFrame.Angles(0, sway, tilt)
				rig:PivotTo(cf)
				for _, sub in ipairs(data.Subs) do
					if sub.Model.Parent then
						sub.Model:PivotTo(cf * sub.Offset * CFrame.Angles(0, t * sub.Speed, 0))
					end
				end
			end
		end

		for inst, data in pairs(spinners) do
			if not inst.Parent or not inst:IsDescendantOf(workspace) then
				spinners[inst] = nil
			elseif (data.Base.Position - camPos).Magnitude < 220 then
				if data.Model then
					inst:PivotTo(data.Base * CFrame.new(0, math.sin(t * 1.3 + data.Phase) * 0.35, 0) * CFrame.Angles(0, t * data.Speed, 0))
				else
					inst.CFrame = data.Base * CFrame.Angles(t * data.Speed, 0, 0)
				end
			end
		end

		local stripeShift = -((t * Config.ConveyorSpeed / 56) % (2 / 19 * 1.5))
		for frame in pairs(patterns) do
			if not frame.Parent then
				patterns[frame] = nil
			else
				frame.Position = UDim2.fromScale(stripeShift, 0)
			end
		end

		for part, data in pairs(scans) do
			if not part.Parent then
				scans[part] = nil
			else
				part.CFrame = data.Center * CFrame.new(0, math.sin(t * 2.6 + data.Index * 2.1) * 2.6, 0)
			end
		end

		for part in pairs(lasers) do
			if not part.Parent then lasers[part] = nil else part.Transparency = 0.5 + math.sin(t * 7) * 0.15 end
		end

		for bulb, data in pairs(lamps) do
			if not bulb.Parent then
				lamps[bulb] = nil
			else
				local c = Color3.fromHSV((t * 0.06 + data.Phase) % 1, 0.45, 1)
				bulb.Color = c
				if data.Light then data.Light.Color = c end
			end
		end

		for part in pairs(blinks) do
			if not part.Parent then blinks[part] = nil else part.Transparency = (math.floor(t * 2) % 2 == 0) and 0 or 0.7 end
		end

		for g in pairs(rainbows) do
			if not g.Parent then rainbows[g] = nil else g.Offset = Vector2.new(math.sin(t * 0.8) * 0.5, 0) end
		end

		-- lasers de porta trancada pulsam
		for _, plot in ipairs(workspace.Tycoons:GetChildren()) do
			local laser = plot:FindFirstChild("Base") and plot.Base.Gate:FindFirstChild("Laser")
			if laser and laser:GetAttribute("Locked") then
				laser.Transparency = 0.62 + math.sin(t * 8) * 0.1
			end
		end

		-- anel da plataforma de coleta pulsa quando há dinheiro no cofre
		local myPlot = Hud.GetMyPlot()
		if myPlot then
			local bank = myPlot:GetAttribute("Bank") or 0
			for _, pad in ipairs(WorldFx.GetPads(myPlot)) do
				local ring = pad.Parent and pad.Parent:FindFirstChild("PadRing")
				if ring then
					ring.Transparency = bank >= 1 and (0.15 + (math.sin(t * 5) + 1) * 0.3) or 0.6
				end
			end
		end

		updateButtons(t)
		updateGuide(t)
	end)
end

return WorldFx
