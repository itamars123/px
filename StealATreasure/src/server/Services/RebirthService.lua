-- RebirthService.lua
-- Rebirth: trade your money, treasures and upgrades for a permanent income
-- and speed bonus, plus exclusive treasures, titles and trails at milestones.
-- Abilities, the treasure index, secrets, titles and exclusive treasures are kept.

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local RebirthService = {}

function RebirthService.Rebirth(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return false, "Not ready"
	end
	local cost = Config.RebirthCost(data.Rebirths)
	if data.Money < cost then
		return false, ("You need %s to rebirth"):format(Util.Money(cost))
	end
	if #session.Carrying > 0 then
		return false, "Deliver what you're carrying first"
	end
	local req = Config.RebirthRequirement(data.Rebirths)
	local have = 0
	for _, t in pairs(data.Treasures) do
		local d = TreasureData.Get(t.Id)
		if d and not d.Exclusive and require(Shared.Rarities).Rank(d.Rarity) >= require(Shared.Rarities).Rank(req.Rarity) then
			have += 1
		end
	end
	if have < req.Count then
		return false, ("Rebirth %d needs %d %s+ treasure%s (you have %d)"):format(data.Rebirths + 1, req.Count, req.Rarity, req.Count > 1 and "s" or "", have)
	end
	if session.Trade then
		return false, "Finish your trade first"
	end
	if next(session.Stealing) then
		return false, "Someone is robbing you! Deal with them first"
	end

	-- keep exclusive treasures only
	local kept = {}
	for uid, t in pairs(data.Treasures) do
		local def = TreasureData.Get(t.Id)
		if def and def.Exclusive then
			kept[uid] = { Id = t.Id, Plot = nil }
		end
	end
	data.Treasures = kept
	data.Rebirths += 1
	data.Money = Config.StartingMoney + data.Rebirths * Config.Rebirth.StartingMoneyPerRebirth
	for k in pairs(data.Upgrades) do
		data.Upgrades[k] = 0
	end

	-- milestone rewards
	local reward = Config.RebirthRewards[data.Rebirths]
	local rewardText = ""
	if reward then
		if reward.Title and not table.find(data.Titles, reward.Title) then
			table.insert(data.Titles, reward.Title)
			data.Title = reward.Title
		end
		if reward.Trail then
			data.Trail = reward.Trail:ToHex()
		end
		if reward.Treasure then
			local def = TreasureData.ByName[reward.Treasure]
			if def then
				local uid = Util.NewUid()
				data.Treasures[uid] = { Id = def.Id, Plot = nil }
				data.Index[def.Id] = true
				rewardText = (" Exclusive reward: %s!"):format(def.Name)
			end
		end
	end
	-- re-place exclusives on the (now smaller) base
	for _, t in pairs(data.Treasures) do
		t.Plot = S.BaseService.FreePlot(player)
	end

	S.BaseService.Refresh(player)
	S.PlayerService.ApplyMovement(player)
	S.PlayerService.UpdateOverhead(player)
	S.PlayerService.ApplyTrail(player)
	data.Gems += Config.Gems.Rebirth
	data.Vault = 0
	data.PlotCash = {}
	S.PlayerService.Emote(player, "Victory", 5)
	S.StateService.MarkFull(player)
	task.spawn(S.DataService.Save, player, false)
	Remotes.Effect:FireClient(player, "Rebirth", data.Rebirths)
	Remotes.Announce:FireAllClients(("🌀 %s reached Rebirth %d!"):format(player.DisplayName, data.Rebirths), "Mythical")
	return true, ("REBIRTH %d! +%d%% income forever, +%d 💎.%s"):format(data.Rebirths, math.floor(data.Rebirths * Config.Rebirth.IncomeBonusPerRebirth * 100), Config.Gems.Rebirth, rewardText)
end

function RebirthService.Init(services)
	S = services
end

function RebirthService.Start()
	S.NetService.Handle("Rebirth", function(player)
		local ok, msg = RebirthService.Rebirth(player)
		return ok, msg
	end)
end

return RebirthService
