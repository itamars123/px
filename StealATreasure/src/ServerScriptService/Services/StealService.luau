-- StealService.lua
-- Server-authoritative stealing:
--   validation (locks, shields, cooldowns, distance, capacity, ownership),
--   alarms, delivery, returning treasure, post-robbery lockdown and the
--   Bonk Hammer that lets defenders knock stolen loot out of a thief's hands.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local UpgradeData = require(Shared.UpgradeData)
local Remotes = require(Shared.Remotes)
local Util = require(Shared.Util)

local S

local StealService = {}

local function now()
	return workspace:GetServerTimeNow()
end

local function hrpOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Returns (ok, reason)
function StealService.CanSteal(thief: Player, owner: Player, uid: string)
	if thief == owner then
		return false, "That's your own treasure!"
	end
	local tData, oData = S.DataService.Get(thief), S.DataService.Get(owner)
	local tSes, oSes = S.DataService.Session(thief), S.DataService.Session(owner)
	if not (tData and oData and tSes and oSes) then
		return false, "Not ready"
	end
	local t = now()
	local entry = oData.Treasures[uid]
	if not entry or not entry.Plot then
		return false, "That treasure is gone"
	end
	if oSes.Stealing[uid] then
		return false, "Someone is already stealing that!"
	end
	if oSes.Arriving[uid] then
		return false, "It's still walking home — wait for it to reach its stand!"
	end
	if oSes.LockEnd > t then
		return false, "This base is locked! 🔒"
	end
	if oSes.ShieldEnd > t then
		return false, ("%s just arrived and is shielded (%ds)"):format(owner.DisplayName, math.ceil(oSes.ShieldEnd - t))
	end
	if tSes.StealCooldownEnd > t then
		return false, ("Steal cooldown: %ds"):format(math.ceil(tSes.StealCooldownEnd - t))
	end
	local victimCd = tSes.VictimCooldowns[owner.UserId]
	if victimCd and victimCd > t then
		return false, ("You robbed %s recently. Wait %ds"):format(owner.DisplayName, math.ceil(victimCd - t))
	end
	if tSes.Trade then
		return false, "Finish your trade first"
	end
	if not S.CarryService.CanCarry(thief) then
		return false, "Your hands are full! Upgrade your backpack."
	end
	if S.TreasureService.IsFull(thief, S.CarryService.Count(thief) + 1) then
		return false, "Your base and storage are full!"
	end
	-- physical validation: thief must be alive and next to the treasure
	local hrp = hrpOf(thief)
	local base = S.BaseService.Get(owner)
	if not hrp or not base then
		return false, "Not ready"
	end
	local pm = base.PlotModels[entry.Plot]
	if not pm or pm.Uid ~= uid then
		return false, "That treasure is gone"
	end
	local dist = (pm.Model:GetPivot().Position - hrp.Position).Magnitude
	if dist > Config.Steal.MaxPromptDistance + 4 then
		return false, "Too far away"
	end
	return true
end

function StealService.TryStart(thief: Player, owner: Player, uid: string)
	local ok, reason = StealService.CanSteal(thief, owner, uid)
	if not ok then
		S.NetService.Notify(thief, reason or "Can't steal that", "error")
		return false
	end
	local oData = S.DataService.Get(owner)
	local oSes = S.DataService.Session(owner)
	local entry = oData.Treasures[uid]
	local def = TreasureData.Get(entry.Id)
	oSes.Stealing[uid] = thief
	-- stealing ends your own new-player shield
	S.DataService.Session(thief).ShieldEnd = 0
	S.BaseService.Refresh(owner)
	S.CarryService.Add(thief, {
		Id = entry.Id,
		Mut = entry.Mut,
		Source = "Steal",
		Victim = owner,
		VictimUid = uid,
	})
	S.BaseService.TriggerAlarm(owner)
	Remotes.Alarm:FireClient(owner, thief.DisplayName, def and def.Name or "a treasure")
	S.NetService.Notify(thief, ("You grabbed %s! Run back to your base!"):format(def and def.Name or "it"), "success")
	S.StateService.PushStats(owner)
	return true
end

