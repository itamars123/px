-- AchievementService.lua
-- Checks achievement progress on the server and awards gems.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AchievementData = require(Shared.AchievementData)
local TreasureData = require(Shared.TreasureData)
local Remotes = require(Shared.Remotes)

local S

local AchievementService = {}

function AchievementService.Progress(data): { [string]: number }
	local discovered, celestial = 0, 0
	for id in pairs(data.Index) do
		local def = TreasureData.Get(id)
		if def and not def.Exclusive then
			discovered += 1
		end
	end
	for _, t in pairs(data.Treasures) do
		local def = TreasureData.Get(t.Id)
		if def and def.Rarity == "Celestial" then
			celestial += 1
		end
	end
	local secrets = 0
	for _ in pairs(data.Secrets) do
		secrets += 1
	end
	local st = data.Stats
	return {
		Collected = st.Collected or 0,
		Steals = st.Steals or 0,
		Defends = st.Defends or 0,
		Trades = st.Trades or 0,
		Hatched = st.Hatched or 0,
		ChestsOpened = st.ChestsOpened or 0,
		Earned = data.TotalEarned or 0,
		Rebirths = data.Rebirths or 0,
		Level = data.Level or 1,
		Discovered = discovered,
		Secrets = secrets,
		Celestial = celestial,
	}
end

function AchievementService.Check(player: Player)
	local data = S.DataService.Get(player)
	if not data then
		return
	end
	local progress = AchievementService.Progress(data)
	local unlocked = false
	for _, a in ipairs(AchievementData.List) do
		if not data.Achievements[a.Id] and (progress[a.Stat] or 0) >= a.Goal then
			data.Achievements[a.Id] = true
			unlocked = true
			S.EconomyService.AddGems(player, a.Gems)
			S.NetService.Notify(player, ("🏆 ACHIEVEMENT: %s %s! +%d 💎"):format(a.Icon, a.Name, a.Gems), "level")
			Remotes.Effect:FireClient(player, "Achievement", a.Id)
		end
	end
	if unlocked then
		S.StateService.MarkFull(player)
	end
end

function AchievementService.Init(services)
	S = services
end

function AchievementService.Start()
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in ipairs(Players:GetPlayers()) do
				AchievementService.Check(player)
			end
		end
	end)
end

return AchievementService
