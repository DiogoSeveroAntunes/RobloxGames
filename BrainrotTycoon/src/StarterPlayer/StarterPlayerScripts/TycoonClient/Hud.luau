--[[
	Hud - toda a interface 2D: dinheiro animado, notificações, painéis,
	banner de anúncio, próximo objetivo, rebirth, ajustes e confete.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")
local Debris = game:GetService("Debris")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Hud = {}
Hud.Settings = { Music = true, Guide = true }
Hud.OnGuideChanged = nil -- callback definido pelo WorldFx

local gui
local sounds = SoundService:WaitForChild("TycoonSounds")
local music
local currentModal
local toastCounter = 0

local COLORS = {
	info = Color3.fromRGB(110, 220, 255),
	success = Color3.fromRGB(90, 235, 130),
	money = Color3.fromRGB(120, 255, 140),
	error = Color3.fromRGB(255, 80, 100),
	rebirth = Color3.fromRGB(255, 210, 70),
}

------------------------------------------------------------------------------
-- Utilidades
------------------------------------------------------------------------------
local function tween(obj, t, props, style, dir)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
Hud.Tween = tween

local function getScale(obj)
	local s = obj:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = obj
	end
	return s
end

function Hud.Play(name: string, speedVariance: number?)
	local base = sounds:FindFirstChild(name)
	if not base then return end
	local s = base:Clone()
	if speedVariance then
		s.PlaybackSpeed = 1 + (math.random() - 0.5) * 2 * speedVariance
	end
	s.Parent = SoundService
	s:Play()
	Debris:AddItem(s, math.max(s.TimeLength, 1) + 1)
end

function Hud.Pop(obj, amount)
	local s = getScale(obj)
	s.Scale = 1 + (amount or 0.12)
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

------------------------------------------------------------------------------
-- Notificações
------------------------------------------------------------------------------
function Hud.Toast(text: string, kind: string?)
	kind = kind or "info"
	local container = gui.Toasts
	local toasts = {}
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Frame") then table.insert(toasts, c) end
	end
	if #toasts >= 4 then
		table.sort(toasts, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
		toasts[1]:Destroy()
	end
	toastCounter += 1
	local t = gui.ToastTemplate:Clone()
	t.Name = "Toast"
	t.LayoutOrder = toastCounter
	t.Visible = true
	t.Text.Text = text
	t.UIStroke.Color = COLORS[kind] or COLORS.info
	t.Text.TextColor3 = (kind == "error") and Color3.fromRGB(255, 200, 205) or Color3.new(1, 1, 1)
	local s = getScale(t)
	s.Scale = 0.4
	t.BackgroundTransparency = 1
	t.Parent = container
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(t, 0.2, { BackgroundTransparency = 0.1 })
	task.delay(3.2, function()
		if not t.Parent then return end
		tween(t, 0.3, { BackgroundTransparency = 1 })
		tween(t.Text, 0.3, { TextTransparency = 1 })
		tween(t.UIStroke, 0.3, { Transparency = 1 })
		tween(s, 0.3, { Scale = 0.8 })
		task.wait(0.32)
		t:Destroy()
	end)
end

-- Texto flutuante na tela (+$ ao coletar etc.)
function Hud.FloatText(text: string, color: Color3, position: UDim2, height: number?, rise: number?)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Position = position
	l.Size = UDim2.fromOffset(420, height or 48)
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.Text = text
	l.TextColor3 = color
	l.Rotation = math.random(-6, 6)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(20, 40, 20); st.Parent = l
	local s = Instance.new("UIScale"); s.Scale = 0.3; s.Parent = l
	l.Parent = gui.Floaters
	tween(s, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	tween(l, 1.1, { Position = position - UDim2.fromOffset(0, rise or 70) }, Enum.EasingStyle.Quad)
	task.delay(0.65, function()
		tween(l, 0.45, { TextTransparency = 1 })
		tween(st, 0.45, { Transparency = 1 })
	end)
	Debris:AddItem(l, 1.3)
end

function Hud.Banner(title: string, sub: string, c1: Color3, c2: Color3)
	local b = gui.Banner
	b.Title.Text = title
	b.Sub.Text = sub
	b.UIGradient.Color = ColorSequence.new(c1, c2)
	b.Position = UDim2.new(0.5, 0, 0, -220)
	b.Visible = true
	tween(b, 0.5, { Position = UDim2.new(0.5, 0, 0, 92) }, Enum.EasingStyle.Back)
	local token = {}
	Hud._bannerToken = token
	task.delay(4.5, function()
		if Hud._bannerToken ~= token then return end
		tween(b, 0.4, { Position = UDim2.new(0.5, 0, 0, -220) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(0.45)
		if Hud._bannerToken == token then b.Visible = false end
	end)
end

function Hud.Confetti(count: number?)
	local palette = { Color3.fromRGB(255, 90, 200), Color3.fromRGB(110, 220, 255), Color3.fromRGB(255, 220, 80), Color3.fromRGB(120, 255, 140), Color3.fromRGB(190, 120, 255) }
	local holder = gui.Floaters
	for i = 1, count or 70 do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.BackgroundColor3 = palette[math.random(1, #palette)]
		f.Size = UDim2.fromOffset(math.random(8, 14), math.random(14, 22))
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.new(math.random(), 0, 0, -30)
		f.Rotation = math.random(0, 360)
		f.ZIndex = 25
		f.Parent = holder
		local dur = 1.6 + math.random() * 1.6
		task.delay(math.random() * 0.5, function()
			tween(f, dur, { Position = UDim2.new(f.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1, 40), Rotation = f.Rotation + math.random(-540, 540) }, Enum.EasingStyle.Sine, Enum.EasingDirection.In)
		end)
		Debris:AddItem(f, dur + 0.6)
	end
end

------------------------------------------------------------------------------
-- Painéis (modais)
------------------------------------------------------------------------------
function Hud.CloseModal()
	local m = currentModal
	if not m then return end
	currentModal = nil
	tween(gui.Dim, 0.2, { BackgroundTransparency = 1 })
	tween(m, 0.18, { GroupTransparency = 1 })
	tween(getScale(m), 0.18, { Scale = 0.85 })
	task.delay(0.2, function()
		if currentModal ~= m then m.Visible = false end
		if not currentModal then gui.Dim.Visible = false end
	end)
end

function Hud.OpenModal(m)
	if currentModal == m then return end
	if currentModal then
		currentModal.Visible = false
	end
	currentModal = m
	gui.Dim.Visible = true
	tween(gui.Dim, 0.2, { BackgroundTransparency = 0.45 })
	m.Visible = true
	m.GroupTransparency = 1
	local s = getScale(m)
	s.Scale = 0.8
	tween(m, 0.2, { GroupTransparency = 0 })
	tween(s, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	Hud.Play("Click")
end

local function hookButton(btn: GuiButton, onClick)
	local s = getScale(btn)
	btn.MouseEnter:Connect(function() tween(s, 0.15, { Scale = 1.07 }) end)
	btn.MouseLeave:Connect(function() tween(s, 0.15, { Scale = 1 }) end)
	btn.MouseButton1Down:Connect(function() tween(s, 0.08, { Scale = 0.92 }) end)
	btn.MouseButton1Up:Connect(function() tween(s, 0.15, { Scale = 1.05 }, Enum.EasingStyle.Back) end)
	btn.Activated:Connect(onClick)
end
Hud.HookButton = hookButton

------------------------------------------------------------------------------
-- Rebirth
------------------------------------------------------------------------------
local rebirthArmed = false
local function updateRebirthPanel()
	local panel = gui.RebirthPanel
	local cash = player:GetAttribute("Cash") or 0
	local cost = player:GetAttribute("RebirthCost") or Config.GetRebirthCost(0)
	local rebirths = player:GetAttribute("Rebirths") or 0
	if player:GetAttribute("RebirthMaxed") then
		rebirthArmed = false
		panel.MultRow.Current.Text = "x" .. Config.GetMultiplier(rebirths)
		panel.MultRow.Next.Text = "🏆"
		panel.Bar.Fill.Size = UDim2.fromScale(1, 1)
		panel.Bar.Progress.Text = "Rebirth " .. rebirths .. "/" .. Config.MaxRebirths
		panel.Confirm.UIGradient.Color = ColorSequence.new(Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 130, 40))
		panel.Confirm.Label.Text = "🏆 MAX REBIRTH!"
		gui.SideButtons.RebirthButton.Badge.Visible = false
		return
	end
	panel.MultRow.Current.Text = "x" .. Config.GetMultiplier(rebirths)
	panel.MultRow.Next.Text = "x" .. Config.GetMultiplier(rebirths + 1)
	local ratio = math.clamp(cash / cost, 0, 1)
	tween(panel.Bar.Fill, 0.25, { Size = UDim2.fromScale(math.max(ratio, 0.04), 1) })
	panel.Bar.Progress.Text = Format.Cash(cash) .. " / " .. Format.Cash(cost)
	local confirm = panel.Confirm
	if cash >= cost then
		confirm.UIGradient.Color = ColorSequence.new(Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 130, 40))
		confirm.Label.Text = rebirthArmed and "ARE YOU SURE? CLICK AGAIN" or "REBIRTH NOW"
	else
		rebirthArmed = false
		confirm.UIGradient.Color = ColorSequence.new(Color3.fromRGB(120, 110, 140), Color3.fromRGB(80, 70, 100))
		confirm.Label.Text = "NEED " .. Format.Cash(cost - cash)
	end
	gui.SideButtons.RebirthButton.Badge.Visible = cash >= cost
end
Hud.UpdateRebirthPanel = updateRebirthPanel

------------------------------------------------------------------------------
-- Ajustes
------------------------------------------------------------------------------
local function renderSwitch(row, on)
	local sw = row.Switch
	tween(sw, 0.2, { BackgroundColor3 = on and Color3.fromRGB(80, 220, 120) or Color3.fromRGB(110, 100, 130) })
	tween(sw.Knob, 0.25, { Position = on and UDim2.new(1, -36, 0.5, 0) or UDim2.new(0, 4, 0.5, 0) }, Enum.EasingStyle.Back)
end

local function applyMusic()
	if not music then
		music = sounds.Music:Clone()
		music.Name = "BackgroundMusic"
		music.Parent = SoundService
	end
	if Hud.Settings.Music then
		if not music.IsPlaying then music:Play() end
	else
		music:Stop()
	end
end

local function setSetting(key, value)
	Hud.Settings[key] = value
	task.spawn(function()
		pcall(function() Remotes.GetState:InvokeServer("SetSetting", key, value) end)
	end)
	if key == "Music" then applyMusic() end
	if key == "Guide" and Hud.OnGuideChanged then Hud.OnGuideChanged(value) end
end

------------------------------------------------------------------------------
-- Próximo objetivo
------------------------------------------------------------------------------
function Hud.GetMyPlot()
	local index = player:GetAttribute("PlotIndex")
	local folder = workspace:FindFirstChild("Tycoons")
	return index and folder and folder:FindFirstChild("Plot" .. index)
end

function Hud.GetNextTarget()
	local plot = Hud.GetMyPlot()
	if not plot then return nil end
	local best
	local rebirths = player:GetAttribute("Rebirths") or 0
	for _, b in ipairs(plot.Buttons:GetChildren()) do
		local cfg = Config.ItemsById[b.Name]
		if cfg and not cfg.Robux and (cfg.Rebirth or 0) <= rebirths and (not best or cfg.Price < best.Cfg.Price) then
			best = { Cfg = cfg, Button = b }
		end
	end
	return best, plot
end

local lastGoalId
local function updateGoal()
	local panel = gui.GoalPanel
	local cash = player:GetAttribute("Cash") or 0
	local target, plot = Hud.GetNextTarget()
	if not plot then
		panel.Visible = false
		return
	end
	panel.Visible = true
	local price, name, icon, id
	if target then
		price, name, icon, id = target.Cfg.Price, target.Cfg.Name, target.Cfg.Icon, target.Cfg.Id
	elseif player:GetAttribute("RebirthMaxed") then
		price, name, icon, id = 0, "🏆 ALL COMPLETE! Upgrade your droppers (F)", "🏆", "__done"
	else
		price = player:GetAttribute("RebirthCost") or Config.GetRebirthCost(0)
		name, icon, id = "REBIRTH ⭐ (everything bought!)", "⭐", "__rebirth"
	end
	if id ~= lastGoalId then
		lastGoalId = id
		Hud.Pop(panel, 0.08)
	end
	panel.Icon.Text = icon
	panel.Title.Text = (id == "__done") and name or ("Next: " .. name)
	local ratio = price <= 0 and 1 or math.clamp(cash / price, 0, 1)
	tween(panel.Bar.Fill, 0.25, { Size = UDim2.fromScale(math.max(ratio, 0.03), 1) })
	if id == "__done" then
		panel.Bar.Progress.Text = "Rebirth " .. Config.MaxRebirths .. " · brainrots +" .. Config.MaxBrainrotBuff .. "%"
	elseif price <= 0 then
		panel.Bar.Progress.Text = "FREE — step on the button!"
	elseif ratio >= 1 then
		panel.Bar.Progress.Text = "READY! " .. Format.Cash(price)
	else
		panel.Bar.Progress.Text = Format.Cash(cash) .. " / " .. Format.Cash(price)
	end
	panel.UIStroke.Color = ratio >= 1 and Color3.fromRGB(90, 235, 130) or Color3.fromRGB(255, 90, 200)
end

------------------------------------------------------------------------------
-- Init
------------------------------------------------------------------------------
function Hud.Init()
	gui = player:WaitForChild("PlayerGui"):WaitForChild("TycoonHUD")
	Hud.Gui = gui

	-- escala para telas pequenas/grandes
	local camera = workspace.CurrentCamera
	local function rescale()
		local vp = camera.ViewportSize
		gui.UIScale.Scale = math.clamp(math.min(vp.X / 1280, vp.Y / 760), 0.55, 1.15)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
	rescale()

	-- Dinheiro animado ----------------------------------------------------
	local cashPanel = gui.CashPanel
	local amountLabel = cashPanel.Amount
	local shown = player:GetAttribute("Cash") or 0
	local target = shown
	local lastCash = shown
	amountLabel.Text = Format.Cash(shown)
	player:GetAttributeChangedSignal("Cash"):Connect(function()
		target = player:GetAttribute("Cash") or 0
		if target > lastCash then
			Hud.Pop(cashPanel, 0.08)
			amountLabel.TextColor3 = Color3.fromRGB(170, 255, 180)
			tween(amountLabel, 0.5, { TextColor3 = Color3.new(1, 1, 1) })
		elseif target < lastCash then
			amountLabel.TextColor3 = Color3.fromRGB(255, 160, 170)
			tween(amountLabel, 0.5, { TextColor3 = Color3.new(1, 1, 1) })
		end
		lastCash = target
		if currentModal == gui.RebirthPanel then updateRebirthPanel() end
		gui.SideButtons.RebirthButton.Badge.Visible = not player:GetAttribute("RebirthMaxed") and target >= (player:GetAttribute("RebirthCost") or math.huge)
	end)
	RunService.RenderStepped:Connect(function(dt)
		if shown ~= target then
			shown += (target - shown) * math.min(1, dt * 9)
			if math.abs(target - shown) < 0.5 then shown = target end
			amountLabel.Text = Format.Cash(math.floor(shown + 0.5))
		end
		local badge = gui.SideButtons.RebirthButton.Badge
		if badge.Visible then
			badge.Rotation = math.sin(os.clock() * 6) * 12
		end
	end)

	local function updateIncome()
		cashPanel.Income.Text = "+" .. Format.Cash(player:GetAttribute("IncomePerSecond") or 0) .. "/s"
	end
	player:GetAttributeChangedSignal("IncomePerSecond"):Connect(updateIncome)
	updateIncome()

	local function updateMult()
		local r = player:GetAttribute("Rebirths") or 0
		cashPanel.Multiplier.Visible = r > 0
		cashPanel.Multiplier.Text = "x" .. Config.GetMultiplier(r)
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(updateMult)
	updateMult()

	-- Buff dos brainrots nos droppers
	local lastBuff = player:GetAttribute("DropperBuff") or 0
	local function updateBuff()
		local buff = player:GetAttribute("DropperBuff") or 0
		local pill = cashPanel:FindFirstChild("Buff")
		if not pill then return end
		pill.Visible = buff > 0
		pill.Text = "⚡ Droppers +" .. buff .. "%"
		if buff > lastBuff then Hud.Pop(pill, 0.3) end
		lastBuff = buff
	end
	player:GetAttributeChangedSignal("DropperBuff"):Connect(updateBuff)
	updateBuff()

	-- Botões laterais ----------------------------------------------------
	local side = gui.SideButtons
	hookButton(side.HomeButton, function()
		Hud.Play("Click")
		Remotes.TeleportHome:FireServer()
	end)
	hookButton(side.RebirthButton, function()
		rebirthArmed = false
		updateRebirthPanel()
		Hud.OpenModal(gui.RebirthPanel)
	end)
	hookButton(side.SettingsButton, function()
		Hud.OpenModal(gui.SettingsPanel)
	end)

	for _, name in ipairs({ "RebirthPanel", "SettingsPanel", "WelcomePanel" }) do
		local m = gui[name]
		hookButton(m.Header.Close, function()
			Hud.Play("Click")
			Hud.CloseModal()
		end)
	end
	gui.Dim.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			Hud.CloseModal()
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Escape then Hud.CloseModal() end
	end)

	-- Rebirth
	hookButton(gui.RebirthPanel.Confirm, function()
		local cash = player:GetAttribute("Cash") or 0
		local cost = player:GetAttribute("RebirthCost") or math.huge
		if cash < cost then
			Hud.Play("Error")
			Hud.Pop(gui.RebirthPanel.Bar, 0.1)
			return
		end
		if not rebirthArmed then
			rebirthArmed = true
			Hud.Play("Click")
			updateRebirthPanel()
			task.delay(3, function()
				if rebirthArmed then rebirthArmed = false; updateRebirthPanel() end
			end)
			return
		end
		rebirthArmed = false
		Remotes.RequestRebirth:FireServer()
	end)

	-- Ajustes
	local sp = gui.SettingsPanel
	for key, row in pairs({ Music = sp.MusicRow, Guide = sp.GuideRow }) do
		hookButton(row.Switch, function()
			Hud.Play("Click")
			setSetting(key, not Hud.Settings[key])
			renderSwitch(row, Hud.Settings[key])
		end)
	end
	task.spawn(function()
		local ok, state = pcall(function() return Remotes.GetState:InvokeServer() end)
		if ok and type(state) == "table" and state.Settings then
			for k, v in pairs(state.Settings) do Hud.Settings[k] = v end
		end
		renderSwitch(sp.MusicRow, Hud.Settings.Music)
		renderSwitch(sp.GuideRow, Hud.Settings.Guide)
		applyMusic()
		if Hud.OnGuideChanged then Hud.OnGuideChanged(Hud.Settings.Guide) end
	end)

	-- Bem-vindo de volta
	hookButton(gui.WelcomePanel.Confirm, function()
		Hud.Play("Coin")
		Hud.CloseModal()
	end)
	Remotes.WelcomeBack.OnClientEvent:Connect(function(amount, seconds)
		local wp = gui.WelcomePanel
		wp.Amount.Text = "+" .. Format.Cash(amount)
		wp.Time.Text = "in " .. Format.Duration(seconds) .. " · already in your vault!"
		Hud.OpenModal(wp)
		Hud.Play("Coin")
	end)

	-- Eventos do servidor -------------------------------------------------
	Remotes.Notify.OnClientEvent:Connect(function(text, kind)
		Hud.Toast(text, kind)
		if kind == "error" then Hud.Play("Error") end
	end)

	Remotes.Collected.OnClientEvent:Connect(function(amount, auto)
		if auto then
			Hud.FloatText("+" .. Format.Cash(amount), Color3.fromRGB(170, 255, 180), UDim2.new(0.5, 120, 0, 60), 26, 30)
		else
			Hud.FloatText("+" .. Format.Cash(amount), Color3.fromRGB(120, 255, 140), UDim2.new(0.5, 0, 0.36, 0), 64, 90)
			Hud.Play("Coin", 0.08)
		end
	end)

	Remotes.ButtonDenied.OnClientEvent:Connect(function(id, missing)
		local cfg = Config.ItemsById[id]
		Hud.Toast("💸 Need " .. Format.Cash(missing) .. " more for " .. (cfg and cfg.Name or id), "error")
		Hud.Play("Error")
	end)

	Remotes.Announce.OnClientEvent:Connect(function(name, id)
		local cfg = Config.ItemsById[id]
		if not cfg then return end
		local rar = Config.Rarities[cfg.Rarity]
		Hud.Banner("🔥 " .. string.upper(cfg.Rarity) .. "!", name .. " unlocked " .. cfg.Icon .. " " .. cfg.Name, rar.Color, Color3.fromRGB(255, 80, 190))
		Hud.Play("Legendary")
	end)

	Remotes.RebirthDone.OnClientEvent:Connect(function(rebirths, mult)
		Hud.CloseModal()
		local cel = gui.RebirthCelebration
		cel.Visible = true
		cel.BackgroundTransparency = 0
		cel.Title.Text = "REBIRTH #" .. rebirths
		cel.Sub.Text = "income x" .. mult .. " forever!"
		cel.Title.TextTransparency = 0
		cel.Sub.TextTransparency = 0
		local s = getScale(cel.Title)
		s.Scale = 0.2
		tween(cel, 0.8, { BackgroundTransparency = 1 })
		tween(s, 0.6, { Scale = 1 }, Enum.EasingStyle.Back)
		Hud.Play("Rebirth")
		Hud.Confetti(90)
		task.delay(2.6, function()
			tween(cel.Title, 0.4, { TextTransparency = 1 })
			tween(cel.Sub, 0.4, { TextTransparency = 1 })
			task.wait(0.45)
			cel.Visible = false
		end)
	end)

	-- Loop do objetivo
	task.spawn(function()
		while true do
			updateGoal()
			task.wait(0.25)
		end
	end)
end

return Hud
