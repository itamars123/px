-- Rarities.lua
-- Rarity tiers, their colours and which visual effects they get.

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret", "Divine" }

Rarities.Info = {
	Common = {
		Rank = 1,
		Color = Color3.fromRGB(200, 205, 215),
		Glow = Color3.fromRGB(255, 255, 255),
		Sparkles = false,
		Particles = 0,
		Light = 0,
		Beam = false,
		Halo = false,
		Rainbow = false,
		Smoke = false,
		Announce = false,
	},
	Uncommon = {
		Rank = 2,
		Color = Color3.fromRGB(90, 220, 110),
		Glow = Color3.fromRGB(120, 255, 140),
		Sparkles = true,
		Particles = 2,
		Light = 0,
		Beam = false,
		Halo = false,
		Rainbow = false,
		Smoke = false,
		Announce = false,
	},
	Rare = {
		Rank = 3,
		Color = Color3.fromRGB(70, 150, 255),
		Glow = Color3.fromRGB(110, 180, 255),
		Sparkles = true,
		Particles = 5,
		Light = 6,
		Beam = false,
		Halo = false,
		Rainbow = false,
		Smoke = false,
		Announce = false,
	},
	Epic = {
		Rank = 4,
		Color = Color3.fromRGB(175, 85, 255),
		Glow = Color3.fromRGB(200, 120, 255),
		Sparkles = true,
		Particles = 9,
		Light = 10,
		Beam = false,
		Halo = false,
		Rainbow = false,
		Smoke = false,
		Announce = false,
	},
	Legendary = {
		Rank = 5,
		Color = Color3.fromRGB(255, 185, 40),
		Glow = Color3.fromRGB(255, 220, 90),
		Sparkles = true,
		Particles = 14,
		Light = 14,
		Beam = true,
		Halo = false,
		Rainbow = false,
		Smoke = false,
		Announce = true,
	},
	Mythical = {
		Rank = 6,
		Color = Color3.fromRGB(255, 70, 120),
		Glow = Color3.fromRGB(255, 120, 170),
		Sparkles = true,
		Particles = 18,
		Light = 16,
		Beam = true,
		Halo = true,
		Rainbow = false,
		Smoke = false,
		Announce = true,
	},
	Secret = {
		Rank = 7,
		Color = Color3.fromRGB(40, 40, 50),
		Glow = Color3.fromRGB(130, 255, 230),
		Sparkles = true,
		Particles = 20,
		Light = 18,
		Beam = true,
		Halo = true,
		Rainbow = false,
		Smoke = true,
		Announce = true,
	},
	Divine = {
		Rank = 8,
		Color = Color3.fromRGB(255, 250, 220),
		Glow = Color3.fromRGB(255, 245, 180),
		Sparkles = true,
		Particles = 26,
		Light = 22,
		Beam = true,
		Halo = true,
		Rainbow = true,
		Smoke = false,
		Announce = true,
	},
}

function Rarities.Rank(name: string): number
	local info = Rarities.Info[name]
	return info and info.Rank or 0
end

function Rarities.Color(name: string): Color3
	local info = Rarities.Info[name]
	return info and info.Color or Color3.new(1, 1, 1)
end

-- Weighted random roll over a { RarityName = weight } table.
function Rarities.Roll(weights: { [string]: number }, rng: Random?): string
	local r = rng or Random.new()
	local total = 0
	for _, name in ipairs(Rarities.Order) do
		total += weights[name] or 0
	end
	local pick = r:NextNumber() * total
	for _, name in ipairs(Rarities.Order) do
		local w = weights[name] or 0
		if w > 0 then
			if pick <= w then
				return name
			end
			pick -= w
		end
	end
	return "Common"
end

return Rarities
