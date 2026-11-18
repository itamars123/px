-- TreasureData.lua
-- 102 collectable treasures + 4 rebirth-exclusive treasures.
-- Each row: Name | Shape | PrimaryHex | SecondaryHex | Material | Fx(optional)
-- Value and money-per-second are derived from rarity and position in the tier so
-- the economy curve stays smooth; every treasure is still unique in model,
-- colours, material, effect, value and income.

local Rarities = require(script.Parent.Rarities)

local RAW = {
	Common = {
		"Rusty Coin|CoinStack|8a5a3c|b07040|Metal",
		"Copper Coins|CoinStack|c87533|e09050|Metal",
		"Pebble Gem|Gem|9aa0a6|c0c4c8|Pebble",
		"Wooden Chest|Chest|8b5a2b|5a3a1a|Wood",
		"Clay Chalice|Chalice|b5651d|d08040|Slate",
		"Tin Ring|Ring|a8a9ad|d0d0d0|Metal",
		"Old Key|Key|6e5a3a|9a8060|Metal",
		"Glass Marble|Orb|7fc8ff|ffffff|Glass",
		"Stone Idol|Idol|7d7d7d|5a5a5a|Slate",
		"Candle Lamp|Lamp|e8d8a0|ff9a30|SmoothPlastic",
		"Mossy Egg|Egg|6b8e23|9acd32|Grass",
		"Paper Crown|Crown|f0e0b0|e05050|Fabric",
		"Bone Skull|Skull|e8e0d0|a09080|SmoothPlastic",
		"Plain Potion|Potion|a0d0a0|ffffff|Glass",
		"Iron Shield|Shield|808890|505860|DiamondPlate",
		"Toy Sword|Sword|d0d0d0|4060c0|Plastic",
		"Sand Pyramid|Pyramid|e0c080|c0a060|Sand",
		"Cobble Cube|Cube|b0b0a0|909080|Cobblestone",
	},
	Uncommon = {
		"Silver Coins|CoinStack|c0c0c8|e8e8f0|Metal",
		"Jade Gem|Gem|00a86b|50d0a0|Glass|Leaves",
		"Bronze Trophy|Trophy|cd7f32|a0602a|Metal",
		"Emerald Ring|Ring|d4af37|50c878|Metal",
		"Sea Shell Orb|Orb|ffc0cb|ffffff|Marble|Bubbles",
		"Fern Feather|Feather|4caf50|8bc34a|Grass|Leaves",
		"Copper Lamp|Lamp|b87333|ffcc66|Metal",
		"Clover Charm|Star|3cb043|a0e080|Neon|Leaves",
		"Amber Egg|Egg|ffbf00|ff8c00|Glass",
		"Bandit Mask|Mask|303030|c03030|Fabric",
		"Silver Key|Key|c0c0c0|80d0ff|Metal|Spark",
		"Herbal Potion|Potion|40c040|a0ff80|Glass|Bubbles",
		"Knight Shield|Shield|4060a0|d0d0d0|Metal",
		"Steel Sword|Sword|c8ccd0|8b4513|Metal",
		"Spell Book|Book|6a3d9a|e0c060|Fabric",
		"Rose Quartz|Crystal|f7cac9|ffffff|Glass",
	},
	Rare = {
		"Gold Coins|CoinStack|ffd700|ffec80|Metal|Spark",
		"Sapphire|Gem|0f52ba|60a0ff|Glass",
		"Golden Chalice|Chalice|ffd700|c04040|Metal",
		"Ruby Ring|Ring|ffd700|e0115f|Metal",
		"Crystal Ball|Orb|a0e0ff|ffffff|Glass|Stars",
		"Pirate Chest|Chest|6b3e1a|ffd700|Wood|Spark",
		"Frost Crystal|Crystal|a0f0ff|ffffff|Ice|Frost",
		"Pharaoh Mask|Mask|ffd700|1e90ff|Metal",
		"Owl Idol|Idol|8b6914|ffd700|Marble",
		"Sand Hourglass|Hourglass|d4a017|f0d090|Glass",
		"Ember Potion|Potion|ff4500|ffa500|Glass|Fire",
		"Silver Trophy|Trophy|e0e0e8|80c0ff|Metal|Stars",
		"Thunder Feather|Feather|4060ff|ffff60|Neon|Lightning",
		"Sea Lantern|Lamp|20b2aa|80ffff|Glass|Bubbles",
		"Dragon Egg|Egg|8b0000|ff6347|Slate|Fire",
	},
	Epic = {
		"Amethyst Cluster|Crystal|9966cc|e0b0ff|Glass|Stars",
		"Diamond|Gem|e0ffff|ffffff|Glass|Spark",
		"Royal Crown|Crown|ffd700|c00030|Metal|Spark",
		"Volcano Heart|Heart|ff3300|ffcc00|CrackedLava|Fire",
		"Wizard Tome|Book|2a2a80|80e0ff|Fabric|Stars",
		"Kraken Orb|Orb|006060|40ffd0|Glass|Bubbles",
		"Samurai Blade|Sword|e8e8f0|aa0000|Metal|Spark",
		"Golden Idol|Idol|ffd700|ffaa00|Metal|Spark",
		"Storm Shield|Shield|404870|60c0ff|DiamondPlate|Lightning",
		"Glacier Skull|Skull|b0e8ff|ffffff|Ice|Frost",
		"Elixir of Life|Potion|ff60a0|ffffff|Glass|Hearts",
		"Starfall Star|Star|ffe060|ffffff|Neon|Stars",
		"Emerald Pyramid|Pyramid|50c878|a0ffc0|Glass|Leaves",
		"Cursed Key|Key|303040|a040ff|Metal|Void",
	},
	Legendary = {
		"King's Chest|Chest|8b0000|ffd700|Wood|Spark",
		"Sun Gem|Gem|ffb000|fff080|Neon|Fire",
		"Excalibur|Sword|f0f0ff|ffd700|Metal|Stars",
		"Crown of Ages|Crown|e0c040|40e0ff|Foil|Stars",
		"Phoenix Egg|Egg|ffa000|ff4000|Foil|Fire",
		"Moonstone Orb|Orb|c0d0ff|ffffff|Glass|Stars",
		"Aztec Mask|Mask|00a080|ffd040|Marble|Spark",
		"Champion Trophy|Trophy|ffd700|ff4040|Foil|Spark",
		"Leviathan Shield|Shield|006080|40ffd0|Glass|Bubbles",
		"Ancient Hourglass|Hourglass|c0a040|80ffff|Metal|Spark",
		"Lightning Crystal|Crystal|ffff40|ffffff|Neon|Lightning",
		"Heart of the Forest|Heart|228b22|a0ff60|Grass|Leaves",
		"Djinn Lamp|Lamp|ffd700|a040ff|Foil|Void",
	},
	Mythical = {
		"Dragon Heart|Heart|c00000|ff8000|Neon|Fire",
		"Nebula Orb|Orb|6020a0|ff60ff|Glass|Stars",
		"Trident of Tides|Sword|20b0c0|ffd700|Metal|Bubbles",
		"Celestial Crown|Crown|e0f0ff|8080ff|Glass|Stars",
		"Infinity Ring|Ring|ffd700|ff00ff|Neon|Spark",
		"Frozen Star|Star|a0f0ff|ffffff|Ice|Frost",
		"Grimoire of Shadows|Book|101010|a000ff|Fabric|Void",
		"Titan Idol|Idol|707080|ffd040|Granite|Lightning",
		"Plasma Cube|Cube|ff00ff|00ffff|Neon|Lightning",
		"Unicorn Egg|Egg|ffffff|ff80ff|Marble|Hearts",
		"Golden Skull|Skull|ffd700|ff4000|Foil|Fire",
	},
	Secret = {
		"Void Gem|Gem|100020|8000ff|Glass|Void",
		"Shadow King Crown|Crown|101018|00ffc0|Metal|Void",
		"Glitch Cube|Cube|00ff80|ff0080|Neon|Lightning",
		"Black Hole Orb|Orb|050505|ff6000|Glass|Void",
		"Ghost Lantern|Lamp|60ffd0|ffffff|ForceField|Void",
		"Reaper Skull|Skull|202020|00ff90|Slate|Void",
		"Forbidden Key|Key|200000|ff2020|Metal|Fire",
		"Eclipse Star|Star|202030|ffb000|Neon|Void",
	},
	Divine = {
		"Angel Feather|Feather|ffffff|fff0a0|Neon|Stars",
		"Heart of the Cosmos|Heart|ff80ff|80ffff|Neon|Rainbow",
		"Crown of the Gods|Crown|fff8d0|ffffff|Foil|Rainbow",
		"Genesis Orb|Orb|ffffff|ffe080|Glass|Rainbow",
		"Sword of Light|Sword|ffffff|ffff80|Neon|Stars",
		"Eternal Hourglass|Hourglass|fff0c0|80e0ff|Foil|Rainbow",
		"Prism Diamond|Gem|ffffff|ff80c0|Glass|Rainbow",
	},
}