-- Stolen treasure goes back to its owner's plot.
function StealService.Return(item, reason: string?)
	local owner = item.Victim
	if not owner or not owner.Parent then
		return
	end
	local oSes = S.DataService.Session(owner)
	if oSes then
		oSes.Stealing[item.VictimUid] = nil
	end
	S.BaseService.Refresh(owner)
	if reason == "bonked" then
		S.NetService.Notify(owner, "Your treasure was recovered! 🛡️", "success")
	elseif reason == "trapped" then
		-- notification sent by the security system
	elseif reason == "timeout" or reason == "dropped" then
		S.NetService.Notify(owner, "Your stolen treasure returned home.", "info")
	end
	S.StateService.MarkFull(owner)
end

-- Thief made it home: transfer ownership.
function StealService.Complete(thief: Player, item)
	local owner = item.Victim
	local def = TreasureData.Get(item.Id)
	local oData = owner and owner.Parent and S.DataService.Get(owner)
	local oSes = owner and S.DataService.Session(owner)
	if not oData or not oSes or not oData.Treasures[item.VictimUid] then
		S.NetService.Notify(thief, "The owner left — the treasure vanished back to them.", "warn")
		return
	end
	-- validate the treasure is still the same item
	if oData.Treasures[item.VictimUid].Id ~= item.Id then
		oSes.Stealing[item.VictimUid] = nil
		return
	end
	oData.Treasures[item.VictimUid] = nil
	oSes.Stealing[item.VictimUid] = nil
	oData.Stats.Robbed += 1

	local tSes = S.DataService.Session(thief)
	local tData = S.DataService.Get(thief)
	local t = now()
	if tSes then
		tSes.StealCooldownEnd = t + Config.Steal.ThiefCooldown
		tSes.VictimCooldowns[owner.UserId] = t + Config.Steal.SameVictimCooldown
	end
	if tData then
		tData.Stats.Steals += 1
	end

	S.TreasureService.Give(thief, item.Id, { Source = "Steal", Mutation = item.Mut })
	S.EconomyService.AddXP(thief, Config.XP.Steal)
	S.PlayerService.Emote(thief, "Victory", 4)

	-- victim's base locks down for a while (fair cooldown)
	S.BaseService.SetLock(owner, UpgradeData.VictimLock(oData))
	S.BaseService.Refresh(owner)
	S.StateService.MarkFull(owner)

	local name = def and def.Name or "a treasure"
	S.NetService.Notify(owner, ("%s stole your %s! Base auto-locked."):format(thief.DisplayName, name), "error")
	S.NetService.Notify(thief, ("Heist complete! +%s %s"):format(name, def and ("(" .. Util.Money(def.MPS) .. "/s)") or ""), "success")
	if def and (def.Rarity == "Mythical" or def.Rarity == "Secret" or def.Rarity == "Divine") then
		Remotes.Announce:FireAllClients(("🚨 %s stole a %s %s from %s!"):format(thief.DisplayName, def.Rarity, name, owner.DisplayName), def.Rarity)
	end
end

-- If the owner leaves while being robbed, cancel all of those thefts.
local function onOwnerLeaving(owner: Player)
	for _, p in ipairs(Players:GetPlayers()) do
		local ses = S.DataService.Session(p)
		if ses and p ~= owner then
			for _, item in ipairs(table.clone(ses.Carrying)) do
				if item.Source == "Steal" and item.Victim == owner then
					S.CarryService.Remove(p, item)
					S.NetService.Notify(p, owner.DisplayName .. " left — the treasure returned to them.", "warn")
				end
			end
		end
	end
end

