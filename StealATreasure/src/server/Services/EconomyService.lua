-- EconomyService.lua
-- Passive income, money/XP helpers, levels, offline earnings and the global
-- income multiplier used by events (Golden Hour).

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local EconomyService = {}
EconomyService.EventMultiplier = 1

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
		S.NetService.Notify(player, ("⭐ LEVEL %d! +%s"):format(data.Level, Util.Money(reward)), "level")
	end
	if leveled then
		Remotes.Effect:FireClient(player, "LevelUp", data.Level)
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
	local total = 0
	for uid, t in pairs(data.Treasures) do
		if t.Plot and not session.Stealing[uid] then
			local def = TreasureData.Get(t.Id)
			if def then
				total += def.MPS
			end
		end
	end
	return total * UpgradeData.IncomeMultiplier(data) * EconomyService.EventMultiplier
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
			mps += def and def.MPS or 0
		end
	end
	mps *= UpgradeData.IncomeMultiplier(data)
	local earned = math.floor(mps * away * Config.OfflineIncomeRate)
	if earned > 0 then
		EconomyService.AddMoney(player, earned)
		S.NetService.Notify(player, ("💤 Welcome back! Your treasures earned %s while you were away (%s)."):format(Util.Money(earned), Util.Time(away)), "discovery")
	end
end

function EconomyService.Init(services)
	S = services
end

function EconomyService.Start()
	task.spawn(function()
		while true do
			task.wait(Config.IncomeTickSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				local data = S.DataService.Get(player)
				local session = S.DataService.Session(player)
				if data and session then
					local mps = EconomyService.ComputeMPS(player)
					session.MPS = mps
					local gain = mps * Config.IncomeTickSeconds
					if gain > 0 then
						data.Money += gain
						data.TotalEarned += gain
					end
					S.StateService.PushStats(player)
				end
			end
		end
	end)
end

return EconomyService
