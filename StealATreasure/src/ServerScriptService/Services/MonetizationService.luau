-- MonetizationService.luau
-- Game Passes and Developer Products (skill: monetization-systems + SE-3).
--   * Pass ownership is checked on join and when a purchase finishes.
--   * ProcessReceipt follows the ProfileStore "PurchaseId cache" pattern:
--     grant once, remember the PurchaseId in the profile, and only return
--     PurchaseGranted after that id is confirmed saved. Duplicate receipts
--     are recognised and never granted twice.
-- Items whose Id is 0 in Config.Monetization are disabled.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local S

local MonetizationService = {}

local PURCHASE_ID_CACHE_SIZE = 100
local passById: { [number]: string } = {}
local productById: { [number]: string } = {}

local function owns(session, key: string): boolean
	return session ~= nil and session.Passes ~= nil and session.Passes[key] == true
end
MonetizationService.Owns = function(player: Player, key: string): boolean
	return owns(S.DataService.Session(player), key)
end

local function applyPasses(player: Player)
	local session = S.DataService.Session(player)
	if not session then
		return
	end
	session.PassIncome = owns(session, "DoubleMoney") and 2 or 1
	session.PassCarry = owns(session, "ExtraCarry") and 1 or 0
	session.PassSlots = owns(session, "VIP") and 1 or 0
	session.PassLuck = owns(session, "VIP") and 0.25 or 0
	local data = S.DataService.Get(player)
	if data and owns(session, "VIP") and not table.find(data.Titles, "VIP") then
		table.insert(data.Titles, "VIP")
	end
	S.PetService.Refresh(player)
	S.PlayerService.UpdateOverhead(player)
	S.StateService.MarkFull(player)
end

local function checkPasses(player: Player)
	local session = S.DataService.Session(player)
	if not session then
		return
	end
	session.Passes = session.Passes or {}
	for key, pass in pairs(Config.Monetization.GamePasses) do
		if pass.Id ~= 0 then
			local ok, has = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and has then
				session.Passes[key] = true
			end
		end
	end
	applyPasses(player)
end

-- Product grant functions: (player, data) -> ()
local GRANTS = {}
for key, product in pairs(Config.Monetization.Products) do
	GRANTS[key] = function(player: Player, data)
		if product.Gems then
			data.Gems += product.Gems
			S.NetService.Notify(player, ("💎 +%d gems! Thank you!"):format(product.Gems), "success")
		elseif product.Boost then
			data.Boosts[product.Boost] = math.max(os.time(), data.Boosts[product.Boost] or 0) + product.Duration
			S.NetService.Notify(player, ("⏳ %s activated!"):format(product.Name), "success")
		end
		Remotes.Effect:FireClient(player, "Confetti")
	end
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local key = productById[receipt.ProductId]
	if not player or not key then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- wait for the profile (the player may still be loading)
	local profile = S.DataService.Profiles[player]
	local waited = 0
	while profile == nil and player.Parent == Players and waited < 30 do
		task.wait(0.5)
		waited += 0.5
		profile = S.DataService.Profiles[player]
	end
	if profile == nil or not profile:IsActive() then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local cache = profile.Data.PurchaseIdCache
	if not table.find(cache, receipt.PurchaseId) then
		local ok, err = pcall(GRANTS[key], player, profile.Data)
		if not ok then
			warn("[Monetization] grant failed:", receipt.PurchaseId, err)
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		table.insert(cache, receipt.PurchaseId)
		while #cache > PURCHASE_ID_CACHE_SIZE do
			table.remove(cache, 1)
		end
		S.StateService.MarkFull(player)
	end
	-- only confirm once the purchase id is actually saved
	profile:Save()
	local start = os.clock()
	while profile:IsActive() and os.clock() - start < 20 do
		local saved = profile.LastSavedData
		if saved and saved.PurchaseIdCache and table.find(saved.PurchaseIdCache, receipt.PurchaseId) then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		task.wait(0.5)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

function MonetizationService.Init(services)
	S = services
	for key, pass in pairs(Config.Monetization.GamePasses) do
		if pass.Id ~= 0 then
			passById[pass.Id] = key
		end
	end
	for key, product in pairs(Config.Monetization.Products) do
		if product.Id ~= 0 then
			productById[product.Id] = key
		end
	end
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local key = passById[passId]
		local session = S.DataService.Session(player)
		if purchased and key and session then
			session.Passes = session.Passes or {}
			session.Passes[key] = true
			applyPasses(player)
			S.NetService.Notify(player, ("🎉 You now own %s!"):format(Config.Monetization.GamePasses[key].Name), "success")
			Remotes.Effect:FireClient(player, "Confetti")
		end
	end)
	S.DataService.Loaded.Event:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
end

return MonetizationService
