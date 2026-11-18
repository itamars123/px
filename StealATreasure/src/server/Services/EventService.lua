-- EventService.lua
-- Timed world events that pull players to special locations:
--   Double Money        - 2x income for everyone, fountain turns gold
--   Meteor Shower       - meteors crash into the Meteor Crater dropping Epic+ loot
--   Golden Treasure Rain- golden coins + free treasures rain on every field
--   Treasure Apocalypse - the sky turns red and high-rarity treasures flood the map
--   Secret Treasure     - a Secret/Divine/Celestial treasure appears in a secret area
--   Lucky Treasure      - everyone's luck is doubled and lucky treasures spawn
--   Divine Descent      - a Mythical+ treasure descends onto the Celestial Shrine

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local TreasureData = require(Shared.TreasureData)
local Remotes = require(Shared.Remotes)

local S

local EventService = {}
EventService.Current = nil :: string?

local rng = Random.new()

local function setState(name: string?, duration: number)
	EventService.Current = name
	workspace:SetAttribute("Event", name or "")
	workspace:SetAttribute("EventEnd", name and (workspace:GetServerTimeNow() + duration) or 0)
	Remotes.EventState:FireAllClients(name, duration)
end

local function goldenHour()
	local d = Config.Events.GoldenHourDuration
	setState("Double Money", d)
	Remotes.Announce:FireAllClients(("💸 DOUBLE MONEY! All income x%d for %ds!"):format(Config.Events.GoldenHourMultiplier, d), "Legendary")
	S.EconomyService.EventMultiplier = Config.Events.GoldenHourMultiplier
	local water = S.MapBuilder.Map.FountainWater
	local oldColor = water and water.Color
	if water then
		water.Color = Color3.fromRGB(255, 210, 60)
		water.Material = Enum.Material.Neon
	end
	task.wait(d)
	S.EconomyService.EventMultiplier = 1
	if water then
		water.Color = oldColor
		water.Material = Enum.Material.Glass
	end
	setState(nil, 0)
end

local function meteorShower()
	local crater = S.MapBuilder.Map.Crater
	setState("Meteor Shower", 40)
	Remotes.Announce:FireAllClients("☄️ METEOR SHOWER at the Meteor Crater! Epic+ treasures incoming!", "Epic")
	task.wait(4)
	for i = 1, Config.Events.MeteorCount do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, crater.Radius - 6)
		local target = crater.Center + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r)
		local start = target + Vector3.new(rng:NextNumber(-60, 60), 260, rng:NextNumber(-60, 60))
		local meteor = Instance.new("Part")
		meteor.Shape = Enum.PartType.Ball
		meteor.Size = Vector3.new(7, 7, 7)
		meteor.Material = Enum.Material.CrackedLava
		meteor.Color = Color3.fromRGB(255, 120, 40)
		meteor.Anchored = true
		meteor.CanCollide = false
		meteor.CanQuery = false
		meteor.CFrame = CFrame.new(start)
		local fire = Instance.new("Fire")
		fire.Size = 14
		fire.Heat = 20
		fire.Parent = meteor
		local light = Instance.new("PointLight")
		light.Range = 40
		light.Brightness = 4
		light.Color = Color3.fromRGB(255, 140, 40)
		light.Parent = meteor
		meteor.Parent = workspace
		local tween = TweenService:Create(meteor, TweenInfo.new(2.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(target) })
		tween:Play()
		task.delay(2.2, function()
			local boom = Instance.new("Explosion")
			boom.Position = target
			boom.BlastRadius = 10
			boom.BlastPressure = 0 -- visual only, nobody gets hurt
			boom.DestroyJointRadiusPercent = 0
			boom.Parent = workspace
			Remotes.Effect:FireAllClients("Shake", target, 0.6)
			meteor.Anchored = true
			Debris:AddItem(meteor, 0.2)
			local def = TreasureData.RollFromPool(Config.SpawnPools.Meteor, rng)
			S.TreasureService.SpawnWorld(def, CFrame.new(target), "Event", { Region = "Meteor Crater", Lifetime = 180 })
		end)
		task.wait(rng:NextNumber(1.5, 4))
	end
	task.wait(20)
	setState(nil, 0)