-- Rebirth-exclusive treasures (never spawn in the world)
local EXCLUSIVE = {
	{ Row = "Phoenix Ember|Egg|ff6000|ffd000|Neon|Fire", Rarity = "Mythical", MPS = 40000 },
	{ Row = "Chrono Hourglass|Hourglass|40c0ff|ffffff|Glass|Stars", Rarity = "Secret", MPS = 250000 },
	{ Row = "Void Crown|Crown|1a0030|c060ff|Foil|Void", Rarity = "Secret", MPS = 400000 },
	{ Row = "Eternity Heart|Heart|ffffff|ffd0ff|Neon|Rainbow", Rarity = "Divine", MPS = 2500000 },
}

local MPS_RANGE = {
	Common = { 1, 8 },
	Uncommon = { 12, 40 },
	Rare = { 60, 180 },
	Epic = { 300, 900 },
	Legendary = { 1500, 5000 },
	Mythical = { 9000, 30000 },
	Secret = { 60000, 200000 },
	Divine = { 450000, 1500000 },
}

local PRICE_FACTOR = {
	Common = 25,
	Uncommon = 30,
	Rare = 35,
	Epic = 40,
	Legendary = 45,
	Mythical = 50,
	Secret = 55,
	Divine = 60,
}

local SHAPE_ICONS = {
	Gem = "💎",
	Crown = "👑",
	Chalice = "🏆",
	CoinStack = "🪙",
	Orb = "🔮",
	Sword = "⚔️",
	Chest = "🧰",
	Egg = "🥚",
	Star = "⭐",
	Skull = "💀",
	Trophy = "🏆",
	Ring = "💍",
	Crystal = "🔷",
	Idol = "🗿",
	Key = "🗝️",
	Lamp = "🪔",
	Mask = "🎭",
	Potion = "🧪",
	Cube = "🧊",
	Pyramid = "🔺",
	Shield = "🛡️",
	Hourglass = "⌛",
	Heart = "❤️",
	Book = "📖",
	Feather = "🪶",
}

