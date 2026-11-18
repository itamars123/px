-- StateService.lua
-- Replicates player state to its owning client. Two channels:
--   FullState: everything (inventory, upgrades, settings ...) when it changes
--   Stats:     small, frequent payload (money, mps, timers, carrying)
-- Both are debounced so bursts of changes collapse into a single send.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local function uncollected(data): number
	local total = data.Vault or 0
	for _, v in pairs(data.PlotCash or {}) do
		total += v
	end
	return total
end

local Scheduler = require(game:GetService("ServerScriptService").Modules.Scheduler)

local S

local StateService = {}

local fullPending: { [Player]: boolean } = {}
local statsPending: { [Player]: boolean } = {}

function StateService.MarkFull(player: Player)
	fullPending[player] = true
	statsPending[player] = true
end

function StateService.PushStats(player: Player)
	statsPending[player] = true
end

local function buildFull(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return nil
	end
	local treasures = {}
	local tradeOffer = session.Trade and session.Trade.MyOffer or {}
	for uid, t in pairs(data.Treasures) do
		table.insert(treasures, {
			Uid = uid,
			Id = t.Id,
			Plot = t.Plot,
			Mut = t.Mut,
			Stealing = session.Stealing[uid] ~= nil,
			InTrade = table.find(tradeOffer, uid) ~= nil,
		})
	end
	local pets = {}
	for uid, pet in pairs(data.Pets) do
		table.insert(pets, { Uid = uid, Id = pet.Id, Equipped = pet.Equipped, InTrade = session.Trade ~= nil and table.find(session.Trade.MyPets or {}, uid) ~= nil })
	end
	local achievements = {}
	for id in pairs(data.Achievements) do
		table.insert(achievements, id)
	end
	local index = {}
	for id in pairs(data.Index) do
		table.insert(index, id)
	end
	local secrets = {}
	for name in pairs(data.Secrets) do
		table.insert(secrets, name)
	end
	return {
		Money = data.Money,
		Gems = data.Gems,
		Vault = uncollected(data),
		Pets = pets,
		PetSlots = UpgradeData.PetSlots(data) + (session.PassSlots or 0),
		Achievements = achievements,
		AchievementProgress = S.AchievementService.Progress(data),
		Boosts = data.Boosts,
		AutoCollect = data.AutoCollect,
		BaseColor = data.BaseColor,
		ExtraPetSlots = data.ExtraPetSlots,
		PetBonus = session.PetBonus,
		Aura = session.Aura,
		Luck = S.EconomyService.Luck(player),
		TotalEarned = data.TotalEarned,
		Rebirths = data.Rebirths,
		Level = data.Level,
		XP = data.XP,
		XPNext = Config.XPForLevel(data.Level),
		Upgrades = data.Upgrades,
		Abilities = data.Abilities,
		Treasures = treasures,
		Index = index,
		Secrets = secrets,
		Settings = data.Settings,
		Stats = data.Stats,
		Title = data.Title,
		Titles = data.Titles,
		PlotCount = UpgradeData.PlotCount(data),
		CarryCap = UpgradeData.CarryCapacity(data),
		MaxStorage = Config.MaxStorage,
		BaseIndex = session.BaseIndex,
		Multiplier = UpgradeData.IncomeMultiplier(data, session.Aura, session.PetBonus.Money),
		RebirthCost = Config.RebirthCost(data.Rebirths),
		RebirthReq = Config.RebirthRequirement(data.Rebirths),
		Gear = data.Gear,
		Passes = session.Passes or {},
		LockDuration = UpgradeData.LockDuration(data),
		CanSave = S.DataService.CanSave(),
	}
end

local function buildStats(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return nil
	end
	local carrying = {}
	for _, item in ipairs(session.Carrying) do
		table.insert(carrying, { Id = item.Id, Source = item.Source, Victim = item.Victim and item.Victim.DisplayName or nil })
	end
	return {
		Money = data.Money,
		Gems = data.Gems,
		Vault = uncollected(data),
		Stamina = session.Stamina,
		MaxStamina = Config.Sprint.MaxStamina,
		Luck = S.EconomyService.Luck(player),
		Boosts = data.Boosts,
		ServerTime = os.time(),
		MPS = session.MPS,
		Level = data.Level,
		XP = data.XP,
		XPNext = Config.XPForLevel(data.Level),
		Rebirths = data.Rebirths,
		Carrying = carrying,
		CarryCap = UpgradeData.CarryCapacity(data),
		LockEnd = session.LockEnd,
		LockCooldownEnd = session.LockCooldownEnd,
		StealCooldownEnd = session.StealCooldownEnd,
		ShieldEnd = session.ShieldEnd,
		AbilityCooldowns = session.AbilityCooldowns,
		EventMultiplier = S.EconomyService.EventMultiplier,
	}
end

local function updateLeaderstats(player: Player)
	local data = S.DataService.Get(player)
	local ls = player:FindFirstChild("leaderstats")
	if not data or not ls then
		return
	end
	local money = ls:FindFirstChild("Money")
	if money then
		money.Value = Util.Money(data.Money)
	end
	local rb = ls:FindFirstChild("Rebirths")
	if rb then
		rb.Value = data.Rebirths
	end
	local lvl = ls:FindFirstChild("Level")
	if lvl then
		lvl.Value = data.Level
	end
end

function StateService.SendFullNow(player: Player)
	local snap = buildFull(player)
	if snap then
		Remotes.FullState:FireClient(player, snap)
	end
end

function StateService.Init(services)
	S = services
end

function StateService.Start()
	-- debounced replication, driven by the shared Scheduler
	Scheduler.Every("Replication", 0.2, function()
		for player in pairs(fullPending) do
			fullPending[player] = nil
			if player.Parent then
				StateService.SendFullNow(player)
			end
		end
		for player in pairs(statsPending) do
			statsPending[player] = nil
			if player.Parent then
				local snap = buildStats(player)
				if snap then
					Remotes.Stats:FireClient(player, snap)
				end
				updateLeaderstats(player)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		fullPending[p] = nil
		statsPending[p] = nil
	end)
	S.NetService.Handle("RequestState", {}, function(player)
		StateService.MarkFull(player)
		return true
	end)
end

return StateService