end

local function treasureRain()
	setState("Golden Treasure Rain", 40)
	Remotes.Announce:FireAllClients("🪙 GOLDEN TREASURE RAIN! Coins and treasures are falling on every field!", "Legendary")
	local fields = S.MapBuilder.Map.Fields
	for i = 1, Config.Events.TreasureRainCount do
		local field = fields[rng:NextInteger(1, #fields)]
		S.TreasureService.SpawnInField(field, { Uncommon = 40, Rare = 35, Epic = 18, Legendary = 6, Mythical = 1 })
		for _ = 1, 3 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, field.Radius + 6)
			S.WorldService.SpawnCoin(field.Center + Vector3.new(math.cos(a) * r, 0.5, math.sin(a) * r))
		end
		task.wait(0.8)
	end
	task.wait(15)
	setState(nil, 0)
end

-- Mutation events: everything that spawns has a big chance to mutate
local function mutationEvent(name: string, title: string, text: string, rarity: string)
	local d = 90
	setState(title, d)
	Remotes.Announce:FireAllClients(text, rarity)
	S.TreasureService.EventMutation = name
	task.wait(d)
	S.TreasureService.EventMutation = nil
	setState(nil, 0)
end

local function lavaEvent()
	mutationEvent("Lava", "Lava Eruption", "🌋 LAVA ERUPTION! Treasures are spawning with the LAVA mutation (x2.5)!", "Mythical")
end

local function rainbowEvent()
	mutationEvent("Rainbow", "Rainbow Storm", "🌈 RAINBOW STORM! Rainbow mutations (x2) everywhere!", "Divine")
end

local function apocalypse()
	local d = Config.Events.ApocalypseDuration
	setState("Treasure Apocalypse", d)
	Remotes.Announce:FireAllClients("☠️ TREASURE APOCALYPSE! The sky burns and legendary loot floods the world!", "Secret")
	Remotes.Effect:FireAllClients("GlobalShake", 0.4)
	local fields = S.MapBuilder.Map.Fields
	local t = 0
	while t < d do
		local field = fields[rng:NextInteger(1, #fields)]
		S.TreasureService.SpawnInField(field, Config.SpawnPools.Apocalypse)
		if rng:NextNumber() < 0.4 then
			local crater = S.MapBuilder.Map.Crater
			local def = TreasureData.RollFromPool(Config.SpawnPools.Apocalypse, rng)
			local a = rng:NextNumber(0, math.pi * 2)
			S.TreasureService.SpawnWorld(def, CFrame.new(crater.Center + Vector3.new(math.cos(a) * 20, 0.5, math.sin(a) * 20)), "Event", { Region = "Meteor Crater", Lifetime = 90 })
		end
		task.wait(3)
		t += 3
	end
	setState(nil, 0)
end

local function secretSpawn()
	local secrets = S.MapBuilder.Map.Secrets
	local secret = secrets[rng:NextInteger(1, #secrets)]
	local def = TreasureData.RollFromPool(Config.SpawnPools.SecretSpawn, rng)
	setState("Secret Treasure", 90)
	Remotes.Announce:FireAllClients(("🤫 SECRET TREASURE! A %s treasure appeared somewhere in the %s!"):format(def.Rarity, secret.Name), def.Rarity)
	local spot = secret.Spawns[rng:NextInteger(1, #secret.Spawns)] + Vector3.new(0, 0.5, 0)
	local record = S.TreasureService.SpawnWorld(def, CFrame.new(spot), "Event", { Region = secret.Name, Lifetime = 90 })
	local t = 0
	while t < 90 and S.TreasureService.World[record.Uid] do
		task.wait(1)
		t += 1
	end
	setState(nil, 0)
end

local function luckyEvent()
	local d = Config.Events.LuckyDuration
	setState("Lucky Treasure", d)
	Remotes.Announce:FireAllClients(("🍀 LUCKY TREASURE EVENT! Everyone has x%d luck for %ds!"):format(Config.Events.LuckyMultiplier, d), "Epic")
	S.EconomyService.EventLuck = Config.Events.LuckyMultiplier - 1
	local fields = S.MapBuilder.Map.Fields
	local t = 0
	while t < d do
		local field = fields[rng:NextInteger(1, #fields)]
		S.TreasureService.SpawnInField(field, Config.SpawnPools.Lucky)
		task.wait(10)
		t += 10
	end
	S.EconomyService.EventLuck = 0
	setState(nil, 0)
end

local function divineDescent()
	local altar = S.MapBuilder.Map.ShrineAltar
	setState("Divine Descent", 120)
	Remotes.Announce:FireAllClients("👼 DIVINE DESCENT! A legendary relic is descending on the Celestial Shrine!", "Divine")
	task.wait(6)
	local def = TreasureData.RollFromPool(Config.SpawnPools.Divine, rng)
	local record = S.TreasureService.SpawnWorld(def, altar, "Event", { Region = "Celestial Shrine", Lifetime = 120 })
	Remotes.Announce:FireAllClients(("👼 A %s %s has landed on the shrine! First come, first served!"):format(def.Rarity, def.Name), def.Rarity)
	local t = 0
	while t < 120 and S.TreasureService.World[record.Uid] do
		task.wait(1)
		t += 1
	end
	setState(nil, 0)
end

local EVENTS = {
	{ Fn = goldenHour, Weight = 22 },
	{ Fn = meteorShower, Weight = 20 },
	{ Fn = treasureRain, Weight = 20 },
	{ Fn = luckyEvent, Weight = 16 },
	{ Fn = secretSpawn, Weight = 10 },
	{ Fn = apocalypse, Weight = 6 },
	{ Fn = divineDescent, Weight = 6 },
	{ Fn = lavaEvent, Weight = 10 },
	{ Fn = rainbowEvent, Weight = 10 },
}

function EventService.RunRandom()
	local total = 0
	for _, e in ipairs(EVENTS) do
		total += e.Weight
	end
	local pick = rng:NextNumber() * total
	for _, e in ipairs(EVENTS) do
		if pick <= e.Weight then
			e.Fn()
			return
		end
		pick -= e.Weight
	end
end

function EventService.Init(services)
	S = services
end

function EventService.Start()
	setState(nil, 0)
	-- Studio-only testing helper: trigger any event from the Settings menu
	if game:GetService("RunService"):IsStudio() then
		local byName = {
			DoubleMoney = goldenHour,
			Meteor = meteorShower,
			GoldenRain = treasureRain,
			Lucky = luckyEvent,
			Secret = secretSpawn,
			Apocalypse = apocalypse,
			Divine = divineDescent,
			Lava = lavaEvent,
			Rainbow = rainbowEvent,
		}
		S.NetService.Handle("DebugEvent", function(_, name)
			local fn = byName[name]
			if not fn or EventService.Current then
				return false, "Unknown event or one is already running"
			end
			task.spawn(fn)
			return true, "Started " .. name
		end)
	end
	task.spawn(function()
		while true do
			local wait = rng:NextNumber(Config.Events.IntervalMin, Config.Events.IntervalMax)
			workspace:SetAttribute("NextEvent", workspace:GetServerTimeNow() + wait)
			task.wait(wait)
			local ok, err = pcall(EventService.RunRandom)
			if not ok then
				warn("[Events] " .. tostring(err))
				setState(nil, 0)
				S.EconomyService.EventMultiplier = 1
				S.EconomyService.EventLuck = 0
				S.TreasureService.EventMutation = nil
			end
		end
	end)
end

return EventService
