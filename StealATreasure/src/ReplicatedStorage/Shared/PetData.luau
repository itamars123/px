-- PetData.lua
-- 52 pets across 9 rarities, plus the eggs that hatch them.
-- Row: Name | Species | BodyHex | AccentHex | Material | BonusType
-- BonusType: Money (income %), Luck (luck %), Speed (+walk speed), Gems (gem %).

local Rarities = require(script.Parent.Rarities)

local RAW = {
	Common = {
		"Puppy|Dog|d9a066|7a4a22|SmoothPlastic|Money",
		"Kitty|Cat|f2a65a|ffffff|SmoothPlastic|Money",
		"Bunny|Bunny|f4f4f4|ffb6c1|SmoothPlastic|Luck",
		"Chick|Chick|ffe066|ff9a30|SmoothPlastic|Speed",
		"Froggy|Frog|6ecb63|f9f871|SmoothPlastic|Money",
		"Mouse|Mouse|b8b8c0|ffb6c1|SmoothPlastic|Speed",
		"Piggy|Pig|ffb3c6|ff8fab|SmoothPlastic|Money",
		"Green Slime|Slime|7cfc00|c8ff9e|Glass|Gems",
	},
	Uncommon = {
		"Fox|Fox|ff7f2a|ffffff|SmoothPlastic|Speed",
		"Panda|Bear|ffffff|222222|SmoothPlastic|Money",
		"Penguin|Penguin|2b2d42|ffffff|SmoothPlastic|Luck",
		"Bumblebee|Bee|ffd23f|222222|SmoothPlastic|Gems",
		"Owl|Owl|8d6e63|ffcc80|SmoothPlastic|Luck",
		"Turtle|Turtle|74c69d|2d6a4f|SmoothPlastic|Money",
		"Hamster|Hamster|f4a261|fff1e6|SmoothPlastic|Speed",
		"Blue Slime|Slime|4cc9f0|bde0fe|Glass|Gems",
	},
	Rare = {
		"Wolf|Wolf|8d99ae|edf2f4|SmoothPlastic|Speed",
		"Tiger|Cat|ff9f1c|222222|SmoothPlastic|Money",
		"Parrot|Parrot|06d6a0|ef476f|SmoothPlastic|Luck",
		"Bat|Bat|3c2a4d|a06cd5|SmoothPlastic|Gems",
		"Koala|Bear|a8a8b3|f1f1f1|SmoothPlastic|Money",
		"Red Panda|Bear|c1440e|fff1e6|SmoothPlastic|Luck",
		"Golden Retriever|Dog|f6bd60|fff1e6|SmoothPlastic|Money",
		"Pink Slime|Slime|ff70a6|ffd6e0|Glass|Luck",
	},
	Epic = {
		"Unicorn|Unicorn|ffffff|ff8fd8|SmoothPlastic|Luck",
		"Ghost|Ghost|e9f5ff|9ad1ff|Glass|Gems",
		"Robo Buddy|Robot|adb5bd|00f5d4|DiamondPlate|Money",
		"Lava Pup|Dog|3d0c02|ff5400|CrackedLava|Money",
		"Ice Cat|Cat|caf0f8|48cae4|Ice|Speed",
		"Fire Fox|Fox|ff4800|ffd000|Neon|Speed",
		"Crystal Bunny|Bunny|b8c0ff|e7c6ff|Glass|Luck",
	},
	Legendary = {
		"Dragon|Dragon|2a9d8f|e9c46a|SmoothPlastic|Money",
		"Phoenix|Phoenix|ff6d00|ffd60a|Neon|Luck",
		"Golden Unicorn|Unicorn|ffd700|fff3b0|Foil|Money",
		"Shadow Wolf|Wolf|1b1b2f|9d4edd|SmoothPlastic|Speed",
		"Kraken|Squid|7209b7|f72585|SmoothPlastic|Gems",
		"Angel Cat|Cat|ffffff|ffe066|SmoothPlastic|Luck",
	},
	Mythical = {
		"Void Dragon|Dragon|10002b|c77dff|SmoothPlastic|Money",
		"Rainbow Unicorn|Unicorn|ffffff|ff595e|SmoothPlastic|Luck",
		"Galaxy Cat|Cat|240046|7b2cbf|Neon|Gems",
		"Storm Phoenix|Phoenix|4361ee|ffffff|Neon|Speed",
		"Mecha Titan|Robot|495057|ff006e|DiamondPlate|Money",
	},
	Secret = {
		"Glitch Slime|Slime|00ff80|ff0080|Neon|Gems",
		"Black Hole Bat|Bat|050505|ff6000|SmoothPlastic|Luck",
		"Reaper Ghost|Ghost|202020|00ff90|Glass|Money",
		"Pharaoh Cat|Cat|ffd700|1e90ff|Foil|Money",
	},
	Divine = {
		"Seraph Owl|Owl|ffffff|fff0a0|Neon|Luck",
		"Holy Dragon|Dragon|fff8e1|ffd54f|Foil|Money",
		"Halo Bunny|Bunny|ffffff|fff59d|Neon|Gems",
	},
	Celestial = {
		"Nebula Dragon|Dragon|3a0ca3|4cc9f0|Neon|Money",
		"Starlight Unicorn|Unicorn|caf0f8|b388ff|Neon|Luck",
		"Cosmic Whale|Whale|1a237e|80d8ff|Neon|Gems",
	},
}

