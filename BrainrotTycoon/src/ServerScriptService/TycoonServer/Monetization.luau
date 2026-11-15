--[[
	Monetization - compras com Robux.
	- Gamepasses (Config.GamePasses): 2x Dinheiro, Auto-Coletor VIP, Ganhos Offline VIP, Tênis Turbo
	- Developer Products: Dropper VIP e Multiplicador VIP de cada andar (permanentes)

	Para ativar no jogo publicado, crie os Game Passes e Developer Products no
	Creator Dashboard e cole os ids em Config.GamePasses[].PassId e Config.VipProductIds.
	Enquanto o id for 0, a compra só funciona no Studio (modo teste, sem cobrar).
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local Remotes = ReplicatedStorage.Remotes

local Monetization = {}
local DataService, GetTycoon
local IS_STUDIO = RunService:IsStudio()
local promptThrottle = {}

local productToItem = {}
for _, item in ipairs(Config.Items) do
	if item.Robux and item.ProductId and item.ProductId ~= 0 then productToItem[item.ProductId] = item end
end
local productToPack = {}
for _, pack in ipairs(Config.CashPacks) do
	if pack.ProductId ~= 0 then productToPack[pack.ProductId] = pack end
end
local passIdToPass = {}
for _, gp in ipairs(Config.GamePasses) do
	if gp.PassId ~= 0 then passIdToPass[gp.PassId] = gp end
end

function Monetization.HasPass(player, id)
	return player:GetAttribute("Pass_" .. id) == true
end

-- Efeitos dos passes
function Monetization.ApplyPasses(player)
	local tycoon = GetTycoon(player)
	if tycoon then tycoon:RecalculateIncome() end
	local character = player.Character
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = Monetization.HasPass(player, "FastWalk") and 28 or 16
	end
end

local function setPass(player, id, owned)
	if player:GetAttribute("Pass_" .. id) == owned then return end
	player:SetAttribute("Pass_" .. id, owned)
	Monetization.ApplyPasses(player)
end

-- Chamado ao entrar (antes dos ganhos offline)
function Monetization.LoadPasses(player)
	local profile = DataService.Get(player)
	for _, gp in ipairs(Config.GamePasses) do
		local owned = false
		if gp.PassId ~= 0 then
			local ok, result = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.PassId)
			end)
			owned = ok and result == true
		elseif IS_STUDIO and profile then
			owned = profile.Data.TestPasses[gp.Id] == true
		end
		setPass(player, gp.Id, owned)
	end
end

-- Concede um item VIP (por compra real ou teste)
local function grantItem(player, item)
	local profile = DataService.Get(player)
	if not profile then return false end
	profile.Data.Premium[item.Id] = true
	local tycoon = GetTycoon(player)
	if tycoon then tycoon:BuildPremium(true) end
	Remotes.Notify:FireClient(player, "💎 " .. item.Name .. " is yours forever!", "rebirth")
	task.spawn(DataService.Save, player)
	return true
end

-- Pacote de dinheiro: X minutos da renda atual, na hora
local function grantCash(player, pack)
	local tycoon = GetTycoon(player)
	if not tycoon then return false end
	local amount = Config.GetCashPackAmount(pack, player:GetAttribute("IncomePerSecond"))
	tycoon.Services.AddCash(player, amount)
	Remotes.Notify:FireClient(player, pack.Icon .. " +" .. Format.Cash(amount) .. " added! (" .. pack.Name .. ")", "rebirth")
	return true
end

function Monetization.PromptCash(player, id)
	local pack = Config.CashPacksById[id]
	if not pack then return { ok = false, msg = "Invalid pack" } end
	local now = os.clock()
	if (promptThrottle[player] or 0) > now then return { ok = false, msg = "" } end
	promptThrottle[player] = now + 2
	if pack.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, pack.ProductId)
		return { ok = true, msg = "", prompted = true }
	elseif IS_STUDIO then
		grantCash(player, pack)
		return { ok = true, msg = "🧪 Test mode: cash pack granted for free" }
	end
	return { ok = false, msg = "This pack isn't on sale yet" }
end

function Monetization.PromptItem(player, item)
	local now = os.clock()
	if (promptThrottle[player] or 0) > now then return end
	promptThrottle[player] = now + 2
	if item.ProductId and item.ProductId ~= 0 then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
	elseif IS_STUDIO then
		grantItem(player, item)
		Remotes.Notify:FireClient(player, "🧪 Studio test mode: purchase granted for free", "info")
	else
		Remotes.Notify:FireClient(player, "This VIP item isn't on sale yet", "error")
	end
end

function Monetization.PromptPass(player, id)
	local gp = Config.GamePassesById[id]
	if not gp then return { ok = false, msg = "Invalid pass" } end
	if Monetization.HasPass(player, id) then return { ok = false, msg = "You already own this pass" } end
	if gp.PassId ~= 0 then
		MarketplaceService:PromptGamePassPurchase(player, gp.PassId)
		return { ok = true, msg = "" , prompted = true }
	elseif IS_STUDIO then
		local profile = DataService.Get(player)
		if profile then profile.Data.TestPasses[id] = true end
		setPass(player, id, true)
		return { ok = true, msg = "🧪 Test mode: " .. gp.Icon .. " " .. gp.Name .. " activated" }
	end
	return { ok = false, msg = "This pass isn't on sale yet" }
end

function Monetization.Init(dataService, getTycoon)
	DataService = dataService
	GetTycoon = getTycoon

	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		local item = productToItem[receipt.ProductId]
		local pack = productToPack[receipt.ProductId]
		if not player or (not item and not pack) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local profile = DataService.Get(player)
		if not profile or not profile.CanSave then return Enum.ProductPurchaseDecision.NotProcessedYet end
		local receipts = profile.Data.Receipts
		if table.find(receipts, receipt.PurchaseId) then return Enum.ProductPurchaseDecision.PurchaseGranted end
		if pack and not GetTycoon(player) then return Enum.ProductPurchaseDecision.NotProcessedYet end
		profile.Data.RobuxSpent += (receipt.CurrencySpent or (item or pack).Robux or 0)
		table.insert(receipts, receipt.PurchaseId)
		while #receipts > 30 do table.remove(receipts, 1) end
		if pack then
			grantCash(player, pack)
			task.spawn(DataService.Save, player)
		elseif not profile.Data.Premium[item.Id] then
			grantItem(player, item)
		end
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local gp = passIdToPass[passId]
		if purchased and gp then
			setPass(player, gp.Id, true)
			local profile = DataService.Get(player)
			if profile and not profile.Data.CountedPasses[gp.Id] then
				profile.Data.CountedPasses[gp.Id] = true
				profile.Data.RobuxSpent += gp.Robux
			end
			Remotes.Notify:FireClient(player, gp.Icon .. " " .. gp.Name .. " activated! Thanks for the support 💖", "rebirth")
		end
	end)

	Players.PlayerRemoving:Connect(function(p) promptThrottle[p] = nil end)
end

return Monetization
