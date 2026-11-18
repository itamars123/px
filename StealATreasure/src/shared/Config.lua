-- Config.lua
-- Central tuning values for STEAL A TREASURE. Everything gameplay-related that a
-- designer might want to tweak lives here so the services stay logic-only.

local Config = {}

Config.GameName = "STEAL A TREASURE"
Config.DataVersion = 3
Config.DataStoreName = "StealATreasure_PlayerData_v3"
Config.LeaderboardStoreName = "StealATreasure_Richest_v3"
Config.RebirthBoardStoreName = "StealATreasure_Rebirths_v3"

-- Economy ------------------------------------------------------------------
Config.StartingMoney = 150
Config.IncomeTickSeconds = 1
Config.SellMultiplier = 0.5 -- treasures sell for 50% of their value
Config.OfflineIncomeRate = 0.1 -- 10% of MPS while offline
Config.OfflineIncomeMaxSeconds = 8 * 3600
Config.AutosaveSeconds = 90
Config.DiscoveryBonusMultiplier = 3 -- first time you own a treasure: +3x its MPS*10

-- Levels -------------------------------------------------------------------
Config.XP = {
	Collect = 10,
	Buy = 15,
	Steal = 40,
	Defend = 25,
	Sell = 3,
}
function Config.XPForLevel(level: number): number
	return math.floor(100 * level ^ 1.45)
end

-- Base ---------------------------------------------------------------------
Config.MaxBases = 8
Config.BaseRingRadius = 230
Config.BaseSize = 72
Config.BaseWallHeight = 22
Config.PlotColumns = 6
Config.PlotRows = 4
Config.PlotSpacing = 9
Config.StartingPlots = 6
Config.PlotsPerBaseLevel = 2
Config.MaxBaseLevel = 10
Config.MaxStorage = 60 -- inventory (unplaced) capacity

-- Stealing / protection -----------------------------------------------------
Config.Steal = {
	BaseHoldDuration = 1.6,
	HoldPerProtectionLevel = 0.25,
	ThiefCooldown = 25, -- seconds between successful steals
	SameVictimCooldown = 75, -- seconds before you can steal from the same player again
	VictimAutoLock = 20, -- base locks for this long after being robbed (+ protection)
	VictimAutoLockPerLevel = 4,
	NewPlayerShield = 90, -- new arrivals can't be robbed for this long
	CarryTimeout = 120, -- stolen treasure returns home if not delivered in time
	MaxPromptDistance = 12,
	BonkRange = 9,
	BonkCooldown = 1.2,
	BonkStun = 1.2,
}

Config.Lock = {
	BaseDuration = 30,
	DurationPerLevel = 8,
	BaseCooldown = 60,
	CooldownReductionPerLevel = 3,
}

-- World spawns -------------------------------------------------------------
Config.Spawns = {
	FieldInterval = 6, -- seconds between field spawn attempts
	MaxPerField = 4,
	SecretInterval = 25,
	MaxPerSecret = 2,
	Lifetime = 150,
	PickupDistance = 12,
}

Config.Market = {
	Stalls = 10,
	RestockSeconds = 45,
	PriceMultiplier = 1.0,
}

-- Rarity weights used by the different spawn pools.
Config.SpawnPools = {
	Field = { Common = 60, Uncommon = 26, Rare = 10, Epic = 3.2, Legendary = 0.7, Mythical = 0.1 },
	Market = { Common = 30, Uncommon = 30, Rare = 22, Epic = 11, Legendary = 5, Mythical = 1.6, Secret = 0.35, Divine = 0.05 },
	Secret = { Rare = 40, Epic = 32, Legendary = 18, Mythical = 7, Secret = 2.5, Divine = 0.5 },
	Meteor = { Epic = 55, Legendary = 30, Mythical = 12, Secret = 2.6, Divine = 0.4 },
	Divine = { Mythical = 60, Secret = 30, Divine = 10 },
}

-- Events -------------------------------------------------------------------
Config.Events = {
	IntervalMin = 240,
	IntervalMax = 360,
	GoldenHourDuration = 120,
	GoldenHourMultiplier = 2,
	TreasureRainCount = 24,
	MeteorCount = 6,
}

-- Rebirth ------------------------------------------------------------------
Config.Rebirth = {
	BaseCost = 250000,
	CostGrowth = 3.5,
	IncomeBonusPerRebirth = 0.5, -- +50% income each rebirth
	SpeedBonusPerRebirth = 1, -- +1 walkspeed each rebirth (cap below)
	MaxSpeedBonus = 10,
	StartingMoneyPerRebirth = 1000,
}
function Config.RebirthCost(rebirths: number): number
	return math.floor(Config.Rebirth.BaseCost * Config.Rebirth.CostGrowth ^ rebirths)
end

-- Rebirth milestone rewards (exclusive treasures / trails / titles)
Config.RebirthRewards = {
	[1] = { Treasure = "Phoenix Ember", Title = "Reborn", Trail = Color3.fromRGB(255, 140, 40) },
	[3] = { Treasure = "Chrono Hourglass", Title = "Timeless", Trail = Color3.fromRGB(90, 200, 255) },
	[5] = { Treasure = "Void Crown", Title = "Void Walker", Trail = Color3.fromRGB(150, 60, 255) },
	[10] = { Treasure = "Eternity Heart", Title = "Eternal", Trail = Color3.fromRGB(255, 255, 255) },
}

-- Movement ------------------------------------------------------------------
Config.BaseWalkSpeed = 18
Config.BaseJumpPower = 50

-- Remote rate limiting ------------------------------------------------------
Config.RateLimit = {
	Window = 1,
	MaxRequests = 12,
}

-- Trading -------------------------------------------------------------------
Config.Trade = {
	MaxItems = 8,
	RequestTimeout = 20,
	ConfirmCountdown = 3,
	MaxDistance = math.huge, -- trading works across the map
}

-- Sound IDs. rbxasset:// sounds ship with every Roblox client, so they always
-- load. Swap in your own rbxassetid:// uploads for a custom soundtrack.
Config.Sounds = {
	Click = "rbxasset://sounds/button.wav",
	Hover = "rbxasset://sounds/clickfast.wav",
	Pickup = "rbxasset://sounds/electronicpingshort.wav",
	Deposit = "rbxasset://sounds/electronicpingshort.wav",
	Purchase = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/clickfast.wav",
	Alarm = "rbxasset://sounds/electronicpingshort.wav",
	Bonk = "rbxasset://sounds/swordslash.wav",
	Swing = "rbxasset://sounds/swordlunge.wav",
	Dash = "rbxasset://sounds/swoosh.wav",
	Jump = "rbxasset://sounds/action_jump.mp3",
	Rebirth = "rbxasset://sounds/victory.wav",
	LevelUp = "rbxasset://sounds/victory.wav",
	Legendary = "rbxasset://sounds/electronicpingshort.wav",
	Event = "rbxasset://sounds/electronicpingshort.wav",
	Lock = "rbxasset://sounds/snap.wav",
	-- Background music. Set to an uploaded/licensed audio asset id to enable.
	Music = "",
}

return Config
