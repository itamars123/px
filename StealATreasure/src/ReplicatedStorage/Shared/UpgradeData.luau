-- UpgradeData.lua
-- Shop catalogue: levelled upgrades and one-time special abilities.

local Config = require(script.Parent.Config)

local UpgradeData = {}

-- Levelled upgrades. Cost(level) is the price to go FROM `level` to `level+1`.
UpgradeData.Upgrades = {
	Speed = {
		Order = 1,
		Name = "Swift Boots",
		Icon = "👟",
		Description = "+2 walk speed per level.",
		MaxLevel = 12,
		Cost = function(level)
			return math.floor(200 * 2.1 ^ level)
		end,
	},
	Carry = {
		Order = 2,
		Name = "Treasure Backpack",
		Icon = "🎒",
		Description = "+1 treasure you can carry at once.",
		MaxLevel = 5,
		Cost = function(level)
			return math.floor(1500 * 6 ^ level)
		end,
	},
	Base = {
		Order = 3,
		Name = "Base Expansion",
		Icon = "🏰",
		Description = ("+%d display platforms and +5%% base income."):format(Config.PlotsPerBaseLevel),
		MaxLevel = Config.MaxBaseLevel - 1,
		Cost = function(level)
			return math.floor(500 * 3.2 ^ level)
		end,
	},
	Protection = {
		Order = 4,
		Name = "Fortress Security",
		Icon = "🛡️",
		Description = "Longer base lock, shorter lock cooldown, slower steals and longer post-robbery lockdown.",
		MaxLevel = 10,
		Cost = function(level)
			return math.floor(800 * 2.6 ^ level)
		end,
	},
	Luck = {
		Order = 6,
		Name = "Four-Leaf Charm",
		Icon = "🍀",
		Description = "+10% luck: better egg hatches and a chance to upgrade treasures you pick up.",
		MaxLevel = 10,
		Cost = function(level)
			return math.floor(2500 * 2.8 ^ level)
		end,
	},
	Security = {
		Order = 7,
		Name = "Security Cameras & Traps",
		Icon = "📷",
		Description = "Cameras warn you about intruders. +7% chance per level to zap thieves escaping with your loot.",
		MaxLevel = 8,
		Cost = function(level)
			return math.floor(3000 * 3 ^ level)
		end,
	},
	Walls = {
		Order = 8,
		Name = "Reinforced Walls",
		Icon = "🧱",
		Description = "Upgrade your wall material (Wood → Diamond). Each tier makes stealing take longer.",
		MaxLevel = 7,
		Cost = function(level)
			return math.floor(1200 * 3.4 ^ level)
		end,
	},
	Floors = {
		Order = 9,
		Name = "Second Floor",
		Icon = "🏢",
		Description = "Build a second floor with stairs and 12 more display stands.",
		MaxLevel = 1,
		Cost = function()
			return 750000
		end,
	},
	Income = {
		Order = 5,
		Name = "Golden Vault",
		Icon = "💰",
		Description = "+10% money from all treasures.",
		MaxLevel = 15,
		Cost = function(level)
			return math.floor(1000 * 2.4 ^ level)
		end,
	},
}

-- One-time abilities.
UpgradeData.Abilities = {
	Dash = {
		Order = 1,
		Name = "Dash",
		Icon = "💨",
		Key = "Q",
		Description = "Burst forward at high speed.",
		Cost = 2500,
		Cooldown = 6,
	},
	SuperJump = {
		Order = 2,
		Name = "Super Jump",
		Icon = "🦘",
		Key = "R",
		Description = "Huge jumps for 8 seconds. Reach secret areas!",
		Cost = 6000,
		Cooldown = 20,
		Duration = 8,
	},
	Cloak = {
		Order = 3,
		Name = "Shadow Cloak",
		Icon = "👻",
		Key = "F",
		Description = "Turn nearly invisible and hide your name for 8 seconds.",
		Cost = 40000,
		Cooldown = 60,
		Duration = 8,
	},
	Magnet = {
		Order = 4,
		Name = "Treasure Magnet",
		Icon = "🧲",
		Key = nil,
		Description = "Passive: automatically grab free world treasures near you.",
		Cost = 120000,
		Cooldown = 0,
		Radius = 18,
	},
}

