-- Config.lua
-- Central tuning values for STEAL A TREASURE. Everything gameplay-related that a
-- designer might want to tweak lives here so the services stay logic-only.

local Config = {}

Config.GameName = "STEAL A TREASURE"
Config.DataVersion = 4
Config.DataStoreName = "StealATreasure_PlayerData_v3" -- legacy store (imported once)
Config.ProfileStoreName = "StealATreasure_Profiles_v4"
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
Config.SecondFloorPlots = 12
Config.SecondFloorHeight = 13

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

-- Layout: bases line both sides of the Treasure Parade; the plaza sits at
-- the parade's start.
Config.PlazaCenter = Vector3.new(-340, 0, 0)
Config.BaseRowZ = 80 -- base centres at z = +/-80, facing the parade
Config.BaseColumnsX = { -168, -56, 56, 168 }
Config.Parade = {
	StartX = -248,
	EndX = 248,
	Z = 0,
	Width = 14,
	Speed = 7, -- studs per second
	Interval = 2.6, -- seconds between treasures
}

Config.Market = {
	Stalls = 0, -- the walking Treasure Parade replaced the old stalls
	RestockSeconds = 45,
	PriceMultiplier = 1.0,
}

-- Rarity weights used by the different spawn pools.
Config.SpawnPools = {
	Field = { Common = 60, Uncommon = 26, Rare = 10, Epic = 3.2, Legendary = 0.7, Mythical = 0.1 },
	Market = { Common = 30, Uncommon = 30, Rare = 22, Epic = 11, Legendary = 5, Mythical = 1.6, Secret = 0.35, Divine = 0.05, Celestial = 0.01 },
	Secret = { Rare = 40, Epic = 32, Legendary = 18, Mythical = 7, Secret = 2.5, Divine = 0.5, Celestial = 0.08 },
	Meteor = { Epic = 55, Legendary = 30, Mythical = 12, Secret = 2.6, Divine = 0.4, Celestial = 0.05 },
	Divine = { Mythical = 55, Secret = 30, Divine = 12, Celestial = 3 },
	Apocalypse = { Epic = 40, Legendary = 35, Mythical = 18, Secret = 5, Divine = 1.6, Celestial = 0.4 },
	SecretSpawn = { Secret = 75, Divine = 20, Celestial = 5 },
	Lucky = { Rare = 30, Epic = 35, Legendary = 22, Mythical = 9, Secret = 3, Divine = 0.8, Celestial = 0.2 },
}

-- Events -------------------------------------------------------------------
Config.Events = {
	IntervalMin = 240,
	IntervalMax = 360,
	GoldenHourDuration = 120,
	GoldenHourMultiplier = 2,
	TreasureRainCount = 24,
	MeteorCount = 6,
	ApocalypseDuration = 75,
	LuckyDuration = 150,
	LuckyMultiplier = 2,
	CoinValueSeconds = 4, -- golden coins are worth this many seconds of your income
}

-- Gems (premium soft currency) ---------------------------------------------
Config.Gems = {
	Start = 25,
	PerLevel = 3, -- gems = level * PerLevel on level up
	SecretFound = 25,
	Rebirth = 60,
	DiscoveryByRank = { [4] = 2, [5] = 5, [6] = 10, [7] = 20, [8] = 40, [9] = 80 },
}

-- Sprint / stamina ------------------------------------------------------------
Config.Sprint = {
	Multiplier = 1.45,
	MaxStamina = 100,
	Drain = 18, -- per second
	Regen = 12, -- per second
	MinToStart = 15,
}

-- Security systems -----------------------------------------------------------
Config.Security = {
	TrapChancePerLevel = 0.07, -- chance a thief is zapped leaving your base, per Security level
	MaxTrapChance = 0.6,
	CameraAlertCooldown = 20,
	WallHoldBonus = 0.15, -- extra steal hold seconds per wall tier
}

-- World ---------------------------------------------------------------------
Config.World = {
	DayLength = 720, -- seconds for a full day/night cycle
	WeatherMin = 150,
	WeatherMax = 300,
	Weather = { Clear = 40, Cloudy = 25, Rain = 18, Storm = 9, Fog = 8 },
	ChestInterval = 45,
	MaxChests = 5,
	WanderRadius = 7,
}

-- Luck --------------------------------------------------------------------------
Config.Luck = {
	PerUpgrade = 0.1,
	UpgradeChancePerLuck = 0.08, -- chance per +1.0 luck to bump a pickup up one rarity
	MaxUpgradeChance = 0.5,
}

-- Pets -------------------------------------------------------------------------
Config.Pets = {
	StartSlots = 3,
	MaxSlots = 6,
	MaxOwned = 120,
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
-- Each rebirth also requires owning certain treasures (kept until you rebirth).
local REQ = {
	{ Rarity = "Epic", Count = 1 },
	{ Rarity = "Legendary", Count = 1 },
	{ Rarity = "Legendary", Count = 2 },
	{ Rarity = "Mythical", Count = 1 },
	{ Rarity = "Mythical", Count = 2 },
	{ Rarity = "Secret", Count = 1 },
	{ Rarity = "Secret", Count = 2 },
	{ Rarity = "Divine", Count = 1 },
	{ Rarity = "Divine", Count = 2 },
	{ Rarity = "Celestial", Count = 1 },
}
function Config.RebirthRequirement(rebirths: number)
	return REQ[math.min(rebirths + 1, #REQ)]
end

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

-- Monetization ---------------------------------------------------------------
-- Create these in the Creator Dashboard and paste the IDs. While an ID is 0
-- the item is hidden from the shop and nothing can be bought.
Config.Monetization = {
	GamePasses = {
		DoubleMoney = { Id = 0, Name = "2x Money", Icon = "💸", Robux = 199, Description = "Permanently double all income." },
		VIP = { Id = 0, Name = "VIP", Icon = "👑", Robux = 149, Description = "VIP title, +1 pet slot and +25% luck." },
		ExtraCarry = { Id = 0, Name = "Big Backpack", Icon = "🎒", Robux = 99, Description = "Carry +1 more treasure." },
	},
	Products = {
		Gems500 = { Id = 0, Name = "500 Gems", Icon = "💎", Robux = 49, Gems = 500 },
		Gems2500 = { Id = 0, Name = "2,500 Gems", Icon = "💎", Robux = 199, Gems = 2500 },
		MoneyBoost = { Id = 0, Name = "2x Money (30 min)", Icon = "⏳", Robux = 39, Boost = "Money", Duration = 1800 },
	},
}

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
	Collect = "rbxasset://sounds/electronicpingshort.wav",
	Steal = "rbxasset://sounds/swordlunge.wav",
	Spawn = "rbxasset://sounds/clickfast.wav",
	ChestOpen = "rbxasset://sounds/unsheath.wav",
	Hatch = "rbxasset://sounds/snap.wav",
	Thunder = "rbxasset://sounds/Rocket shot.wav",
	Portal = "rbxasset://sounds/swoosh.wav",
	Discovery = "rbxasset://sounds/victory.wav",
	-- The built-in music sequencer plays melodies with this note sample.
	MusicNote = "rbxasset://sounds/electronicpingshort.wav",
	MusicBass = "rbxasset://sounds/button.wav",
	-- Optional: an uploaded/licensed music asset id. When set it replaces the
	-- built-in procedural soundtrack.
	Music = "",
}

return Config