-- Species flags used by the procedural builder and the follow animation.
local SPECIES = {
	Dog = { Ears = "Floppy", Tail = "Short", Legs = 4, Snout = true },
	Cat = { Ears = "Pointy", Tail = "Long", Legs = 4 },
	Bunny = { Ears = "Long", Tail = "Puff", Legs = 4, Hops = true },
	Chick = { Beak = true, Legs = 2, Wings = "Small" },
	Frog = { Eyes = "Top", Legs = 4, Hops = true, Wide = true },
	Mouse = { Ears = "Round", Tail = "Thin", Legs = 4 },
	Pig = { Ears = "Pointy", Snout = true, Tail = "Curl", Legs = 4 },
	Slime = { Blob = true, Hops = true },
	Fox = { Ears = "Pointy", Tail = "Fluffy", Legs = 4, Snout = true },
	Bear = { Ears = "Round", Tail = "Puff", Legs = 4 },
	Penguin = { Beak = true, Legs = 2, Wings = "Flipper" },
	Bee = { Flies = true, Wings = "Bug", Antenna = true, Stripes = true },
	Owl = { Flies = true, Wings = "Bird", Beak = true, Ears = "Tuft" },
	Turtle = { Shell = true, Legs = 4 },
	Hamster = { Ears = "Round", Legs = 4, Wide = true },
	Wolf = { Ears = "Pointy", Tail = "Fluffy", Legs = 4, Snout = true },
	Parrot = { Flies = true, Wings = "Bird", Beak = true, Tail = "Feather" },
	Bat = { Flies = true, Wings = "Bat", Ears = "Pointy" },
	Unicorn = { Ears = "Pointy", Horn = true, Legs = 4, Snout = true, Tail = "Long" },
	Ghost = { Flies = true, Blob = true, Ghostly = true },
	Robot = { Boxy = true, Antenna = true, Legs = 2 },
	Dragon = { Flies = true, Wings = "Bat", Horn = true, Tail = "Long", Snout = true },
	Phoenix = { Flies = true, Wings = "Bird", Beak = true, Tail = "Feather", Fiery = true },
	Squid = { Flies = true, Tentacles = true },
	Whale = { Flies = true, Fins = true, Tail = "Fin", Wide = true },
}

local POWER = {
	Common = 0.05,
	Uncommon = 0.10,
	Rare = 0.18,
	Epic = 0.30,
	Legendary = 0.50,
	Mythical = 0.80,
	Secret = 1.20,
	Divine = 1.80,
	Celestial = 3.00,
}

