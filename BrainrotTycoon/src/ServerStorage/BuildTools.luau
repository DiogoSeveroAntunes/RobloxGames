-- Ferramentas de construção usadas só no Studio para gerar os modelos do template.
-- Não é usado em runtime; pode ser apagado sem problemas.
local B = {}

function B.P(props, parent)
	local p = Instance.new(props.Class or "Part"); props.Class = nil
	p.Anchored = true; p.TopSurface = Enum.SurfaceType.Smooth; p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent
	return p
end

-- Elipsóide (Part + SpecialMesh esfera)
function B.E(name, size, cf, color, parent, material)
	local p = B.P({Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic}, parent)
	local mesh = Instance.new("SpecialMesh"); mesh.MeshType = Enum.MeshType.Sphere; mesh.Parent = p
	return p
end

function B.Ball(name, d, cf, color, parent, material)
	return B.P({Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(d, d, d), CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic}, parent)
end

-- Cilindro com eixo vertical
function B.Cyl(name, height, d, cf, color, parent, material)
	return B.P({Name = name, Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, d, d), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material or Enum.Material.SmoothPlastic}, parent)
end

-- Olho cartoon olhando para +Z do cf
function B.Eye(cf, r, parent, look)
	look = look or Vector3.new(0, 0, 0)
	B.Ball("EyeWhite", r, cf, Color3.new(1, 1, 1), parent)
	B.Ball("Pupil", r * 0.5, cf * CFrame.new(look.X * r * 0.15, look.Y * r * 0.15, r * 0.3), Color3.fromRGB(20, 15, 25), parent)
	B.Ball("Glint", r * 0.16, cf * CFrame.new(r * 0.1, r * 0.12, r * 0.5), Color3.new(1, 1, 1), parent)
end

function B.Eyes(cf, r, spacing, parent, look)
	B.Eye(cf * CFrame.new(-spacing / 2, 0, 0), r, parent, look)
	B.Eye(cf * CFrame.new(spacing / 2, 0, 0), r, parent, look)
end

-- Boca: fatia escura com língua
function B.Mouth(cf, w, h, parent, open)
	local m = B.E("Mouth", Vector3.new(w, h, 0.5), cf, Color3.fromRGB(60, 15, 30), parent)
	if open then
		B.E("Tongue", Vector3.new(w * 0.6, h * 0.45, 0.3), cf * CFrame.new(0, -h * 0.2, 0.15), Color3.fromRGB(255, 100, 120), parent)
	end
	return m
end

-- Cria o Model de personagem: Rig (animação) + InfoAnchor (billboard)
function B.NewCharacter(id, anchorCF, height)
	local Config = require(script.Parent:FindFirstChild("ConfigOverride") or game.ReplicatedStorage.Shared.Config)
	local cfg = Config.ItemsById[id]
	local rar = Config.Rarities[cfg.Rarity]
	local model = Instance.new("Model"); model.Name = id
	local rig = Instance.new("Model"); rig.Name = "Rig"; rig.Parent = model
	local root = B.P({Name = "Root", Size = Vector3.new(1, 1, 1), CFrame = anchorCF, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, rig)
	rig.PrimaryPart = root
	local info = B.P({Name = "InfoAnchor", Size = Vector3.new(1, 1, 1), CFrame = anchorCF * CFrame.new(0, height + 1.2, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false}, model)
	local bb = Instance.new("BillboardGui"); bb.Name = "Info"; bb.Size = UDim2.fromScale(8, 3.3); bb.StudsOffset = Vector3.new(0, 1.2, 0); bb.MaxDistance = 70; bb.LightInfluence = 0; bb.AlwaysOnTop = false; bb.Parent = info
	local name = Instance.new("TextLabel"); name.Name = "NameLabel"; name.BackgroundTransparency = 1; name.Size = UDim2.new(1, 0, 0.42, 0); name.Font = Enum.Font.FredokaOne; name.TextScaled = true; name.Text = cfg.Name; name.TextColor3 = Color3.new(1, 1, 1); name.Parent = bb
	local ns = Instance.new("UIStroke"); ns.Thickness = 2.5; ns.Color = Color3.fromRGB(30, 15, 45); ns.Parent = name
	local rl = Instance.new("TextLabel"); rl.Name = "Rarity"; rl.BackgroundTransparency = 1; rl.Position = UDim2.fromScale(0, 0.4); rl.Size = UDim2.new(1, 0, 0.3, 0); rl.Font = Enum.Font.FredokaOne; rl.TextScaled = true; rl.Text = cfg.Rarity; rl.TextColor3 = rar.Color; rl.Parent = bb
	local rs = Instance.new("UIStroke"); rs.Thickness = 2; rs.Color = Color3.fromRGB(30, 15, 45); rs.Parent = rl
	if rar.Rainbow then
		local g = Instance.new("UIGradient"); g.Name = "Rainbow"
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)), ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(110, 255, 110)), ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 200, 255)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(190, 100, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 80)),
		}); g.Parent = rl
	end
	local il = Instance.new("TextLabel"); il.Name = "Income"; il.BackgroundTransparency = 1; il.Position = UDim2.fromScale(0, 0.7); il.Size = UDim2.new(1, 0, 0.3, 0); il.Font = Enum.Font.FredokaOne; il.TextScaled = true; il.Text = "⚡ +" .. (cfg.Buff or 0) .. "% droppers"; il.TextColor3 = Color3.fromRGB(255, 225, 90); il.Parent = bb
	local is = Instance.new("UIStroke"); is.Thickness = 2; is.Color = Color3.fromRGB(10, 50, 20); is.Parent = il
	model:SetAttribute("Rarity", cfg.Rarity)
	model:SetAttribute("Buff", cfg.Buff)
	model.PrimaryPart = info
	return model, rig, root, rar
end

return B