-- Gear: tools bought with money (kept through rebirth).
UpgradeData.Gear = {
	Bat = {
		Order = 1,
		Name = "Bonk Bat",
		Icon = "🏏",
		Levels = { "Wooden Bonk Hammer", "Iron Bat", "Diamond Bat", "Galaxy Bat" },
		Costs = { 25000, 400000, 6000000 },
		Description = "Bigger bonks: longer reach, longer stun, bigger knockback.",
	},
	SpeedCoil = { Order = 2, Name = "Speed Coil", Icon = "🌀", Cost = 15000, Description = "Hold it to run +6 faster." },
	Grapple = { Order = 3, Name = "Grapple Hook", Icon = "🪝", Cost = 90000, Description = "Click to zip to a spot up to 90 studs away (4s cooldown)." },
	Trap = { Order = 4, Name = "Bear Trap", Icon = "🪤", Cost = 60000, Description = "Place up to 3 traps in your base. Thieves get stuck and drop their loot." },
}

function UpgradeData.BatStats(level: number)
	level = level or 0
	return {
		Name = UpgradeData.Gear.Bat.Levels[level + 1],
		Range = 9 + level * 2,
		Stun = 1.2 + level * 0.4,
		Knock = 60 + level * 20,
		Color = ({ Color3.fromRGB(255, 80, 90), Color3.fromRGB(170, 175, 185), Color3.fromRGB(120, 230, 255), Color3.fromRGB(150, 80, 255) })[level + 1],
	}
end

-- Gem shop: boosts and permanent perks bought with gems.
UpgradeData.GemShop = {
	MoneyBoost = { Order = 1, Name = "2x Money (15 min)", Icon = "💸", Cost = 100, Boost = "Money", Duration = 900, Description = "Double all income for 15 minutes." },
	LuckBoost = { Order = 2, Name = "2x Luck (15 min)", Icon = "🍀", Cost = 80, Boost = "Luck", Duration = 900, Description = "+100% luck for 15 minutes." },
	SpeedBoost = { Order = 3, Name = "Speed Potion (10 min)", Icon = "⚡", Cost = 50, Boost = "Speed", Duration = 600, Description = "+8 walk speed for 10 minutes." },
	AutoCollect = { Order = 4, Name = "Auto Collector", Icon = "🤖", Cost = 400, Permanent = true, Description = "Income goes straight to your wallet. No more collecting!" },
	PetSlot = { Order = 5, Name = "+1 Pet Slot", Icon = "🐾", Cost = 250, Description = "Equip one more pet (max 6)." },
}

-- Base colour palette for personalisation
UpgradeData.BaseColors = {
	Color3.fromRGB(255, 95, 95), Color3.fromRGB(255, 170, 60), Color3.fromRGB(250, 220, 70),
	Color3.fromRGB(100, 220, 110), Color3.fromRGB(70, 200, 255), Color3.fromRGB(120, 120, 255),
	Color3.fromRGB(200, 110, 255), Color3.fromRGB(255, 110, 200), Color3.fromRGB(60, 60, 75),
	Color3.fromRGB(245, 245, 250), Color3.fromRGB(40, 200, 170), Color3.fromRGB(150, 90, 50),
}

-- Wall tiers (index = Walls upgrade level + 1)
UpgradeData.WallTiers = {
	{ Name = "Wood", Material = "WoodPlanks" },
	{ Name = "Brick", Material = "Brick" },
	{ Name = "Stone", Material = "Cobblestone" },
	{ Name = "Slate", Material = "Slate" },
	{ Name = "Steel", Material = "DiamondPlate" },
	{ Name = "Marble", Material = "Marble" },
	{ Name = "Gold", Material = "Foil" },
	{ Name = "Diamond", Material = "Glass" },
}

