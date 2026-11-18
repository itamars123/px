-- EconomyService.lua
-- Passive income, money/XP helpers, levels, offline earnings and the global
-- income multiplier used by events (Golden Hour).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)
local Mutations = require(Shared.Mutations)

local Scheduler = require(game:GetService("ServerScriptService").Modules.Scheduler)

local S

local EconomyService = {}
EconomyService.EventMultiplier = 1
EconomyService.EventLuck = 0 -- additive luck bonus from the Lucky Treasure event

function EconomyService.AddGems(player: Player, amount: number)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or amount ~= amount or amount == 0 then
		return
	end
	if amount > 0 and session then
		amount = math.floor(amount * (1 + session.PetBonus.Gems) + 0.5)
	end
	data.Gems = math.max(0, math.floor(data.Gems + amount))
	S.StateService.PushStats(player)
end

function EconomyService.Luck(player: Player): number
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data then
		return 1
	end
	local passLuck = session and session.PassLuck or 0
	return UpgradeData.Luck(data, (session and session.PetBonus.Luck or 0) + passLuck, EconomyService.EventLuck)
end

function EconomyService.AddMoney(player: Player, amount: number)
	local data = S.DataService.Get(player)
	if not data or amount ~= amount then -- NaN guard
		return
	end
	data.Money = math.max(0, data.Money + amount)
	if amount > 0 then
		data.TotalEarned += amount
	end
	S.StateService.PushStats(player)
end

function EconomyService.AddXP(player: Player, amount: number)
	local data = S.DataService.Get(player)
	if not data then
		return
	end
	data.XP += amount
	local leveled = false
	while data.XP >= Config.XPForLevel(data.Level) do
		data.XP -= Config.XPForLevel(data.Level)
		data.Level += 1
		leveled = true
		-- level reward
		local reward = 100 * data.Level * data.Level
		data.Money += reward
		data.Gems += data.Level * Config.Gems.PerLevel
		S.NetService.Notify(player, ("⭐ LEVEL %d! +%s  +%d 💎"):format(data.Level, Util.Money(reward), data.Level * Config.Gems.PerLevel), "level")
	end
	if leveled then
		Remotes.Effect:FireClient(player, "LevelUp", data.Level)
		S.PlayerService.Emote(player, "Celebrate", 3)
		S.PlayerService.UpdateOverhead(player)
	end
	S.StateService.PushStats(player)
end

-- Money per second from all placed treasures (not being stolen).
function EconomyService.ComputeMPS(player: Player): number
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return 0
	end
	local total, aura = 0, 0
	local perPlot = {}
	for uid, t in pairs(data.Treasures) do
		if t.Plot and not session.Stealing[uid] and not session.Arriving[uid] then
			local def = TreasureData.Get(t.Id)
			if def then
				local v = def.MPS * Mutations.Multiplier(t.Mut)
				total += v
				perPlot[t.Plot] = v
				aura += def.Aura or 0
			end
		end
	end
	session.Aura = aura
	local mult = UpgradeData.IncomeMultiplier(data, aura, session.PetBonus.Money) * EconomyService.EventMultiplier * (session.PassIncome or 1)
	session.PlotIncome = perPlot
	session.IncomeMult = mult
	return total * mult
end

function EconomyService.GrantOffline(player: Player)
	local data = S.DataService.Get(player)
	if not data or (data.LastOnline or 0) <= 0 then
		return
	end
	local away = math.min(os.time() - data.LastOnline, Config.OfflineIncomeMaxSeconds)
	if away < 60 then
		return
	end
	local mps = 0
	for _, t in pairs(data.Treasures) do
		if t.Plot then
			local def = TreasureData.Get(t.Id)
			mps += def and def.MPS * Mutations.Multiplier(t.Mut) or 0
		end
	end
	mps *= UpgradeData.IncomeMultiplier(data)
	local earned = math.floor(mps * away * Config.OfflineIncomeRate)
	if earned > 0 then
		data.Vault = (data.Vault or 0) + earned
		S.NetService.Notify(player, ("💤 Welcome back! Your treasures earned %s while you were away (%s). Collect it at your base!"):format(Util.Money(earned), Util.Time(away)), "discovery")
	end
end

function EconomyService.Init(services)
	S = services
end

function EconomyService.Start()
	Scheduler.Every("Income", Config.IncomeTickSeconds, function()
		for _, player in ipairs(Players:GetPlayers()) do
			local data = S.DataService.Get(player)
			local session = S.DataService.Session(player)
			if data and session then
				local mps = EconomyService.ComputeMPS(player)
				session.MPS = mps
				local gain = mps * Config.IncomeTickSeconds
				if gain > 0 then
					if data.AutoCollect then
						data.Money += gain
					else
						-- each stand fills up its own collect plate
						local m = (session.IncomeMult or 1) * Config.IncomeTickSeconds
						for plot, v in pairs(session.PlotIncome or {}) do
							local key = tostring(plot)
							data.PlotCash[key] = (data.PlotCash[key] or 0) + v * m
						end
					end
					data.TotalEarned += gain
				end
				S.StateService.PushStats(player)
			end
		end
	end)
end

return EconomyService