local function niceRound(n: number): number
	if n < 10 then
		return math.floor(n + 0.5)
	end
	local mag = 10 ^ math.floor(math.log10(n) - 1)
	return math.floor(n / mag + 0.5) * mag
end

local function slug(name: string): string
	return (name:lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", ""))
end

local function parse(row: string)
	local parts = string.split(row, "|")
	return {
		Name = parts[1],
		Shape = parts[2],
		Primary = Color3.fromHex(parts[3]),
		Secondary = Color3.fromHex(parts[4]),
		Material = parts[5],
		Fx = parts[6] or "None",
	}
end

local TreasureData = {}
TreasureData.ById = {} :: { [string]: any }
TreasureData.ByName = {} :: { [string]: any }
TreasureData.List = {} :: { any }
TreasureData.ByRarity = {} :: { [string]: { any } }
TreasureData.ShapeIcons = SHAPE_ICONS

local function register(def)
	def.Id = slug(def.Name)
	def.Icon = SHAPE_ICONS[def.Shape] or "✨"
	assert(TreasureData.ById[def.Id] == nil, "Duplicate treasure id " .. def.Id)
	TreasureData.ById[def.Id] = def
	TreasureData.ByName[def.Name] = def
	table.insert(TreasureData.List, def)
	TreasureData.ByRarity[def.Rarity] = TreasureData.ByRarity[def.Rarity] or {}
	if not def.Exclusive then
		table.insert(TreasureData.ByRarity[def.Rarity], def)
	end
end

for _, rarity in ipairs(Rarities.Order) do
	local rows = RAW[rarity]
	local lo, hi = MPS_RANGE[rarity][1], MPS_RANGE[rarity][2]
	for i, row in ipairs(rows) do
		local def = parse(row)
		local t = (#rows > 1) and (i - 1) / (#rows - 1) or 0
		-- slightly exponential curve inside a tier
		local mps = lo * (hi / lo) ^ t
		def.Rarity = rarity
		def.MPS = niceRound(mps)
		def.Value = niceRound(def.MPS * PRICE_FACTOR[rarity])
		def.Exclusive = false
		def.Order = #TreasureData.List + 1
		register(def)
	end
end

for _, ex in ipairs(EXCLUSIVE) do
	local def = parse(ex.Row)
	def.Rarity = ex.Rarity
	def.MPS = ex.MPS
	def.Value = niceRound(ex.MPS * PRICE_FACTOR[ex.Rarity])
	def.Exclusive = true
	def.Order = #TreasureData.List + 1
	register(def)
end

TreasureData.CollectableCount = 0
for _, def in ipairs(TreasureData.List) do
	if not def.Exclusive then
		TreasureData.CollectableCount += 1
	end
end

function TreasureData.Get(id: string)
	return TreasureData.ById[id]
end

function TreasureData.RandomOfRarity(rarity: string, rng: Random?)
	local pool = TreasureData.ByRarity[rarity]
	if not pool or #pool == 0 then
		pool = TreasureData.ByRarity.Common
	end
	local r = rng or Random.new()
	-- within a tier, cheaper items are more common (weight 1/(index))
	local total = 0
	for i = 1, #pool do
		total += 1 / (1 + (i - 1) * 0.25)
	end
	local pick = r:NextNumber() * total
	for i = 1, #pool do
		local w = 1 / (1 + (i - 1) * 0.25)
		if pick <= w then
			return pool[i]
		end
		pick -= w
	end
	return pool[#pool]
end

function TreasureData.RollFromPool(weights: { [string]: number }, rng: Random?)
	return TreasureData.RandomOfRarity(Rarities.Roll(weights, rng), rng)
end

return TreasureData
