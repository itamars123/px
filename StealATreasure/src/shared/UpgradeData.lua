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
function UpgradeData.WalkSpeed(data)
	local rebirthBonus = math.min(Config.Rebirth.MaxSpeedBonus, (data.Rebirths or 0) * Config.Rebirth.SpeedBonusPerRebirth)
	return Config.BaseWalkSpeed + (data.Upgrades.Speed or 0) * 2 + rebirthBonus
end

function UpgradeData.CarryCapacity(data)
	return 1 + (data.Upgrades.Carry or 0)
end

function UpgradeData.BaseLevel(data)
	return 1 + (data.Upgrades.Base or 0)
end

function UpgradeData.PlotCount(data)
	local total = Config.PlotColumns * Config.PlotRows
	return math.min(total, Config.StartingPlots + (UpgradeData.BaseLevel(data) - 1) * Config.PlotsPerBaseLevel)
end

function UpgradeData.LockDuration(data)
	return Config.Lock.BaseDuration + (data.Upgrades.Protection or 0) * Config.Lock.DurationPerLevel
end

function UpgradeData.LockCooldown(data)
	return math.max(15, Config.Lock.BaseCooldown - (data.Upgrades.Protection or 0) * Config.Lock.CooldownReductionPerLevel)
end

function UpgradeData.StealHold(data)
	return Config.Steal.BaseHoldDuration + (data.Upgrades.Protection or 0) * Config.Steal.HoldPerProtectionLevel
end

function UpgradeData.VictimLock(data)
	return Config.Steal.VictimAutoLock + (data.Upgrades.Protection or 0) * Config.Steal.VictimAutoLockPerLevel
end

function UpgradeData.IncomeMultiplier(data)
	local m = 1
	m += (data.Rebirths or 0) * Config.Rebirth.IncomeBonusPerRebirth
	m += (data.Upgrades.Income or 0) * 0.10
	m += (UpgradeData.BaseLevel(data) - 1) * 0.05
	return m
end

return UpgradeData
