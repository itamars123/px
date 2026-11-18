-- Mutations.lua
-- Treasure mutations: rare variants that multiply income and value and
-- change how the treasure looks. Rolled when a treasure spawns on the parade
-- or in the world; kept through stealing, trading and saving.

local Mutations = {}

Mutations.Order = { "Gold", "Diamond", "Rainbow", "Lava", "Galaxy" }

Mutations.Info = {
	Gold = { Multiplier = 1.25, Chance = 0.08, Color = Color3.fromRGB(255, 200, 50), Material = "Foil", Icon = "🟡" },
	Diamond = { Multiplier = 1.5, Chance = 0.03, Color = Color3.fromRGB(150, 230, 255), Material = "Glass", Icon = "💠" },
	Rainbow = { Multiplier = 2, Chance = 0.01, Color = Color3.fromRGB(255, 120, 220), Material = "Neon", Icon = "🌈", Rainbow = true },
	Lava = { Multiplier = 2.5, Chance = 0.004, Color = Color3.fromRGB(255, 90, 20), Material = "CrackedLava", Icon = "🌋", EventOnly = "Lava" },
	Galaxy = { Multiplier = 4, Chance = 0.002, Color = Color3.fromRGB(110, 70, 255), Material = "Neon", Icon = "🌌" },
}

function Mutations.Multiplier(name: string?): number
	local info = name and Mutations.Info[name]
	return info and info.Multiplier or 1
end

-- Rolls a mutation (or nil). luck multiplies every chance; boost (event) adds.
function Mutations.Roll(rng: Random, luck: number?, eventMutation: string?)
	local l = luck or 1
	-- rarest first so a lucky roll lands on the best mutation
	for i = #Mutations.Order, 1, -1 do
		local name = Mutations.Order[i]
		local info = Mutations.Info[name]
		local chance = info.Chance * l
		if info.EventOnly and info.EventOnly ~= eventMutation then
			chance = 0
		end
		if eventMutation == name then
			chance = math.max(chance, 0.25)
		end
		if chance > 0 and rng:NextNumber() < chance then
			return name
		end
	end
	return nil
end

function Mutations.Label(name: string?): string
	local info = name and Mutations.Info[name]
	return info and (info.Icon .. " " .. name:upper()) or ""
end

return Mutations