-- Bonk Hammer ---------------------------------------------------------------------
local function makeHammer(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Bonk Hammer"
	tool:SetAttribute("Bat", true)
	tool.ToolTip = "Bonk thieves to recover stolen treasure!"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.GripPos = Vector3.new(0, -1.2, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.4, 3, 0.4)
	handle.Color = Color3.fromRGB(140, 90, 50)
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(1.6, 1.2, 1.2)
	head.Color = Color3.fromRGB(255, 80, 90)
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(0, 1.6, 0)
	head.Parent = tool
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(1.65, 0.3, 1.25)
	stripe.Color = Color3.fromRGB(255, 230, 80)
	stripe.Material = Enum.Material.Neon
	stripe.CanCollide = false
	stripe.Massless = true
	stripe.CFrame = head.CFrame
	stripe.Parent = tool
	for _, p in ipairs({ head, stripe }) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	local sound = Instance.new("Sound")
	sound.Name = "Swing"
	sound.SoundId = Config.Sounds.Swing
	sound.Volume = 0.6
	sound.Parent = handle
	local hit = Instance.new("Sound")
	hit.Name = "Hit"
	hit.SoundId = Config.Sounds.Bonk
	hit.Volume = 0.9
	hit.Parent = handle
	return tool
end

local hammerTemplate: Tool

local function onSwing(player: Player, tool: Tool)
	local session = S.DataService.Session(player)
	local hrp = hrpOf(player)
	if not session or not hrp then
		return
	end
	local t = os.clock()
	if t - session.LastBonk < Config.Steal.BonkCooldown then
		return
	end
	session.LastBonk = t
	local handle = tool:FindFirstChild("Handle")
	if handle then
		local swing = handle:FindFirstChild("Swing")
		if swing then
			swing:Play()
		end
	end
	-- swing "animation": tilt the grip forward then back
	tool.Grip = CFrame.new(0, -1.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
	task.delay(0.25, function()
		if tool.Parent then
			tool.Grip = CFrame.new(0, -1.2, 0)
		end
	end)
	-- bat tier stats
	local pdata = S.DataService.Get(player)
	local bat = UpgradeData.BatStats(pdata and pdata.Gear and pdata.Gear.Bat or 0)
	-- find a target in front of us
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local ohrp = hrpOf(other)
			if ohrp then
				local offset = ohrp.Position - hrp.Position
				local dist = offset.Magnitude
				if dist <= bat.Range and (dist < 3 or hrp.CFrame.LookVector:Dot(offset.Unit) > 0.2) then
					local hitSound = handle and handle:FindFirstChild("Hit")
					if hitSound then
						hitSound:Play()
					end
					local recovered = 0
					if S.CarryService.IsCarryingStolen(other) then
						recovered = S.CarryService.DropStolen(other)
					end
					S.PlayerService.Grace(other, 3)
					Remotes.Effect:FireClient(other, "Knockback", (offset.Unit + Vector3.new(0, 0.6, 0)) * bat.Knock, bat.Stun)
					Remotes.Effect:FireClient(player, "BonkHit", ohrp.Position)
					if recovered > 0 then
						local data = S.DataService.Get(player)
						if data then
							data.Stats.Defends += 1
						end
						S.EconomyService.AddXP(player, Config.XP.Defend)
						S.NetService.Notify(player, ("BONK! %s dropped the loot!"):format(other.DisplayName), "success")
						S.NetService.Notify(other, ("%s bonked you! The treasure went home."):format(player.DisplayName), "error")
					end
					break
				end
			end
		end
	end
end

function StealService.GiveHammer(player: Player)
	local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	if not backpack then
		return
	end
	for _, t in ipairs(backpack:GetChildren()) do
		if t:GetAttribute("Bat") then
			return
		end
	end
	if player.Character and player.Character:FindFirstChildWhichIsA("Tool") and player.Character:FindFirstChildWhichIsA("Tool"):GetAttribute("Bat") then
		return
	end
	local tool = hammerTemplate:Clone()
	local data = S.DataService.Get(player)
	local stats = UpgradeData.BatStats(data and data.Gear and data.Gear.Bat or 0)
	tool.Name = stats.Name
	local head = tool:FindFirstChild("Head")
	if head then
		head.Color = stats.Color
		if (data and data.Gear and data.Gear.Bat or 0) >= 2 then
			head.Material = Enum.Material.Neon
		end
	end
	tool.Activated:Connect(function()
		onSwing(player, tool)
	end)
	tool.Parent = backpack
end

-- Replace the bat after a tier upgrade
function StealService.RefreshHammer(player: Player)
	for _, holder in ipairs({ player:FindFirstChildOfClass("Backpack"), player.Character }) do
		if holder then
			for _, t in ipairs(holder:GetChildren()) do
				if t:IsA("Tool") and t:GetAttribute("Bat") then
					t:Destroy()
				end
			end
		end
	end
	StealService.GiveHammer(player)
end

function StealService.Init(services)
	S = services
	hammerTemplate = makeHammer()
end

function StealService.Start()
	Players.PlayerRemoving:Connect(onOwnerLeaving)
end

return StealService
