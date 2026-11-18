-- PetService.lua
-- Pets: hatching eggs (server-side rolls with luck), equipping, deleting and
-- applying pet bonuses (income, luck, speed, gems). Equipped pets are
-- published as a player attribute; every client renders and animates the
-- followers locally, so pets cost no network traffic while moving.

local HttpService = game:GetService("HttpService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local PetData = require(Shared.PetData)
local UpgradeData = require(Shared.UpgradeData)
local Rarities = require(Shared.Rarities)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local PetService = {}

local rng = Random.new()

local function count(t): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

-- Pet slots from upgrades + the VIP pass
local function slotsFor(player: Player, data): number
	local session = S.DataService.Session(player)
	return UpgradeData.PetSlots(data) + (session and session.PassSlots or 0)
end

local function equippedList(data): { string }
	local list = {}
	for uid, pet in pairs(data.Pets) do
		if pet.Equipped then
			table.insert(list, uid)
		end
	end
	table.sort(list)
	return list
end

-- Recomputes bonuses and publishes the equipped pets for client rendering.
function PetService.Refresh(player: Player)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session then
		return
	end
	local bonus = { Money = 0, Luck = 0, Speed = 0, Gems = 0 }
	local ids = {}
	local slots = slotsFor(player, data)
	local equipped = equippedList(data)
	for i, uid in ipairs(equipped) do
		local pet = data.Pets[uid]
		local def = PetData.Get(pet.Id)
		if i > slots or not def then
			pet.Equipped = false
		else
			bonus[def.BonusType] += def.Bonus
			table.insert(ids, def.Id)
		end
	end
	session.PetBonus = bonus
	player:SetAttribute("Pets", HttpService:JSONEncode(ids))
	S.PlayerService.ApplyMovement(player)
	S.StateService.MarkFull(player)
end

function PetService.Hatch(player: Player, eggKey)
	local data = S.DataService.Get(player)
	local session = S.DataService.Session(player)
	if not data or not session or typeof(eggKey) ~= "string" then
		return false, "Bad request"
	end
	local egg = PetData.Eggs[eggKey]
	if not egg then
		return false, "Unknown egg"
	end
	if count(data.Pets) >= Config.Pets.MaxOwned then
		return false, "Your pet inventory is full! Delete some pets."
	end
	if egg.Currency == "Gems" then
		if data.Gems < egg.Cost then
			return false, ("Need %d more 💎"):format(egg.Cost - data.Gems)
		end
		data.Gems -= egg.Cost
	else
		if data.Money < egg.Cost then
			return false, ("Need %s more"):format(Util.Money(egg.Cost - data.Money))
		end
		data.Money -= egg.Cost
	end
	local def = PetData.Roll(eggKey, S.EconomyService.Luck(player), rng)
	local uid = Util.NewUid()
	while data.Pets[uid] do
		uid = Util.NewUid()
	end
	data.Pets[uid] = { Id = def.Id, Equipped = false }
	data.Stats.Hatched = (data.Stats.Hatched or 0) + 1
	-- auto-equip into a free slot
	if #equippedList(data) < slotsFor(player, data) then
		data.Pets[uid].Equipped = true
	end
	PetService.Refresh(player)
	S.StateService.PushStats(player)
	if Rarities.Rank(def.Rarity) >= 6 then
		Remotes.Announce:FireAllClients(("🥚 %s hatched a %s %s!"):format(player.DisplayName, def.Rarity, def.Name), def.Rarity)
	end
	return true, nil, { PetId = def.Id, Uid = uid }
end

function PetService.SetEquipped(player: Player, uid, equip)
	local data = S.DataService.Get(player)
	if not data or typeof(uid) ~= "string" or not data.Pets[uid] then
		return false, "Unknown pet"
	end
	local session = S.DataService.Session(player)
	if session and session.Trade and table.find(session.Trade.MyPets or {}, uid) then
		return false, "That pet is in a trade"
	end
	if equip == true and not data.Pets[uid].Equipped then
		if #equippedList(data) >= slotsFor(player, data) then
			return false, ("All %d pet slots are full"):format(slotsFor(player, data))
		end
	end
	data.Pets[uid].Equipped = equip == true
	PetService.Refresh(player)
	return true
end

function PetService.EquipBest(player: Player)
	local data = S.DataService.Get(player)
	if not data then
		return false
	end
	local list = {}
	for uid, pet in pairs(data.Pets) do
		pet.Equipped = false
		local def = PetData.Get(pet.Id)
		if def then
			local score = def.BonusType == "Speed" and def.Bonus * 0.02 or def.Bonus
			if def.BonusType == "Money" then
				score *= 1.5
			end
			table.insert(list, { uid, score })
		end
	end
	table.sort(list, function(a, b)
		return a[2] > b[2]
	end)
	local session = S.DataService.Session(player)
	local inTrade = session and session.Trade and session.Trade.MyPets or {}
	local n = 0
	for _, e in ipairs(list) do
		if n >= slotsFor(player, data) then
			break
		end
		if not table.find(inTrade, e[1]) then
			data.Pets[e[1]].Equipped = true
			n += 1
		end
	end
	PetService.Refresh(player)
	return true, "Equipped your best pets!"
end

function PetService.Delete(player: Player, uid)
	local data = S.DataService.Get(player)
	if not data or typeof(uid) ~= "string" or not data.Pets[uid] then
		return false, "Unknown pet"
	end
	local session = S.DataService.Session(player)
	if session and session.Trade and table.find(session.Trade.MyPets or {}, uid) then
		return false, "That pet is in a trade"
	end
	local def = PetData.Get(data.Pets[uid].Id)
	data.Pets[uid] = nil
	local refund = def and math.max(1, Rarities.Rank(def.Rarity) * 2) or 1
	S.EconomyService.AddGems(player, refund)
	PetService.Refresh(player)
	return true, ("Released pet (+%d 💎)"):format(refund)
end

function PetService.Init(services)
	S = services
end

function PetService.Start()
	S.NetService.Handle("HatchEgg", { { Type = "string", MaxLen = 24 } }, PetService.Hatch)
	S.NetService.Handle("EquipPet", { { Type = "string", MaxLen = 40 } }, function(player, uid)
		return PetService.SetEquipped(player, uid, true)
	end)
	S.NetService.Handle("UnequipPet", { { Type = "string", MaxLen = 40 } }, function(player, uid)
		return PetService.SetEquipped(player, uid, false)
	end)
	S.NetService.Handle("EquipBestPets", {}, PetService.EquipBest)
	S.NetService.Handle("DeletePet", { { Type = "string", MaxLen = 40 } }, PetService.Delete)
	S.DataService.Loaded.Event:Connect(function(player)
		task.defer(PetService.Refresh, player)
	end)
end

return PetService
