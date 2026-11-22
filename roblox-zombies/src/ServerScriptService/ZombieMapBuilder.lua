-- ZombieMapBuilder (ModuleScript) — put in ServerScriptService
-- Builds a starter map (two rooms joined by a buyable door) when workspace has no "ZombieMap".
--
-- Want your own map? Make a Folder/Model called "ZombieMap" in Workspace and add parts with attributes:
--   Zombie spawn : Part named "ZombieSpawn", ~3 studs above the floor, attribute Area = "A" (string)
--   Wall-buy     : Interact = "WallBuy", Weapon = "SMG" (key from ZombieConfig.Weapons), optional Cost
--   Door         : Interact = "Door", Cost = 750, OpensArea = "B"  (spawns in area B wake up when opened)
--   Mystery box  : Interact = "MysteryBox"
--   Perk machine : Interact = "Perk", Perk = "ToughBrew" or "QuickHands"
-- Plus a SpawnLocation for players.

local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("ZombieConfig"))

local MapBuilder = {}

local function part(parent, name, size, cframe, color, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			p[k] = v
		end
	end
	p.Parent = parent
	return p
end

local function label(adornee, text, color, height)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Label"
	bb.Size = UDim2.fromOffset(220, 56)
	bb.StudsOffset = Vector3.new(0, height or 3, 0)
	bb.MaxDistance = 45
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextScaled = true
	t.Font = Enum.Font.GothamBlack
	t.TextStrokeTransparency = 0
	t.Parent = bb
	bb.Parent = adornee
	return bb
end

local function lamp(parent, pos)
	local p = part(parent, "Lamp", Vector3.new(2, 0.6, 2), CFrame.new(pos), Color3.fromRGB(255, 200, 130), Enum.Material.Neon, { CanCollide = false })
	local light = Instance.new("PointLight")
	light.Range = 34
	light.Brightness = 2.2
	light.Color = Color3.fromRGB(255, 190, 120)
	light.Shadows = true
	light.Parent = p
end

local function zombieSpawn(parent, pos, area)
	local p = part(parent, "ZombieSpawn", Vector3.new(2, 1, 2), CFrame.new(pos), Color3.fromRGB(255, 0, 0), nil, {
		Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
	})
	p:SetAttribute("Area", area)
end

local function wallBuy(parent, weapon, pos, size)
	local w = Config.Weapons[weapon]
	local p = part(parent, "WallBuy_" .. weapon, size, CFrame.new(pos), Color3.fromRGB(150, 120, 60), Enum.Material.Wood)
	p:SetAttribute("Interact", "WallBuy")
	p:SetAttribute("Weapon", weapon)
	label(p, w.DisplayName .. "\n" .. w.Cost, Color3.fromRGB(255, 230, 140), 3)
	-- chalk outline glow
	local light = Instance.new("PointLight")
	light.Range = 8
	light.Brightness = 1
	light.Color = Color3.fromRGB(255, 230, 160)
	light.Parent = p
end

function MapBuilder.Build()
	local map = Instance.new("Folder")
	map.Name = "ZombieMap"

	local H = 16
	local wallColor = Color3.fromRGB(92, 82, 72)
	local brick = Enum.Material.Brick

	-- Floors (top surface at y = 0.1 so it never z-fights a default Baseplate)
	part(map, "FloorA", Vector3.new(80, 1, 80), CFrame.new(0, -0.4, 0), Color3.fromRGB(62, 60, 56), Enum.Material.Concrete)
	part(map, "FloorB", Vector3.new(60, 1, 60), CFrame.new(0, -0.4, -70), Color3.fromRGB(78, 58, 40), Enum.Material.WoodPlanks)

	-- Room A walls (x -40..40, z -40..40)
	part(map, "Wall", Vector3.new(84, H, 2), CFrame.new(0, H / 2, 41), wallColor, brick)
	part(map, "Wall", Vector3.new(2, H, 80), CFrame.new(41, H / 2, 0), wallColor, brick)
	part(map, "Wall", Vector3.new(2, H, 80), CFrame.new(-41, H / 2, 0), wallColor, brick)
	part(map, "Wall", Vector3.new(37, H, 2), CFrame.new(-23.5, H / 2, -41), wallColor, brick)
	part(map, "Wall", Vector3.new(37, H, 2), CFrame.new(23.5, H / 2, -41), wallColor, brick)
	part(map, "Wall", Vector3.new(10, H - 12, 2), CFrame.new(0, 12 + (H - 12) / 2, -41), wallColor, brick)

	-- Room B walls (x -30..30, z -100..-40)
	part(map, "Wall", Vector3.new(2, H, 60), CFrame.new(-31, H / 2, -70), wallColor, brick)
	part(map, "Wall", Vector3.new(2, H, 60), CFrame.new(31, H / 2, -70), wallColor, brick)
	part(map, "Wall", Vector3.new(64, H, 2), CFrame.new(0, H / 2, -101), wallColor, brick)

	-- Buyable door between A and B
	local door = part(map, "Door", Vector3.new(10, 12, 1.6), CFrame.new(0, 6, -41), Color3.fromRGB(105, 70, 40), Enum.Material.WoodPlanks)
	door:SetAttribute("Interact", "Door")
	door:SetAttribute("Cost", 750)
	door:SetAttribute("OpensArea", "B")
	label(door, "Door — 750", Color3.fromRGB(255, 255, 255), 7.5)

	-- Cover
	local crate = Color3.fromRGB(110, 85, 55)
	part(map, "Crate", Vector3.new(4, 4, 4), CFrame.new(15, 2.1, 10), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(6, 4, 3), CFrame.new(-12, 2.1, -15), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(4, 3, 4), CFrame.new(20, 1.6, -25), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(8, 4, 3), CFrame.new(-10, 2.1, -65), crate, Enum.Material.WoodPlanks)
	part(map, "Crate", Vector3.new(4, 4, 4), CFrame.new(12, 2.1, -78), crate, Enum.Material.WoodPlanks)

	-- Lights
	for _, pos in { Vector3.new(0, 14, 38), Vector3.new(38, 14, -18), Vector3.new(-38, 14, 18), Vector3.new(0, 14, -98), Vector3.new(28, 14, -60), Vector3.new(-28, 14, -85) } do
		lamp(map, pos)
	end

	-- Player spawn
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlayerSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(0, 0.6, 25)
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(50, 50, 55)
	spawn.Material = Enum.Material.DiamondPlate
	spawn.Parent = map

	-- Zombie spawns
	zombieSpawn(map, Vector3.new(34, 3.1, 34), "A")
	zombieSpawn(map, Vector3.new(-34, 3.1, 34), "A")
	zombieSpawn(map, Vector3.new(34, 3.1, -34), "A")
	zombieSpawn(map, Vector3.new(-34, 3.1, 5), "A")
	zombieSpawn(map, Vector3.new(24, 3.1, -95), "B")
	zombieSpawn(map, Vector3.new(-24, 3.1, -50), "B")
	zombieSpawn(map, Vector3.new(24, 3.1, -55), "B")

	-- Wall-buys
	wallBuy(map, "SMG", Vector3.new(39.8, 6, 0), Vector3.new(0.4, 3, 5))
	wallBuy(map, "Shotgun", Vector3.new(-39.8, 6, 12), Vector3.new(0.4, 3, 5))
	wallBuy(map, "Rifle", Vector3.new(-29.8, 6, -70), Vector3.new(0.4, 3, 5))

	-- Mystery box
	local box = part(map, "MysteryBox", Vector3.new(6, 3, 3), CFrame.new(18, 1.6, -93), Color3.fromRGB(110, 70, 35), Enum.Material.Wood)
	box:SetAttribute("Interact", "MysteryBox")
	label(box, "? MYSTERY BOX ?\n" .. Config.MysteryBoxCost, Color3.fromRGB(120, 200, 255), 3.5)
	local boxLight = Instance.new("PointLight")
	boxLight.Range = 14
	boxLight.Brightness = 3
	boxLight.Color = Color3.fromRGB(90, 170, 255)
	boxLight.Parent = box

	-- Perk machines
	local function perkMachine(perkId, pos)
		local perk = Config.Perks[perkId]
		local m = part(map, "Perk_" .. perkId, Vector3.new(4, 8, 3), CFrame.new(pos), perk.Color, Enum.Material.Neon)
		m:SetAttribute("Interact", "Perk")
		m:SetAttribute("Perk", perkId)
		label(m, perk.DisplayName .. "\n" .. perk.Cost, Color3.new(1, 1, 1), 5.5)
		local l = Instance.new("PointLight")
		l.Range = 12
		l.Brightness = 2
		l.Color = perk.Color
		l.Parent = m
	end
	perkMachine("ToughBrew", Vector3.new(-33, 4.1, -33))
	perkMachine("QuickHands", Vector3.new(-24, 4.1, -96))

	map.Parent = workspace
	return map
end

return MapBuilder