function UpgradeData.SortedKeys(tbl)
	local keys = {}
	for k in pairs(tbl) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tbl[a].Order < tbl[b].Order
	end)
	return keys
end

-- Derived stats ------------------------------------------------------------
local function boostActive(data, name)
	return data.Boosts and (data.Boosts[name] or 0) > os.time()
end
UpgradeData.BoostActive = boostActive

function UpgradeData.WalkSpeed(data, petSpeed: number?)
	local rebirthBonus = math.min(Config.Rebirth.MaxSpeedBonus, (data.Rebirths or 0) * Config.Rebirth.SpeedBonusPerRebirth)
	local boost = boostActive(data, "Speed") and 8 or 0
	return Config.BaseWalkSpeed + (data.Upgrades.Speed or 0) * 2 + rebirthBonus + boost + (petSpeed or 0)
end

-- Luck multiplier (1 = normal). eventBonus/petBonus are additive (+0.5 = +50%).
function UpgradeData.Luck(data, petBonus: number?, eventBonus: number?)
	local l = 1 + (data.Upgrades.Luck or 0) * Config.Luck.PerUpgrade
	if boostActive(data, "Luck") then
		l += 1
	end
	return l + (petBonus or 0) + (eventBonus or 0)
end

function UpgradeData.WallTier(data)
	return UpgradeData.WallTiers[math.clamp((data.Upgrades.Walls or 0) + 1, 1, #UpgradeData.WallTiers)]
end

function UpgradeData.PetSlots(data)
	return math.min(Config.Pets.MaxSlots, Config.Pets.StartSlots + (data.ExtraPetSlots or 0))
end

function UpgradeData.CarryCapacity(data)
	return 1 + (data.Upgrades.Carry or 0)
end

function UpgradeData.BaseLevel(data)
	return 1 + (data.Upgrades.Base or 0)
end

function UpgradeData.PlotCount(data)
	local total = Config.PlotColumns * Config.PlotRows
	local ground = math.min(total, Config.StartingPlots + (UpgradeData.BaseLevel(data) - 1) * Config.PlotsPerBaseLevel)
	return ground + ((data.Upgrades.Floors or 0) > 0 and Config.SecondFloorPlots or 0)
end

function UpgradeData.LockDuration(data)
	return Config.Lock.BaseDuration + (data.Upgrades.Protection or 0) * Config.Lock.DurationPerLevel
end

function UpgradeData.LockCooldown(data)
	return math.max(15, Config.Lock.BaseCooldown - (data.Upgrades.Protection or 0) * Config.Lock.CooldownReductionPerLevel)
end

function UpgradeData.StealHold(data)
	return Config.Steal.BaseHoldDuration + (data.Upgrades.Protection or 0) * Config.Steal.HoldPerProtectionLevel + (data.Upgrades.Walls or 0) * Config.Security.WallHoldBonus
end

function UpgradeData.VictimLock(data)
	return Config.Steal.VictimAutoLock + (data.Upgrades.Protection or 0) * Config.Steal.VictimAutoLockPerLevel
end

-- auraBonus: summed Aura of placed treasures. petBonus: summed pet income bonus.
function UpgradeData.IncomeMultiplier(data, auraBonus: number?, petBonus: number?)
	local m = 1 + (auraBonus or 0) + (petBonus or 0)
	m += (data.Rebirths or 0) * Config.Rebirth.IncomeBonusPerRebirth
	m += (data.Upgrades.Income or 0) * 0.10
	m += (UpgradeData.BaseLevel(data) - 1) * 0.05
	if boostActive(data, "Money") then
		m *= 2
	end
	return m
end

return UpgradeData
