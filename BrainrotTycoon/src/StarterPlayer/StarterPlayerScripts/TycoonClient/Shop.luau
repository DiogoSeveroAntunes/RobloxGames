--[[
	Shop - loja de armas e skins brainrot (compras permanentes).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer
local Shop = {}
local Hud, panel
local tab = "Weapon"
local cards = {}
local busy = false

local GREEN = { Color3.fromRGB(90, 230, 130), Color3.fromRGB(40, 180, 110) }
local RED = { Color3.fromRGB(255, 110, 120), Color3.fromRGB(210, 60, 80) }
local GRAY = { Color3.fromRGB(120, 110, 140), Color3.fromRGB(85, 75, 105) }
local GOLD = { Color3.fromRGB(255, 210, 70), Color3.fromRGB(255, 140, 40) }
local BLUE = { Color3.fromRGB(110, 200, 255), Color3.fromRGB(70, 120, 240) }
local ROBUX = { Color3.fromRGB(255, 225, 90), Color3.fromRGB(255, 170, 30) }

local function ownedSet(attr)
	local set = {}
	for id in string.gmatch(player:GetAttribute(attr) or "", "[^,]+") do set[id] = true end
	return set
end

local function styleAction(card, colors, text)
	card.Action.UIGradient.Color = ColorSequence.new(colors[1], colors[2])
	card.Action.Label.Text = text
end

local function refresh()
	if not panel then return end
	local cash = player:GetAttribute("Cash") or 0
	local rebirths = player:GetAttribute("Rebirths") or 0
	local weapons, skins = ownedSet("OwnedWeapons"), ownedSet("OwnedSkins")
	local equipped = player:GetAttribute("EquippedSkin") or ""
	for _, entry in ipairs(cards) do
		local cfg, card, kind = entry.Cfg, entry.Card, entry.Kind
		card.Visible = (kind == tab) or (kind == "Cash" and tab == "Pass")
		if kind == "Cash" then
			local ips = player:GetAttribute("IncomePerSecond") or 0
			local amount = Config.GetCashPackAmount(cfg, ips)
			card.Req.Text = "💵 You get +" .. Format.Cash(amount)
			card.Req.TextColor3 = Color3.fromRGB(110, 255, 140)
			card.Desc.Text = "= " .. Config.FormatMinutes(cfg.Minutes) .. " of your current income (" .. Format.Cash(math.max(ips, Config.CashPackMinIncome)) .. "/s). Grows as your base grows!"
			styleAction(card, ROBUX, "R$ " .. cfg.Robux)
			card.UIStroke.Color = Color3.fromRGB(110, 255, 140)
			continue
		end
		if kind == "Pass" then
			local has = player:GetAttribute("Pass_" .. cfg.Id) == true
			card.Req.Text = "💎 Robux · forever"
			card.Req.TextColor3 = Color3.fromRGB(255, 220, 90)
			styleAction(card, has and BLUE or ROBUX, has and "✔ ACTIVE" or ("R$ " .. cfg.Robux))
			card.UIStroke.Color = has and Color3.fromRGB(110, 200, 255) or Color3.fromRGB(255, 205, 60)
			continue
		end
		local owned = (kind == "Weapon") and weapons[cfg.Id] or skins[cfg.Id]
		local locked = cfg.Rebirth > rebirths
		card.Req.Text = cfg.Rebirth > 0 and ("⭐ Requires " .. cfg.Rebirth .. " rebirth" .. (cfg.Rebirth > 1 and "s" or "")) or "⭐ No requirement"
		card.Req.TextColor3 = locked and Color3.fromRGB(255, 120, 130) or Color3.fromRGB(255, 220, 90)
		local stroke = card.UIStroke
		if owned then
			if kind == "Weapon" then
				styleAction(card, BLUE, "✔ IN INVENTORY")
			elseif equipped == cfg.Id then
				styleAction(card, GOLD, "✔ WEARING (remove)")
			else
				styleAction(card, BLUE, "WEAR")
			end
			stroke.Color = Color3.fromRGB(110, 200, 255)
		elseif locked then
			styleAction(card, GRAY, "🔒 REBIRTH " .. cfg.Rebirth)
			stroke.Color = Color3.fromRGB(90, 70, 120)
		else
			local can = cash >= cfg.Price
			styleAction(card, can and GREEN or RED, Format.Cash(cfg.Price))
			stroke.Color = can and Color3.fromRGB(90, 235, 130) or Color3.fromRGB(120, 90, 170)
		end
	end
	for _, t in ipairs({ { panel.Tabs.WeaponsTab, "Weapon" }, { panel.Tabs.SkinsTab, "Skin" }, { panel.Tabs.PassTab, "Pass" } }) do
		t[1].BackgroundColor3 = (t[2] == tab) and Color3.fromRGB(255, 90, 200) or Color3.fromRGB(70, 50, 110)
	end
end
Shop.Refresh = refresh

local function onAction(entry)
	if busy then return end
	local cfg, kind = entry.Cfg, entry.Kind
	if kind == "Cash" then
		busy = true
		local ok, result = pcall(function() return Remotes.ShopAction:InvokeServer("Cash", "Buy", cfg.Id) end)
		busy = false
		if ok and result and result.msg and result.msg ~= "" then
			Hud.Toast(result.msg, result.ok and "success" or "error")
			if result.ok then Hud.Play("Purchase"); Hud.Confetti(40) end
		end
		task.defer(refresh)
		return
	end
	if kind == "Pass" then
		if player:GetAttribute("Pass_" .. cfg.Id) then
			Hud.Toast(cfg.Icon .. " " .. cfg.Name .. " is already active", "info")
			return
		end
		busy = true
		local ok, result = pcall(function() return Remotes.ShopAction:InvokeServer("Pass", "Buy", cfg.Id) end)
		busy = false
		if ok and result and result.msg and result.msg ~= "" then
			Hud.Toast(result.msg, result.ok and "success" or "error")
			if result.ok then Hud.Play("Purchase"); Hud.Confetti(40) end
		end
		task.defer(refresh)
		return
	end
	local owned = (kind == "Weapon") and ownedSet("OwnedWeapons")[cfg.Id] or ownedSet("OwnedSkins")[cfg.Id]
	local action
	if owned then
		if kind == "Weapon" then
			Hud.Toast("⚔️ It's in your backpack — press its number to equip", "info")
			return
		end
		action = (player:GetAttribute("EquippedSkin") == cfg.Id) and "Unequip" or "Equip"
	else
		if cfg.Rebirth > (player:GetAttribute("Rebirths") or 0) then
			Hud.Play("Error")
			Hud.Toast("🔒 Requires " .. cfg.Rebirth .. " rebirth" .. (cfg.Rebirth > 1 and "s" or ""), "error")
			Hud.Pop(entry.Card, 0.06)
			return
		end
		action = "Buy"
	end
	busy = true
	local ok, result = pcall(function() return Remotes.ShopAction:InvokeServer(kind, action, cfg.Id) end)
	busy = false
	if ok and result then
		Hud.Toast(result.msg or "", result.ok and "success" or "error")
		if result.ok then
			Hud.Play(action == "Buy" and "Purchase" or "Pop")
			Hud.Pop(entry.Card, 0.1)
			if action == "Buy" then Hud.Confetti(30) end
		else
			Hud.Play("Error")
		end
	end
	task.defer(refresh)
end

function Shop.Init(hud)
	Hud = hud
	panel = Hud.Gui:WaitForChild("ShopPanel")
	local template = panel.CardTemplate
	local order = 0
	for _, group in ipairs({ { Config.Weapons, "Weapon" }, { Config.Skins, "Skin" }, { Config.CashPacks, "Cash" }, { Config.GamePasses, "Pass" } }) do
		for _, cfg in ipairs(group[1]) do
			order += 1
			local card = template:Clone()
			card.Name = group[2] .. "_" .. cfg.Id
			card.LayoutOrder = order
			card.IconBg.Icon.Text = cfg.Icon
			card.ItemName.Text = cfg.Name
			card.Desc.Text = cfg.Description or ""
			if group[2] == "Weapon" then
				card.Stats.Text = string.format("%s · %d dmg · %.1fs", cfg.Kind == "Melee" and "🗡️ Melee" or "🎯 Ranged", cfg.Damage, cfg.Cooldown)
			elseif group[2] == "Pass" then
				card.Stats.Text = "💎 Game Pass"
			elseif group[2] == "Cash" then
				card.Stats.Text = "⏱️ Instant cash · buy as many as you want"
			else
				card.Stats.Text = "👕 Brainrot costume"
			end
			card.Visible = false
			card.Parent = panel.List
			local entry = { Cfg = cfg, Card = card, Kind = group[2] }
			table.insert(cards, entry)
			Hud.HookButton(card.Action, function() onAction(entry) end)
		end
	end
	Hud.HookButton(panel.Tabs.WeaponsTab, function() tab = "Weapon"; Hud.Play("Click"); refresh() end)
	Hud.HookButton(panel.Tabs.SkinsTab, function() tab = "Skin"; Hud.Play("Click"); refresh() end)
	Hud.HookButton(panel.Tabs.PassTab, function() tab = "Pass"; Hud.Play("Click"); refresh() end)
	for _, gp in ipairs(Config.GamePasses) do
		player:GetAttributeChangedSignal("Pass_" .. gp.Id):Connect(function() if panel.Visible then refresh() end end)
	end
	Hud.HookButton(panel.Header.Close, function() Hud.Play("Click"); Hud.CloseModal() end)
	Hud.HookButton(Hud.Gui.SideButtons.ShopButton, function()
		refresh()
		Hud.OpenModal(panel)
	end)
	for _, attr in ipairs({ "Cash", "Rebirths", "OwnedWeapons", "OwnedSkins", "EquippedSkin", "IncomePerSecond" }) do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if panel.Visible then refresh() end
		end)
	end
	refresh()
end

return Shop
