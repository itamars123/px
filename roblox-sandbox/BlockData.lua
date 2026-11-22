--[[
	BlockData  (ModuleScript → ReplicatedStorage)
	Shared settings, block types, items and recipes for "Block Diggers".
	Used by both the server and the client.
]]

local BlockData = {}

BlockData.BLOCK_SIZE = 3      -- studs per block
BlockData.WIDTH = 100         -- world width in blocks
BlockData.HEIGHT = 55         -- world height in blocks
BlockData.PLANE_Z = 0
BlockData.REACH = 20          -- how far (studs) a player can mine/place

-- hardness = seconds to mine with bare hands, tier = pickaxe tier required
-- back = true  → decoration that sits behind the player (trees, torches)
BlockData.Blocks = {
	Grass      = { color = Color3.fromRGB(134, 96, 67),  hardness = 0.35, drop = "Dirt" },
	Dirt       = { color = Color3.fromRGB(134, 96, 67),  hardness = 0.35, drop = "Dirt" },
	Stone      = { color = Color3.fromRGB(128, 128, 132), hardness = 0.9,  drop = "Stone" },
	CoalOre    = { color = Color3.fromRGB(128, 128, 132), hardness = 1.1,  drop = "Coal" },
	IronOre    = { color = Color3.fromRGB(128, 128, 132), hardness = 1.6,  drop = "Iron" },
	GoldOre    = { color = Color3.fromRGB(128, 128, 132), hardness = 2.2,  drop = "Gold", tier = 2 },
	Trunk      = { color = Color3.fromRGB(120, 82, 48),  hardness = 0.6,  drop = "Wood", solid = false, back = true },
	Leaves     = { color = Color3.fromRGB(60, 150, 55),  hardness = 0.15, solid = false, back = true },
	Planks     = { color = Color3.fromRGB(190, 140, 85), hardness = 0.5,  drop = "Planks" },
	StoneBrick = { color = Color3.fromRGB(150, 150, 160), hardness = 1.0,  drop = "StoneBrick" },
	Torch      = { color = Color3.fromRGB(255, 170, 60), hardness = 0.05, drop = "Torch", solid = false, back = true,
	               transparency = 1, light = true },
	Bedrock    = { color = Color3.fromRGB(40, 40, 48),   hardness = math.huge },
}

-- Items you can place (hotbar order, keys 1-5)
BlockData.Placeable = { "Dirt", "Stone", "Planks", "StoneBrick", "Torch" }

-- Materials / tools shown in the side panel
BlockData.Materials = { "Wood", "Coal", "Iron", "Gold", "Coins" }
BlockData.Tools = { "IronPickaxe", "GoldPickaxe", "IronSword" }

BlockData.Names = {
	Dirt = "אדמה", Stone = "אבן", Planks = "קרשים", StoneBrick = "לבני אבן", Torch = "לפיד",
	Wood = "עץ", Coal = "פחם", Iron = "ברזל", Gold = "זהב", Coins = "מטבעות",
	IronPickaxe = "מכוש ברזל", GoldPickaxe = "מכוש זהב", IronSword = "חרב ברזל",
}

BlockData.ItemColors = {
	Wood = Color3.fromRGB(110, 75, 40), Coal = Color3.fromRGB(45, 45, 50),
	Iron = Color3.fromRGB(205, 150, 120), Gold = Color3.fromRGB(255, 200, 40),
	Coins = Color3.fromRGB(255, 230, 90),
}

BlockData.Recipes = {
	{ id = "Planks",      gives = { Planks = 4 },      cost = { Wood = 1 } },
	{ id = "StoneBrick",  gives = { StoneBrick = 2 },  cost = { Stone = 2 } },
	{ id = "Torch",       gives = { Torch = 4 },       cost = { Wood = 1, Coal = 1 } },
	{ id = "IronPickaxe", gives = { IronPickaxe = 1 }, cost = { Iron = 5, Wood = 3 }, tool = true },
	{ id = "GoldPickaxe", gives = { GoldPickaxe = 1 }, cost = { Gold = 5, Wood = 3 }, tool = true },
	{ id = "IronSword",   gives = { IronSword = 1 },   cost = { Iron = 4, Wood = 1 }, tool = true },
}

local function has(inventory, item)
	local v = inventory and inventory:FindFirstChild(item)
	return v ~= nil and v.Value > 0
end
BlockData.Has = has

-- returns tier, speed multiplier
function BlockData.GetPickaxe(inventory)
	if has(inventory, "GoldPickaxe") then return 3, 2.8 end
	if has(inventory, "IronPickaxe") then return 2, 1.8 end
	return 1, 1
end

function BlockData.GetDamage(inventory)
	return has(inventory, "IronSword") and 30 or 12
end

function BlockData.CellToWorld(x, y)
	local bs = BlockData.BLOCK_SIZE
	return Vector3.new(x * bs, y * bs, BlockData.PLANE_Z)
end

function BlockData.WorldToCell(pos)
	local bs = BlockData.BLOCK_SIZE
	return math.floor(pos.X / bs + 0.5), math.floor(pos.Y / bs + 0.5)
end

return BlockData