local PetData = {}
PetData.Species = SPECIES
PetData.Icons = {
	Dog = "🐶", Cat = "🐱", Bunny = "🐰", Chick = "🐥", Frog = "🐸", Mouse = "🐭", Pig = "🐷",
	Slime = "🟢", Fox = "🦊", Bear = "🐻", Penguin = "🐧", Bee = "🐝", Owl = "🦉", Turtle = "🐢",
	Hamster = "🐹", Wolf = "🐺", Parrot = "🦜", Bat = "🦇", Unicorn = "🦄", Ghost = "👻",
	Robot = "🤖", Dragon = "🐉", Phoenix = "🔥", Squid = "🦑", Whale = "🐋",
}
PetData.ById = {}
PetData.List = {}
PetData.ByRarity = {}

local function slug(name: string): string
	return (name:lower():gsub("[^%w]+", "_"))
end

for _, rarity in ipairs(Rarities.Order) do
	PetData.ByRarity[rarity] = {}
	for i, row in ipairs(RAW[rarity] or {}) do
		local p = string.split(row, "|")
		local def = {
			Name = p[1],
			Species = p[2],
			Body = Color3.fromHex(p[3]),
			Accent = Color3.fromHex(p[4]),
			Material = p[5],
			BonusType = p[6],
			Rarity = rarity,
			Id = "pet_" .. slug(p[1]),
		}
		local power = POWER[rarity] * (1 + (i - 1) * 0.06)
		if def.BonusType == "Speed" then
			def.Bonus = math.floor(power * 10 + 0.5) -- walk speed studs
		else
			def.Bonus = math.floor(power * 100 + 0.5) / 100 -- fraction
		end
		def.Flies = SPECIES[def.Species] and SPECIES[def.Species].Flies or false
		def.Order = #PetData.List + 1
		PetData.ById[def.Id] = def
		table.insert(PetData.List, def)
		table.insert(PetData.ByRarity[rarity], def)
	end
end

function PetData.Get(id: string)
	return PetData.ById[id]
end

function PetData.BonusText(def): string
	if def.BonusType == "Speed" then
		return ("+%d Speed"):format(def.Bonus)
	end
	local label = def.BonusType == "Money" and "Income" or (def.BonusType == "Luck" and "Luck" or "Gems")
	return ("+%d%% %s"):format(math.floor(def.Bonus * 100 + 0.5), label)
end

-- Eggs ---------------------------------------------------------------------
PetData.Eggs = {
	Meadow = {
		Order = 1,
		Name = "Meadow Egg",
		Currency = "Money",
		Cost = 2500,
		Color = Color3.fromRGB(150, 230, 120),
		Weights = { Common = 70, Uncommon = 25, Rare = 5 },
	},
	Golden = {
		Order = 2,
		Name = "Golden Egg",
		Currency = "Money",
		Cost = 250000,
		Color = Color3.fromRGB(255, 210, 60),
		Weights = { Uncommon = 35, Rare = 40, Epic = 20, Legendary = 5 },
	},
	Gem = {
		Order = 3,
		Name = "Gem Egg",
		Currency = "Gems",
		Cost = 150,
		Color = Color3.fromRGB(120, 200, 255),
		Weights = { Rare = 30, Epic = 40, Legendary = 22, Mythical = 7, Secret = 1 },
	},
	Cosmic = {
		Order = 4,
		Name = "Cosmic Egg",
		Currency = "Gems",
		Cost = 1000,
		Color = Color3.fromRGB(170, 110, 255),
		Weights = { Legendary = 50, Mythical = 30, Secret = 12, Divine = 6, Celestial = 2 },
	},
}

-- Rolls a pet from an egg. Luck (1 = normal) boosts rarer tiers.
function PetData.Roll(eggKey: string, luck: number, rng: Random?)
	local egg = PetData.Eggs[eggKey]
	if not egg then
		return nil
	end
	local r = rng or Random.new()
	local weights = {}
	local lowest = math.huge
	for name in pairs(egg.Weights) do
		lowest = math.min(lowest, Rarities.Rank(name))
	end
	for name, w in pairs(egg.Weights) do
		local steps = Rarities.Rank(name) - lowest
		weights[name] = w * (luck ^ steps)
	end
	local rarity = Rarities.Roll(weights, r)
	local pool = PetData.ByRarity[rarity]
	return pool[r:NextInteger(1, #pool)]
end

return PetData
